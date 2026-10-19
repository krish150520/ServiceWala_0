import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/app_user.dart';
import 'package:service_wala_business/data/models/booking_model.dart';

/// Repository managing bookings assigned to the authenticated provider.
///
/// NOTE: Bookings reference `providers.id` via `bookings.provider_id`,
/// which resolves from `providers.user_id = authenticated_user.id`.
class BookingRepository {
  final sp.SupabaseClient? _client;

  BookingRepository({sp.SupabaseClient? client}) : _client = client;

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

  /// Resolve current authenticated provider ID (`providers.id`) from `auth.uid()`.
  Future<String?> resolveCurrentProviderId() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return null;

      final res = await _supabaseClient
          .from(DbTables.providers)
          .select(ProviderColumns.id)
          .eq(ProviderColumns.userId, user.id)
          .maybeSingle();

      return res?[ProviderColumns.id]?.toString();
    } catch (e) {
      return null;
    }
  }

  /// Retrieve all bookings assigned to a provider ID (`bookings.provider_id = providerId`).
  ///
  /// Strictly queries by provider profile UUID without mixing in user_id.
  Future<List<BookingModel>> getBookingsForProvider(String providerId) async {
    try {
      // Primary attempt with relational join for customer and service
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
        return await _enrichBookingsWithCustomers(bookings);
      } catch (_) {
        // Fallback: flat select without strict relational join constraints
        final flatResponse = await _supabaseClient
            .from(DbTables.bookings)
            .select()
            .eq(BookingColumns.providerId, providerId)
            .order(BookingColumns.createdAt, ascending: false);

        final bookings = (flatResponse as List)
            .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
            .toList();
        return await _enrichBookingsWithCustomers(bookings);
      }
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to retrieve bookings for provider: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Safely enriches bookings with customer details (full_name, phone) from public.users table
  Future<List<BookingModel>> _enrichBookingsWithCustomers(List<BookingModel> bookings) async {
    final missingCustomerIds = bookings
        .where((b) =>
            (b.customer == null ||
             b.customer?.fullName == null ||
             b.customer!.fullName!.trim().isEmpty ||
             b.customer!.fullName!.trim().toLowerCase() == 'customer' ||
             b.customer?.phone == null ||
             b.customer!.phone!.trim().isEmpty) &&
            b.customerId != null &&
            b.customerId!.isNotEmpty)
        .map((b) => b.customerId!)
        .toSet()
        .toList();

    if (missingCustomerIds.isEmpty) return bookings;

    try {
      final userRows = await _supabaseClient
          .from(DbTables.users)
          .select()
          .inFilter(UserColumns.id, missingCustomerIds);

      final userMap = <String, AppUser>{};
      for (final row in (userRows as List)) {
        final u = AppUser.fromJson(Map<String, dynamic>.from(row as Map));
        userMap[u.id] = u;
      }

      if (userMap.isNotEmpty) {
        return bookings.map((b) {
          if (b.customerId != null && userMap.containsKey(b.customerId)) {
            final existingUser = b.customer;
            final fetchedUser = userMap[b.customerId]!;
            final mergedUser = existingUser != null
                ? existingUser.copyWith(
                    fullName: (fetchedUser.fullName != null &&
                            fetchedUser.fullName!.trim().isNotEmpty &&
                            fetchedUser.fullName!.trim().toLowerCase() != 'customer')
                        ? fetchedUser.fullName
                        : existingUser.fullName,
                    phone: (fetchedUser.phone != null && fetchedUser.phone!.trim().isNotEmpty)
                        ? fetchedUser.phone
                        : existingUser.phone,
                    avatarUrl: fetchedUser.avatarUrl ?? existingUser.avatarUrl,
                  )
                : fetchedUser;
            return b.copyWith(customer: mergedUser);
          }
          return b;
        }).toList();
      }
    } catch (e) {
      debugPrint('[BookingRepository] Customer enrichment notice: $e');
    }
    return bookings;
  }

  /// Retrieve a single booking by ID with customer and service details
  Future<BookingModel> getBookingById(String bookingId) async {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) {
      throw const ValidationException(
        message: 'Booking ID cannot be empty.',
        code: 'VALIDATION_ERROR',
      );
    }

    Map<String, dynamic>? record;
    dynamic primaryError;

    // 1. Primary attempt with relational join for customer and service
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
          .eq(BookingColumns.id, cleanId)
          .maybeSingle();

      record = response;
    } catch (e) {
      primaryError = e;
      debugPrint('[BookingRepository] getBookingById relational join notice: $e');
    }

    // 2. Fallback: flat select without strict relational join constraints (mirrors getBookingsForProvider)
    if (record == null && primaryError != null) {
      try {
        final flatResponse = await _supabaseClient
            .from(DbTables.bookings)
            .select()
            .eq(BookingColumns.id, cleanId)
            .maybeSingle();

        record = flatResponse;
      } catch (e) {
        debugPrint('[BookingRepository] getBookingById flat query error: $e');
        if (primaryError is sp.PostgrestException) {
          throw DatabaseException(
            message: primaryError.message,
            code: primaryError.code,
            originalError: primaryError,
          );
        }
        throw DatabaseException(
          message: 'Failed to retrieve booking: ${e.toString()}',
          originalError: e,
        );
      }
    }

    if (record == null) {
      throw NotFoundException(
        message: 'Booking not found.',
        code: primaryError is sp.PostgrestException ? primaryError.code : 'NOT_FOUND',
        originalError: primaryError,
      );
    }

    var singleBooking = BookingModel.fromJson(record);
    if ((singleBooking.customer == null ||
         singleBooking.customer?.fullName == null ||
         singleBooking.customer!.fullName!.trim().toLowerCase() == 'customer' ||
         singleBooking.customer?.phone == null) &&
        singleBooking.customerId != null &&
        singleBooking.customerId!.isNotEmpty) {
      final enriched = await _enrichBookingsWithCustomers([singleBooking]);
      if (enriched.isNotEmpty) singleBooking = enriched.first;
    }

    return singleBooking;
  }

  /// Accept an incoming booking atomically via PostgreSQL RPC.
  Future<BookingModel> acceptBooking(String bookingId) async {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) {
      throw const ValidationException(
        message: 'Booking ID cannot be empty.',
        code: 'VALIDATION_ERROR',
      );
    }

    try {
      // Safe pre-check: do not let transient pre-check failure block authoritative RPC
      try {
        final current = await getBookingById(cleanId);
        if (current.status == DbBookingStatuses.accepted ||
            DbBookingStatuses.hasReachedOrPassed(current.status, DbBookingStatuses.confirmed)) {
          return current;
        }
      } catch (e) {
        debugPrint('[BookingRepository] Pre-check notice for $cleanId: $e');
      }

      final rpcResult = await _supabaseClient.rpc(
        'accept_booking',
        params: {'p_booking_id': cleanId},
      );

      if (rpcResult is Map) {
        final success = rpcResult['success'] == true;
        if (!success) {
          throw DatabaseException(
            message: rpcResult['error']?.toString() ??
                'Failed to accept booking.',
          );
        }
      } else if (rpcResult is bool && !rpcResult) {
        throw const DatabaseException(message: 'Failed to accept booking.');
      }

      // Return authoritative record after RPC
      return await getBookingById(cleanId);
    } on sp.PostgrestException catch (pgErr) {
      debugPrint('[BookingRepository] accept_booking PostgrestException: code=${pgErr.code}, message=${pgErr.message}, details=${pgErr.details}');
      if (pgErr.code == '42883') {
        // Fall back to update_booking_status RPC if accept_booking RPC is not present
        return updateBookingStatus(
          bookingId: cleanId,
          status: DbBookingStatuses.accepted,
        );
      }
      if (pgErr.code == 'P0002') {
        throw NotFoundException(
          message: pgErr.message.isNotEmpty ? pgErr.message : 'Booking not found.',
          code: pgErr.code,
          originalError: pgErr,
        );
      }
      if (pgErr.code == '42501') {
        throw UnauthorizedException(
          message: pgErr.message.isNotEmpty ? pgErr.message : 'Unauthorized to accept this booking.',
          code: pgErr.code,
          originalError: pgErr,
        );
      }
      if (pgErr.code == '22023') {
        throw ValidationException(
          message: pgErr.message.isNotEmpty ? pgErr.message : 'Invalid booking status for acceptance.',
          code: pgErr.code,
          originalError: pgErr,
        );
      }

      try {
        final latest = await getBookingById(cleanId);
        if (latest.status == DbBookingStatuses.accepted ||
            DbBookingStatuses.hasReachedOrPassed(latest.status, DbBookingStatuses.confirmed)) {
          return latest;
        }
      } catch (_) {}

      throw DatabaseException(
        message: pgErr.message,
        code: pgErr.code,
        originalError: pgErr,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to accept booking: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Decline an incoming booking atomically via PostgreSQL RPC.
  Future<BookingModel> declineBooking(String bookingId) async {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) {
      throw const ValidationException(
        message: 'Booking ID cannot be empty.',
        code: 'VALIDATION_ERROR',
      );
    }

    try {
      // Safe pre-check: do not let transient pre-check failure block authoritative RPC
      try {
        final current = await getBookingById(cleanId);
        if (current.status == DbBookingStatuses.declined ||
            current.status == DbBookingStatuses.cancelled) {
          return current;
        }
      } catch (e) {
        debugPrint('[BookingRepository] Pre-check notice for $cleanId: $e');
      }

      final rpcResult = await _supabaseClient.rpc(
        'decline_booking',
        params: {'p_booking_id': cleanId},
      );

      if (rpcResult is Map) {
        final success = rpcResult['success'] == true;
        if (!success) {
          throw DatabaseException(
            message: rpcResult['error']?.toString() ??
                'Failed to decline booking.',
          );
        }
      } else if (rpcResult is bool && !rpcResult) {
        throw const DatabaseException(message: 'Failed to decline booking.');
      }

      return await getBookingById(cleanId);
    } on sp.PostgrestException catch (pgErr) {
      debugPrint('[BookingRepository] decline_booking PostgrestException: code=${pgErr.code}, message=${pgErr.message}, details=${pgErr.details}');
      if (pgErr.code == '42883') {
        // Fall back to update_booking_status RPC if decline_booking RPC is not present
        return updateBookingStatus(
          bookingId: cleanId,
          status: DbBookingStatuses.declined,
        );
      }
      if (pgErr.code == 'P0002') {
        throw NotFoundException(
          message: pgErr.message.isNotEmpty ? pgErr.message : 'Booking not found.',
          code: pgErr.code,
          originalError: pgErr,
        );
      }
      if (pgErr.code == '42501') {
        throw UnauthorizedException(
          message: pgErr.message.isNotEmpty ? pgErr.message : 'Unauthorized to decline this booking.',
          code: pgErr.code,
          originalError: pgErr,
        );
      }
      if (pgErr.code == '22023') {
        throw ValidationException(
          message: pgErr.message.isNotEmpty ? pgErr.message : 'Invalid booking status for declining.',
          code: pgErr.code,
          originalError: pgErr,
        );
      }

      try {
        final latest = await getBookingById(cleanId);
        if (latest.status == DbBookingStatuses.declined ||
            latest.status == DbBookingStatuses.cancelled) {
          return latest;
        }
      } catch (_) {}

      throw DatabaseException(
        message: pgErr.message,
        code: pgErr.code,
        originalError: pgErr,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to decline booking: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Update booking status via secure PostgreSQL RPC.
  ///
  /// Never bypasses the canonical lifecycle from the client.
  Future<BookingModel> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) {
      throw const ValidationException(
        message: 'Booking ID cannot be empty.',
        code: 'VALIDATION_ERROR',
      );
    }

    try {
      // 1. Authoritative safe pre-check: Fetch the current booking status from Supabase
      try {
        final currentBooking = await getBookingById(cleanId);
        if (DbBookingStatuses.hasReachedOrPassed(currentBooking.status, status)) {
          // The target status (or a later stage) is already persisted in the database.
          // Return the authoritative record immediately without issuing an invalid duplicate transition.
          return currentBooking;
        }

        // Auto-promote prerequisite stages if transitioning confirmed -> arrived
        final curNorm = currentBooking.status?.toLowerCase().trim() ?? '';
        if (status == DbBookingStatuses.arrived && curNorm == DbBookingStatuses.confirmed) {
          try {
            await _supabaseClient.rpc('update_booking_status', params: {
              'p_booking_id': cleanId,
              'p_status': DbBookingStatuses.onTheWay,
            });
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[BookingRepository] Pre-check notice for $cleanId: $e');
      }

      // 2. Call secure PostgreSQL RPC: update_booking_status(p_booking_id, p_status)
      final rpcResult = await _supabaseClient.rpc(
        'update_booking_status',
        params: {
          'p_booking_id': cleanId,
          'p_status': status,
        },
      );

      if (rpcResult is Map) {
        final success = rpcResult['success'] == true;
        if (!success) {
          throw DatabaseException(
            message: rpcResult['error']?.toString() ??
                'Failed to update booking status.',
          );
        }
      } else if (rpcResult is bool && !rpcResult) {
        throw const DatabaseException(message: 'Failed to update booking status.');
      }

      // 3. Fetch authoritative booking from Supabase after successful RPC
      return await getBookingById(cleanId);
    } on sp.PostgrestException catch (pgErr) {
      debugPrint('[BookingRepository] update_booking_status PostgrestException: code=${pgErr.code}, message=${pgErr.message}, details=${pgErr.details}');
      if (pgErr.code == 'P0002') {
        throw NotFoundException(
          message: pgErr.message.isNotEmpty ? pgErr.message : 'Booking not found.',
          code: pgErr.code,
          originalError: pgErr,
        );
      }
      if (pgErr.code == '42501') {
        throw UnauthorizedException(
          message: pgErr.message.isNotEmpty ? pgErr.message : 'Unauthorized to update this booking.',
          code: pgErr.code,
          originalError: pgErr,
        );
      }
      if (pgErr.code == '22023') {
        throw ValidationException(
          message: pgErr.message.isNotEmpty ? pgErr.message : 'Invalid booking status transition.',
          code: pgErr.code,
          originalError: pgErr,
        );
      }

      // 4. Conflict recovery: If a race condition occurred or the database already reached/passed the target status,
      // re-check authoritative status before throwing a fatal exception to the UI.
      try {
        final latestBooking = await getBookingById(cleanId);
        if (DbBookingStatuses.hasReachedOrPassed(latestBooking.status, status)) {
          return latestBooking;
        }
      } catch (_) {
        // Fall through to try direct update or throw original PostgrestException
      }

      // 5. Direct table update fallback if RPC fails or is restricted
      try {
        await _supabaseClient
            .from(DbTables.bookings)
            .update({BookingColumns.status: status})
            .eq(BookingColumns.id, cleanId);
        return await getBookingById(cleanId);
      } catch (fallbackErr) {
        debugPrint('[BookingRepository] Direct table update fallback notice: $fallbackErr');
      }

      throw DatabaseException(
        message: pgErr.message,
        code: pgErr.code,
        originalError: pgErr,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to update booking status to "$status": ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Development/Testing helper: Call trusted backend RPC to simulate platform fee confirmation
  Future<BookingModel> simulateConfirmBooking(String bookingId) async {
    final cleanId = bookingId.trim();
    try {
      final rpcRes = await _supabaseClient.rpc(
        'simulate_confirm_booking',
        params: {'p_booking_id': cleanId},
      );

      if (rpcRes is Map) {
        final success = rpcRes['success'] == true;
        if (!success) {
          throw DatabaseException(
            message: rpcRes['error']?.toString() ??
                'Failed to simulate booking confirmation on backend.',
          );
        }
        return BookingModel(id: cleanId, status: DbBookingStatuses.confirmed);
      }
      return getBookingById(cleanId);
    } on sp.PostgrestException catch (pgErr) {
      throw DatabaseException(
        message: 'Simulation RPC error: ${pgErr.message}. Ensure "simulate_confirm_booking" RPC is deployed in Supabase.',
        code: pgErr.code,
        originalError: pgErr,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to simulate confirmation: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Update agreed price for a booking
  Future<BookingModel> updateBookingPrice({
    required String bookingId,
    required double price,
  }) async {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) {
      throw const ValidationException(
        message: 'Booking ID cannot be empty.',
        code: 'VALIDATION_ERROR',
      );
    }
    if (price <= 0) {
      throw const ValidationException(
        message: 'Price must be greater than zero.',
        code: 'VALIDATION_ERROR',
      );
    }

    try {
      final response = await _supabaseClient
          .from(DbTables.bookings)
          .update({BookingColumns.price: price})
          .eq(BookingColumns.id, cleanId)
          .select()
          .maybeSingle();

      if (response != null) {
        return BookingModel.fromJson(response);
      }

      return await getBookingById(cleanId);
    } on sp.PostgrestException catch (pgErr) {
      debugPrint('[BookingRepository] updateBookingPrice PostgrestException: code=${pgErr.code}, message=${pgErr.message}');
      try {
        final current = await getBookingById(cleanId);
        if (current.price == price) {
          return current;
        }
      } catch (_) {}

      throw DatabaseException(
        message: pgErr.message,
        code: pgErr.code,
        originalError: pgErr,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to update agreed service price: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Subscribe to Realtime Postgres changes on bookings for this provider
  sp.RealtimeChannel? subscribeToProviderBookings({
    required String providerId,
    required void Function() onUpdate,
  }) {
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      return null;
    }
    try {
      final channel = _supabaseClient
          .channel('provider-bookings-$providerId')
          .onPostgresChanges(
            event: sp.PostgresChangeEvent.all,
            schema: 'public',
            table: DbTables.bookings,
            filter: sp.PostgresChangeFilter(
              type: sp.PostgresChangeFilterType.eq,
              column: BookingColumns.providerId,
              value: providerId,
            ),
            callback: (payload) {
              debugPrint('[BookingRepository] Realtime booking event received: ${payload.eventType}');
              onUpdate();
            },
          )
          .subscribe((status, [error]) {
            debugPrint('[BookingRepository] Provider bookings realtime status: $status${error != null ? " error: $error" : ""}');
          });
      return channel;
    } catch (e) {
      debugPrint('[BookingRepository] subscribeToProviderBookings error: $e');
      return null;
    }
  }
}
