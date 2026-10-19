import 'package:service_wala_business/core/constants/database_constants.dart';

/// Model representing a booking-linked chat conversation from 'public.conversations'.
class ConversationModel {
  final String id;
  final String bookingId;
  final String? customerId;
  final DateTime createdAt;

  const ConversationModel({
    required this.id,
    required this.bookingId,
    this.customerId,
    required this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    String? customerId;
    if (json[DbTables.bookings] is Map<String, dynamic>) {
      customerId = json[DbTables.bookings][BookingColumns.customerId]?.toString();
    } else if (json['customer_id'] != null) {
      customerId = json['customer_id']?.toString();
    }

    return ConversationModel(
      id: json[ConversationColumns.id]?.toString() ?? '',
      bookingId: json[ConversationColumns.bookingId]?.toString() ?? '',
      customerId: customerId,
      createdAt: json[ConversationColumns.createdAt] != null
          ? DateTime.tryParse(json[ConversationColumns.createdAt].toString()) ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ConversationColumns.id: id,
      ConversationColumns.bookingId: bookingId,
      if (customerId != null) 'customer_id': customerId,
      ConversationColumns.createdAt: createdAt.toIso8601String(),
    };
  }
}
