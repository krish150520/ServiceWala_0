import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/models/transaction.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/widgets/common_widgets.dart';
import 'package:service_wala_business/widgets/loading_animation.dart';

/// Screen displaying earnings summary, payout requests, and transaction history
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  String _selectedPeriod = 'All Time';
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final transactions = _getFilteredTransactions(appState.transactions);

    // Digital earnings calculation strictly excludes Cash on Service
    final totalPaid = transactions
        .where((t) =>
            t.paymentStatus == PaymentStatus.paid && t.paymentMethod.isDigital)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalPending = transactions
        .where((t) =>
            t.paymentStatus == PaymentStatus.pending &&
            t.paymentMethod.isDigital)
        .fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Earnings & Settlements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showPayoutPolicy(context),
            tooltip: 'Payout Policy',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => appState.refreshBookings(),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (appState.error != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
              ],
              // Period Filter Selector Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _periods.map((period) {
                  final isSelected = _selectedPeriod == period;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(period),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedPeriod = period);
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      backgroundColor: AppColors.surfaceLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: 0.8,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Top Hero Solid Cobalt Blue Card (matching Special Offer banner from reference)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Earnings ($_selectedPeriod)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Verified Partner',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${NumberFormat('#,##,###').format(totalPaid)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 14),

                  // Sub stats row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Payout',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${NumberFormat('#,##,###').format(totalPending)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completed Jobs',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${appState.completedJobsCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Direct Bank Settlement Action Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Direct Bank Transfer',
                          style: AppTextStyles.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'HDFC Bank •••• 8912 (UPI)',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _handleWithdrawal(context, totalPending),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(88, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Withdraw',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaction History Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Settlements',
                    style: AppTextStyles.headingSmall),
                Text(
                  '${transactions.length} items',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Transactions List
            if (transactions.isEmpty)
              if (appState.isLoading)
                const BookingCardsShimmerLoading(count: 2, label: 'Fetching settlements...')
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No Transactions',
                      subtitle:
                          'Completed job settlements and payouts will appear here.',
                    ),
                  ),
                )
            else
              ...transactions.map((txn) => _buildTransactionTile(txn)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  List<Transaction> _getFilteredTransactions(List<Transaction> list) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Today':
        return list.where((t) {
          return t.createdAt.year == now.year &&
              t.createdAt.month == now.month &&
              t.createdAt.day == now.day;
        }).toList();
      case 'This Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return list.where((t) => t.createdAt.isAfter(weekAgo)).toList();
      case 'This Month':
        return list.where((t) {
          return t.createdAt.year == now.year &&
              t.createdAt.month == now.month;
        }).toList();
      default:
        return list;
    }
  }

  Widget _buildTransactionTile(Transaction txn) {
    final isPaid = txn.paymentStatus == PaymentStatus.paid;
    final isPending = txn.paymentStatus == PaymentStatus.pending;

    Color badgeBg = isPaid
        ? AppColors.successLight
        : (isPending ? AppColors.primaryLight : AppColors.errorLight);
    Color badgeText = isPaid
        ? AppColors.success
        : (isPending ? AppColors.primary : AppColors.error);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPaid
                  ? Icons.arrow_downward_rounded
                  : (isPending ? Icons.hourglass_top_rounded : Icons.close_rounded),
              color: badgeText,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.serviceName,
                  style: AppTextStyles.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(txn.createdAt),
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: txn.paymentMethod.isDigital
                            ? AppColors.primaryLight
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        txn.paymentMethod.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: txn.paymentMethod.isDigital
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${NumberFormat('#,##,###').format(txn.amount)}',
                style: AppTextStyles.labelLarge.copyWith(
                  color: isPaid ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  txn.paymentStatus.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleWithdrawal(BuildContext context, double pendingAmount) {
    if (pendingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No pending balance available for withdrawal.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirm Payout Request',
                style: AppTextStyles.headingSmall),
            const SizedBox(height: 12),
            Text(
              'A payout of ₹${NumberFormat('#,##,###').format(pendingAmount)} will be transferred directly to your linked UPI/Bank account within 24 hours.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Zero fee instant bank transfer enabled for ServiceWala Partners',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          '🚀 Payout request submitted successfully! Funds will arrive shortly.'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: const Text('Request Payout Now →'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayoutPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Partner Payout Policy'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '• 100% Transparency: Service charges agreed with customers go directly to the partner.\n\n'
                '• Settlement Cycle: Earnings are credited immediately upon customer job completion.\n\n'
                '• Instant Withdrawals: Partners can withdraw funds directly to their registered UPI or bank account anytime.',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
