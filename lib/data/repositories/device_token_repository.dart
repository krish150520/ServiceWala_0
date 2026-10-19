import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;

/// Repository managing Firebase Cloud Messaging (FCM) device tokens in Supabase.
///
/// Features:
/// - Supports multiple devices per user without token collision.
/// - Safely upserts token records on (user_id, token) conflict.
/// - Automatically syncs token updates via [FirebaseMessaging.onTokenRefresh].
/// - Cleans up the current device's token on logout.
/// - Gracefully handles permission denial or missing Firebase configuration.
class DeviceTokenRepository {
  static final DeviceTokenRepository instance = DeviceTokenRepository._();
  DeviceTokenRepository._({FirebaseMessaging? fcm}) : _customFcm = fcm;

  static const String _kCachedTokenKey = 'cached_fcm_device_token';

  final FirebaseMessaging? _customFcm;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentToken;
  bool _isRegistering = false;

  FirebaseMessaging? get _fcm {
    if (_customFcm != null) return _customFcm;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseMessaging.instance;
      }
    } catch (_) {}
    return null;
  }

  /// Cached FCM token for the active device session
  String? get currentToken => _currentToken;

  sp.SupabaseClient get _client => SupabaseService.client;

  /// Determine the current operating system platform string
  String get currentPlatform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Initialize token refresh listener and register device token for the given authenticated user.
  Future<void> initAndRegister(String userId) async {
    if (userId.trim().isEmpty) {
      debugPrint('[DeviceTokenRepository] Cannot register token: invalid userId');
      return;
    }

    final fcm = _fcm;
    if (fcm == null) {
      debugPrint('[DeviceTokenRepository] Firebase not initialized. Skipping FCM token registration.');
      return;
    }

    // 1. Setup automatic token refresh handler
    _setupTokenRefreshListener(userId);

    // 2. Fetch current FCM token and upsert into Supabase
    try {
      final token = await fcm.getToken();
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        await _saveCachedToken(token);
        await registerToken(userId: userId, token: token);
      } else {
        debugPrint('[DeviceTokenRepository] No FCM token returned by Firebase');
      }
    } catch (e) {
      debugPrint('[DeviceTokenRepository] Failed to retrieve FCM token: $e');
    }
  }

  /// Upsert device token for the authenticated user in Supabase public.user_fcm_tokens (and public.device_tokens).
  Future<bool> registerToken({
    required String userId,
    required String token,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final cleanUserId = userId.trim();
    final cleanToken = token.trim();
    if (cleanUserId.isEmpty || cleanToken.isEmpty) return false;
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      debugPrint('[DeviceTokenRepository] Supabase not configured. Skipping token sync.');
      return false;
    }

    // Verify current authenticated session belongs to this userId
    final authUid = SupabaseService.currentUser?.id;
    if (authUid != null && authUid != cleanUserId) {
      debugPrint('[DeviceTokenRepository] Warning: userId $cleanUserId does not match active auth.uid $authUid. Skipping registration.');
      return false;
    }

    if (_isRegistering) return false;
    _isRegistering = true;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final info = deviceInfo ??
          {
            'app': 'service_wala_business',
            'timestamp': nowIso,
          };

      bool syncedFcmTokens = false;

      // 1. Primary synchronization in public.user_fcm_tokens
      try {
        final fcmPayload = {
          UserFcmTokenColumns.userId: cleanUserId,
          UserFcmTokenColumns.fcmToken: cleanToken,
          UserFcmTokenColumns.platform: currentPlatform,
          UserFcmTokenColumns.deviceInfo: info,
          UserFcmTokenColumns.updatedAt: nowIso,
        };

        await _client.from(DbTables.userFcmTokens).upsert(
          fcmPayload,
          onConflict: 'user_id, fcm_token',
        );
        syncedFcmTokens = true;
        debugPrint('[DeviceTokenRepository] Synced with public.user_fcm_tokens (fcm_token column)');
      } catch (e) {
        debugPrint('[DeviceTokenRepository] user_fcm_tokens fcm_token attempt notice: $e');
        // Fallback: try with 'token' column in user_fcm_tokens if schema uses 'token'
        try {
          final fallbackPayload = {
            UserFcmTokenColumns.userId: cleanUserId,
            'token': cleanToken,
            UserFcmTokenColumns.platform: currentPlatform,
            UserFcmTokenColumns.deviceInfo: info,
            UserFcmTokenColumns.updatedAt: nowIso,
          };
          await _client.from(DbTables.userFcmTokens).upsert(
            fallbackPayload,
            onConflict: 'user_id, token',
          );
          syncedFcmTokens = true;
          debugPrint('[DeviceTokenRepository] Synced with public.user_fcm_tokens (token column)');
        } catch (e2) {
          debugPrint('[DeviceTokenRepository] user_fcm_tokens fallback notice: $e2');
        }
      }

      // 2. Dual-write to public.device_tokens for multi-device push compatibility
      bool syncedDeviceTokens = false;
      try {
        final devicePayload = {
          DeviceTokenColumns.userId: cleanUserId,
          DeviceTokenColumns.token: cleanToken,
          DeviceTokenColumns.platform: currentPlatform,
          DeviceTokenColumns.deviceInfo: info,
          DeviceTokenColumns.updatedAt: nowIso,
        };

        await _client.from(DbTables.deviceTokens).upsert(
          devicePayload,
          onConflict: 'user_id, token',
        );
        syncedDeviceTokens = true;
        debugPrint('[DeviceTokenRepository] Synced with public.device_tokens');
      } catch (e) {
        debugPrint('[DeviceTokenRepository] device_tokens upsert notice: $e');
      }

      _currentToken = cleanToken;
      await _saveCachedToken(cleanToken);
      return syncedFcmTokens || syncedDeviceTokens;
    } catch (e) {
      debugPrint('[DeviceTokenRepository] Error registering device token: $e');
      return false;
    } finally {
      _isRegistering = false;
    }
  }

  /// Remove this device's token from Supabase upon logout.
  Future<void> removeTokenOnLogout(String userId) async {
    // Cancel active refresh subscription
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    final token = _currentToken ?? await _getCachedToken();
    if (token == null || token.isEmpty) {
      debugPrint('[DeviceTokenRepository] No token to remove on logout.');
      _currentToken = null;
      return;
    }

    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      _currentToken = null;
      await _clearCachedToken();
      return;
    }

    try {
      debugPrint('[DeviceTokenRepository] Removing device token on logout for user $userId');

      // 1. Delete from public.user_fcm_tokens
      try {
        await _client
            .from(DbTables.userFcmTokens)
            .delete()
            .match({
              UserFcmTokenColumns.userId: userId,
              UserFcmTokenColumns.fcmToken: token,
            });
      } catch (_) {
        try {
          await _client
              .from(DbTables.userFcmTokens)
              .delete()
              .match({
                UserFcmTokenColumns.userId: userId,
                'token': token,
              });
        } catch (_) {}
      }

      // 2. Delete from public.device_tokens
      try {
        await _client
            .from(DbTables.deviceTokens)
            .delete()
            .match({
              DeviceTokenColumns.userId: userId,
              DeviceTokenColumns.token: token,
            });
      } catch (_) {}

      // Optionally unregister from FCM instance
      try {
        await _fcm?.deleteToken();
      } catch (_) {}
    } catch (e) {
      debugPrint('[DeviceTokenRepository] Error removing device token: $e');
    } finally {
      _currentToken = null;
      await _clearCachedToken();
    }
  }

  void _setupTokenRefreshListener(String userId) {
    _tokenRefreshSubscription?.cancel();
    final fcm = _fcm;
    if (fcm == null) return;
    _tokenRefreshSubscription = fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('[DeviceTokenRepository] FCM token refreshed: $newToken');
      _currentToken = newToken;
      await _saveCachedToken(newToken);
      await registerToken(userId: userId, token: newToken);
    }, onError: (err) {
      debugPrint('[DeviceTokenRepository] Token refresh stream error: $err');
    });
  }

  Future<void> _saveCachedToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedTokenKey, token);
    } catch (_) {}
  }

  Future<String?> _getCachedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kCachedTokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearCachedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedTokenKey);
    } catch (_) {}
  }
}
