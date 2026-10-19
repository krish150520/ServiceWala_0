import 'package:service_wala_business/config/constants.dart';

/// Booking model - a confirmed (or in-progress) service job
class Booking {
  final String id;
  final String? requestId;
  final String? customerId;
  final String customerName;
  final String? agentId;
  final String serviceType;
  final String description;
  final DateTime appointmentTime;
  final String? customerAddress;
  final String? customerPhone;
  final double? customerLatitude;
  final double? customerLongitude;
  final BookingStatus status;
  final double? agreedPrice;
  final PaymentStatus paymentStatus;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;

  /// Price accessor alias for agreedPrice
  double get price => agreedPrice ?? 0.0;

  const Booking({
    required this.id,
    this.requestId,
    this.customerId,
    required this.customerName,
    this.agentId,
    required this.serviceType,
    required this.description,
    required this.appointmentTime,
    this.customerAddress,
    this.customerPhone,
    this.customerLatitude,
    this.customerLongitude,
    this.status = BookingStatus.confirmed,
    this.agreedPrice,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentMethod = PaymentMethod.razorpay,
    required this.createdAt,
  });

  Booking copyWith({
    String? id,
    String? requestId,
    String? customerId,
    String? customerName,
    String? agentId,
    String? serviceType,
    String? description,
    DateTime? appointmentTime,
    String? customerAddress,
    String? customerPhone,
    double? customerLatitude,
    double? customerLongitude,
    BookingStatus? status,
    double? agreedPrice,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    DateTime? createdAt,
  }) {
    return Booking(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      agentId: agentId ?? this.agentId,
      serviceType: serviceType ?? this.serviceType,
      description: description ?? this.description,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      customerAddress: customerAddress ?? this.customerAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      status: status ?? this.status,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'customer_id': customerId,
      'customer_name': customerName,
      'agent_id': agentId,
      'service_type': serviceType,
      'description': description,
      'appointment_time': appointmentTime.toIso8601String(),
      'customer_address': customerAddress,
      'customer_phone': customerPhone,
      'customer_latitude': customerLatitude,
      'customer_longitude': customerLongitude,
      'status': status.name,
      'agreed_price': agreedPrice,
      'payment_status': paymentStatus.name,
      'payment_method': paymentMethod.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? '',
      requestId: json['request_id'],
      customerId: json['customer_id'],
      customerName: json['customer_name'] ?? 'Customer',
      agentId: json['agent_id'],
      serviceType: json['service_type'] ?? '',
      description: json['description'] ?? '',
      appointmentTime: json['appointment_time'] != null
          ? DateTime.parse(json['appointment_time'])
          : DateTime.now(),
      customerAddress: json['customer_address'],
      customerPhone: json['customer_phone'],
      customerLatitude: (json['customer_latitude'] as num?)?.toDouble(),
      customerLongitude: (json['customer_longitude'] as num?)?.toDouble(),
      status: BookingStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BookingStatus.confirmed,
      ),
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
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
