import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/app_user.dart';

/// Repository managing Email/Password Authentication and Supabase user sessions.
class AuthRepository {
  final sp.SupabaseClient? _client;

  AuthRepository({sp.SupabaseClient? client}) : _client = client;

  sp.SupabaseClient get _supabaseClient {
    final client = _client;
    if (client != null) return client;
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      throw const ConfigurationException(
        message: 'Supabase is not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY.',
        code: 'AUTH_NOT_CONFIGURED',
      );
    }
    return SupabaseService.client;
  }

  /// Get the current active Supabase session
  sp.Session? get currentSession {
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) return null;
    return _supabaseClient.auth.currentSession;
  }

  /// Get the currently authenticated Supabase user
  sp.User? get currentAuthUser {
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) return null;
    return _supabaseClient.auth.currentUser;
  }

  /// Authenticate using Email and Password
  Future<sp.AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseClient.auth
          .signInWithPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const AppAuthException(
              message: 'Connection timed out. Slow network detected. Please check your connection and try again.',
              code: 'TIMEOUT',
            ),
          );
      return response;
    } on AppAuthException {
      rethrow;
    } on sp.AuthException catch (e) {
      throw AppAuthException(
        message: _getReadableAuthErrorMessage(e),
        code: e.statusCode,
        originalError: e,
      );
    } catch (e) {
      throw AppAuthException(
        message: 'Sign-in failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Register a new account using Email and Password
  Future<sp.AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _supabaseClient.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
        },
      );
      return response;
    } on sp.AuthException catch (e) {
      throw AppAuthException(
        message: _getReadableAuthErrorMessage(e),
        code: e.statusCode,
        originalError: e,
      );
    } catch (e) {
      throw AppAuthException(
        message: 'Registration failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Send password reset email
  Future<void> resetPasswordForEmail(String email) async {
    try {
      await _supabaseClient.auth.resetPasswordForEmail(email.trim());
    } on sp.AuthException catch (e) {
      throw AppAuthException(
        message: _getReadableAuthErrorMessage(e),
        code: e.statusCode,
        originalError: e,
      );
    } catch (e) {
      throw AppAuthException(
        message: 'Failed to send password reset email: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Sign out current Supabase session
  Future<void> signOut() async {
    try {
      if (SupabaseConfig.isConfigured && SupabaseService.isInitialized) {
        await _supabaseClient.auth.signOut();
      }
    } catch (e) {
      throw AppAuthException(
        message: 'Failed to sign out.',
        originalError: e,
      );
    }
  }

  /// Fetch or create public user record in 'users' table
  Future<AppUser> getOrCreatePublicUser({
    required String userId,
    String? phone,
    String? email,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final response = await _supabaseClient
          .from(DbTables.users)
          .select()
          .eq(UserColumns.id, userId)
          .maybeSingle();

      if (response != null) {
        return AppUser.fromJson(response);
      }

      // Create new user profile in 'users' table
      final newUserData = {
        UserColumns.id: userId,
        if (phone != null && phone.isNotEmpty) UserColumns.phone: phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (fullName != null && fullName.isNotEmpty) UserColumns.fullName: fullName,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
        UserColumns.role: 'provider',
      };

      final insertResponse = await _supabaseClient
          .from(DbTables.users)
          .insert(newUserData)
          .select()
          .single();

      return AppUser.fromJson(insertResponse);
    } catch (e) {
      // Return fallback user model if profile table sync is not available or restricted
      return AppUser(
        id: userId,
        phone: phone,
        fullName: fullName,
        role: 'provider',
        avatarUrl: avatarUrl,
      );
    }
  }

  String _getReadableAuthErrorMessage(sp.AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit')) {
      return 'Email rate limit exceeded. Disable "Confirm email" in Supabase dashboard to register instantly without email limits.';
    }
    if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('user already registered') || msg.contains('already registered')) {
      return 'An account with this email address already exists. Please sign in.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email address before signing in. Check your inbox for the confirmation link.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password should be at least 6 characters long.';
    }
    return e.message;
  }
}
