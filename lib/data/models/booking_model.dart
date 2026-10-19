import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/data/models/app_user.dart';
import 'package:service_wala_business/data/models/service_model.dart';

/// Typed model for the 'bookings' database table.
class BookingModel {
  final String id;
  final DateTime? createdAt;
  final String? customerId;
  final String? providerId;
  final String? serviceId;
  final String? status;
  final String? address;
  final DateTime? scheduledAt;
  final String? notes;
  final double? price;
  final String? paymentMethod;
  final String? paymentStatus;
  final double? customerLatitude;
  final double? customerLongitude;

  // Optional joined relational data
  final AppUser? customer;
  final ServiceModel? service;

  const BookingModel({
    required this.id,
    this.createdAt,
    this.customerId,
    this.providerId,
    this.serviceId,
    this.status,
    this.address,
    this.scheduledAt,
    this.notes,
    this.price,
    this.paymentMethod,
    this.paymentStatus,
    this.customerLatitude,
    this.customerLongitude,
    this.customer,
    this.service,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json[BookingColumns.id]?.toString() ?? '',
      createdAt: json[BookingColumns.createdAt] != null
          ? DateTime.tryParse(json[BookingColumns.createdAt].toString())
          : null,
      customerId: json[BookingColumns.customerId]?.toString(),
      providerId: json[BookingColumns.providerId]?.toString(),
      serviceId: json[BookingColumns.serviceId]?.toString(),
      status: json[BookingColumns.status]?.toString(),
      address: json[BookingColumns.address]?.toString(),
      scheduledAt: json[BookingColumns.scheduledAt] != null
          ? DateTime.tryParse(json[BookingColumns.scheduledAt].toString())
          : null,
      notes: json[BookingColumns.notes]?.toString(),
      price: json[BookingColumns.price] != null
          ? (json[BookingColumns.price] as num).toDouble()
          : null,
      paymentMethod: json[BookingColumns.paymentMethod]?.toString(),
      paymentStatus: json[BookingColumns.paymentStatus]?.toString(),
      customerLatitude: (json['customer_latitude'] ?? json['latitude'] ?? json['lat'] as num?)?.toDouble(),
      customerLongitude: (json['customer_longitude'] ?? json['longitude'] ?? json['lng'] as num?)?.toDouble(),
      customer: json[DbTables.users] is Map
          ? AppUser.fromJson(Map<String, dynamic>.from(json[DbTables.users] as Map))
          : (json['customer'] is Map
              ? AppUser.fromJson(Map<String, dynamic>.from(json['customer'] as Map))
              : (json['user'] is Map
                  ? AppUser.fromJson(Map<String, dynamic>.from(json['user'] as Map))
                  : ((json['customer_name'] != null || json['customer_phone'] != null)
                      ? AppUser(
                          id: json[BookingColumns.customerId]?.toString() ?? '',
                          fullName: json['customer_name']?.toString(),
                          phone: json['customer_phone']?.toString(),
                        )
                      : null))),
      service: (json[DbTables.services] is Map<String, dynamic>)
          ? ServiceModel.fromJson(json[DbTables.services] as Map<String, dynamic>)
          : ((json['service'] is Map<String, dynamic>)
              ? ServiceModel.fromJson(json['service'] as Map<String, dynamic>)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      BookingColumns.id: id,
      if (createdAt != null) BookingColumns.createdAt: createdAt!.toIso8601String(),
      if (customerId != null) BookingColumns.customerId: customerId,
      if (providerId != null) BookingColumns.providerId: providerId,
      if (serviceId != null) BookingColumns.serviceId: serviceId,
      if (status != null) BookingColumns.status: status,
      if (address != null) BookingColumns.address: address,
      if (scheduledAt != null)
        BookingColumns.scheduledAt: scheduledAt!.toIso8601String(),
      if (notes != null) BookingColumns.notes: notes,
      if (price != null) BookingColumns.price: price,
      if (paymentMethod != null) BookingColumns.paymentMethod: paymentMethod,
      if (paymentStatus != null) BookingColumns.paymentStatus: paymentStatus,
      if (customerLatitude != null) 'customer_latitude': customerLatitude,
      if (customerLongitude != null) 'customer_longitude': customerLongitude,
    };
  }

  BookingModel copyWith({
    String? id,
    DateTime? createdAt,
    String? customerId,
    String? providerId,
    String? serviceId,
    String? status,
    String? address,
    DateTime? scheduledAt,
    String? notes,
    double? price,
    String? paymentMethod,
    String? paymentStatus,
    double? customerLatitude,
    double? customerLongitude,
    AppUser? customer,
    ServiceModel? service,
  }) {
    return BookingModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      serviceId: serviceId ?? this.serviceId,
      status: status ?? this.status,
      address: address ?? this.address,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      notes: notes ?? this.notes,
      price: price ?? this.price,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      customer: customer ?? this.customer,
      service: service ?? this.service,
    );
  }

  @override
  String toString() =>
      'BookingModel(id: $id, customerId: $customerId, providerId: $providerId, status: $status, price: $price)';
}
