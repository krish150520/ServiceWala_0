import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/booking_model.dart';
import 'package:service_wala_business/data/models/chat_message_model.dart';
import 'package:service_wala_business/data/models/conversation_model.dart';
import 'package:service_wala_business/data/models/earnings_model.dart';
import 'package:service_wala_business/data/repositories/booking_repository.dart';
import 'package:service_wala_business/data/repositories/chat_repository.dart';
import 'package:service_wala_business/data/repositories/earnings_repository.dart';

/// Centralized Backend Service Contract for the Agent / Partner application.
///
/// Implements the 10 core operations required for provider lifecycle management,
/// booking tracking, unread badges, and verified earnings.
class BackendService {
  final BookingRepository _bookingRepo;
  final ChatRepository _chatRepo;
  final EarningsRepository _earningsRepo;
  final sp.SupabaseClient? _client;

  BackendService({
    BookingRepository? bookingRepo,
    ChatRepository? chatRepo,
    EarningsRepository? earningsRepo,
    sp.SupabaseClient? client,
  })  : _bookingRepo = bookingRepo ?? BookingRepository(client: client),
        _chatRepo = chatRepo ?? ChatRepository(client: client),
        _earningsRepo = earningsRepo ?? EarningsRepository(client: client),
        _client = client;

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

  /// 1. fetchProviderBookings()
  /// - Resolves the current provider profile (`providers.id`) from `auth.uid()`.
  /// - Fetches ONLY bookings assigned to that provider.
  /// - Includes customer and service relational details.
  Future<List<BookingModel>> fetchProviderBookings() async {
    final providerId = await resolveCurrentProviderId();
    if (providerId == null) {
      throw const AppAuthException(
        message: 'Provider profile could not be resolved for current user.',
        code: 'NO_PROVIDER_PROFILE',
      );
    }
    return _bookingRepo.getBookingsForProvider(providerId);
  }

  /// Helper to resolve current authenticated provider ID
  Future<String?> resolveCurrentProviderId() async {
    return _bookingRepo.resolveCurrentProviderId();
  }

  /// 2. updateBookingStatus(bookingId, status)
  /// - Calls public.update_booking_status RPC.
  /// - Handles real return types and error behaviors.
  /// - Refetches authoritative booking after success.
  Future<BookingModel> updateBookingStatus(String bookingId, String status) async {
    return _bookingRepo.updateBookingStatus(
      bookingId: bookingId,
      status: status,
    );
  }

  /// 3. acceptBooking(bookingId)
  /// - Calls existing public.accept_booking RPC.
  /// - Returns authoritative refreshed booking.
  Future<BookingModel> acceptBooking(String bookingId) async {
    return _bookingRepo.acceptBooking(bookingId);
  }

  /// 4. declineBooking(bookingId)
  /// - Calls existing public.decline_booking RPC.
  /// - Enforces provider ownership and valid lifecycle transitions.
  Future<BookingModel> declineBooking(String bookingId) async {
    return _bookingRepo.declineBooking(bookingId);
  }

  /// 5. subscribeToProviderBookings(onChange)
  /// - Subscribes to relevant public.bookings changes.
  /// - Triggers callback when provider's bookings change.
  sp.RealtimeChannel? subscribeToProviderBookings(
    String providerId,
    void Function() onChange,
  ) {
    return _bookingRepo.subscribeToProviderBookings(
      providerId: providerId,
      onUpdate: onChange,
    );
  }

  /// 6. fetchExistingProviderConversations()
  /// - Fetches only existing conversations belonging to the authenticated provider's eligible bookings.
  /// - Strictly read-only. Never creates conversations.
  Future<List<ConversationModel>> fetchExistingProviderConversations(
    List<String> bookingIds,
  ) async {
    return _chatRepo.fetchExistingProviderConversations(bookingIds);
  }

  /// 7. subscribeToConversationMessages(conversationId, onMessage)
  /// - Subscribes only to an authorized existing conversation.
  /// - Respects existing chat access rules and RLS.
  sp.RealtimeChannel? subscribeToConversationMessages({
    required String conversationId,
    required String currentUserId,
    required void Function(ChatMessageModel message) onMessage,
  }) {
    return _chatRepo.subscribeToConversationMessages(
      conversationId: conversationId,
      currentUserId: currentUserId,
      onMessageReceived: onMessage,
    );
  }

  /// 8. fetchUnreadCustomerMessageCounts()
  /// - Returns unread customer-message counts grouped by conversation ID.
  /// - Does not count provider's own messages.
  Future<Map<String, int>> fetchUnreadCustomerMessageCounts({
    required String currentUserId,
    required List<String> conversationIds,
  }) async {
    return _chatRepo.fetchUnreadCustomerMessageCounts(
      currentUserId: currentUserId,
      conversationIds: conversationIds,
    );
  }

  /// 9. markIncomingMessagesRead(conversationId)
  /// - Marks only appropriate incoming messages as read via secure RPC.
  /// - Verifies authenticated user is an authorized participant.
  Future<void> markIncomingMessagesRead(String conversationId) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) return;
    await _chatRepo.markMessagesAsRead(
      conversationId: conversationId,
      currentUserId: currentUserId,
    );
  }

  /// 10. fetchProviderEarnings()
  /// - Uses verified earnings business model and real database records.
  /// - Strictly counts completed, paid digital bookings. Excludes platform fees and cash.
  Future<EarningsSummary> fetchProviderEarnings(String providerId) async {
    return _earningsRepo.getEarningsSummary(providerId);
  }
}
