import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/models/service_request.dart';
import 'package:service_wala_business/screens/booking/request_detail_screen.dart';
import 'package:service_wala_business/screens/booking/job_detail_screen.dart';
import 'package:service_wala_business/screens/earnings/earnings_screen.dart';
import 'package:service_wala_business/models/agent_profile.dart';
import 'package:service_wala_business/widgets/incoming_request_card.dart';
import 'package:service_wala_business/widgets/service_request_card.dart';

/// Precision Partner Suite - Approved Google Stitch Home Dashboard
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final agent = appState.agent ??
              AgentProfile(
                id: appState.providerId ?? '',
                fullName: 'Partner',
                phone: '',
                isOnline: true,
                serviceArea: 'Amritsar, Punjab',
              );

          final firstName = agent.fullName.trim().isNotEmpty
              ? agent.fullName.trim().split(' ').first
              : 'Partner';

          final totalDigital = appState.totalEarnings;
          final completedCount = appState.completedJobsCount;

          final liveIncoming = appState.incomingRequests;
          final demoIncoming = appState.isDemoMode
              ? appState.serviceRequests
              : const <ServiceRequest>[];
          final hasIncoming = liveIncoming.isNotEmpty || demoIncoming.isNotEmpty;

          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () => appState.refreshBookings(),
              color: AppColors.stitchPrimaryCobalt,
              backgroundColor: AppColors.stitchSurfaceContainerLowest,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Top Header Bar (Branding & Notification Action)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _TopHeaderBar(
                        hasNotifications: hasIncoming,
                        onNotificationsTap: () =>
                            _showNotificationsModal(context, appState),
                      ),
                    ),
                  ),

                  // Optional Sync Indicator during background network fetch
                  if (appState.isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.stitchPrimaryFixed.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.stitchPrimaryCobalt,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Syncing with ServiceWala cloud...',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 2. Personalized Salutation
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Hello, $firstName',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.stitchOnSurface,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '👋',
                                style: TextStyle(fontSize: 24),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Accept customer jobs and manage your daily earnings',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Online Availability Card (Mint / Emerald Container)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _StitchAvailabilityCard(
                        isOnline: agent.isOnline,
                        onToggle: () => appState.toggleOnlineStatus(),
                      ),
                    ),
                  ),

                  // 5. Verified Digital Earnings Card (Cobalt Gradient with Curved Accents)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _StitchDigitalEarningsCard(
                        totalDigital: totalDigital,
                        completedCount: completedCount,
                        onSettlementsTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EarningsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 6. Dashboard Overview 2x2 Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dashboard Overview',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchOnSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StitchOverviewTile(
                                  icon: Icons.notifications_active_rounded,
                                  iconColor: AppColors.stitchOutline,
                                  iconBgColor: AppColors.stitchSurfaceContainer,
                                  count: appState.pendingRequestsCount,
                                  label: 'Incoming Requests',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StitchOverviewTile(
                                  icon: Icons.hourglass_top_rounded,
                                  iconColor: AppColors.stitchPrimary,
                                  iconBgColor: AppColors.stitchPrimaryFixed,
                                  count: appState.acceptedJobsCount,
                                  label: 'Accepted (₹9 Fee)',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StitchOverviewTile(
                                  icon: Icons.engineering_rounded,
                                  iconColor: AppColors.stitchPrimaryCobalt,
                                  iconBgColor: AppColors.stitchSurfaceContainerHighest,
                                  count: appState.confirmedJobsCount,
                                  label: 'Active / In Progress',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StitchOverviewTile(
                                  icon: Icons.verified_user_rounded,
                                  iconColor: AppColors.stitchTertiary,
                                  iconBgColor: AppColors.stitchTertiaryFixed.withValues(alpha: 0.5),
                                  count: appState.completedJobsCount,
                                  label: 'Completed Jobs',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 7. Active Ongoing Job Section (if any)
                  if (appState.currentActiveJob != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Active Ongoing Job',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.stitchOnSurface,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.stitchPrimaryFixed,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    appState.currentActiveJob!.status.label.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.stitchPrimary,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _StitchOngoingJobCard(
                              booking: appState.currentActiveJob!,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JobDetailScreen(
                                      booking: appState.currentActiveJob!,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 8. Accepted Jobs Section (if any)
                  if (appState.acceptedJobs.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Accepted Jobs',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.stitchOnSurface,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.stitchSurfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    '${appState.acceptedJobs.length} Awaiting Fee',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.stitchOnSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...appState.acceptedJobs.map(
                              (job) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _StitchAcceptedJobCard(
                                  booking: job,
                                  onViewDetails: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => JobDetailScreen(
                                          booking: job,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 9. Incoming Requests Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Incoming Requests',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOnSurface,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (hasIncoming) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.stitchPrimaryFixed,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    '${appState.pendingRequestsCount}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.stitchPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (hasIncoming)
                            const Text(
                              'Live Radar ⚡',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 10. Requests Content: Empty State OR Live Cards
                  if (!hasIncoming)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _StitchEmptyStateCard(isOnline: agent.isOnline),
                      ),
                    )
                  else ...[
                    // Live Supabase Incoming Requests
                    if (liveIncoming.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.separated(
                          itemCount: liveIncoming.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final booking = liveIncoming[index];
                            return IncomingRequestCard(
                              booking: booking,
                              onAccept: () async {
                                final success =
                                    await appState.acceptRequest(booking.id);
                                if (context.mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '✅ Request accepted! Waiting for customer platform fee.'),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(appState.error ??
                                            'Failed to accept request. Check permissions.'),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              onDecline: () async {
                                final success =
                                    await appState.declineRequest(booking.id);
                                if (context.mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Request declined.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(appState.error ??
                                            'Failed to decline request.'),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JobDetailScreen(
                                      booking: booking,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),

                    // Demo Incoming Requests (if in demo mode)
                    if (appState.isDemoMode && demoIncoming.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.separated(
                          itemCount: demoIncoming.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final request = demoIncoming[index];
                            return ServiceRequestCard(
                              request: request,
                              onAccept: () async {
                                final success =
                                    await appState.acceptRequest(request.id);
                                if (context.mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '✅ Request accepted! Waiting for customer confirmation.'),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(appState.error ??
                                            'Failed to accept request.'),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              onDecline: () =>
                                  appState.declineRequest(request.id),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RequestDetailScreen(
                                      request: request,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],

                  // Padding at the bottom for floating bottom navigation bar
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNotificationsModal(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.stitchSurfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.stitchOutlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.stitchOnSurface,
                  ),
                ),
                Text(
                  '${appState.pendingRequestsCount} New',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.stitchPrimaryCobalt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (appState.pendingRequestsCount > 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: AppColors.stitchPrimaryCobalt,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You have ${appState.pendingRequestsCount} active incoming booking request(s).',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: const Text(
                  'No unread notifications right now.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// STITCH SUB-COMPONENTS
// ============================================================================

/// 1. Top Header Bar matching Stitch:
/// Wordmark badge with check + "PARTNER PORTAL / Dashboard Home" + Notification Bell
class _TopHeaderBar extends StatelessWidget {
  final bool hasNotifications;
  final VoidCallback onNotificationsTap;

  const _TopHeaderBar({
    required this.hasNotifications,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: ServiceWala Partner Official Wordmark Badge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.stitchPrimary, AppColors.stitchPrimaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.handyman_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'PARTNER PORTAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.stitchOutline,
                  ),
                ),
                Text(
                  'Dashboard Home',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.stitchOnSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Right: Notification Button
        IconButton(
          icon: Stack(
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 22,
                color: AppColors.stitchOnSurfaceVariant,
              ),
              if (hasNotifications)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: onNotificationsTap,
          splashRadius: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        ),
      ],
    );
  }
}


/// 2. Online Availability Card (Stitch: Mint container + Power Squircle + iOS toggle)
class _StitchAvailabilityCard extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onToggle;

  const _StitchAvailabilityCard({
    required this.isOnline,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.stitchTertiaryBg
            : AppColors.stitchSurfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? AppColors.stitchTertiaryFixed.withValues(alpha: 0.6)
              : AppColors.stitchOutlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Power Settings Squircle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.stitchTertiaryFixed
                  : AppColors.stitchSurfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              color: isOnline
                  ? AppColors.stitchOnTertiaryFixed
                  : AppColors.stitchOutline,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Online / Offline Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? AppColors.stitchTertiary
                            : AppColors.stitchOutline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isOnline
                            ? 'Online • Visible to Customers'
                            : 'Offline • Unavailable',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isOnline
                              ? AppColors.stitchOnTertiaryFixedVariant
                              : AppColors.stitchOnSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? 'Accepting incoming service requests'
                      : 'You won’t receive new booking alerts',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Adaptive Switch with Stitch tertiary green
          Switch.adaptive(
            value: isOnline,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppColors.stitchTertiary,
            activeTrackColor: AppColors.stitchTertiaryFixed,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.stitchSurfaceDim,
          ),
        ],
      ),
    );
  }
}

/// 3. Verified Digital Earnings Card (Deep cobalt gradient, ambient curved vectors, large balance)
class _StitchDigitalEarningsCard extends StatelessWidget {
  final double totalDigital;
  final int completedCount;
  final VoidCallback onSettlementsTap;

  const _StitchDigitalEarningsCard({
    required this.totalDigital,
    required this.completedCount,
    required this.onSettlementsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.stitchPrimary,
            AppColors.stitchPrimaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.stitchPrimary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient Decorative Vector Circles matching Stitch
            Positioned(
              right: -32,
              top: -32,
              child: Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceTint.withValues(alpha: 0.30),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 48,
              bottom: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.40),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Main Earnings Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Wallet Icon + Verified Digital Earnings + Settlements Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 20,
                            color: AppColors.stitchOnPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Verified Digital Earnings',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onSettlementsTap,
                          borderRadius: BorderRadius.circular(9999),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceContainerLowest
                                  .withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Settlements',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Large Balance Display
                  Text(
                    '₹${NumberFormat('#,##,###').format(totalDigital)}',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Bottom Partition Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceContainerLowest
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Completed Jobs',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$completedCount Jobs',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: AppColors.stitchSurfaceContainerLowest
                              .withValues(alpha: 0.20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Payout Mode',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'UPI / Bank Direct',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

/// 4. Metric Tile for 2x2 Dashboard Overview Grid
class _StitchOverviewTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final int count;
  final String label;

  const _StitchOverviewTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.stitchSurfaceContainerHigh,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.stitchOnSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 5. Active Ongoing Job Card
class _StitchOngoingJobCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const _StitchOngoingJobCard({
    required this.booking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final service = ServiceCategory.findById(booking.serviceType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.stitchSurfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.stitchSurfaceContainerHigh,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.stitchPrimaryFixed,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    service?.icon ?? Icons.construction_rounded,
                    color: AppColors.stitchPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service?.name ?? booking.serviceType,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            booking.customerName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.stitchOnSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: AppColors.stitchPrimaryCobalt,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    booking.status.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scheduled Service Window Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.stitchPrimaryCobalt,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Scheduled Service Window • Action Required',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.stitchOnSurfaceVariant,
                      ),
                    ),
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

/// 6. Accepted Job Card (Stitch: Squircle icon + Customer + Timestamp Bar + "View Details" button)
class _StitchAcceptedJobCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onViewDetails;

  const _StitchAcceptedJobCard({
    required this.booking,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final service = ServiceCategory.findById(booking.serviceType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.stitchSurfaceContainerHigh,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.stitchPrimaryFixed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  service?.icon ?? Icons.handyman_rounded,
                  color: AppColors.stitchPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service?.name ?? booking.serviceType,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stitchOnSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          booking.customerName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.stitchOnSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: AppColors.stitchPrimaryCobalt,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text(
                  'Accepted',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Timestamp Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: AppColors.stitchPrimaryCobalt,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(booking.appointmentTime),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Full-width View Details button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: TextButton(
              onPressed: onViewDetails,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.stitchSurfaceContainerHigh,
                foregroundColor: AppColors.stitchPrimaryCobalt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.stitchPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 7. Empty State Card for Incoming Requests matching Stitch
class _StitchEmptyStateCard extends StatelessWidget {
  final bool isOnline;

  const _StitchEmptyStateCard({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.stitchSurfaceContainerHigh,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inbox_rounded,
              size: 26,
              color: AppColors.stitchOutline,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No new requests right now',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.stitchOnSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOnline
                ? 'Stay online to receive instant service bookings from nearby customers.'
                : 'Switch your availability to Online to start receiving requests.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.stitchOnSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
