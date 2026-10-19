import 'package:service_wala_business/core/constants/database_constants.dart';

/// Typed model for the 'providers' database table.
///
/// NOTE: The database column for description is spelled 'desciption'.
class ProviderModel {
  final String id;
  final DateTime? createdAt;
  final String userId;
  final String? businessName;
  final String? description;
  final String? address;
  final String? city;
  final bool isAvailable;
  final String? avatarUrl;

  const ProviderModel({
    required this.id,
    this.createdAt,
    required this.userId,
    this.businessName,
    this.description,
    this.address,
    this.city,
    this.isAvailable = false,
    this.avatarUrl,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json[ProviderColumns.id]?.toString() ?? '',
      createdAt: json[ProviderColumns.createdAt] != null
          ? DateTime.tryParse(json[ProviderColumns.createdAt].toString())
          : null,
      userId: json[ProviderColumns.userId]?.toString() ?? '',
      businessName: json[ProviderColumns.businessName]?.toString(),
      description: json[ProviderColumns.description]?.toString(),
      address: json[ProviderColumns.address]?.toString(),
      city: json[ProviderColumns.city]?.toString(),
      isAvailable: json[ProviderColumns.isAvailable] == true,
      avatarUrl: json['avatar_url']?.toString() ??
          json['profile_image']?.toString() ??
          json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ProviderColumns.id: id,
      if (createdAt != null) ProviderColumns.createdAt: createdAt!.toIso8601String(),
      ProviderColumns.userId: userId,
      if (businessName != null) ProviderColumns.businessName: businessName,
      if (description != null) ProviderColumns.description: description,
      if (address != null) ProviderColumns.address: address,
      if (city != null) ProviderColumns.city: city,
      ProviderColumns.isAvailable: isAvailable,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }

  ProviderModel copyWith({
    String? id,
    DateTime? createdAt,
    String? userId,
    String? businessName,
    String? description,
    String? address,
    String? city,
    bool? isAvailable,
    String? avatarUrl,
  }) {
    return ProviderModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      isAvailable: isAvailable ?? this.isAvailable,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  String toString() =>
      'ProviderModel(id: $id, userId: $userId, businessName: $businessName, isAvailable: $isAvailable, avatarUrl: $avatarUrl)';
}
