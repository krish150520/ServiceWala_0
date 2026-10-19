import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/models/chat_message.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/chat/chat_screen.dart';
import 'package:service_wala_business/widgets/common_widgets.dart';
import 'package:service_wala_business/widgets/loading_animation.dart';

/// Screen displaying all customer conversations for active and recent bookings
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().refreshBookings();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Get all bookings that have conversations or are active
    final conversationBookings = appState.bookings.where((booking) {
      final messages = appState.getMessagesForBooking(booking.id);
      final hasMessages = messages.isNotEmpty;
      final hasConv = appState.hasExistingConversation(booking.id);
      final isRelevant = booking.status.isActive || hasMessages || hasConv;

      if (!isRelevant) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = booking.customerName.toLowerCase().contains(query);
        final serviceMatch = booking.serviceType.toLowerCase().contains(query);
        final descMatch = booking.description.toLowerCase().contains(query);
        return nameMatch || serviceMatch || descMatch;
      }

      return true;
    }).toList();

    // Deduplicate and group strictly by customer identity so repeat customer requests remain in the same chat
    final Map<String, Booking> unifiedBookingsMap = {};
    for (final booking in conversationBookings) {
      final key = appState.getCustomerKey(booking);

      if (!unifiedBookingsMap.containsKey(key)) {
        unifiedBookingsMap[key] = booking;
      } else {
        final existing = unifiedBookingsMap[key]!;
        // Prefer active bookings over inactive, then more recent
        if (!existing.status.isActive && booking.status.isActive) {
          unifiedBookingsMap[key] = booking;
        } else if (existing.status.isActive == booking.status.isActive &&
            booking.createdAt.isAfter(existing.createdAt)) {
          unifiedBookingsMap[key] = booking;
        }
      }
    }

    final displayedBookings = unifiedBookingsMap.values.toList()
      ..sort((a, b) {
        final msgsA = appState.getMessagesForBooking(a.id);
        final msgsB = appState.getMessagesForBooking(b.id);
        final timeA = msgsA.isNotEmpty ? msgsA.last.createdAt : a.createdAt;
        final timeB = msgsB.isNotEmpty ? msgsB.last.createdAt : b.createdAt;
        return timeB.compareTo(timeA);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await appState.refreshBookings();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Chat messages synchronized'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Sync Messages',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search chats by customer or service...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Conversation List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => appState.refreshBookings(),
              color: AppColors.primary,
              child: appState.isLoading && displayedBookings.isEmpty
                  ? const ChatListShimmerLoading()
                  : displayedBookings.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: EmptyStateWidget(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  title: _searchQuery.isNotEmpty
                                      ? 'No matching chats found'
                                      : 'No Active Chats',
                                  subtitle: _searchQuery.isNotEmpty
                                      ? 'Try searching with a different customer name or service.'
                                      : 'When you accept a booking, customer messaging will appear here.',
                                ),
                              ),
                            ),
                          ),
                        )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: displayedBookings.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final booking = displayedBookings[index];
                      final messages = appState.getMessagesForBooking(booking.id);
                      final lastMessage =
                          messages.isNotEmpty ? messages.last : null;
                      final unreadCount =
                          appState.getUnreadCountForCustomer(booking);

                      return _ChatConversationTile(
                        booking: booking,
                        lastMessage: lastMessage,
                        unreadCount: unreadCount,
                        onTap: () {
                          final appState = context.read<AppState>();
                          // Immediately clear unread badge on tap
                          appState.markIncomingMessagesRead(booking.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(booking: booking),
                            ),
                          ).then((_) {
                            if (mounted) {
                              appState.markIncomingMessagesRead(booking.id);
                            }
                          });
                        },
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single Conversation Tile in the chat list
class _ChatConversationTile extends StatelessWidget {
  final Booking booking;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final VoidCallback onTap;

  const _ChatConversationTile({
    required this.booking,
    required this.lastMessage,
    this.unreadCount = 0,
    required this.onTap,
  });

  String _formatTimestamp(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && now.day == time.day) {
      return DateFormat('hh:mm a').format(time);
    }
    if (diff.inDays < 7) {
      return DateFormat('EEE').format(time);
    }
    return DateFormat('dd MMM').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final hasMessages = lastMessage != null;
    final messagePreview = hasMessages
        ? (lastMessage!.isMe ? 'You: ${lastMessage!.message}' : lastMessage!.message)
        : 'Tap to start conversation with customer';

    final messageTime = lastMessage?.createdAt ?? booking.createdAt;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Row(
          children: [
            // Customer Avatar with Online indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      booking.customerName.isNotEmpty
                          ? booking.customerName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Customer Name, Service Tag, and Last Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          booking.customerName,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTimestamp(messageTime),
                            style: TextStyle(
                              fontSize: 11,
                              color: unreadCount > 0 ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Center(
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Service Category Pill
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          booking.serviceType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (booking.status.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            booking.status.label,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Message snippet
                  Text(
                    messagePreview,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.normal,
                      color: unreadCount > 0
                          ? AppColors.textPrimary
                          : (hasMessages
                              ? AppColors.textSecondary
                              : AppColors.textMuted),
                      fontStyle:
                          hasMessages ? FontStyle.normal : FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
