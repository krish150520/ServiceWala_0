import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/models/chat_message.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/calling/calling_screen.dart';
import 'package:service_wala_business/widgets/loading_animation.dart';

/// In-app real-time chat interface between Partner Agent and Customer for an active booking.
///
/// Fully integrated with Supabase `public.conversations` and `public.messages`.
class ChatScreen extends StatefulWidget {
  final Booking booking;

  const ChatScreen({super.key, required this.booking});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;

  final List<String> _quickReplies = [
    "I'm on my way to your location 🚗",
    "I have arrived outside 📍",
    "Could you please confirm the exact apartment number?",
    "Work has been completed! Please review 👍",
  ];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final appState = context.read<AppState>();

    // Mark messages read immediately upon opening the chat screen
    appState.markIncomingMessagesRead(widget.booking.id);

    // 1. Refresh latest booking status from Supabase to ensure accurate state
    await appState.refreshBooking(widget.booking.id);

    // 2. Fetch messages for conversation
    await appState.loadMessagesForBooking(widget.booking.id);
    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom();
      // Ensure all loaded messages are marked read
      appState.markIncomingMessagesRead(widget.booking.id);
    }

    // 3. Subscribe to real-time incoming messages
    await appState.subscribeToBookingChat(
      widget.booking.id,
      onMessageReceived: (message) {
        if (mounted) {
          _scrollToBottom();
          if (!message.isMe) {
            appState.markIncomingMessagesRead(widget.booking.id);
          }
        }
      },
    );
  }

  @override
  void dispose() {
    // Ensure all read receipts are finalized and cleanup channel subscription
    final appState = context.read<AppState>();
    appState.markIncomingMessagesRead(widget.booking.id);
    appState.unsubscribeFromBookingChat(widget.booking.id);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent + 80,
          );
        }
      }
    });
  }

  Future<void> _sendMessage([String? text]) async {
    if (_isSending) return; // Prevent double-submit

    final content = (text ?? _messageController.text).trim();
    if (content.isEmpty) return;

    if (content.length > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message exceeds limit of 5000 characters.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    if (text == null) {
      _messageController.clear();
    }

    final appState = context.read<AppState>();
    final success = await appState.sendMessage(widget.booking.id, content);

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appState.error ?? 'Failed to send message. Please try again.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _callCustomer(Booking booking) {
    CallingScreen.start(
      context: context,
      customerName: booking.customerName,
      customerPhone: booking.customerPhone,
      serviceTitle: booking.serviceType,
      bookingId: booking.id,
      customerId: booking.customerId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentBooking = appState.bookings.firstWhere(
      (b) => b.id == widget.booking.id,
      orElse: () => widget.booking,
    );
    final messages = appState.getMessagesForBooking(currentBooking.id);
    final isChatOpen = appState.isChatEligible(currentBooking);
    final isPendingOrAccepted =
        currentBooking.status == BookingStatus.pendingResponse ||
        currentBooking.status == BookingStatus.accepted;
    final isHistory = currentBooking.status.isHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  currentBooking.customerName.isNotEmpty
                      ? currentBooking.customerName
                            .substring(0, 1)
                            .toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          currentBooking.customerName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  Text(
                    '${currentBooking.serviceType.toUpperCase()} • ${currentBooking.status.label}',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _initializeChat();
            },
            tooltip: 'Refresh Chat',
          ),
          if (isChatOpen)
            IconButton(
              icon: const Icon(Icons.phone_rounded, color: AppColors.success),
              onPressed: () => _callCustomer(currentBooking),
              tooltip: 'Call Customer',
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner based on lifecycle state
          if (isPendingOrAccepted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      currentBooking.status == BookingStatus.pendingResponse
                          ? 'Chat unlocks once you accept the request and customer pays platform fee.'
                          : 'Waiting for customer platform fee (₹9). Chat will unlock immediately after confirmation.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isHistory)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceLight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'This job is ${currentBooking.status.label.toLowerCase()}. Chat is now read-only.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else if (!appState.hasExistingConversation(currentBooking.id))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFEFF6FF),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Customer has not initiated chat yet. You can reply as soon as the customer sends a message.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E40AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceLight,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Direct communication with verified customer',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const ChatMessagesShimmerLoading()
                : messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 30,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            appState.hasExistingConversation(currentBooking.id)
                                ? 'No messages yet'
                                : 'Waiting for Customer Message',
                            style: AppTextStyles.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            !appState.hasExistingConversation(currentBooking.id)
                                ? 'Customer must start the conversation from the ServiceWala app. You can reply as soon as they send a message.'
                                : (isChatOpen
                                      ? 'Send a quick message below to coordinate service arrival.'
                                      : 'Customer chat is currently locked for this booking stage.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          // Quick replies and message input bar
          if (isChatOpen) ...[
            if (appState.hasExistingConversation(currentBooking.id)) ...[
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickReplies.length,
                  itemBuilder: (context, index) {
                    final reply = _quickReplies[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          reply,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: AppColors.surfaceLight,
                        side: const BorderSide(
                          color: AppColors.border,
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onPressed: _isSending
                            ? null
                            : () => _sendMessage(reply),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Message Input Field
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  MediaQuery.of(context).padding.bottom + 10,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 0.75),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.8,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 5000,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => _sendMessage(),
                            ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  MediaQuery.of(context).padding.bottom + 14,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 0.75),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_empty_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Waiting for customer to initiate conversation...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMe = msg.isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  msg.senderName.isNotEmpty
                      ? msg.senderName.substring(0, 1).toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.surfaceCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: isMe ? AppColors.primary : AppColors.border,
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.message,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('hh:mm a').format(msg.createdAt),
                        style: TextStyle(
                          color: isMe ? Colors.white70 : AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.readAt != null
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 13,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
