import 'package:service_wala_business/core/constants/database_constants.dart';

/// Payment method enumeration for the application.
enum AppPaymentMethod {
  razorpay(DbPaymentMethods.razorpay, 'Razorpay (Online)'),
  cash(DbPaymentMethods.cash, 'Cash on Service'),
  unknown('unknown', 'Unknown');

  final String dbValue;
  final String displayName;

  const AppPaymentMethod(this.dbValue, this.displayName);

  bool get isOnline => this == AppPaymentMethod.razorpay;
  bool get isCash => this == AppPaymentMethod.cash;

  static AppPaymentMethod fromDb(String? value) {
    if (value == null) return AppPaymentMethod.unknown;
    final normalized = value.trim().toLowerCase();
    if (normalized == DbPaymentMethods.razorpay || normalized == DbPaymentMethods.online) {
      return AppPaymentMethod.razorpay;
    }
    if (normalized == DbPaymentMethods.cash) {
      return AppPaymentMethod.cash;
    }
    return AppPaymentMethod.unknown;
  }
}

/// Payment status enumeration matching database values.
enum AppPaymentStatus {
  pending(DbPaymentStatuses.pending, 'Pending'),
  paid(DbPaymentStatuses.paid, 'Paid'),
  failed(DbPaymentStatuses.failed, 'Failed'),
  refunded(DbPaymentStatuses.refunded, 'Refunded'),
  unknown('unknown', 'Unknown');

  final String dbValue;
  final String displayName;

  const AppPaymentStatus(this.dbValue, this.displayName);

  bool get isPaid => this == AppPaymentStatus.paid;
  bool get isPending => this == AppPaymentStatus.pending;
  bool get isFailed => this == AppPaymentStatus.failed;
  bool get isRefunded => this == AppPaymentStatus.refunded;

  static AppPaymentStatus fromDb(String? value) {
    if (value == null) return AppPaymentStatus.unknown;
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case DbPaymentStatuses.pending:
        return AppPaymentStatus.pending;
      case DbPaymentStatuses.paid:
        return AppPaymentStatus.paid;
      case DbPaymentStatuses.failed:
        return AppPaymentStatus.failed;
      case DbPaymentStatuses.refunded:
        return AppPaymentStatus.refunded;
      default:
        return AppPaymentStatus.unknown;
    }
  }
}

/// Model representing a backend-generated Razorpay payment order.
///
/// NOTE: Razorpay orders MUST be created on a secure backend / Supabase Edge Function.
/// Mobile clients must NEVER create orders using private Razorpay API keys.
class PaymentOrderModel {
  final String orderId;
  final String bookingId;
  final double amount;
  final String currency;
  final String? status;
  final String? keyId; // Public Razorpay Key ID
  final Map<String, dynamic>? notes;

  const PaymentOrderModel({
    required this.orderId,
    required this.bookingId,
    required this.amount,
    this.currency = 'INR',
    this.status,
    this.keyId,
    this.notes,
  });

  factory PaymentOrderModel.fromJson(Map<String, dynamic> json) {
    return PaymentOrderModel(
      orderId: json['order_id']?.toString() ?? json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      status: json['status']?.toString(),
      keyId: json['key_id']?.toString(),
      notes: json['notes'] is Map<String, dynamic>
          ? json['notes'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'booking_id': bookingId,
      'amount': amount,
      'currency': currency,
      if (status != null) 'status': status,
      if (keyId != null) 'key_id': keyId,
      if (notes != null) 'notes': notes,
    };
  }
}

/// Verification payload sent from Flutter client to backend for server-side HMAC verification.
class PaymentVerificationModel {
  final String bookingId;
  final String razorpayPaymentId;
  final String razorpayOrderId;
  final String razorpaySignature;

  const PaymentVerificationModel({
    required this.bookingId,
    required this.razorpayPaymentId,
    required this.razorpayOrderId,
    required this.razorpaySignature,
  });

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_signature': razorpaySignature,
    };
  }
}
