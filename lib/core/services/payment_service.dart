import 'package:flutter/foundation.dart';
import 'package:service_wala_business/core/config/api_config.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/data/models/payment_model.dart';

/// Contract for future Razorpay and online payment processing.
///
/// CRITICAL SECURITY ARCHITECTURE:
/// 1. Order Creation: Flutter client invokes a secure backend / Supabase Edge Function to create Razorpay Order.
/// 2. Checkout: Flutter displays Razorpay checkout with only the public [key_id].
/// 3. Verification: Client receives [razorpay_payment_id], [razorpay_order_id], and [razorpay_signature],
///    and passes them to the backend endpoint for HMAC SHA256 signature verification.
/// 4. Settlement: Database row [bookings.payment_status] is updated ONLY by verified server-side code or webhook.
/// 5. No client code ever writes [payment_status = 'paid'] directly to bypass authorization.
abstract class IPaymentService {
  /// Create a Razorpay payment order via backend API / Supabase Edge Function
  Future<PaymentOrderModel> createOrder({
    required String bookingId,
    required double amount,
  });

  /// Verify payment signature on backend
  Future<bool> verifyPayment({
    required PaymentVerificationModel verification,
  });

  /// Open Razorpay native checkout sheet (when configured)
  Future<void> openCheckout({
    required PaymentOrderModel order,
    required String customerPhone,
    String? customerEmail,
    required Function(PaymentVerificationModel) onSuccess,
    required Function(String code, String message) onFailure,
  });
}

/// Placeholder implementation of [IPaymentService].
///
/// Ready for plug-and-play when Razorpay SDK (`razorpay_flutter`) and Supabase Edge Functions
/// are configured with live API credentials.
class PaymentService implements IPaymentService {
  static final PaymentService instance = PaymentService._();
  PaymentService._();

  @override
  Future<PaymentOrderModel> createOrder({
    required String bookingId,
    required double amount,
  }) async {
    if (!ApiConfig.isRazorpayConfigured) {
      debugPrint(
        '[PaymentService] Razorpay is not configured. Simulating unconfigured environment.',
      );
      throw const ConfigurationException(
        message: 'Razorpay is not yet configured on this environment.',
        code: 'RAZORPAY_NOT_CONFIGURED',
      );
    }

    // Future implementation will invoke Supabase Edge Function:
    // final res = await supabase.functions.invoke('create-razorpay-order', body: {...});
    throw UnimplementedError('Live Razorpay order creation is not active yet.');
  }

  @override
  Future<bool> verifyPayment({
    required PaymentVerificationModel verification,
  }) async {
    if (!ApiConfig.isRazorpayConfigured) {
      throw const ConfigurationException(
        message: 'Payment verification requires backend configuration.',
        code: 'RAZORPAY_NOT_CONFIGURED',
      );
    }

    // Future implementation will verify HMAC signature server-side:
    // final res = await supabase.functions.invoke('verify-razorpay-payment', body: verification.toJson());
    return false;
  }

  @override
  Future<void> openCheckout({
    required PaymentOrderModel order,
    required String customerPhone,
    String? customerEmail,
    required Function(PaymentVerificationModel) onSuccess,
    required Function(String code, String message) onFailure,
  }) async {
    if (!ApiConfig.isRazorpayConfigured) {
      onFailure(
        'NOT_CONFIGURED',
        'Razorpay checkout is in placeholder mode until API keys are set.',
      );
      return;
    }

    debugPrint('[PaymentService] Opening Razorpay checkout for order: ${order.orderId}');
  }
}
