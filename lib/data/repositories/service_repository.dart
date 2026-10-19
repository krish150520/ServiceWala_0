import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/service_model.dart';

/// Repository managing system-wide service catalog queries in Supabase.
class ServiceRepository {
  final sp.SupabaseClient? _client;

  ServiceRepository({sp.SupabaseClient? client}) : _client = client;

  sp.SupabaseClient get _supabaseClient {
    final client = _client;
    if (client != null) return client;
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      throw const ConfigurationException(
        message: 'Supabase is not configured.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
    return SupabaseService.client;
  }

  /// Retrieve all active service categories from the 'services' table
  Future<List<ServiceModel>> getActiveServices() async {
    try {
      final response = await _supabaseClient
          .from(DbTables.services)
          .select()
          .eq(ServiceColumns.isActive, true)
          .order(ServiceColumns.name);

      return (response as List)
          .map((s) => ServiceModel.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to retrieve active services.',
        originalError: e,
      );
    }
  }

  /// Retrieve single service category by ID
  Future<ServiceModel> getServiceById(String serviceId) async {
    try {
      final response = await _supabaseClient
          .from(DbTables.services)
          .select()
          .eq(ServiceColumns.id, serviceId)
          .single();

      return ServiceModel.fromJson(response);
    } catch (e) {
      throw NotFoundException(
        message: 'Service category not found.',
        originalError: e,
      );
    }
  }
}
