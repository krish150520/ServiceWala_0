import 'package:service_wala_business/core/constants/database_constants.dart';

/// Typed model for the 'services' database table.
class ServiceModel {
  final String id;
  final DateTime? createdAt;
  final String name;
  final String? description;
  final String? icon;
  final bool isActive;

  const ServiceModel({
    required this.id,
    this.createdAt,
    required this.name,
    this.description,
    this.icon,
    this.isActive = true,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json[ServiceColumns.id]?.toString() ?? '',
      createdAt: json[ServiceColumns.createdAt] != null
          ? DateTime.tryParse(json[ServiceColumns.createdAt].toString())
          : null,
      name: json[ServiceColumns.name]?.toString() ?? '',
      description: json[ServiceColumns.description]?.toString(),
      icon: json[ServiceColumns.icon]?.toString(),
      isActive: json[ServiceColumns.isActive] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ServiceColumns.id: id,
      if (createdAt != null) ServiceColumns.createdAt: createdAt!.toIso8601String(),
      ServiceColumns.name: name,
      if (description != null) ServiceColumns.description: description,
      if (icon != null) ServiceColumns.icon: icon,
      ServiceColumns.isActive: isActive,
    };
  }

  ServiceModel copyWith({
    String? id,
    DateTime? createdAt,
    String? name,
    String? description,
    String? icon,
    bool? isActive,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() => 'ServiceModel(id: $id, name: $name, isActive: $isActive)';
}
