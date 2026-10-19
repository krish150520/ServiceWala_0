import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:service_wala_business/core/services/agora_call_service.dart';
import 'package:service_wala_business/core/services/notification_service.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/call_model.dart';
import 'package:service_wala_business/screens/calling/incoming_call_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global manager for listening to incoming voice calls via Supabase Realtime.
class IncomingCallManager {
  static final IncomingCallManager instance = IncomingCallManager._();
  IncomingCallManager._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  RealtimeChannel? _subscriptionChannel;
  String? _listeningAgentId;
  String? _activeIncomingCallId;
  bool _isDialogShowing = false;
  Timer? _ringingPollTimer;

  /// Start listening for incoming calls for the current authenticated Agent.
  void startListening() {
    final user = SupabaseService.currentUser;
    if (user == null) {
      debugPrint(
        '[IncomingCallManager] Cannot start listening: unauthenticated.',
      );
      return;
    }

    if (_listeningAgentId == user.id && _subscriptionChannel != null) {
      // Already subscribed for this agent
      return;
    }

    stopListening();
    _listeningAgentId = user.id;

    debugPrint(
      '[IncomingCallManager] Subscribing to public.calls for receiver_id = ${user.id}',
    );

    try {
      _subscriptionChannel = SupabaseService.client
          .channel('public:agent_incoming_calls:${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'calls',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: user.id,
            ),
            callback: (payload) => _handleCallEvent(payload),
          )
          .subscribe();

      // Check for any currently ringing call
      _checkPendingRingingCall(user.id);
    } catch (e) {
      debugPrint('[IncomingCallManager] Subscription error: $e');
    }
  }

  /// Stop and unsubscribe Realtime listener
  void stopListening() {
    _ringingPollTimer?.cancel();
    _ringingPollTimer = null;

    try {
      FlutterCallkitIncoming.endAllCalls().catchError((_) {});
    } catch (_) {}

    if (_subscriptionChannel != null) {
      try {
        SupabaseService.client.removeChannel(_subscriptionChannel!);
      } catch (e) {
        debugPrint('[IncomingCallManager] Error removing subscription: $e');
      }
      _subscriptionChannel = null;
    }
    _listeningAgentId = null;
    _activeIncomingCallId = null;
    _isDialogShowing = false;
  }

  /// Programmatically dismiss the active in-app incoming call dialog
  void dismissInAppDialog() {
    _ringingPollTimer?.cancel();
    _ringingPollTimer = null;

    if (_isDialogShowing) {
      _activeIncomingCallId = null;
      _isDialogShowing = false;

      final navContext = navigatorKey.currentContext;
      if (navContext != null &&
          Navigator.of(navContext, rootNavigator: true).canPop()) {
        Navigator.of(navContext, rootNavigator: true).pop();
      }
    }
  }

  void _handleCallEvent(PostgresChangePayload payload) {
    final newRecord = payload.newRecord;
    if (newRecord.isEmpty) return;

    final callId = newRecord['id'] as String? ?? '';
    final receiverId = newRecord['receiver_id'] as String? ?? '';
    final status = (newRecord['status'] as String? ?? '').toLowerCase();

    // STRICT: Only process if receiver_id equals the authenticated Agent's user UUID
    if (receiverId != _listeningAgentId) {
      return;
    }

    debugPrint(
      '[IncomingCallManager] Call event for $callId: status = $status',
    );

    if (status == 'ringing') {
      _onCallRinging(callId, newRecord);
    } else if (status == 'ended' ||
        status == 'declined' ||
        status == 'missed') {
      _onCallEndedOrDismissed(callId);
    }
  }

  Future<void> _checkPendingRingingCall(String agentId) async {
    try {
      final res = await SupabaseService.client
          .from('calls')
          .select()
          .eq('receiver_id', agentId)
          .eq('status', 'ringing')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        _onCallRinging(res['id'] as String, res);
      }
    } catch (e) {
      debugPrint(
        '[IncomingCallManager] Error checking pending ringing call: $e',
      );
    }
  }

  Future<void> _onCallRinging(
    String callId,
    Map<String, dynamic> rawCall,
  ) async {
    // Prevent duplicate dialog for same call or if already engaged in call
    if (_activeIncomingCallId == callId && _isDialogShowing) {
      return;
    }
    if (AgoraCallService.instance.hasActiveCall) {
      debugPrint(
        '[IncomingCallManager] Ignored incoming call $callId: Agent already has an active call.',
      );
      return;
    }

    // If native CallKit is already actively displaying this call, skip duplicate in-app dialog
    if (NotificationService.instance.isCallKitActiveFor(callId)) {
      debugPrint(
        '[IncomingCallManager] CallKit is actively showing call $callId. Skipping in-app dialog.',
      );
      return;
    }

    _activeIncomingCallId = callId;

    // Start periodic status poller to auto-cut if customer cancels during ringing
    _ringingPollTimer?.cancel();
    _ringingPollTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (timer) async {
        if (_activeIncomingCallId != callId) {
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
                '[IncomingCallManager] Poller detected incoming call terminated by customer: $status',
              );
              timer.cancel();
              _onCallEndedOrDismissed(callId);
            }
          }
        } catch (_) {}
      },
    );

    // Fetch associated booking and customer information
    final enrichedCall = await _enrichCallDetails(rawCall);

    _showIncomingCallDialog(enrichedCall);
  }

  void _onCallEndedOrDismissed(String callId) {
    _ringingPollTimer?.cancel();
    _ringingPollTimer = null;

    // 1. Ensure native CallKit UI is dismissed
    try {
      FlutterCallkitIncoming.endCall(callId).catchError((_) {});
    } catch (_) {}

    // 2. Dismiss in-app dialog if active
    if (_activeIncomingCallId == callId && _isDialogShowing) {
      _activeIncomingCallId = null;
      _isDialogShowing = false;

      final navContext = navigatorKey.currentContext;
      if (navContext != null &&
          Navigator.of(navContext, rootNavigator: true).canPop()) {
        Navigator.of(navContext, rootNavigator: true).pop();
      }
    }
  }

  Future<CallModel> _enrichCallDetails(Map<String, dynamic> raw) async {
    CallModel baseCall = CallModel.fromJson(raw);
    String? callerName;
    String? callerPhone;
    String? serviceTitle;

    // 1. Primary: Look up caller's profile in public.users by caller_id (customer's auth UUID)
    if (baseCall.callerId.isNotEmpty) {
      try {
        final userData = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', baseCall.callerId)
            .maybeSingle();

        if (userData != null) {
          final name = (userData['full_name'] ??
                  userData['name'] ??
                  userData['display_name'])
              ?.toString()
              .trim();
          final phone = (userData['phone'] ??
                  userData['phone_number'] ??
                  userData['mobile'])
              ?.toString()
              .trim();

          if (name != null && name.isNotEmpty && name.toLowerCase() != 'customer') {
            callerName = name;
          }
          if (phone != null && phone.isNotEmpty) {
            callerPhone = phone;
          }
        }
      } catch (e) {
        debugPrint('[IncomingCallManager] Error fetching caller from users: $e');
      }
    }

    // 2. Secondary: Enrich from Booking if booking_id is provided
    if (baseCall.bookingId != null && baseCall.bookingId!.isNotEmpty) {
      try {
        final bookingData = await SupabaseService.client
            .from('bookings')
            .select()
            .eq('id', baseCall.bookingId!)
            .maybeSingle();

        if (bookingData != null) {
          final serviceId = bookingData['service_id']?.toString();
          if (serviceId != null && serviceId.isNotEmpty) {
            try {
              final svc = await SupabaseService.client
                  .from('services')
                  .select('name')
                  .eq('id', serviceId)
                  .maybeSingle();
              if (svc != null && svc['name'] != null) {
                serviceTitle = svc['name'].toString();
              }
            } catch (_) {}
          }

          final custId = bookingData['customer_id']?.toString();
          if ((callerName == null || callerName.isEmpty || callerName.toLowerCase() == 'customer') &&
              custId != null &&
              custId.isNotEmpty) {
            final custData = await SupabaseService.client
                .from('users')
                .select()
                .eq('id', custId)
                .maybeSingle();

            if (custData != null) {
              final name = (custData['full_name'] ??
                      custData['name'] ??
                      custData['display_name'])
                  ?.toString()
                  .trim();
              final phone = (custData['phone'] ??
                      custData['phone_number'] ??
                      custData['mobile'])
                  ?.toString()
                  .trim();

              if (name != null && name.isNotEmpty && name.toLowerCase() != 'customer') {
                callerName = name;
              }
              if (phone != null && phone.isNotEmpty) {
                callerPhone ??= phone;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[IncomingCallManager] Error fetching booking for call: $e');
      }
    }



    return baseCall.copyWith(
      callerName: (callerName != null && callerName.isNotEmpty)
          ? callerName
          : 'Customer',
      callerPhone: callerPhone,
      serviceTitle: serviceTitle ?? 'Service Appointment',
    );
  }

  void _showIncomingCallDialog(CallModel call) {
    final navContext = navigatorKey.currentContext;
    if (navContext == null) {
      debugPrint(
        '[IncomingCallManager] Navigator context not available to show call dialog.',
      );
      return;
    }

    _isDialogShowing = true;

    showDialog(
      context: navContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => IncomingCallDialog(
        call: call,
        onDismiss: () {
          _isDialogShowing = false;
          if (_activeIncomingCallId == call.id) {
            _activeIncomingCallId = null;
          }
        },
      ),
    );
  }
}
