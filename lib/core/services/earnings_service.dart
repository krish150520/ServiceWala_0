import 'package:service_wala_business/data/models/booking_model.dart';
import 'package:service_wala_business/data/models/earnings_model.dart';

/// Calculation and filtering domain service for Partner Earnings.
class EarningsService {
  static final EarningsService instance = EarningsService._();
  EarningsService._();

  /// Calculate earnings summary directly from a list of bookings
  EarningsSummary calculateSummary(List<BookingModel> bookings) {
    return EarningsSummary.fromBookings(bookings);
  }

  /// Filter earnings items according to selected UI timeframe
  List<EarningsItemModel> filterByPeriod({
    required List<EarningsItemModel> items,
    required String period,
  }) {
    final now = DateTime.now();

    switch (period) {
      case 'Today':
        return items.where((item) {
          return item.createdAt.year == now.year &&
              item.createdAt.month == now.month &&
              item.createdAt.day == now.day;
        }).toList();

      case 'This Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return items.where((item) => item.createdAt.isAfter(weekAgo)).toList();

      case 'This Month':
        return items.where((item) {
          return item.createdAt.year == now.year &&
              item.createdAt.month == now.month;
        }).toList();

      case 'All Time':
      default:
        return items;
    }
  }

  /// Sum digital earnings for a specific list of filtered items
  double calculatePeriodDigitalTotal(List<EarningsItemModel> items) {
    return items
        .where((i) => i.isDigitalEarning)
        .fold(0.0, (sum, i) => sum + i.amount);
  }

  /// Sum pending payout balance for a list of items
  double calculatePeriodPendingTotal(List<EarningsItemModel> items) {
    return items
        .where((i) =>
            i.bookingStatus.toLowerCase() == 'completed' &&
            i.paymentStatus.isPending &&
            i.paymentMethod.isOnline)
        .fold(0.0, (sum, i) => sum + i.amount);
  }
}
