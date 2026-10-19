import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:service_wala_business/core/services/agora_call_service.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/call_model.dart';
import 'package:service_wala_business/screens/calling/agora_call_screen.dart';

/// Entry point and router for voice calling in the ServiceWala Agent app.
/// Initiates real Agora RTC voice calls to customers via Supabase backend.
class CallingScreen extends StatelessWidget {
  final String customerName;
  final String? customerPhone;
  final String? serviceTitle;
  final String? bookingId;
  final String? customerId;

  const CallingScreen({
    super.key,
    required this.customerName,
    this.customerPhone,
    this.serviceTitle,
    this.bookingId,
    this.customerId,
  });

  /// Primary entry point to call a customer using Agora RTC voice calling.
  static Future<void> start({
    required BuildContext context,
    required String customerName,
    String? customerPhone,
    String? serviceTitle,
    String? bookingId,
    String? customerId,
  }) async {
    // 1. If an Agora call is already active, navigate straight to it
    if (AgoraCallService.instance.hasActiveCall) {
      final active = AgoraCallService.instance.currentCall.value;
      if (active != null && context.mounted) {
        AgoraCallScreen.open(context: context, call: active);
        return;
      }
    }

    final currentUserId = SupabaseService.currentUser?.id;

    // 2. Validate bookingId requirement
    if (bookingId == null || bookingId.trim().isEmpty) {
      debugPrint('[CallingScreen] Warning: bookingId is missing!');
      if (customerPhone != null && customerPhone.isNotEmpty) {
        final uri = Uri(scheme: 'tel', path: customerPhone);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot initiate voice call: Booking reference is missing.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final cleanBookingId = bookingId.trim();

    // 3. Check if an incoming ringing call exists in Supabase for this booking
    if (currentUserId != null) {
      try {
        final existingCall = await SupabaseService.client
            .from('calls')
            .select()
            .eq('receiver_id', currentUserId)
            .eq('booking_id', cleanBookingId)
            .eq('status', 'ringing')
            .maybeSingle();

        if (existingCall != null && context.mounted) {
          final callModel = CallModel.fromJson(existingCall).copyWith(
            callerName: customerName,
            callerPhone: customerPhone,
            serviceTitle: serviceTitle,
          );
          final acceptFuture = AgoraCallService.instance.acceptIncomingCall(
            callModel,
          );
          AgoraCallScreen.open(
            context: context,
            call: callModel,
            initialAcceptFuture: acceptFuture,
          );
          return;
        }
      } catch (e) {
        debugPrint('[CallingScreen] Check ringing call notice: $e');
      }
    }

    // 4. Initiate real Agora Voice Call to the customer
    if (currentUserId != null && context.mounted) {
      String? resolvedCustomerId = customerId;
      if (resolvedCustomerId == null || resolvedCustomerId.isEmpty) {
        try {
          final bRes = await SupabaseService.client
              .from('bookings')
              .select('customer_id')
              .eq('id', cleanBookingId)
              .maybeSingle();
          resolvedCustomerId = bRes?['customer_id']?.toString();
        } catch (_) {}
      }

      final placeholderCall = CallModel(
        id: 'outgoing_${DateTime.now().millisecondsSinceEpoch}',
        callerId: currentUserId,
        receiverId: resolvedCustomerId ?? '',
        bookingId: cleanBookingId,
        status: CallStatus.ringing,
        createdAt: DateTime.now(),
        callerName: customerName,
        callerPhone: customerPhone,
        serviceTitle: serviceTitle,
      );

      final outgoingFuture = AgoraCallService.instance.startOutgoingCall(
        customerName: customerName,
        customerPhone: customerPhone,
        serviceTitle: serviceTitle,
        bookingId: cleanBookingId,
        customerId: resolvedCustomerId,
      );

      if (!context.mounted) return;
      AgoraCallScreen.open(
        context: context,
        call: placeholderCall,
        initialAcceptFuture: outgoingFuture.then((c) => c != null),
      );
      return;
    }

    // 4. Fallback to direct cellular phone call if offline or not authenticated
    if (customerPhone != null && customerPhone.isNotEmpty) {
      final uri = Uri(scheme: 'tel', path: customerPhone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to place call: Please check your network connection or sign in.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If instantiated directly as a Widget, delegate directly to AgoraCallScreen
    final currentCall =
        AgoraCallService.instance.currentCall.value ??
        CallModel(
          id: 'call_${DateTime.now().millisecondsSinceEpoch}',
          callerId: SupabaseService.currentUser?.id ?? '',
          receiverId: customerId ?? '',
          bookingId: bookingId,
          status: CallStatus.ringing,
          createdAt: DateTime.now(),
          callerName: customerName,
          callerPhone: customerPhone,
          serviceTitle: serviceTitle,
        );

    return AgoraCallScreen(call: currentCall);
  }
}
