import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/models/service_request.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/booking/job_detail_screen.dart';
import 'package:service_wala_business/screens/booking/request_detail_screen.dart';
import 'package:service_wala_business/widgets/booking_card.dart';
import 'package:service_wala_business/widgets/incoming_request_card.dart';
import 'package:service_wala_business/widgets/service_request_card.dart';
import 'package:service_wala_business/widgets/loading_animation.dart';

/// Screen displaying jobs with 5-stage tab filtering (Requests, Accepted, Active, History, All)
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final pendingCount = appState.pendingRequestsCount;
    final acceptedCount = appState.acceptedJobsCount;
    final activeCount = appState.confirmedJobsCount;
    final historyCount = appState.historyJobs.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings & Jobs'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                children: [
                  const Text('Requests'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildBadge(pendingCount, const Color(0xFFD97706)),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Accepted (₹9 Fee)'),
                  if (acceptedCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildBadge(acceptedCount, const Color(0xFF2563EB)),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Active / In Progress'),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildBadge(activeCount, AppColors.primary),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('History'),
                  if (historyCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildBadge(historyCount, AppColors.textMuted),
                  ],
                ],
              ),
            ),
            const Tab(text: 'All Jobs'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar matching Customer App Pill
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customer, service or job ID...',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Incoming Requests Tab
                _buildRequestsTab(appState),

                // 2. Accepted Jobs Tab (Awaiting ₹9 Platform Fee)
                _buildBookingsList(
                  bookings: _filterBookings(appState.acceptedJobs),
                  emptyIcon: Icons.hourglass_empty_rounded,
                  emptyTitle: 'No accepted jobs awaiting fee',
                  emptySubtitle:
                      'When you accept an incoming request, it will show here while the customer pays the ₹9 platform fee.',
                  onRefresh: () => appState.refreshBookings(),
                ),

                // 3. Active / Confirmed Jobs Tab
                _buildBookingsList(
                  bookings: _filterBookings(appState.confirmedJobs),
                  emptyIcon: Icons.directions_run_rounded,
                  emptyTitle: 'No active jobs in progress',
                  emptySubtitle:
                      'Confirmed bookings ready for service delivery and route navigation will appear here.',
                  onRefresh: () => appState.refreshBookings(),
                ),

                // 4. Job History Tab (Completed, Declined, Cancelled)
                _buildBookingsList(
                  bookings: _filterBookings(appState.historyJobs),
                  emptyIcon: Icons.history_rounded,
                  emptyTitle: 'No job history yet',
                  emptySubtitle:
                      'Completed, cancelled, or declined bookings will be archived here.',
                  onRefresh: () => appState.refreshBookings(),
                ),

                // 5. All Bookings Tab
                _buildBookingsList(
                  bookings: _filterBookings(appState.bookings),
                  emptyIcon: Icons.calendar_today_outlined,
                  emptyTitle: 'No bookings found',
                  emptySubtitle:
                      'All your past and present service jobs will appear in this log.',
                  onRefresh: () => appState.refreshBookings(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(AppState appState) {
    final liveRequests = _filterBookings(appState.incomingRequests);
    final demoRequests = appState.isDemoMode
        ? _filterServiceRequests(appState.serviceRequests)
        : const <ServiceRequest>[];

    if (appState.isLoading && liveRequests.isEmpty && demoRequests.isEmpty) {
      return const BookingCardsShimmerLoading(
        label: 'Fetching available customer requests...',
      );
    }

    if (liveRequests.isEmpty && demoRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => appState.refreshBookings(),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              if (appState.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          appState.error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => appState.refreshBookings(),
                        child: const Text('Retry',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 30),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inbox_outlined,
                    size: 30, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              const Text('No Incoming Requests',
                  style: AppTextStyles.labelLarge),
              const SizedBox(height: 6),
              const Text(
                'Make sure your status is Online to receive real-time service leads from local customers.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => appState.refreshBookings(),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        children: [
          if (appState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error, width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        appState.error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Live requests
          ...liveRequests.map(
            (b) => IncomingRequestCard(
              booking: b,
              onAccept: () async {
                final messenger = ScaffoldMessenger.of(context);
                final success = await appState.acceptRequest(b.id);
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text(
                          '✅ Request accepted! Waiting for customer platform fee.'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(appState.error ??
                          'Failed to accept request. Check permissions.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              onDecline: () async {
                final messenger = ScaffoldMessenger.of(context);
                final success = await appState.declineRequest(b.id);
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Request declined.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          appState.error ?? 'Failed to decline request.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobDetailScreen(booking: b),
                  ),
                );
              },
            ),
          ),

          // Demo requests (if in demo mode)
          ...demoRequests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ServiceRequestCard(
                request: r,
                onAccept: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await appState.acceptRequest(r.id);
                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text(
                            '✅ Request accepted! Waiting for customer confirmation.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            appState.error ?? 'Failed to accept request.'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                onDecline: () => appState.declineRequest(r.id),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(request: r),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList({
    required List<Booking> bookings,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    required Future<void> Function() onRefresh,
  }) {
    final appState = context.watch<AppState>();
    if (appState.isLoading && bookings.isEmpty) {
      return const BookingCardsShimmerLoading(
        label: 'Syncing bookings with ServiceWala cloud...',
      );
    }

    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(emptyIcon, size: 30, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text(emptyTitle, style: AppTextStyles.labelLarge),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return BookingCard(
            booking: booking,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobDetailScreen(booking: booking),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Booking> _filterBookings(List<Booking> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((b) {
      return b.customerName.toLowerCase().contains(q) ||
          b.serviceType.toLowerCase().contains(q) ||
          b.description.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q);
    }).toList();
  }

  List<ServiceRequest> _filterServiceRequests(List<ServiceRequest> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((r) {
      return r.customerName.toLowerCase().contains(q) ||
          r.serviceType.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q);
    }).toList();
  }

  Widget _buildBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
