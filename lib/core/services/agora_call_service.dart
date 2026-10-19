import 'dart:async';
import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/call_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Active Call UI States
enum CallUiState {
  idle,
  connecting, // Local agent initializing RTC & joining channel
  ringing, // Local agent joined channel, waiting for customer
  connected, // Remote customer joined, 2-way audio established
  ended, // Call terminated cleanly
  failed, // Error during initialization, token generation, or network
}

/// Service managing Agora RTC Voice Calling and Supabase Calls RPCs.
class AgoraCallService {
  static final AgoraCallService instance = AgoraCallService._();
  AgoraCallService._();

  /// Validate if a string is a standard UUID
  static bool isValidUuid(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id.trim());
  }

  RtcEngine? _engine;
  RealtimeChannel? _callRealtimeChannel;
  Timer? _durationTimer;
  Timer? _missedTimeoutTimer;
  Timer? _remoteStatusPollTimer;
  bool _isEnding = false;
  DateTime? _lastAudioHeartbeatTime;

  // Reactive State Notifiers
  final ValueNotifier<CallUiState> callState = ValueNotifier<CallUiState>(
    CallUiState.idle,
  );
  final ValueNotifier<CallModel?> currentCall = ValueNotifier<CallModel?>(null);
  final ValueNotifier<int> callDurationSeconds = ValueNotifier<int>(0);
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSpeakerOn = ValueNotifier<bool>(true);
  final ValueNotifier<int?> remoteUid = ValueNotifier<int?>(null);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  /// Check if an active or incoming call session is running
  bool get hasActiveCall =>
      callState.value != CallUiState.idle &&
      callState.value != CallUiState.ended &&
      callState.value != CallUiState.failed;

  // ===========================================================================
  // 1. ACCEPT CALL WORKFLOW
  // ===========================================================================

  /// Checks and requests microphone permission.
  /// Throws user-actionable error if permission is denied or permanently blocked.
  Future<void> _checkAndRequestMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      debugPrint('[AgoraCallService] Microphone permission already granted.');
      return;
    }

    final result = await Permission.microphone.request();
    if (result.isGranted) {
      debugPrint('[AgoraCallService] Microphone permission granted by user.');
      return;
    }

    if (result.isPermanentlyDenied) {
      throw 'Microphone permission is permanently denied. Please allow microphone access in device Settings.';
    }
    throw 'Microphone permission was denied. Cannot connect voice call.';
  }

  /// Accepts an incoming call:
  /// 1. Requests mic permission.
  /// 2. Verifies call is still ringing.
  /// 3. Invokes accept_call RPC.
  /// 4. Requests token via generate-agora-token Edge Function.
  /// 5. Initializes Agora RTC Engine and joins channel.
  Future<bool> acceptIncomingCall(CallModel call) async {
    if (_isEnding) return false;
    _isEnding = false;
    errorMessage.value = null;
    callState.value = CallUiState.connecting;
    currentCall.value = call;
    callDurationSeconds.value = 0;
    remoteUid.value = null;
    isMuted.value = false;
    isSpeakerOn.value = true;

    try {
      // Step 1: Request Microphone Permission
      await _checkAndRequestMicPermission();

      // Step 2: Verify call record is still ringing in database
      final latestCallRes = await SupabaseService.client
          .from('calls')
          .select()
          .eq('id', call.id)
          .maybeSingle();

      if (latestCallRes == null) {
        throw 'Call was not found.';
      }
      final latestStatus = (latestCallRes['status'] as String? ?? '')
          .toLowerCase();
      if (latestStatus != 'ringing' &&
          latestStatus != 'initiated' &&
          latestStatus != 'accepted') {
        throw 'Call is no longer active (status: $latestStatus).';
      }

      final String? bookingId =
          (call.bookingId != null && call.bookingId!.trim().isNotEmpty)
          ? call.bookingId!.trim()
          : (latestCallRes['booking_id'] as String?)?.trim();

      // Step 3: Invoke accept_call RPC
      debugPrint('[AgoraCallService] Calling RPC accept_call for ${call.id}');
      if (isValidUuid(call.id)) {
        await SupabaseService.client.rpc(
          'accept_call',
          params: {'p_call_id': call.id},
        );
      }

      // Step 4: Request Agora Token from Edge Function (join existing call)
      debugPrint(
        '[AgoraCallService] Requesting token to join call ${call.id} (booking: $bookingId)',
      );
      final CallTokenData tokenData = await _fetchAgoraToken(
        callId: call.id,
        bookingId: bookingId,
        action: 'join',
      );

      // Step 5: Initialize Agora RTC & Join Channel
      await _initAgoraAndJoin(call, tokenData);

      // Step 6: Listen to Realtime updates on this specific call for hangup
      if (isValidUuid(call.id)) {
        _subscribeToCallRecord(call.id);
      }

      return true;
    } catch (e) {
      debugPrint('[AgoraCallService] Error accepting call: $e');
      errorMessage.value = e.toString();
      callState.value = CallUiState.failed;
      await _cleanupEngine();
      return false;
    }
  }

  // ===========================================================================
  // 2. OUTGOING / AGENT CALL INITIATION VIA AGORA
  // ===========================================================================

  /// Initiates an outgoing Agora voice call to the customer:
  /// 1. Requests mic permission.
  /// 2. Requests Agora RTC token from generate-agora-token with booking_id and action: 'create'.
  /// 3. Resolves the call record and sets currentCall.
  /// 4. Initializes Agora RTC Engine and joins the channel.
  /// 5. Subscribes to public.calls via Realtime to wait for customer response.
  Future<CallModel?> startOutgoingCall({
    required String customerName,
    String? customerPhone,
    String? customerId,
    required String bookingId,
    String? serviceTitle,
  }) async {
    if (_isEnding) return null;
    _isEnding = false;
    errorMessage.value = null;
    callState.value = CallUiState.connecting;
    callDurationSeconds.value = 0;
    remoteUid.value = null;
    isMuted.value = false;
    isSpeakerOn.value = true;

    try {
      final cleanBookingId = bookingId.trim();
      if (cleanBookingId.isEmpty) {
        throw 'booking_id is required to initiate a call';
      }

      // Step 1: Request Microphone Permission
      await _checkAndRequestMicPermission();

      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw 'You must be logged in to make in-app voice calls.';
      }

      // Step 2: Resolve receiver (customer) UUID and details
      String receiverId = (customerId != null && customerId.trim().isNotEmpty)
          ? customerId.trim()
          : '';

      String resolvedCustomerName = customerName.trim();
      String? resolvedCustomerPhone = customerPhone?.trim();

      if (receiverId.isEmpty ||
          resolvedCustomerName.isEmpty ||
          resolvedCustomerName.toLowerCase() == 'customer' ||
          resolvedCustomerPhone == null ||
          resolvedCustomerPhone.isEmpty) {
        try {
          final bookingRes = await SupabaseService.client
              .from('bookings')
              .select('customer_id')
              .eq('id', cleanBookingId)
              .maybeSingle();
          if (bookingRes != null && bookingRes['customer_id'] != null) {
            receiverId = bookingRes['customer_id'].toString().trim();
          }
        } catch (e) {
          debugPrint('[AgoraCallService] Error fetching booking for customer_id: $e');
        }
      }

      // Enrich customer name & phone directly from public.users table
      if (receiverId.isNotEmpty) {
        try {
          final userRes = await SupabaseService.client
              .from('users')
              .select()
              .eq('id', receiverId)
              .maybeSingle();
          if (userRes != null) {
            final realName = (userRes['full_name'] ??
                    userRes['name'] ??
                    userRes['display_name'])
                ?.toString()
                .trim();
            final realPhone = (userRes['phone'] ??
                    userRes['phone_number'] ??
                    userRes['mobile'])
                ?.toString()
                .trim();

            if (realName != null &&
                realName.isNotEmpty &&
                realName.toLowerCase() != 'customer') {
              resolvedCustomerName = realName;
            }
            if (realPhone != null && realPhone.isNotEmpty) {
              resolvedCustomerPhone = realPhone;
            }
          }
        } catch (e) {
          debugPrint('[AgoraCallService] Error resolving user profile: $e');
        }
      }

      if (receiverId.isEmpty) {
        throw 'Cannot initiate call: Customer account reference is missing.';
      }

      final channelName = 'sw_${cleanBookingId.replaceAll("-", "")}';
      String? callId;

      // Step 3: Check for existing ringing call initiated by this agent within 60s
      try {
        final existingCalls = await SupabaseService.client
            .from('calls')
            .select('id, caller_id, status, created_at, channel_name')
            .eq('booking_id', cleanBookingId)
            .inFilter('status', ['ringing', 'accepted'])
            .order('created_at', ascending: false)
            .limit(1);

        if (existingCalls.isNotEmpty) {
          final existing = existingCalls.first;
          final existingCaller = existing['caller_id']?.toString();
          final createdStr = existing['created_at']?.toString();
          final createdAt = createdStr != null ? DateTime.tryParse(createdStr) : null;
          final ageMs = createdAt != null
              ? DateTime.now().difference(createdAt).inMilliseconds
              : 999999;

          if (existingCaller == currentUser.id &&
              existing['status'] == 'ringing' &&
              ageMs < 60000) {
            callId = existing['id'].toString();
            debugPrint('[AgoraCallService] Reusing active ringing call session: $callId');
          } else if (existing['status'] == 'ringing' && ageMs >= 60000) {
            await SupabaseService.client.from('calls').update({
              'status': 'missed',
              'ended_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('id', existing['id']);
          }
        }
      } catch (checkErr) {
        debugPrint('[AgoraCallService] Error checking existing calls: $checkErr');
      }

      // Step 4: Insert new call record using the authenticated agent client session
      if (callId == null) {
        debugPrint(
          '[AgoraCallService] Creating call record in public.calls: '
          'booking=$cleanBookingId, caller=${currentUser.id}, receiver=$receiverId',
        );
        final inserted = await SupabaseService.client
            .from('calls')
            .insert({
              'booking_id': cleanBookingId,
              'caller_id': currentUser.id,
              'receiver_id': receiverId,
              'channel_name': channelName,
              'status': 'ringing',
            })
            .select('id, channel_name, status, created_at')
            .single();

        callId = inserted['id']?.toString();
      }

      if (callId == null || callId.isEmpty) {
        throw 'Failed to initialize call session in database.';
      }

      // Step 5: Request Agora RTC Token for this call_id from Edge Function (action: 'join')
      debugPrint(
        '[AgoraCallService] Requesting Agora RTC Token for call_id: $callId (action: join)',
      );
      final CallTokenData tokenData = await _fetchAgoraToken(
        callId: callId,
        bookingId: cleanBookingId,
        action: 'join',
      );

      // Step 6: Construct CallModel
      final call = CallModel(
        id: callId,
        callerId: currentUser.id,
        receiverId: receiverId,
        bookingId: cleanBookingId,
        status: CallStatus.ringing,
        channelName: tokenData.channelName.isNotEmpty ? tokenData.channelName : channelName,
        createdAt: DateTime.now(),
        callerName: resolvedCustomerName.isNotEmpty ? resolvedCustomerName : 'Customer',
        callerPhone: resolvedCustomerPhone,
        serviceTitle: serviceTitle,
      );

      currentCall.value = call;

      // Step 7: Initialize Agora Engine and Join Channel
      await _initAgoraAndJoin(call, tokenData);

      // Step 8: Listen for customer response via Realtime
      if (isValidUuid(call.id)) {
        _subscribeToCallRecord(call.id);
      }

      // Step 9: 45-Second Missed Call Timeout
      _missedTimeoutTimer?.cancel();
      _missedTimeoutTimer = Timer(const Duration(seconds: 45), () async {
        if (callState.value == CallUiState.ringing ||
            callState.value == CallUiState.connecting) {
          debugPrint(
            '[AgoraCallService] Outgoing call timed out after 45s without answer.',
          );
          if (isValidUuid(call.id)) {
            await markCallMissed(call.id);
          }
          await endCall(callId: call.id, sendEndRpc: false);
        }
      });

      return call;
    } catch (e) {
      debugPrint('[AgoraCallService] Error starting outgoing Agora call: $e');
      errorMessage.value = e.toString();
      callState.value = CallUiState.failed;
      await _cleanupEngine();
      return null;
    }
  }

  /// Join existing call channel (e.g. if initiated from booking)
  Future<bool> joinActiveCall({
    required String callId,
    required CallModel call,
  }) async {
    if (_isEnding) return false;
    _isEnding = false;
    errorMessage.value = null;
    callState.value = CallUiState.connecting;
    currentCall.value = call;
    callDurationSeconds.value = 0;
    remoteUid.value = null;
    isMuted.value = false;
    isSpeakerOn.value = true;

    try {
      await _checkAndRequestMicPermission();

      final CallTokenData tokenData = await _fetchAgoraToken(
        callId: callId,
        bookingId: call.bookingId,
        action: 'join',
      );
      await _initAgoraAndJoin(call, tokenData);
      _subscribeToCallRecord(callId);
      return true;
    } catch (e) {
      debugPrint('[AgoraCallService] Error joining call: $e');
      errorMessage.value = e.toString();
      callState.value = CallUiState.failed;
      await _cleanupEngine();
      return false;
    }
  }

  // ===========================================================================
  // 3. DECLINE & MISSED RPCs
  // ===========================================================================

  /// Declines an incoming call using decline_call RPC
  Future<void> declineIncomingCall(String callId) async {
    try {
      if (isValidUuid(callId)) {
        debugPrint('[AgoraCallService] Invoking decline_call RPC for $callId');
        try {
          await SupabaseService.client.rpc(
            'decline_call',
            params: {'p_call_id': callId},
          );
        } catch (rpcErr) {
          debugPrint('[AgoraCallService] decline_call RPC notice: $rpcErr');
          await SupabaseService.client.from('calls').update({
            'status': 'declined',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', callId);
        }
      }
    } catch (e) {
      debugPrint('[AgoraCallService] Error declining call: $e');
    } finally {
      await endCall(callId: callId, sendEndRpc: false);
    }
  }

  /// Marks a ringing call as missed after 45-second timeout
  Future<void> markCallMissed(String callId) async {
    if (!isValidUuid(callId)) return;
    try {
      debugPrint(
        '[AgoraCallService] Invoking mark_call_missed RPC for $callId',
      );
      try {
        await SupabaseService.client.rpc(
          'mark_call_missed',
          params: {'p_call_id': callId},
        );
      } catch (rpcErr) {
        debugPrint('[AgoraCallService] mark_call_missed RPC notice: $rpcErr');
        await SupabaseService.client.from('calls').update({
          'status': 'missed',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', callId);
      }
    } catch (e) {
      debugPrint('[AgoraCallService] Error marking call missed: $e');
    }
  }

  // ===========================================================================
  // 4. END ACTIVE CALL
  // ===========================================================================

  /// Cleanly terminates active or ringing call:
  /// - Invokes end_call RPC (if requested and call was active)
  /// - Leaves Agora channel
  /// - Releases RTC engine
  /// - Stops duration timer
  Future<void> endCall({String? callId, bool sendEndRpc = true}) async {
    if (_isEnding) return;
    _isEnding = true;
    _lastAudioHeartbeatTime = null;

    final resolvedCallId = currentCall.value?.id ?? callId;
    final isUuid = isValidUuid(resolvedCallId);
    final targetCallId = isUuid ? resolvedCallId : null;
    debugPrint(
      '[AgoraCallService] Ending call $resolvedCallId (targetUuid: $targetCallId, sendRpc: $sendEndRpc)',
    );

    // Step 1: Immediately cancel all timers to stop ticker & timeouts
    _durationTimer?.cancel();
    _durationTimer = null;
    _missedTimeoutTimer?.cancel();
    _missedTimeoutTimer = null;
    _remoteStatusPollTimer?.cancel();
    _remoteStatusPollTimer = null;

    // Step 2: Immediately notify UI listeners that the call has ended
    remoteUid.value = null;
    callState.value = CallUiState.ended;

    // Step 3: Unsubscribe from Realtime and polling
    _unsubscribeCallRecord();

    // Step 4: Dispatch backend end_call update asynchronously in background (never blocks UI pop)
    if (sendEndRpc && targetCallId != null) {
      unawaited(_sendEndCallUpdate(targetCallId));
    }

    // Step 5: Clean up Agora Engine
    try {
      await _cleanupEngine();
    } catch (e) {
      debugPrint('[AgoraCallService] Note during engine cleanup in endCall: $e');
    }

    // Reset to idle state after brief UI animation window
    Future.delayed(const Duration(milliseconds: 600), () {
      callState.value = CallUiState.idle;
      currentCall.value = null;
      callDurationSeconds.value = 0;
      remoteUid.value = null;
      errorMessage.value = null;
      isSpeakerOn.value = true;
      isMuted.value = false;
      _isEnding = false;
    });
  }

  /// Sends end_call RPC or fallback direct database update asynchronously in background
  Future<void> _sendEndCallUpdate(String targetCallId) async {
    try {
      await SupabaseService.client.rpc(
        'end_call',
        params: {'p_call_id': targetCallId},
      );
      debugPrint('[AgoraCallService] Background RPC end_call completed for $targetCallId');
    } catch (e) {
      debugPrint(
        '[AgoraCallService] RPC end_call notice: $e; falling back to direct table update',
      );
      try {
        final updates = <String, dynamic>{
          'status': 'ended',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (callDurationSeconds.value > 0) {
          updates['duration_seconds'] = callDurationSeconds.value;
        }
        await SupabaseService.client
            .from('calls')
            .update(updates)
            .eq('id', targetCallId);
      } catch (err) {
        debugPrint('[AgoraCallService] Direct table update for endCall error: $err');
      }
    }
  }

  // ===========================================================================
  // 5. IN-CALL CONTROLS (MUTE, SPEAKERPHONE)
  // ===========================================================================

  /// Toggles local microphone mute
  Future<void> toggleMute(bool muted) async {
    isMuted.value = muted;
    if (_engine == null) return;
    try {
      await _engine!.muteLocalAudioStream(muted);
      debugPrint('[AgoraCallService] Local microphone muted: $muted');
    } catch (e) {
      debugPrint('[AgoraCallService] Failed to mute/unmute: $e');
    }
  }

  /// Toggles speakerphone vs earpiece
  Future<void> toggleSpeaker(bool speakerOn) async {
    isSpeakerOn.value = speakerOn;
    if (_engine == null) return;
    try {
      await _engine!.setEnableSpeakerphone(speakerOn);
      await _engine!.adjustPlaybackSignalVolume(400);
      final currentRemoteUid = remoteUid.value;
      if (currentRemoteUid != null && currentRemoteUid > 0) {
        await _engine!.adjustUserPlaybackSignalVolume(
          uid: currentRemoteUid,
          volume: 400,
        );
      }
      debugPrint('[AgoraCallService] Speakerphone enabled: $speakerOn (playback boosted to 400%)');
    } catch (e) {
      debugPrint('[AgoraCallService] Failed to toggle speaker: $e');
    }
  }

  // ===========================================================================
  // 6. AGORA RTC INITIALIZATION & EVENT HANDLERS
  // ===========================================================================

  Future<void> _initAgoraAndJoin(
    CallModel call,
    CallTokenData tokenData,
  ) async {
    if (tokenData.appId.isEmpty) {
      throw 'Agora App ID is missing from server response.';
    }
    if (tokenData.token.isEmpty) {
      throw 'Agora Token is missing from server response.';
    }
    if (tokenData.channelName.isEmpty) {
      throw 'Agora Channel Name is missing from server response.';
    }

    // Step 0: Release previous engine if present
    _lastAudioHeartbeatTime = null;
    debugPrint(
      '[AgoraDiagnostics] Step 0: Cleaning up previous engine if any...',
    );
    await _cleanupEngine();

    // Step 1: Create and initialize engine
    debugPrint(
      '[AgoraDiagnostics] Step 1: Initializing RTC Engine with appId: ${tokenData.appId}...',
    );
    final engine = createAgoraRtcEngine();
    _engine = engine;

    try {
      await engine.initialize(
        RtcEngineContext(
          appId: tokenData.appId.trim(),
          channelProfile: ChannelProfileType.channelProfileCommunication,
          audioScenario: AudioScenarioType.audioScenarioDefault,
        ),
      );
      debugPrint('[AgoraDiagnostics] Step 1: Engine initialization SUCCESS.');
    } catch (e, st) {
      debugPrint(
        '[AgoraDiagnostics] Step 1: Engine initialization FAILED: $e\n$st',
      );
      rethrow;
    }

    // Step 2: Register Callbacks
    debugPrint('[AgoraAudioDiag] Step 2: Registering event handlers...');
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          debugPrint(
            '[AgoraAudioDiag] [onJoinChannelSuccess] Joined channel: ${connection.channelId}, localUid: ${connection.localUid}, elapsed: ${elapsed}ms',
          );
          // Local participant joined; state is ringing until remote user joins
          if (callState.value == CallUiState.connecting) {
            callState.value = CallUiState.ringing;
          }

          // Apply audio routing upon successful channel join
          try {
            await engine.setEnableSpeakerphone(isSpeakerOn.value);
            await engine.adjustRecordingSignalVolume(400);
            await engine.adjustPlaybackSignalVolume(400);
            debugPrint(
              '[AgoraAudioDiag] Applied speakerphone setting: ${isSpeakerOn.value} with 400% volume boost',
            );
          } catch (e) {
            debugPrint(
              '[AgoraAudioDiag] setEnableSpeakerphone in onJoinChannelSuccess note: $e',
            );
          }

          // Ensure local microphone transmission state matches isMuted
          try {
            await engine.muteLocalAudioStream(isMuted.value);
          } catch (e) {
            debugPrint(
              '[AgoraAudioDiag] muteLocalAudioStream in onJoinChannelSuccess note: $e',
            );
          }
        },

        // CRITICAL: Only transition to 'connected' when remote user joins!
        onUserJoined: (RtcConnection connection, int remoteId, int elapsed) async {
          debugPrint(
            '[AgoraCallScreen] Remote user joined: $remoteId. Call connected!',
          );
          debugPrint(
            '[AgoraAudioDiag] Remote user joined: $remoteId. Call connected!',
          );
          _missedTimeoutTimer?.cancel();
          _missedTimeoutTimer = null;
          remoteUid.value = remoteId;
          callState.value = CallUiState.connected;
          _startDurationTimer();

          // Explicitly ensure remote audio track is unmuted and set playback volume to 400% (boosted)
          try {
            await engine.muteRemoteAudioStream(uid: remoteId, mute: false);
            await engine.adjustUserPlaybackSignalVolume(
              uid: remoteId,
              volume: 400,
            );
            await engine.adjustPlaybackSignalVolume(400);
            await engine.setEnableSpeakerphone(isSpeakerOn.value);
            debugPrint(
              '[AgoraAudioDiag] Configured boosted playback volume (400%) and speakerphone for UID: $remoteId',
            );
          } catch (e) {
            debugPrint(
              '[AgoraAudioDiag] Note configuring remote playback volume: $e',
            );
          }

          // Record connection timestamp in database
          final activeCallId = currentCall.value?.id ?? call.id;
          if (isValidUuid(activeCallId)) {
            try {
              await SupabaseService.client.rpc(
                'record_call_connected',
                params: {'p_call_id': activeCallId},
              );
            } catch (_) {
              try {
                await SupabaseService.client.from('calls').update({
                  'connected_at': DateTime.now().toUtc().toIso8601String(),
                }).eq('id', activeCallId);
              } catch (_) {}
            }
          }
        },

        onUserOffline:
            (
              RtcConnection connection,
              int remoteId,
              UserOfflineReasonType reason,
            ) {
              debugPrint(
                '[AgoraAudioDiag] onUserOffline: remoteUid=$remoteId, reason=$reason (Customer cut or disconnected call)',
              );
              // Customer disconnected or hung up -> cut call immediately without waiting
              endCall(callId: call.id, sendEndRpc: false);
            },

        onAudioPublishStateChanged:
            (
              String channel,
              StreamPublishState oldState,
              StreamPublishState newState,
              int elapse,
            ) {
              debugPrint(
                '[AgoraAudioDiag] onAudioPublishStateChanged: channel=$channel, oldState=$oldState, newState=$newState, elapse=${elapse}ms',
              );
              if (newState == StreamPublishState.pubStatePublished) {
                debugPrint(
                  '[AgoraAudioDiag] >>> LOCAL MICROPHONE AUDIO PUBLISHED TO AGORA <<<',
                );
              }
            },

        onAudioSubscribeStateChanged:
            (
              String channel,
              int uid,
              StreamSubscribeState oldState,
              StreamSubscribeState newState,
              int elapse,
            ) {
              debugPrint(
                '[AgoraAudioDiag] onAudioSubscribeStateChanged: channel=$channel, remoteUid=$uid, oldState=$oldState, newState=$newState, elapse=${elapse}ms',
              );
              if (newState == StreamSubscribeState.subStateSubscribed) {
                debugPrint(
                  '[AgoraAudioDiag] >>> REMOTE AUDIO TRACK SUBSCRIBED FOR UID: $uid <<<',
                );
              }
            },

        onRemoteAudioStateChanged:
            (
              RtcConnection connection,
              int remoteId,
              RemoteAudioState state,
              RemoteAudioStateReason reason,
              int elapsed,
            ) async {
              debugPrint(
                '[AgoraAudioDiag] onRemoteAudioStateChanged: remoteUid=$remoteId, state=$state, reason=$reason, elapsed=${elapsed}ms',
              );
              if (state == RemoteAudioState.remoteAudioStateDecoding ||
                  state == RemoteAudioState.remoteAudioStateStarting) {
                debugPrint(
                  '[AgoraAudioDiag] >>> REMOTE AUDIO DECODING AND PLAYING OUT (UID: $remoteId) <<<',
                );
                try {
                  await engine.adjustUserPlaybackSignalVolume(
                    uid: remoteId,
                    volume: 400,
                  );
                  await engine.adjustPlaybackSignalVolume(400);
                  await engine.setEnableSpeakerphone(isSpeakerOn.value);
                } catch (_) {}
                if (callState.value != CallUiState.connected) {
                  _missedTimeoutTimer?.cancel();
                  _missedTimeoutTimer = null;
                  remoteUid.value = remoteId;
                  callState.value = CallUiState.connected;
                  _startDurationTimer();
                }
              }
            },

        onLocalAudioStateChanged:
            (
              RtcConnection connection,
              LocalAudioStreamState state,
              LocalAudioStreamReason reason,
            ) {
              debugPrint(
                '[AgoraAudioDiag] onLocalAudioStateChanged: state=$state, reason=$reason (local mic state)',
              );
              if (state ==
                  LocalAudioStreamState.localAudioStreamStateRecording) {
                debugPrint(
                  '[AgoraAudioDiag] >>> LOCAL MICROPHONE HARDWARE IS CAPTURING AUDIO <<<',
                );
              } else if (state ==
                  LocalAudioStreamState.localAudioStreamStateEncoding) {
                debugPrint(
                  '[AgoraAudioDiag] >>> LOCAL AUDIO ENCODER ACTIVE <<<',
                );
              } else if (state ==
                  LocalAudioStreamState.localAudioStreamStateFailed) {
                debugPrint(
                  '[AgoraAudioDiag] !!! LOCAL AUDIO CAPTURE FAILED: $reason !!!',
                );
              }
            },

        onAudioRoutingChanged: (int routing) {
          debugPrint(
            '[AgoraAudioDiag] onAudioRoutingChanged: routing=$routing (0: default, 1: headset, 2: earpiece, 3: speakerphone, 4/5: bluetooth)',
          );
        },

        onAudioVolumeIndication:
            (
              RtcConnection connection,
              List<AudioVolumeInfo> speakers,
              int totalVolume,
              int vad,
            ) {
              int localMicVol = 0;
              int remoteAudioVol = 0;

              for (final speaker in speakers) {
                final speakerUid = speaker.uid ?? 0;
                final vol = speaker.volume ?? 0;
                final isLocal = (speakerUid == 0 || speakerUid == tokenData.uid);

                if (isLocal) {
                  if (vol > localMicVol) localMicVol = vol;
                  if (vol > 0) {
                    debugPrint(
                      '[AgoraAudioDiag] Local mic capturing audio: volume=$vol, vad=$vad, totalVol=$totalVolume',
                    );
                  }
                } else {
                  if (vol > remoteAudioVol) remoteAudioVol = vol;
                  if (vol > 0) {
                    debugPrint(
                      '[AgoraAudioDiag] Remote audio received: speakerUid=$speakerUid, volume=$vol, totalVol=$totalVolume',
                    );
                  }
                }
              }

              // Periodic 4-second audio level heartbeat for silence / hardware mic diagnostics
              final now = DateTime.now();
              if (_lastAudioHeartbeatTime == null ||
                  now.difference(_lastAudioHeartbeatTime!).inSeconds >= 4) {
                _lastAudioHeartbeatTime = now;
                final localDesc = localMicVol > 0
                    ? 'Local mic ACTIVE'
                    : 'Local mic reporting 0/silence';
                final remoteDesc = remoteAudioVol > 0
                    ? 'Remote audio ACTIVE'
                    : 'Remote audio reporting 0/silence';
                debugPrint(
                  '[AgoraAudioDiag] Audio level heartbeat: '
                  'localMicVol=$localMicVol, remoteAudioVol=$remoteAudioVol, totalVol=$totalVolume '
                  '($localDesc) ($remoteDesc)',
                );
              }
            },

        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              debugPrint(
                '[AgoraAudioDiag] onConnectionStateChanged: state=$state, reason=$reason',
              );
              if (state == ConnectionStateType.connectionStateFailed) {
                errorMessage.value = 'Voice connection failed: $reason';
                callState.value = CallUiState.failed;
              }
            },

        onTokenPrivilegeWillExpire:
            (RtcConnection connection, String oldToken) async {
              debugPrint(
                '[AgoraAudioDiag] [onTokenPrivilegeWillExpire] Agora token privilege will expire. Refreshing token...',
              );
              try {
                final refreshedTokenData = await _fetchAgoraToken(
                  callId: call.id,
                  bookingId: call.bookingId,
                  action: 'refresh',
                );
                await engine.renewToken(refreshedTokenData.token);
                debugPrint(
                  '[AgoraAudioDiag] Successfully renewed Agora token.',
                );
              } catch (e) {
                debugPrint('[AgoraAudioDiag] Failed to renew token: $e');
              }
            },

        onError: (ErrorCodeType err, String msg) {
          debugPrint(
            '[AgoraAudioDiag] [onError] Agora error code: $err, message: $msg',
          );
          if (callState.value != CallUiState.ended) {
            errorMessage.value = 'Agora Voice Error ($err): $msg';
            if (err == ErrorCodeType.errTokenExpired ||
                err == ErrorCodeType.errInvalidToken) {
              callState.value = CallUiState.failed;
            }
          }
        },

        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint(
            '[AgoraAudioDiag] [onLeaveChannel] Left channel: ${connection.channelId}',
          );
        },
      ),
    );
    debugPrint('[AgoraAudioDiag] Step 2: Event handlers registered.');

    // Step 3: Audio configuration for crystal-clear 2-way VoIP
    debugPrint('[AgoraDiagnostics] Step 3: Configuring audio settings...');

    // 3a. Enable audio module
    try {
      await engine.enableAudio();
      debugPrint('[AgoraDiagnostics] Step 3a: enableAudio SUCCESS.');
    } catch (e) {
      debugPrint('[AgoraDiagnostics] Step 3a: enableAudio WARNING: $e');
    }

    // 3b. Explicitly enable local audio capture (microphone ADC hardware)
    try {
      await engine.enableLocalAudio(true);
      debugPrint('[AgoraDiagnostics] Step 3b: enableLocalAudio(true) SUCCESS.');
    } catch (e) {
      debugPrint('[AgoraDiagnostics] Step 3b: enableLocalAudio WARNING: $e');
    }

    // 3c. Set client role to Broadcaster (publisher)
    try {
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      debugPrint(
        '[AgoraDiagnostics] Step 3c: setClientRole(broadcaster) SUCCESS.',
      );
    } catch (e) {
      debugPrint('[AgoraDiagnostics] Step 3c: setClientRole WARNING: $e');
    }

    // 3d. Ensure local audio track is NOT muted
    try {
      await engine.muteLocalAudioStream(false);
      debugPrint(
        '[AgoraDiagnostics] Step 3d: muteLocalAudioStream(false) SUCCESS.',
      );
    } catch (e) {
      debugPrint(
        '[AgoraDiagnostics] Step 3d: muteLocalAudioStream WARNING: $e',
      );
    }

    // 3e. Ensure remote audio tracks are NOT muted
    try {
      await engine.muteAllRemoteAudioStreams(false);
      debugPrint(
        '[AgoraDiagnostics] Step 3e: muteAllRemoteAudioStreams(false) SUCCESS.',
      );
    } catch (e) {
      debugPrint(
        '[AgoraDiagnostics] Step 3e: muteAllRemoteAudioStreams WARNING: $e',
      );
    }

    // 3f. Set audio profile and scenario for clear speech with voice enhancements
    try {
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioDefault,
      );
      debugPrint(
        '[AgoraAudioDiag] Step 3f: setAudioProfile(audioProfileSpeechStandard, audioScenarioDefault) SUCCESS.',
      );
    } catch (e) {
      debugPrint('[AgoraAudioDiag] Step 3f: setAudioProfile WARNING: $e');
    }

    // 3g. Boosted volume levels (400% maximum digital gain for loud, clear VoIP)
    try {
      await engine.adjustRecordingSignalVolume(400);
      await engine.adjustPlaybackSignalVolume(400);
      debugPrint(
        '[AgoraAudioDiag] Step 3g: adjust Signal Volumes to 400% (boosted) SUCCESS.',
      );
    } catch (e) {
      debugPrint(
        '[AgoraAudioDiag] Step 3g: adjust Signal Volumes WARNING: $e',
      );
    }

    // 3h. Enable audio volume indication (metering)
    try {
      await engine.enableAudioVolumeIndication(
        interval: 300,
        smooth: 3,
        reportVad: true,
      );
      debugPrint(
        '[AgoraAudioDiag] Step 3h: enableAudioVolumeIndication SUCCESS.',
      );
    } catch (e) {
      debugPrint(
        '[AgoraAudioDiag] Step 3h: enableAudioVolumeIndication WARNING: $e',
      );
    }

    // 3i. Set default audio route (speakerphone enabled by default matching Customer app)
    try {
      await engine.setDefaultAudioRouteToSpeakerphone(true);
      debugPrint(
        '[AgoraDiagnostics] Step 3i: setDefaultAudioRouteToSpeakerphone(true) SUCCESS.',
      );
    } catch (e) {
      debugPrint(
        '[AgoraDiagnostics] Step 3i: setDefaultAudioRouteToSpeakerphone note: $e',
      );
    }

    // Step 4: Log safe diagnostics immediately before joining
    final tokenTrimmed = tokenData.token.trim();
    final bool tokenIsEmpty = tokenTrimmed.isEmpty;
    final int tokenLength = tokenTrimmed.length;

    debugPrint('================ [AGORA SAFE DIAGNOSTICS] ================');
    debugPrint('Token is empty: $tokenIsEmpty');
    debugPrint('Token length: $tokenLength (token contents hidden)');
    debugPrint('Returned app_id: ${tokenData.appId}');
    debugPrint('Returned channel_name: ${tokenData.channelName}');
    debugPrint('Returned UID: ${tokenData.uid}');
    debugPrint('===========================================================');

    // Step 5: Join Channel with explicit ChannelMediaOptions for 2-way audio
    debugPrint(
      '[AgoraDiagnostics] Step 5: Invoking joinChannel for ${tokenData.channelName} with assigned UID ${tokenData.uid}...',
    );
    try {
      await engine.joinChannel(
        token: tokenTrimmed,
        channelId: tokenData.channelName.trim(),
        uid: tokenData.uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          enableAudioRecordingOrPlayout: true,
        ),
      );
      debugPrint('[AgoraDiagnostics] Step 5: joinChannel call completed.');
    } catch (e, st) {
      debugPrint('[AgoraDiagnostics] Step 5: joinChannel FAILED: $e\n$st');
      rethrow;
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    callDurationSeconds.value = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      callDurationSeconds.value++;
    });
  }

  Future<void> _cleanupEngine() async {
    _lastAudioHeartbeatTime = null;
    final engine = _engine;
    _engine = null;

    if (engine != null) {
      try {
        await engine.leaveChannel();
      } catch (e) {
        debugPrint(
          '[AgoraCallService] Note on leaveChannel during cleanup: $e',
        );
      }
      try {
        await engine.release();
      } catch (e) {
        debugPrint('[AgoraCallService] Note on release during cleanup: $e');
      }
    }
  }

  // ===========================================================================
  // 7. EDGE FUNCTION TOKEN GENERATION
  // ===========================================================================

  Future<CallTokenData> _fetchAgoraToken({
    String? callId,
    String? bookingId,
    required String action,
  }) async {
    final payload = <String, dynamic>{'action': action};
    if (bookingId != null && bookingId.trim().isNotEmpty) {
      payload['booking_id'] = bookingId.trim();
    }
    if (callId != null && callId.trim().isNotEmpty) {
      payload['call_id'] = callId.trim();
    }

    debugPrint(
      '[AgoraCallService] Invoking generate-agora-token with payload: $payload',
    );

    try {
      final FunctionResponse res = await SupabaseService.client.functions
          .invoke('generate-agora-token', body: payload);

      if (res.status != 200 && res.status != 201) {
        final errorMsg = res.data is Map
            ? (res.data['error'] ?? res.data['message'] ?? res.data)
            : res.data;
        throw 'Edge Function generate-agora-token returned status ${res.status}: $errorMsg';
      }

      if (res.data == null) {
        throw 'No data received from generate-agora-token';
      }

      Map<String, dynamic> rawMap;
      if (res.data is Map<String, dynamic>) {
        rawMap = res.data as Map<String, dynamic>;
      } else if (res.data is Map) {
        rawMap = Map<String, dynamic>.from(res.data as Map);
      } else if (res.data is String) {
        rawMap = jsonDecode(res.data as String) as Map<String, dynamic>;
      } else {
        throw 'Unexpected response format from generate-agora-token: ${res.data}';
      }

      return CallTokenData.fromJson(rawMap);
    } on FunctionException catch (fe) {
      debugPrint(
        '[AgoraCallService] FunctionException: status=${fe.status}, details=${fe.details}, reasonPhrase=${fe.reasonPhrase}',
      );
      final detailMsg = fe.details is Map
          ? (fe.details['error'] ??
                fe.details['message'] ??
                fe.details.toString())
          : fe.details?.toString() ??
                fe.reasonPhrase ??
                'Failed to connect call (status: ${fe.status})';
      throw detailMsg;
    }
  }

  // ===========================================================================
  // 8. REALTIME ACTIVE CALL OBSERVER
  // ===========================================================================

  void _subscribeToCallRecord(String callId) {
    _unsubscribeCallRecord();

    try {
      _callRealtimeChannel = SupabaseService.client
          .channel('public:call_session:$callId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'calls',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: callId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final status = (newRecord['status'] as String? ?? '')
                    .toLowerCase();
                debugPrint(
                  '[AgoraCallService] Active call status update: $status',
                );
                if (status == 'ended' ||
                    status == 'declined' ||
                    status == 'missed') {
                  // Customer or server marked call ended/declined/missed
                  endCall(callId: callId, sendEndRpc: false);
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint(
        '[AgoraCallService] Realtime active call subscription error: $e',
      );
    }

    // Polling safety net: Checks every 1.5s in case Realtime socket disconnects or cellular network drops packets
    _remoteStatusPollTimer?.cancel();
    _remoteStatusPollTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (timer) async {
        if (_isEnding ||
            callState.value == CallUiState.ended ||
            callState.value == CallUiState.idle) {
          timer.cancel();
          return;
        }
        try {
          final res = await SupabaseService.client
              .from('calls')
              .select('status')
              .eq('id', callId)
              .maybeSingle();
          if (res != null) {
            final status = (res['status'] as String? ?? '').toLowerCase();
            if (status == 'ended' ||
                status == 'declined' ||
                status == 'missed') {
              debugPrint(
                '[AgoraCallService] Polling detected customer cut call: $status',
              );
              timer.cancel();
              endCall(callId: callId, sendEndRpc: false);
            }
          }
        } catch (_) {}
      },
    );
  }

  void _unsubscribeCallRecord() {
    _remoteStatusPollTimer?.cancel();
    _remoteStatusPollTimer = null;

    if (_callRealtimeChannel != null) {
      try {
        SupabaseService.client.removeChannel(_callRealtimeChannel!);
      } catch (e) {
        debugPrint('[AgoraCallService] Error removing realtime channel: $e');
      }
      _callRealtimeChannel = null;
    }
  }
}
