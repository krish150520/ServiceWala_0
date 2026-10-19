import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/booking_model.dart';
import 'package:service_wala_business/data/models/earnings_model.dart';

/// Repository responsible for calculating real digital earnings and transaction history
/// from Supabase booking records.
///
/// RULES:
/// 1. Only bookings where `bookings.provider_id = current_provider.id` are used.
/// 2. Digital earnings = `status == 'completed' && payment_status == 'paid' && payment_method == 'razorpay'`.
/// 3. Cash on Service bookings are strictly EXCLUDED from digital earnings.
/// 4. Unpaid bookings or non-completed bookings are NEVER counted in earnings.
class EarningsRepository {
  final sp.SupabaseClient? _client;

  EarningsRepository({sp.SupabaseClient? client}) : _client = client;

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

  /// Retrieve comprehensive earnings summary for a given provider ID
  Future<EarningsSummary> getEarningsSummary(String providerId) async {
    try {
      final response = await _supabaseClient
          .from(DbTables.bookings)
          .select('''
            *,
            ${DbTables.users}:customer_id (
              ${UserColumns.id},
              ${UserColumns.fullName},
              ${UserColumns.phone}
            ),
            ${DbTables.services}:service_id (
              ${ServiceColumns.id},
              ${ServiceColumns.name},
              ${ServiceColumns.icon}
            )
          ''')
          .eq(BookingColumns.providerId, providerId)
          .order(BookingColumns.createdAt, ascending: false);

      final bookings = (response as List)
          .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
          .toList();

      return EarningsSummary.fromBookings(bookings);
    } catch (_) {
      try {
        final flatResponse = await _supabaseClient
            .from(DbTables.bookings)
            .select()
            .eq(BookingColumns.providerId, providerId)
            .order(BookingColumns.createdAt, ascending: false);

        final bookings = (flatResponse as List)
            .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
            .toList();

        return EarningsSummary.fromBookings(bookings);
      } catch (_) {
        return EarningsSummary.empty();
      }
    }
  }

  /// Retrieve earnings transactions filtered by date range
  Future<List<EarningsItemModel>> getEarningsHistory({
    required String providerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabaseClient
          .from(DbTables.bookings)
          .select('''
            *,
            ${DbTables.users}:customer_id (
              ${UserColumns.id},
              ${UserColumns.fullName},
              ${UserColumns.phone}
            ),
            ${DbTables.services}:service_id (
              ${ServiceColumns.id},
              ${ServiceColumns.name},
              ${ServiceColumns.icon}
            )
          ''')
          .eq(BookingColumns.providerId, providerId);

      if (startDate != null) {
        query = query.gte(BookingColumns.createdAt, startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte(BookingColumns.createdAt, endDate.toIso8601String());
      }

      final response = await query.order(BookingColumns.createdAt, ascending: false);

      final bookings = (response as List)
          .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
          .toList();

      return bookings.map((b) => EarningsItemModel.fromBooking(b)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to load earnings transaction history.',
        originalError: e,
      );
    }
  }
}
