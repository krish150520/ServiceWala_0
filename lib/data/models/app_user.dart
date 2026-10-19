import 'package:service_wala_business/core/constants/database_constants.dart';

/// Typed model for the 'users' database table.
class AppUser {
  final String id;
  final DateTime? createdAt;
  final String? fullName;
  final String? phone;
  final String? role;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    this.createdAt,
    this.fullName,
    this.phone,
    this.role,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json[UserColumns.id]?.toString() ?? '',
      createdAt: json[UserColumns.createdAt] != null
          ? DateTime.tryParse(json[UserColumns.createdAt].toString())
          : null,
      fullName: (json[UserColumns.fullName] ??
              json['name'] ??
              json['display_name'] ??
              json['customer_name'])
          ?.toString(),
      phone: (json[UserColumns.phone] ??
              json['phone_number'] ??
              json['mobile'] ??
              json['customer_phone'])
          ?.toString(),
      role: json[UserColumns.role]?.toString(),
      avatarUrl: json['avatar_url']?.toString() ??
          json['profile_image']?.toString() ??
          json['avatar']?.toString() ??
          json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      UserColumns.id: id,
      if (createdAt != null) UserColumns.createdAt: createdAt!.toIso8601String(),
      if (fullName != null) UserColumns.fullName: fullName,
      if (phone != null) UserColumns.phone: phone,
      if (role != null) UserColumns.role: role,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }

  AppUser copyWith({
    String? id,
    DateTime? createdAt,
    String? fullName,
    String? phone,
    String? role,
    String? avatarUrl,
  }) {
    return AppUser(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  String toString() =>
      'AppUser(id: $id, fullName: $fullName, phone: $phone, role: $role, avatarUrl: $avatarUrl)';
}
