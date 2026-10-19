import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/payment_model.dart';

/// Repository managing payment records and payment status checks in Supabase.
class PaymentRepository {
  final sp.SupabaseClient? _client;

  PaymentRepository({sp.SupabaseClient? client}) : _client = client;

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

  /// Check payment status for a specific booking
  Future<AppPaymentStatus> getBookingPaymentStatus(String bookingId) async {
    try {
      final response = await _supabaseClient
          .from(DbTables.bookings)
          .select(BookingColumns.paymentStatus)
          .eq(BookingColumns.id, bookingId)
          .single();

      final statusStr = response[BookingColumns.paymentStatus]?.toString();
      return AppPaymentStatus.fromDb(statusStr);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to retrieve payment status for booking $bookingId.',
        originalError: e,
      );
    }
  }

  /// Mark payment method for a booking (e.g. customer chooses 'cash' or 'razorpay')
  Future<void> setBookingPaymentMethod({
    required String bookingId,
    required AppPaymentMethod method,
  }) async {
    try {
      await _supabaseClient
          .from(DbTables.bookings)
          .update({BookingColumns.paymentMethod: method.dbValue})
          .eq(BookingColumns.id, bookingId);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update payment method.',
        originalError: e,
      );
    }
  }

  /// Acknowledge cash payment received by agent
  ///
  /// Updates payment_method = 'cash', payment_status = 'paid', and optionally updates final price.
  Future<void> confirmCashPaymentReceived({
    required String bookingId,
    double? amount,
  }) async {
    final cleanId = bookingId.trim();
    try {
      final updateData = <String, dynamic>{
        BookingColumns.paymentMethod: DbPaymentMethods.cash,
        BookingColumns.paymentStatus: DbPaymentStatuses.paid,
      };
      if (amount != null && amount > 0) {
        updateData[BookingColumns.price] = amount;
      }
      await _supabaseClient
          .from(DbTables.bookings)
          .update(updateData)
          .eq(BookingColumns.id, cleanId);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to confirm cash collection in database: $e',
        originalError: e,
      );
    }
  }

  /// Request customer to pay online via Razorpay/UPI
  ///
  /// Sets price = amount, payment_method = 'razorpay', and payment_status = 'pending'.
  Future<void> requestUpiPayment({
    required String bookingId,
    required double amount,
  }) async {
    final cleanId = bookingId.trim();
    try {
      await _supabaseClient
          .from(DbTables.bookings)
          .update({
            BookingColumns.price: amount,
            BookingColumns.paymentMethod: DbPaymentMethods.razorpay,
            BookingColumns.paymentStatus: DbPaymentStatuses.pending,
          })
          .eq(BookingColumns.id, cleanId);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to request UPI payment from customer: $e',
        originalError: e,
      );
    }
  }
}
