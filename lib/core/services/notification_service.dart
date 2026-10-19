import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/services/agora_call_service.dart';
import 'package:service_wala_business/core/services/fcm_background_handler.dart';
import 'package:service_wala_business/core/services/incoming_call_manager.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/call_model.dart';
import 'package:service_wala_business/screens/calling/agora_call_screen.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/data/repositories/booking_repository.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/booking/job_detail_screen.dart';
import 'package:service_wala_business/screens/chat/chat_screen.dart';

/// Comprehensive Push Notification and Native CallKit Service for ServiceWala Agent.
///
/// Features:
/// - Single-point Firebase initialization.
/// - Top-level background message handling.
/// - Android notification channel configuration.
/// - Android 13+ and 14+ notification & full-screen intent permission handling.
/// - Native CallKit incoming UI with full-screen lockscreen display.
/// - Idempotent Accept, Decline, and Missed-timeout action routing.
/// - Supabase session and recipient verification before call connection.
/// - Real-time synchronization with AgoraCallService and IncomingCallManager.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._({FirebaseMessaging? fcm}) : _customFcm = fcm;

  final FirebaseMessaging? _customFcm;
  bool _isInitialized = false;

  FirebaseMessaging? get _fcm {
    if (_customFcm != null) return _customFcm;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseMessaging.instance;
      }
    } catch (_) {}
    return null;
  }

  // Idempotency guards to prevent duplicate CallKit actions
  final Set<String> _processingAcceptCallIds = {};
  final Set<String> _processingDeclineCallIds = {};
  final Set<String> _activeCallKitCallIds = {};

  /// Check whether native CallKit is actively ringing for a given call ID
  bool isCallKitActiveFor(String callId) => _activeCallKitCallIds.contains(callId);

  /// Initialize Firebase, FCM handlers, Android channels, and CallKit event listeners.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp();
      debugPrint('[NotificationService] Firebase initialized successfully.');

      final fcm = _fcm;
      if (fcm != null) {
        // 2. Register top-level background handler
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // 3. Set foreground presentation options
        await fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // 4. Request system notification permissions
        await _requestPermissions();

        // 5. Setup foreground and opened-app message listeners
        _setupFcmListeners();
      }

      // 6. Setup Flutter CallKit Incoming event listeners
      _setupCallKitEventListeners();

      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization notice: $e');
    }
  }

  /// Request FCM notification and Android-specific permissions (API 33+ and 34+)
  Future<void> _requestPermissions() async {
    final fcm = _fcm;
    if (fcm != null) {
      try {
        final settings = await fcm.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: true,
          provisional: false,
          sound: true,
        );
        debugPrint('[NotificationService] User granted permission: ${settings.authorizationStatus}');
      } catch (e) {
        debugPrint('[NotificationService] FCM requestPermission notice: $e');
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      // Request post notification permission for Android 13+
      try {
        await FlutterCallkitIncoming.requestNotificationPermission({
          'rationaleMessagePermission':
              'Notification permission is required to receive incoming customer calls and instant job alerts.',
          'postNotificationMessageRequired':
              'Please grant notification permission in system settings to receive incoming calls.',
        });
      } catch (_) {}

      // Request full-screen intent permission for Android 14+ (API 34)
      try {
        final canUse = await FlutterCallkitIncoming.canUseFullScreenIntent();
        if (canUse == false) {
          debugPrint('[NotificationService] Full-screen intent not granted. Prompting user.');
          await FlutterCallkitIncoming.requestFullIntentPermission();
        }
      } catch (_) {}
    }
  }

  void _setupFcmListeners() {
    final fcm = _fcm;
    if (fcm == null) return;

    // A. Foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[NotificationService] Foreground message received: ${message.messageId}, data: ${message.data}',
      );
      _handleIncomingMessage(message, isForeground: true);
    });

    // B. App opened from background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Notification opened from background: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // C. Check if app was opened from terminated state by tapping a notification
    fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[NotificationService] App launched from terminated notification tap: ${message.data}');
        _handleNotificationTap(message.data);
      }
    });
  }

  /// Process incoming FCM message payloads
  Future<void> _handleIncomingMessage(
    RemoteMessage message, {
    required bool isForeground,
  }) async {
    final data = message.data;
    if (data.isEmpty) return;

    final type = (data['type'] ?? data['action'] ?? '').toString().toLowerCase();

    // 1. Incoming Voice Call Event
    if (type == 'incoming_call' || (type.isEmpty && data.containsKey('call_id') && data.containsKey('channel_name'))) {
      final callId = data['call_id']?.toString() ?? data['id']?.toString();
      if (callId == null || callId.trim().isEmpty) return;

      // Deduplication: Do not show if agent already has an active call or if CallKit is already ringing for this call
      if (AgoraCallService.instance.hasActiveCall || _activeCallKitCallIds.contains(callId)) {
        debugPrint('[NotificationService] Ignored incoming call $callId: already active.');
        return;
      }

      await showIncomingCall(
        callId: callId,
        callerName: (data['caller_name'] ?? data['name'] ?? 'Customer').toString(),
        callerPhone: data['caller_phone']?.toString(),
        callerAvatar: data['caller_avatar']?.toString() ?? data['avatar']?.toString(),
        serviceTitle: data['service_title']?.toString(),
        extraData: data,
      );
    }
    // 2. Call Cancelled / Ended Event
    else if (type == 'call_cancelled' || type == 'call_ended') {
      final callId = data['call_id']?.toString() ?? data['id']?.toString();
      if (callId != null && callId.isNotEmpty) {
        await dismissIncomingCall(callId);
        if (AgoraCallService.instance.currentCall.value?.id == callId ||
            AgoraCallService.instance.hasActiveCall) {
          AgoraCallService.instance.endCall(callId: callId, sendEndRpc: false);
        }
      }
    }
    // 3. New Service Request or Booking Status Update
    else if (type == 'new_request' ||
             type == 'service_request' ||
             type == 'booking_request' ||
             type == 'booking_confirmed' ||
             type == 'agent_available') {
      debugPrint('[NotificationService] Received booking event notification: $type');
      final navContext = IncomingCallManager.navigatorKey.currentContext;
      if (navContext != null) {
        try {
          final appState = Provider.of<AppState>(navContext, listen: false);
          appState.refreshBookings();
        } catch (_) {}
      }
    }
    // 4. Chat Message Notification
    else if (type == 'chat_message' || type == 'chat') {
      debugPrint('[NotificationService] Received chat notification.');
      final navContext = IncomingCallManager.navigatorKey.currentContext;
      if (navContext != null) {
        try {
          final appState = Provider.of<AppState>(navContext, listen: false);
          final bookingId = data['booking_id']?.toString();
          if (bookingId != null && bookingId.isNotEmpty) {
            appState.loadMessagesForBooking(bookingId);
          }
        } catch (_) {}
      }
    }
  }

  /// Show the native lock-screen full-screen incoming call UI using CallKit
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    String? callerPhone,
    String? callerAvatar,
    String? serviceTitle,
    Map<String, dynamic>? extraData,
  }) async {
    final cleanCallId = callId.trim();
    if (cleanCallId.isEmpty) return;

    _activeCallKitCallIds.add(cleanCallId);

    final handle = (callerPhone != null && callerPhone.trim().isNotEmpty)
        ? callerPhone.trim()
        : (serviceTitle ?? 'Incoming Voice Call');

    final params = CallKitParams(
      id: cleanCallId,
      nameCaller: callerName.isNotEmpty ? callerName : 'Customer',
      appName: 'ServiceWala Partner',
      avatar: callerAvatar,
      handle: handle,
      type: 0, // Audio Call
      duration: 45000, // 45 seconds ringing timeout
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: extraData ?? {'call_id': cleanCallId},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0957DE',
        actionColor: '#4CAF50',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'ServiceWala Incoming Calls',
        missedCallNotificationChannelName: 'ServiceWala Missed Calls',
        isShowFullLockedScreen: true,
        isImportant: true,
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('[NotificationService] Native incoming call shown for $cleanCallId');
    } catch (e) {
      debugPrint('[NotificationService] Error showing CallKit incoming: $e');
    }
  }

  /// Dismiss the native incoming-call UI
  Future<void> dismissIncomingCall(String callId) async {
    final cleanId = callId.trim();
    if (cleanId.isEmpty) return;

    _activeCallKitCallIds.remove(cleanId);
    try {
      await FlutterCallkitIncoming.endCall(cleanId);
    } catch (_) {}
    IncomingCallManager.instance.dismissInAppDialog();
  }

  /// Setup event listener for native CallKit actions (Accept, Decline, Timeout)
  void _setupCallKitEventListeners() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;

      debugPrint('[NotificationService] CallKit event: ${event.event}, body: ${event.body}');

      final body = event.body;
      final Map<String, dynamic> data = (body is Map)
          ? Map<String, dynamic>.from(body)
          : <String, dynamic>{};

      final rawId = data['id'] ?? data['call_id'] ?? data['extra']?['call_id'];
      final callId = rawId?.toString().trim();

      switch (event.event) {
        case Event.actionCallAccept:
          if (callId != null && callId.isNotEmpty) {
            await _handleCallKitAccept(callId, data);
          }
          break;

        case Event.actionCallDecline:
          if (callId != null && callId.isNotEmpty) {
            await _handleCallKitDecline(callId);
          }
          break;

        case Event.actionCallTimeout:
          if (callId != null && callId.isNotEmpty) {
            await _handleCallKitTimeout(callId);
          }
          break;

        case Event.actionCallEnded:
          if (callId != null && callId.isNotEmpty) {
            _activeCallKitCallIds.remove(callId);
          }
          break;

        default:
          break;
      }
    });
  }

  /// Handle native Accept action from CallKit UI
  Future<void> _handleCallKitAccept(
    String callId,
    Map<String, dynamic> data,
  ) async {
    // Idempotency: Prevent joining twice
    if (_processingAcceptCallIds.contains(callId) || AgoraCallService.instance.hasActiveCall) {
      debugPrint('[NotificationService] Accept ignored: call $callId is already being processed.');
      return;
    }
    _processingAcceptCallIds.add(callId);
    _activeCallKitCallIds.remove(callId);
    IncomingCallManager.instance.dismissInAppDialog();

    try {
      // 1. Verify authenticated user
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        debugPrint('[NotificationService] Accept rejected: Unauthenticated.');
        return;
      }

      // 2. Fetch call record from Supabase
      final callRecord = await SupabaseService.client
          .from(DbTables.calls)
          .select()
          .eq('id', callId)
          .maybeSingle();

      if (callRecord == null) {
        debugPrint('[NotificationService] Call $callId not found in database.');
        return;
      }

      // 3. Strict verification: Must be intended recipient
      final receiverId = callRecord['receiver_id']?.toString();
      if (receiverId != currentUser.id) {
        debugPrint('[NotificationService] Unauthorized: Receiver $receiverId does not match user ${currentUser.id}');
        return;
      }

      // 4. Verify call is still active/ringing
      final status = (callRecord['status'] as String? ?? '').toLowerCase();
      if (status != 'ringing' && status != 'initiated' && status != 'accepted') {
        debugPrint('[NotificationService] Call $callId is no longer active (status: $status)');
        return;
      }

      // 5. Build and enrich CallModel
      CallModel call = CallModel.fromJson(callRecord);
      final extraMap = data['extra'] is Map ? Map<String, dynamic>.from(data['extra']) : null;
      if (extraMap != null) {
        call = call.copyWith(
          callerName: extraMap['caller_name']?.toString() ?? call.callerName,
          callerPhone: extraMap['caller_phone']?.toString() ?? call.callerPhone,
          serviceTitle: extraMap['service_title']?.toString() ?? call.serviceTitle,
        );
      }

      // 6. Invoke established Agora acceptance pipeline
      debugPrint('[NotificationService] Initiating Agora call acceptance for $callId');
      final acceptFuture = AgoraCallService.instance.acceptIncomingCall(call);

      // 7. Navigate to AgoraCallScreen
      final navState = await _waitForNavigatorState();
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => AgoraCallScreen(
              call: call,
              initialAcceptFuture: acceptFuture,
            ),
          ),
        );
      } else {
        debugPrint('[NotificationService] Navigator state not available after waiting.');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error processing CallKit accept: $e');
    } finally {
      _processingAcceptCallIds.remove(callId);
    }
  }

  /// Handle native Decline action from CallKit UI
  Future<void> _handleCallKitDecline(String callId) async {
    if (_processingDeclineCallIds.contains(callId)) return;
    _processingDeclineCallIds.add(callId);
    _activeCallKitCallIds.remove(callId);
    IncomingCallManager.instance.dismissInAppDialog();

    try {
      debugPrint('[NotificationService] Invoking decline for call $callId');
      await AgoraCallService.instance.declineIncomingCall(callId);
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('[NotificationService] Error declining call: $e');
    } finally {
      _processingDeclineCallIds.remove(callId);
    }
  }

  /// Handle native ringing timeout (45s without answer)
  Future<void> _handleCallKitTimeout(String callId) async {
    _activeCallKitCallIds.remove(callId);
    IncomingCallManager.instance.dismissInAppDialog();

    try {
      debugPrint('[NotificationService] Marking call $callId as missed');
      await AgoraCallService.instance.markCallMissed(callId);
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('[NotificationService] Error marking call missed: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('[NotificationService] Handling notification tap: $data');
    final type = (data['type'] ?? data['action'] ?? '').toString().toLowerCase();

    // 1. Incoming Call Tap
    if (type == 'incoming_call' || data.containsKey('call_id')) {
      final callId = (data['call_id'] ?? data['id'])?.toString();
      if (callId != null && callId.isNotEmpty) {
        _handleCallKitAccept(callId, data);
        return;
      }
    }

    // 2. Chat Message Tap
    if (type == 'chat_message' || type == 'chat' || data.containsKey('conversation_id')) {
      final bookingId = data['booking_id']?.toString();
      if (bookingId != null && bookingId.isNotEmpty) {
        navigateToBookingChat(bookingId);
        return;
      }
    }

    // 3. New Request or Booking Confirmed Tap
    final bookingId = data['booking_id']?.toString() ?? data['id']?.toString();
    if (bookingId != null && bookingId.isNotEmpty) {
      navigateToBookingDetail(bookingId);
      return;
    }
  }

  /// Deep-link navigation to open a specific job detail
  Future<void> navigateToBookingDetail(String bookingId) async {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) return;

    final navState = await _waitForNavigatorState();
    if (navState == null) {
      debugPrint('[NotificationService] NavigatorState unavailable for booking detail navigation.');
      return;
    }

    Booking? targetBooking;
    if (navState.mounted) {
      try {
        final appState = Provider.of<AppState>(navState.context, listen: false);
        targetBooking = appState.bookings.where((b) => b.id == cleanId).firstOrNull;
        targetBooking ??= await appState.refreshBooking(cleanId);
      } catch (_) {}
    }

    if (targetBooking == null) {
      try {
        final dbBooking = await BookingRepository().getBookingById(cleanId);
        targetBooking = AppState.mapDbBookingToUiStatic(dbBooking);
      } catch (e) {
        debugPrint('[NotificationService] Failed to load booking for navigation: $e');
      }
    }

    if (targetBooking != null && navState.mounted) {
      navState.push(
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(booking: targetBooking!),
        ),
      );
    }
  }

  /// Deep-link navigation to open conversation chat screen
  Future<void> navigateToBookingChat(String bookingId) async {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) return;

    final navState = await _waitForNavigatorState();
    if (navState == null) {
      debugPrint('[NotificationService] NavigatorState unavailable for chat navigation.');
      return;
    }

    Booking? targetBooking;
    if (navState.mounted) {
      try {
        final appState = Provider.of<AppState>(navState.context, listen: false);
        targetBooking = appState.bookings.where((b) => b.id == cleanId).firstOrNull;
        targetBooking ??= await appState.refreshBooking(cleanId);
      } catch (_) {}
    }

    if (targetBooking == null) {
      try {
        final dbBooking = await BookingRepository().getBookingById(cleanId);
        targetBooking = AppState.mapDbBookingToUiStatic(dbBooking);
      } catch (e) {
        debugPrint('[NotificationService] Failed to load booking for chat navigation: $e');
      }
    }

    if (targetBooking != null && navState.mounted) {
      navState.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(booking: targetBooking!),
        ),
      );
    }
  }

  /// Wait for the global NavigatorState to become available (e.g. after cold start)
  Future<NavigatorState?> _waitForNavigatorState({int maxAttempts = 20}) async {
    for (int i = 0; i < maxAttempts; i++) {
      final state = IncomingCallManager.navigatorKey.currentState;
      if (state != null) return state;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return null;
  }
}
