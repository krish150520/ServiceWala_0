import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/app_user.dart';
import 'package:service_wala_business/data/models/provider_model.dart';

/// Repository managing user and provider profile synchronization in Supabase.
class ProfileRepository {
  final sp.SupabaseClient? _client;

  ProfileRepository({sp.SupabaseClient? client}) : _client = client;

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

  /// Fetch public user profile from 'users' table
  Future<AppUser> getUserProfile(String userId) async {
    try {
      final response = await _supabaseClient
          .from(DbTables.users)
          .select()
          .eq(UserColumns.id, userId)
          .single();

      return AppUser.fromJson(response);
    } catch (e) {
      throw NotFoundException(
        message: 'User profile not found in public users table.',
        originalError: e,
      );
    }
  }

  /// Update basic profile fields in 'users' table
  Future<AppUser> updateUserProfile({
    required String userId,
    required String fullName,
    String? phone,
  }) async {
    try {
      final data = {
        UserColumns.fullName: fullName,
        UserColumns.phone: ?phone,
      };

      final response = await _supabaseClient
          .from(DbTables.users)
          .update(data)
          .eq(UserColumns.id, userId)
          .select()
          .single();

      return AppUser.fromJson(response);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update user profile.',
        originalError: e,
      );
    }
  }

  /// Update provider profile in 'providers' table
  /// Note: 'desciption' is the exact column name in PostgreSQL.
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

  /// Update avatar URL in users/providers table, auth user metadata, and via RPC if available
  Future<bool> updateAvatarUrl({
    required String userId,
    String? providerId,
    required String avatarUrl,
  }) async {
    bool anySuccess = false;

    // 1. Try secure RPC: update_user_avatar (atomic update if migration is applied)
    try {
      await _supabaseClient.rpc('update_user_avatar', params: {
        'p_avatar_url': avatarUrl,
      });
      debugPrint('[ProfileRepository] RPC update_user_avatar succeeded.');
      anySuccess = true;
    } catch (e) {
      debugPrint('[ProfileRepository] RPC update_user_avatar notice: $e');
    }

    // 2. Update Supabase Auth user metadata
    try {
      await _supabaseClient.auth.updateUser(
        sp.UserAttributes(data: {'avatar_url': avatarUrl}),
      );
      anySuccess = true;
      debugPrint('[ProfileRepository] auth.updateUser metadata synchronized.');
    } catch (e) {
      debugPrint('[ProfileRepository] auth.updateUser metadata notice: $e');
    }

    // 3. Update public.users table
    try {
      await _supabaseClient
          .from(DbTables.users)
          .update({UserColumns.avatarUrl: avatarUrl})
          .eq(UserColumns.id, userId);
      anySuccess = true;
      debugPrint('[ProfileRepository] public.users avatar_url updated for $userId.');
    } catch (e) {
      debugPrint('[ProfileRepository] public.users avatar_url update notice: $e');
    }

    // 4. Update public.providers table
    try {
      String? targetProvId = providerId;
      if (targetProvId == null || targetProvId.isEmpty) {
        final prov = await _supabaseClient
            .from(DbTables.providers)
            .select(ProviderColumns.id)
            .eq(ProviderColumns.userId, userId)
            .maybeSingle();
        targetProvId = prov?[ProviderColumns.id]?.toString();
      }

      if (targetProvId != null && targetProvId.isNotEmpty) {
        await _supabaseClient
            .from(DbTables.providers)
            .update({ProviderColumns.avatarUrl: avatarUrl})
            .eq(ProviderColumns.id, targetProvId);
        anySuccess = true;
        debugPrint(
          '[ProfileRepository] public.providers avatar_url updated for $targetProvId.',
        );
      }
    } catch (e) {
      debugPrint('[ProfileRepository] public.providers avatar_url update notice: $e');
    }

    return anySuccess;
  }

  /// Upload avatar image bytes to Supabase Storage and return public URL.
  /// Seamlessly checks both uppercase 'AVATARS' (as configured in Supabase Dashboard)
  /// and lowercase 'avatars'.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List imageBytes,
    String fileExtension = 'jpg',
  }) async {
    final sanitizedExt = fileExtension.replaceAll('.', '').toLowerCase();
    final path =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$sanitizedExt';

    final candidateBuckets = ['AVATARS', 'avatars'];
    Object? lastError;

    for (final bucket in candidateBuckets) {
      try {
        await _supabaseClient.storage.from(bucket).uploadBinary(
              path,
              imageBytes,
              fileOptions: sp.FileOptions(
                contentType: 'image/$sanitizedExt',
                upsert: true,
              ),
            );

        final publicUrl =
            _supabaseClient.storage.from(bucket).getPublicUrl(path);
        debugPrint(
          '[ProfileRepository] Uploaded avatar to bucket "$bucket": $publicUrl',
        );
        return publicUrl;
      } catch (e) {
        lastError = e;
        debugPrint('[ProfileRepository] Upload attempt to "$bucket" failed: $e');
      }
    }

    throw DatabaseException(
      message: 'Failed to upload photo to Supabase storage. '
          'Please ensure storage bucket "AVATARS" has INSERT and UPDATE policies enabled.',
      originalError: lastError,
    );
  }
}
