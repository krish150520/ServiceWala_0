/// Service request from a customer
class ServiceRequest {
  final String id;
  final String? customerId;
  final String customerName;
  final String serviceType;
  final String description;
  final String? preferredTime;
  final String approximateArea;
  final double? latitude;
  final double? longitude;
  final String status; // pending, accepted, confirmed, declined, expired
  final DateTime createdAt;
  final List<String>? photos;

  const ServiceRequest({
    required this.id,
    this.customerId,
    required this.customerName,
    required this.serviceType,
    required this.description,
    this.preferredTime,
    required this.approximateArea,
    this.latitude,
    this.longitude,
    this.status = 'pending',
    required this.createdAt,
    this.photos,
  });

  ServiceRequest copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? serviceType,
    String? description,
    String? preferredTime,
    String? approximateArea,
    double? latitude,
    double? longitude,
    String? status,
    DateTime? createdAt,
    List<String>? photos,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      serviceType: serviceType ?? this.serviceType,
      description: description ?? this.description,
      preferredTime: preferredTime ?? this.preferredTime,
      approximateArea: approximateArea ?? this.approximateArea,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      photos: photos ?? this.photos,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'service_type': serviceType,
      'description': description,
      'preferred_time': preferredTime,
      'approximate_area': approximateArea,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'photos': photos,
    };
  }

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] ?? '',
      customerId: json['customer_id'],
      customerName: json['customer_name'] ?? 'Customer',
      serviceType: json['service_type'] ?? '',
      description: json['description'] ?? '',
      preferredTime: json['preferred_time'],
      approximateArea: json['approximate_area'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      photos: json['photos'] != null
          ? List<String>.from(json['photos'])
          : null,
    );
  }
}
