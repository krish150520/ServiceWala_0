import 'package:flutter/foundation.dart';
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';

/// Service for delegating push notification dispatches to the existing
/// Supabase Edge Function `send-fcm-notification` (HTTP v1 backend).
///
/// Security:
/// - Never includes Firebase service-account private keys or admin secrets on the client.
/// - Communicates through authenticated Supabase client using Bearer JWT.
/// - Gracefully fails when Supabase or Edge Function is unreachable without crashing callers.
class NotificationSenderService {
  static final NotificationSenderService instance = NotificationSenderService._();
  NotificationSenderService._();

  /// Low-level invocation of the `send-fcm-notification` Edge Function.
  Future<bool> sendNotification({
    required String recipientUserId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final cleanRecipient = recipientUserId.trim();
    if (cleanRecipient.isEmpty) {
      debugPrint('[NotificationSenderService] Cannot send notification: empty recipientUserId');
      return false;
    }

    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      debugPrint('[NotificationSenderService] Supabase not configured. Skipping push notification.');
      return false;
    }

    try {
      final client = SupabaseService.client;
      final payload = {
        'user_id': cleanRecipient,
        'recipient_id': cleanRecipient,
        'title': title,
        'body': body,
        'data': {
          ...data,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      };

      final response = await client.functions.invoke(
        'send-fcm-notification',
        body: payload,
      );

      final status = response.status;
      final isSuccess = status >= 200 && status < 300;
      debugPrint(
        '[NotificationSenderService] send-fcm-notification: recipient=$cleanRecipient, '
        'status=$status, success=$isSuccess',
      );
      return isSuccess;
    } catch (e) {
      debugPrint('[NotificationSenderService] send-fcm-notification notice: $e');
      return false;
    }
  }

  /// Notify customer when agent responds Available or Unavailable to a booking request.
  Future<bool> sendAvailabilityResponse({
    required String customerUserId,
    required String bookingId,
    required bool isAvailable,
    required String agentName,
    String? serviceName,
  }) async {
    final srv = (serviceName != null && serviceName.isNotEmpty) ? serviceName : 'Service';
    final title = isAvailable ? 'Partner is Available!' : 'Partner Unavailable';
    final body = isAvailable
        ? '$agentName is available for your $srv request. Please confirm booking to proceed.'
        : '$agentName is unavailable for your $srv request at this time.';

    return sendNotification(
      recipientUserId: customerUserId,
      title: title,
      body: body,
      data: {
        'type': isAvailable ? 'agent_available' : 'agent_unavailable',
        'action': isAvailable ? 'agent_available' : 'agent_unavailable',
        'booking_id': bookingId,
        'status': isAvailable ? 'accepted' : 'declined',
      },
    );
  }

  /// Notify recipient of a new in-app chat message.
  Future<bool> sendChatMessageNotification({
    required String recipientUserId,
    required String senderName,
    required String content,
    required String bookingId,
    required String conversationId,
  }) async {
    return sendNotification(
      recipientUserId: recipientUserId,
      title: senderName.isNotEmpty ? senderName : 'New Message',
      body: content,
      data: {
        'type': 'chat_message',
        'action': 'chat_message',
        'booking_id': bookingId,
        'conversation_id': conversationId,
      },
    );
  }

  /// Notify customer that agent has arrived at their location.
  Future<bool> sendArrivalNotification({
    required String customerUserId,
    required String bookingId,
    required String agentName,
  }) async {
    return sendNotification(
      recipientUserId: customerUserId,
      title: 'Partner Arrived',
      body: '$agentName has arrived at your service location.',
      data: {
        'type': 'agent_arrived',
        'action': 'agent_arrived',
        'booking_id': bookingId,
        'status': 'arrived',
      },
    );
  }

  /// Notify customer that agent completed the job and requested UPI payment.
  Future<bool> sendUpiPaymentRequestNotification({
    required String customerUserId,
    required String bookingId,
    required double amount,
    required String agentName,
  }) async {
    final formattedAmount = amount.toStringAsFixed(0);
    return sendNotification(
      recipientUserId: customerUserId,
      title: 'Service Payment Request',
      body: '$agentName has requested ₹$formattedAmount for completed service.',
      data: {
        'type': 'payment_request',
        'action': 'payment_request',
        'booking_id': bookingId,
        'amount': amount.toString(),
      },
    );
  }
}
