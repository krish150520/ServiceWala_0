import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// Top-level Firebase Cloud Messaging background message handler.
///
/// MUST be annotated with `@pragma('vm:entry-point')` so the Flutter Engine
/// can invoke it in an isolated background execution environment when the app
/// is backgrounded or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[FCMBackground] Firebase.initializeApp notice: $e');
  }

  debugPrint(
    '[FCMBackground] Received background message id: ${message.messageId}, '
    'data: ${message.data}',
  );

  final data = message.data;
  if (data.isEmpty) return;

  final type = (data['type'] ?? data['action'] ?? '').toString().toLowerCase();

  // Distinguish incoming-call events from ordinary notifications
  if (type == 'incoming_call' || (type.isEmpty && data.containsKey('call_id') && data.containsKey('channel_name'))) {
    final callId = data['call_id']?.toString() ?? data['id']?.toString();
    if (callId == null || callId.trim().isEmpty) {
      debugPrint('[FCMBackground] Ignored incoming call: missing call_id.');
      return;
    }

    final callerName = (data['caller_name'] ??
            data['name'] ??
            data['customer_name'] ??
            'Customer')
        .toString()
        .trim();
    final callerPhone = (data['caller_phone'] ?? data['phone'])?.toString();
    final serviceTitle = (data['service_title'] ?? data['service_name'])?.toString();
    final handle = (callerPhone != null && callerPhone.isNotEmpty)
        ? callerPhone
        : (serviceTitle ?? 'Incoming Voice Call');

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName.isNotEmpty ? callerName : 'Customer',
      appName: 'ServiceWala Partner',
      avatar: data['caller_avatar']?.toString() ?? data['avatar']?.toString(),
      handle: handle,
      type: 0, // Audio call
      duration: 45000, // 45 seconds ringing timeout
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: Map<String, dynamic>.from(data),
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
      debugPrint('[FCMBackground] Native CallKit incoming UI displayed for call $callId');
    } catch (e) {
      debugPrint('[FCMBackground] Error displaying CallKit incoming UI: $e');
    }
  } else if (type == 'call_cancelled' || type == 'call_ended') {
    final callId = data['call_id']?.toString() ?? data['id']?.toString();
    if (callId != null && callId.isNotEmpty) {
      try {
        await FlutterCallkitIncoming.endCall(callId);
        debugPrint('[FCMBackground] Native CallKit dismissed for cancelled call $callId');
      } catch (e) {
        debugPrint('[FCMBackground] Error ending CallKit UI: $e');
      }
    }
  }
}
