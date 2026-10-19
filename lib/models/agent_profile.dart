/// Agent profile model
class AgentProfile {
  final String id;
  final String? userId;
  final String fullName;
  final String phone;
  final String? profileImage;
  final List<String> services;
  final String? serviceArea;
  final double? latitude;
  final double? longitude;
  final bool isOnline;
  final String? verificationStatus;
  final int? yearsExperience;
  final double rating;
  final int reviewCount;
  final String? description;
  final DateTime? createdAt;

  const AgentProfile({
    required this.id,
    this.userId,
    required this.fullName,
    required this.phone,
    this.profileImage,
    this.services = const [],
    this.serviceArea,
    this.latitude,
    this.longitude,
    this.isOnline = false,
    this.verificationStatus,
    this.yearsExperience,
    this.rating = 4.9,
    this.reviewCount = 128,
    this.description,
    this.createdAt,
  });

  AgentProfile copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? phone,
    String? profileImage,
    List<String>? services,
    String? serviceArea,
    double? latitude,
    double? longitude,
    bool? isOnline,
    String? verificationStatus,
    int? yearsExperience,
    double? rating,
    int? reviewCount,
    String? description,
    DateTime? createdAt,
  }) {
    return AgentProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      services: services ?? this.services,
      serviceArea: serviceArea ?? this.serviceArea,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isOnline: isOnline ?? this.isOnline,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'phone': phone,
      'profile_image': profileImage,
      'services': services,
      'service_area': serviceArea,
      'latitude': latitude,
      'longitude': longitude,
      'is_online': isOnline,
      'verification_status': verificationStatus,
      'years_experience': yearsExperience,
      'rating': rating,
      'review_count': reviewCount,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      id: json['id'] ?? '',
      userId: json['user_id'],
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      profileImage: json['profile_image'],
      services: List<String>.from(json['services'] ?? []),
      serviceArea: json['service_area'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isOnline: json['is_online'] ?? false,
      verificationStatus: json['verification_status'],
      yearsExperience: json['years_experience'],
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      reviewCount: json['review_count'] ?? 128,
      description: json['description'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}
