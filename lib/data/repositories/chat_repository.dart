import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/chat_message_model.dart';
import 'package:service_wala_business/data/models/conversation_model.dart';

/// Repository managing real-time chat conversations and messages in Supabase.
///
/// Shared with ServiceWala Customer App (CX) using:
/// - `public.conversations` (`id`, `booking_id`, `created_at`)
/// - `public.messages` (`id`, `conversation_id`, `sender_id`, `content`, `created_at`, `read_at`)
class ChatRepository {
  final sp.SupabaseClient? _client;

  ChatRepository({sp.SupabaseClient? client}) : _client = client;

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

  /// Retrieve existing conversation record for a specific booking.
  ///
  /// STRICT: Read-only on the Agent app. Never creates a conversation.
  /// Only the Customer app is permitted to initiate/create conversations.
  ///
  /// If direct lookup by [bookingId] yields no conversation, attempts fallback
  /// resolution for sibling bookings between [customerId] and [providerId] to
  /// support Customer App's unified conversation architecture.
  Future<ConversationModel?> getExistingConversation(
    String bookingId, {
    String? customerId,
    String? providerId,
  }) async {
    try {
      // 1. Direct match on public.conversations by booking_id
      final existing = await _supabaseClient
          .from(DbTables.conversations)
          .select()
          .eq(ConversationColumns.bookingId, bookingId)
          .maybeSingle();

      if (existing != null) {
        return ConversationModel.fromJson(existing);
      }

      // 2. Fallback for unified conversations across multiple bookings
      if (customerId != null && customerId.isNotEmpty) {
        try {
          var query = _supabaseClient
              .from(DbTables.bookings)
              .select(BookingColumns.id)
              .eq(BookingColumns.customerId, customerId);

          if (providerId != null && providerId.isNotEmpty) {
            query = query.eq(BookingColumns.providerId, providerId);
          }

          final siblingBookings = await query;
          final siblingIds = (siblingBookings as List)
              .map((r) => r[BookingColumns.id]?.toString())
              .whereType<String>()
              .where((id) => id != bookingId)
              .toList();

          if (siblingIds.isNotEmpty) {
            final siblingConv = await _supabaseClient
                .from(DbTables.conversations)
                .select()
                .inFilter(ConversationColumns.bookingId, siblingIds)
                .order(ConversationColumns.createdAt, ascending: false)
                .limit(1)
                .maybeSingle();

            if (siblingConv != null) {
              return ConversationModel.fromJson(siblingConv);
            }
          }
        } catch (siblingErr) {
          debugPrint('[ChatRepository] Sibling conversation lookup notice: $siblingErr');
        }
      }

      return null;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to access conversation for booking: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Compatibility alias: returns existing conversation or null.
  /// Never creates a conversation from the Agent app.
  Future<ConversationModel?> getOrCreateConversation(
    String bookingId, {
    String? customerId,
    String? providerId,
  }) async {
    return getExistingConversation(
      bookingId,
      customerId: customerId,
      providerId: providerId,
    );
  }

  /// Fetch all existing conversations belonging to a list of eligible booking IDs
  /// or belonging to the provider's active/past bookings.
  ///
  /// Strictly read-only. Never inserts or creates conversations.
  Future<List<ConversationModel>> fetchExistingProviderConversations([
    List<String>? bookingIds,
    String? providerId,
  ]) async {
    try {
      // 1. Attempt relational query to resolve booking and customer linkage
      try {
        final query = _supabaseClient
            .from(DbTables.conversations)
            .select('''
              *,
              ${DbTables.bookings}:booking_id (
                ${BookingColumns.id},
                ${BookingColumns.customerId},
                ${BookingColumns.providerId}
              )
            ''');

        final response = (bookingIds != null && bookingIds.isNotEmpty)
            ? await query.inFilter(ConversationColumns.bookingId, bookingIds)
            : await query;

        return (response as List)
            .map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Fallback: flat select on conversations table
        if (bookingIds != null && bookingIds.isNotEmpty) {
          final response = await _supabaseClient
              .from(DbTables.conversations)
              .select()
              .inFilter(ConversationColumns.bookingId, bookingIds);

          return (response as List)
              .map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
              .toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('[ChatRepository] fetchExistingProviderConversations error: $e');
      return [];
    }
  }

  /// Batch fetch messages for a list of conversation IDs.
  ///
  /// Enables preloading conversation history and last message previews
  /// for conversation lists.
  Future<List<ChatMessageModel>> fetchMessagesForConversations(
    List<String> conversationIds, {
    String? currentUserId,
  }) async {
    if (conversationIds.isEmpty) return [];
    try {
      try {
        final response = await _supabaseClient
            .from(DbTables.messages)
            .select('''
              *,
              ${DbTables.users}:sender_id (
                ${UserColumns.id},
                ${UserColumns.fullName}
              )
            ''')
            .inFilter(MessageColumns.conversationId, conversationIds)
            .order(MessageColumns.createdAt, ascending: true);

        return (response as List)
            .map((m) => ChatMessageModel.fromJson(
                  m as Map<String, dynamic>,
                  currentUserId: currentUserId,
                ))
            .toList();
      } catch (_) {
        final flatResponse = await _supabaseClient
            .from(DbTables.messages)
            .select()
            .inFilter(MessageColumns.conversationId, conversationIds)
            .order(MessageColumns.createdAt, ascending: true);

        return (flatResponse as List)
            .map((m) => ChatMessageModel.fromJson(
                  m as Map<String, dynamic>,
                  currentUserId: currentUserId,
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('[ChatRepository] fetchMessagesForConversations error: $e');
      return [];
    }
  }

  /// Fetch unread customer-message counts grouped by conversation ID.
  ///
  /// Filters out provider's own messages (`sender_id != currentUserId`) and counts
  /// only incoming messages where `read_at IS NULL`.
  Future<Map<String, int>> fetchUnreadCustomerMessageCounts({
    required String currentUserId,
    required List<String> conversationIds,
  }) async {
    if (conversationIds.isEmpty) return {};
    try {
      final response = await _supabaseClient
          .from(DbTables.messages)
          .select(MessageColumns.conversationId)
          .inFilter(MessageColumns.conversationId, conversationIds)
          .neq(MessageColumns.senderId, currentUserId)
          .filter(MessageColumns.readAt, 'is', null);

      final counts = <String, int>{};
      for (final row in (response as List)) {
        final cId = row[MessageColumns.conversationId]?.toString();
        if (cId != null) {
          counts[cId] = (counts[cId] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e) {
      debugPrint('[ChatRepository] fetchUnreadCustomerMessageCounts error: $e');
      return {};
    }
  }

  /// Fetch all messages for a given conversation ordered by created_at ascending.
  Future<List<ChatMessageModel>> getMessages(
    String conversationId, {
    String? currentUserId,
  }) async {
    try {
      try {
        // Attempt relational select to resolve sender name
        final response = await _supabaseClient
            .from(DbTables.messages)
            .select('''
              *,
              ${DbTables.users}:sender_id (
                ${UserColumns.id},
                ${UserColumns.fullName}
              )
            ''')
            .eq(MessageColumns.conversationId, conversationId)
            .order(MessageColumns.createdAt, ascending: true);

        return (response as List)
            .map((m) => ChatMessageModel.fromJson(
                  m as Map<String, dynamic>,
                  currentUserId: currentUserId,
                ))
            .toList();
      } catch (_) {
        // Flat fallback if users relation is restricted by RLS
        final flatResponse = await _supabaseClient
            .from(DbTables.messages)
            .select()
            .eq(MessageColumns.conversationId, conversationId)
            .order(MessageColumns.createdAt, ascending: true);

        return (flatResponse as List)
            .map((m) => ChatMessageModel.fromJson(
                  m as Map<String, dynamic>,
                  currentUserId: currentUserId,
                ))
            .toList();
      }
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to load messages: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Send a message in a conversation.
  ///
  /// Validates content length (1 - 5000 chars) and ensures sender_id matches
  /// the authenticated user.
  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException(
        message: 'Message cannot be empty.',
        code: 'EMPTY_MESSAGE',
      );
    }
    if (trimmed.length > 5000) {
      throw const ValidationException(
        message: 'Message exceeds maximum limit of 5000 characters.',
        code: 'MESSAGE_TOO_LONG',
      );
    }

    final currentAuthUser = _supabaseClient.auth.currentUser;
    if (currentAuthUser == null) {
      throw const AppAuthException(
        message: 'You must be logged in to send messages.',
        code: 'UNAUTHENTICATED',
      );
    }

    try {
      final response = await _supabaseClient
          .from(DbTables.messages)
          .insert({
            MessageColumns.conversationId: conversationId,
            MessageColumns.senderId: currentAuthUser.id,
            MessageColumns.content: trimmed,
          })
          .select()
          .single();

      return ChatMessageModel.fromJson(
        response,
        currentUserId: currentAuthUser.id,
      );
    } on sp.PostgrestException catch (pgErr) {
      throw DatabaseException(
        message: pgErr.message,
        code: pgErr.code,
        originalError: pgErr,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to send message: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Subscribe to Realtime messages for an active conversation.
  sp.RealtimeChannel? subscribeToConversationMessages({
    required String conversationId,
    required String currentUserId,
    required void Function(ChatMessageModel message) onMessageReceived,
  }) {
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      return null;
    }

    try {
      final channelName = 'conversation-messages-$conversationId';
      final channel = _supabaseClient
          .channel(channelName)
          .onPostgresChanges(
            event: sp.PostgresChangeEvent.insert,
            schema: 'public',
            table: DbTables.messages,
            filter: sp.PostgresChangeFilter(
              type: sp.PostgresChangeFilterType.eq,
              column: MessageColumns.conversationId,
              value: conversationId,
            ),
            callback: (payload) {
              try {
                final newRecord = payload.newRecord;
                if (newRecord.isNotEmpty) {
                  final msg = ChatMessageModel.fromJson(
                    newRecord,
                    currentUserId: currentUserId,
                  );
                  onMessageReceived(msg);
                }
              } catch (e) {
                debugPrint('[ChatRepository] Realtime payload parse error: $e');
              }
            },
          )
          .subscribe();

      return channel;
    } catch (e) {
      debugPrint('[ChatRepository] Realtime subscription error: $e');
      return null;
    }
  }

  /// Subscribe to Realtime messages table for all incoming messages and read receipts.
  ///
  /// Enables the Agent app to receive live message updates and unread badges
  /// across all screens without requiring manual pull-to-refresh.
  sp.RealtimeChannel? subscribeToAllMessages({
    required String currentUserId,
    required void Function(ChatMessageModel message) onMessage,
    void Function(Map<String, dynamic> record)? onUpdate,
  }) {
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      return null;
    }

    try {
      final channelName = 'global-messages-$currentUserId';
      final channel = _supabaseClient
          .channel(channelName)
          .onPostgresChanges(
            event: sp.PostgresChangeEvent.insert,
            schema: 'public',
            table: DbTables.messages,
            callback: (payload) {
              try {
                final newRecord = payload.newRecord;
                if (newRecord.isNotEmpty) {
                  final msg = ChatMessageModel.fromJson(
                    newRecord,
                    currentUserId: currentUserId,
                  );
                  onMessage(msg);
                }
              } catch (e) {
                debugPrint('[ChatRepository] Realtime insert parse error: $e');
              }
            },
          )
          .onPostgresChanges(
            event: sp.PostgresChangeEvent.update,
            schema: 'public',
            table: DbTables.messages,
            callback: (payload) {
              try {
                final newRecord = payload.newRecord;
                if (newRecord.isNotEmpty && onUpdate != null) {
                  onUpdate(newRecord);
                }
              } catch (e) {
                debugPrint('[ChatRepository] Realtime update parse error: $e');
              }
            },
          )
          .subscribe();

      return channel;
    } catch (e) {
      debugPrint('[ChatRepository] Global messages subscription error: $e');
      return null;
    }
  }

  /// Safely mark incoming unread messages as read.
  ///
  /// Attempts the secure PostgreSQL RPC `mark_messages_read(p_conversation_id)` first.
  /// If the RPC is unavailable, unauthorized, or encounters any error, immediately
  /// executes direct database update on `public.messages` setting `read_at = now()`.
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    bool rpcSuccess = false;
    // 1. Try secure PostgreSQL RPC
    try {
      final res = await _supabaseClient.rpc(
        'mark_messages_read',
        params: {'p_conversation_id': conversationId},
      );
      rpcSuccess = true;
      debugPrint('[ChatRepository] mark_messages_read RPC succeeded: $res');
    } catch (e) {
      debugPrint('[ChatRepository] mark_messages_read RPC notice (proceeding to direct update): $e');
    }

    // 2. Direct update fallback (always run if RPC didn't succeed to ensure DB sync)
    if (!rpcSuccess) {
      try {
        final nowIso = DateTime.now().toIso8601String();
        await _supabaseClient
            .from(DbTables.messages)
            .update({
              MessageColumns.readAt: nowIso,
            })
            .eq(MessageColumns.conversationId, conversationId)
            .neq(MessageColumns.senderId, currentUserId);
        debugPrint('[ChatRepository] Direct fallback marked messages read for conv: $conversationId');
      } catch (e) {
        debugPrint('[ChatRepository] Direct update read_at error: $e');
      }
    }
  }
}
