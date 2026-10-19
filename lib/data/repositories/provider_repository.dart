import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/provider_model.dart';
import 'package:service_wala_business/data/models/service_model.dart';

/// Repository managing Agent / Provider profiles and service mappings in Supabase.
class ProviderRepository {
  final sp.SupabaseClient? _client;

  ProviderRepository({sp.SupabaseClient? client}) : _client = client;

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

  /// Retrieve provider profile for the authenticated user ID (`providers.user_id = userId`)
  Future<ProviderModel?> getProviderByUserId(String userId) async {
    try {
      final response = await _supabaseClient
          .from(DbTables.providers)
          .select()
          .eq(ProviderColumns.userId, userId)
          .maybeSingle();

      if (response == null) return null;
      return ProviderModel.fromJson(response);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to retrieve provider profile.',
        originalError: e,
      );
    }
  }

  /// Retrieve provider profile by provider ID (`providers.id = providerId`)
  Future<ProviderModel> getProviderById(String providerId) async {
    try {
      final response = await _supabaseClient
          .from(DbTables.providers)
          .select()
          .eq(ProviderColumns.id, providerId)
          .single();

      return ProviderModel.fromJson(response);
    } catch (e) {
      throw NotFoundException(
        message: 'Provider not found.',
        originalError: e,
      );
    }
  }

  /// Create a new provider profile for an authenticated user
  Future<ProviderModel> createProviderProfile({
    required String userId,
    required String businessName,
    String? description,
    String? address,
    String? city,
    bool isAvailable = true,
  }) async {
    try {
      final data = {
        ProviderColumns.userId: userId,
        ProviderColumns.businessName: businessName.trim().isNotEmpty ? businessName.trim() : 'Partner',
        if (description != null && description.isNotEmpty) ProviderColumns.description: description,
        if (address != null && address.isNotEmpty) ProviderColumns.address: address,
        if (city != null && city.isNotEmpty) ProviderColumns.city: city,
        ProviderColumns.isAvailable: isAvailable,
      };

      final response = await _supabaseClient
          .from(DbTables.providers)
          .insert(data)
          .select()
          .single();

      return ProviderModel.fromJson(response);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create provider profile: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Get or create provider profile for the authenticated user ID
  Future<ProviderModel> getOrCreateProviderProfile({
    required String userId,
    required String businessName,
    String? description,
    String? address,
    String? city,
    bool isAvailable = true,
  }) async {
    try {
      final existing = await getProviderByUserId(userId);
      if (existing != null) {
        return existing;
      }
      return await createProviderProfile(
        userId: userId,
        businessName: businessName,
        description: description,
        address: address,
        city: city,
        isAvailable: isAvailable,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to synchronize provider profile: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Toggle or update availability status (`providers.is_available`)
  Future<void> updateAvailability({
    required String providerId,
    required bool isAvailable,
  }) async {
    try {
      await _supabaseClient
          .from(DbTables.providers)
          .update({ProviderColumns.isAvailable: isAvailable})
          .eq(ProviderColumns.id, providerId);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update online availability.',
        originalError: e,
      );
    }
  }

  /// Fetch all active services associated with a provider
  Future<List<ServiceModel>> getProviderServices(String providerId) async {
    try {
      // 1. Fetch service IDs from provider_services table
      final mappings = await _supabaseClient
          .from(DbTables.providerServices)
          .select(ProviderServiceColumns.serviceId)
          .eq(ProviderServiceColumns.providerId, providerId);

      final serviceIds = (mappings as List)
          .map((m) => m[ProviderServiceColumns.serviceId]?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (serviceIds.isEmpty) return [];

      // 2. Fetch service records from services table
      final servicesResponse = await _supabaseClient
          .from(DbTables.services)
          .select()
          .inFilter(ServiceColumns.id, serviceIds);

      return (servicesResponse as List)
          .map((s) => ServiceModel.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to retrieve provider services.',
        originalError: e,
      );
    }
  }

  /// Update provider profile fields in 'providers' table
  Future<ProviderModel> updateProviderProfile({
    required String providerId,
    String? businessName,
    String? description,
    String? address,
    String? city,
  }) async {
    try {
      final data = {
        ProviderColumns.businessName: ?businessName,
        ProviderColumns.description: ?description,
        ProviderColumns.address: ?address,
        ProviderColumns.city: ?city,
      };

      final response = await _supabaseClient
          .from(DbTables.providers)
          .update(data)
          .eq(ProviderColumns.id, providerId)
          .select()
          .single();

      return ProviderModel.fromJson(response);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update provider profile.',
        originalError: e,
      );
    }
  }

  /// Retrieve all services from system catalog
  Future<List<ServiceModel>> getAllServices() async {
    try {
      final response = await _supabaseClient
          .from(DbTables.services)
          .select()
          .order(ServiceColumns.name);

      return (response as List)
          .map((s) => ServiceModel.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch services.',
        originalError: e,
      );
    }
  }

  /// Synchronize provider skills in provider_services table
  Future<void> syncProviderServices({
    required String providerId,
    required List<String> serviceIds,
  }) async {
    try {
      // 1. Remove existing mappings
      await _supabaseClient
          .from(DbTables.providerServices)
          .delete()
          .eq(ProviderServiceColumns.providerId, providerId);

      // 2. Insert new mappings
      if (serviceIds.isNotEmpty) {
        final records = serviceIds.map((sId) => {
              ProviderServiceColumns.providerId: providerId,
              ProviderServiceColumns.serviceId: sId,
            }).toList();

        await _supabaseClient.from(DbTables.providerServices).insert(records);
      }
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to synchronize provider services.',
        originalError: e,
      );
    }
  }
}
