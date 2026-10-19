import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';

/// Centralized service managing the Supabase client lifecycle and session access.
class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;

  /// Private constructor to enforce singleton usage
  SupabaseService._();

  /// Check whether Supabase has been initialized
  static bool get isInitialized => _isInitialized;

  /// Direct accessor for the global SupabaseClient.
  /// Throws a [ConfigurationException] if accessed before initialization or without configuration.
  static SupabaseClient get client {
    if (!_isInitialized || _client == null) {
      if (!SupabaseConfig.isConfigured) {
        throw const ConfigurationException(
          message:
              'Supabase credentials are not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY.',
          code: 'SUPABASE_NOT_CONFIGURED',
        );
      }
      throw const ConfigurationException(
        message: 'SupabaseService has not been initialized. Call initialize() first.',
        code: 'SUPABASE_NOT_INITIALIZED',
      );
    }
    return _client!;
  }

  /// Initialize Supabase at app startup.
  /// Safely handles unconfigured environments without crashing the UI.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (!SupabaseConfig.isConfigured) {
      // Allow the app to run in demo/offline mode without crashing
      _isInitialized = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url.trim(),
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.anonKey.trim(),
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      throw DatabaseException(
        message: 'Failed to initialize Supabase connection: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Current authenticated user (null if unauthenticated or offline)
  static User? get currentUser {
    if (!_isInitialized || _client == null) return null;
    return _client!.auth.currentUser;
  }

  /// Current auth session
  static Session? get currentSession {
    if (!_isInitialized || _client == null) return null;
    return _client!.auth.currentSession;
  }

  /// Auth state change stream
  static Stream<AuthState>? get authStateChanges {
    if (!_isInitialized || _client == null) return null;
    return _client!.auth.onAuthStateChange;
  }
}
