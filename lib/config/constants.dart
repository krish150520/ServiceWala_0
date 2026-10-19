import 'package:flutter/material.dart';

/// All available service categories with pastel styling matching ServiceWala design
class ServiceCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.bgColor = const Color(0xFFF1F5F9),
    this.iconColor = const Color(0xFF0047FF),
  });

  static const List<ServiceCategory> all = [
    ServiceCategory(
      id: 'electrician',
      name: 'Electrician',
      icon: Icons.bolt_rounded,
      bgColor: Color(0xFFE6F9EE),
      iconColor: Color(0xFF16A34A),
    ),
    ServiceCategory(
      id: 'plumbing',
      name: 'Plumber',
      icon: Icons.water_drop_outlined,
      bgColor: Color(0xFFE0F7FA),
      iconColor: Color(0xFF00ACC1),
    ),
    ServiceCategory(
      id: 'ac_repair',
      name: 'AC Repair',
      icon: Icons.ac_unit_rounded,
      bgColor: Color(0xFFE1F5FE),
      iconColor: Color(0xFF0288D1),
    ),
    ServiceCategory(
      id: 'carpentry',
      name: 'Carpenter',
      icon: Icons.hardware_rounded,
      bgColor: Color(0xFFFFF3E0),
      iconColor: Color(0xFFD97706),
    ),
    ServiceCategory(
      id: 'cleaning',
      name: 'Cleaning',
      icon: Icons.cleaning_services_rounded,
      bgColor: Color(0xFFEBF8FF),
      iconColor: Color(0xFF3182CE),
    ),
    ServiceCategory(
      id: 'painting',
      name: 'Painter',
      icon: Icons.format_paint_rounded,
      bgColor: Color(0xFFF3E8FF),
      iconColor: Color(0xFF9333EA),
    ),
    ServiceCategory(
      id: 'vehicle',
      name: 'Vehicle Repair',
      icon: Icons.build_circle_outlined,
      bgColor: Color(0xFFFCE4EC),
      iconColor: Color(0xFFD81B60),
    ),
    ServiceCategory(
      id: 'appliance_repair',
      name: 'Appliance Repair',
      icon: Icons.home_repair_service_rounded,
      bgColor: Color(0xFFFEF3C7),
      iconColor: Color(0xFFD97706),
    ),
    ServiceCategory(
      id: 'beauty',
      name: 'Beauty Services',
      icon: Icons.face_retouching_natural_rounded,
      bgColor: Color(0xFFFDF2F8),
      iconColor: Color(0xFFDB2777),
    ),
    ServiceCategory(
      id: 'tutoring',
      name: 'Tutoring',
      icon: Icons.school_rounded,
      bgColor: Color(0xFFEDE9FE),
      iconColor: Color(0xFF7C3AED),
    ),
    ServiceCategory(
      id: 'other',
      name: 'Other Services',
      icon: Icons.grid_view_rounded,
      bgColor: Color(0xFFF1F5F9),
      iconColor: Color(0xFF475569),
    ),
  ];

  static ServiceCategory? findById(String id) {
    try {
      return all.firstWhere((s) => s.id == id || s.id == id.toLowerCase());
    } catch (_) {
      return null;
    }
  }
}

/// Booking status enum
enum BookingStatus {
  pendingResponse('Pending Response', 'Waiting for agent response'),
  accepted('Accepted', 'Awaiting customer confirmation'),
  confirmed('Confirmed', 'Booking confirmed'),
  onTheWay('On The Way', 'Agent is on the way'),
  arrived('Arrived', 'Agent has arrived'),
  workStarted('Work Started', 'Work in progress'),
  completed('Completed', 'Job completed'),
  declined('Declined', 'Request declined'),
  cancelled('Cancelled', 'Booking cancelled'),
  expired('Expired', 'Request expired');

  final String label;
  final String description;

  const BookingStatus(this.label, this.description);

  bool get isActive =>
      this == confirmed ||
      this == onTheWay ||
      this == arrived ||
      this == workStarted;

  bool get isPending => this == accepted;
  bool get isCompleted => this == completed;
  bool get isCancelled => this == cancelled || this == declined || this == expired;
  bool get isHistory => this == completed || this == declined || this == cancelled || this == expired;
}

/// Payment status
enum PaymentStatus {
  pending('Pending'),
  paid('Paid'),
  failed('Failed');

  final String label;
  const PaymentStatus(this.label);
}

/// Payment method
enum PaymentMethod {
  razorpay('Razorpay', true),
  cash('Cash on Service', false);

  final String label;
  final bool isDigital;
  const PaymentMethod(this.label, this.isDigital);
}
