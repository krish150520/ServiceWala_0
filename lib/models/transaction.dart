import 'package:service_wala_business/config/constants.dart';

/// Earnings transaction model
class Transaction {
  final String id;
  final String bookingId;
  final String? agentId;
  final String serviceName;
  final double amount;
  final PaymentStatus paymentStatus;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.bookingId,
    this.agentId,
    required this.serviceName,
    required this.amount,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentMethod = PaymentMethod.razorpay,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'agent_id': agentId,
      'service_name': serviceName,
      'amount': amount,
      'payment_status': paymentStatus.name,
      'payment_method': paymentMethod.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? '',
      bookingId: json['booking_id'] ?? '',
      agentId: json['agent_id'],
      serviceName: json['service_name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == json['payment_status'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (m) => m.name == json['payment_method'],
        orElse: () => PaymentMethod.razorpay,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
