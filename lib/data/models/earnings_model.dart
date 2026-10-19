import 'package:service_wala_business/data/models/booking_model.dart';
import 'package:service_wala_business/data/models/payment_model.dart';

/// Single earnings transaction item derived from a Booking record.
class EarningsItemModel {
  final String bookingId;
  final String serviceName;
  final String customerName;
  final double amount;
  final AppPaymentMethod paymentMethod;
  final AppPaymentStatus paymentStatus;
  final String bookingStatus;
  final DateTime createdAt;
  final bool isDigitalEarning;

  const EarningsItemModel({
    required this.bookingId,
    required this.serviceName,
    required this.customerName,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.createdAt,
    required this.isDigitalEarning,
  });

  /// Factory constructing an earnings item from a database [BookingModel].
  factory EarningsItemModel.fromBooking(BookingModel booking) {
    final method = AppPaymentMethod.fromDb(booking.paymentMethod);
    final status = AppPaymentStatus.fromDb(booking.paymentStatus);
    final isCompleted = booking.status?.toLowerCase() == 'completed';
    final isPaid = status == AppPaymentStatus.paid;
    final isDigital = isCompleted && isPaid && method.isOnline;

    return EarningsItemModel(
      bookingId: booking.id,
      serviceName: booking.service?.name ?? 'Service Booking',
      customerName: booking.customer?.fullName ?? 'Customer',
      amount: booking.price ?? 0.0,
      paymentMethod: method,
      paymentStatus: status,
      bookingStatus: booking.status ?? 'unknown',
      createdAt: booking.createdAt ?? DateTime.now(),
      isDigitalEarning: isDigital,
    );
  }
}

/// Comprehensive earnings summary calculated from database booking records.
class EarningsSummary {
  /// Total digital earnings from verified, completed, online/Razorpay payments.
  final double totalDigitalEarnings;

  /// Digital earnings for the current calendar month.
  final double currentMonthDigitalEarnings;

  /// Digital earnings for today.
  final double todayDigitalEarnings;

  /// Digital earnings for the last 7 days.
  final double thisWeekDigitalEarnings;

  /// Total number of completed service jobs.
  final int completedJobsCount;

  /// Total number of all bookings for the agent.
  final int totalJobsCount;

  /// Pending payout balance for digital earnings awaiting settlement.
  final double pendingPayoutAmount;

  /// Total collected via Cash on Service (excluded from digital earnings).
  final double cashTotalAmount;

  /// Number of cash bookings.
  final int cashBookingsCount;

  /// List of individual earnings/settlement items.
  final List<EarningsItemModel> items;

  const EarningsSummary({
    required this.totalDigitalEarnings,
    required this.currentMonthDigitalEarnings,
    required this.todayDigitalEarnings,
    required this.thisWeekDigitalEarnings,
    required this.completedJobsCount,
    required this.totalJobsCount,
    required this.pendingPayoutAmount,
    required this.cashTotalAmount,
    required this.cashBookingsCount,
    required this.items,
  });

  /// Factory creating a clean summary from a raw list of [BookingModel]s.
  ///
  /// Strict Rules Enforced:
  /// 1. Digital earnings ONLY include bookings where:
  ///    - booking.status == 'completed'
  ///    - booking.paymentStatus == 'paid'
  ///    - booking.paymentMethod is 'razorpay' or 'online'
  /// 2. Cash payments are calculated separately and EXCLUDED from digital earnings.
  /// 3. Unpaid, pending, or cancelled bookings are EXCLUDED from digital earnings.
  factory EarningsSummary.fromBookings(List<BookingModel> bookings) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    double totalDigital = 0.0;
    double currentMonthDigital = 0.0;
    double todayDigital = 0.0;
    double thisWeekDigital = 0.0;
    double pendingPayout = 0.0;
    double cashTotal = 0.0;
    int cashCount = 0;
    int completedJobs = 0;

    final List<EarningsItemModel> itemsList = [];

    for (final booking in bookings) {
      final item = EarningsItemModel.fromBooking(booking);
      itemsList.add(item);

      final isCompleted = booking.status?.toLowerCase() == 'completed';
      if (isCompleted) {
        completedJobs++;
      }

      final method = item.paymentMethod;
      final status = item.paymentStatus;
      final amount = item.amount;
      final bookingDate = item.createdAt;

      if (method.isCash) {
        // Track cash separately; NEVER include in digital earnings
        if (isCompleted && status.isPaid) {
          cashTotal += amount;
          cashCount++;
        }
      } else if (method.isOnline) {
        // Digital online / Razorpay payment
        if (isCompleted && status.isPaid) {
          totalDigital += amount;

          // Check if today
          if (bookingDate.year == now.year &&
              bookingDate.month == now.month &&
              bookingDate.day == now.day) {
            todayDigital += amount;
          }

          // Check if this week
          if (bookingDate.isAfter(weekAgo)) {
            thisWeekDigital += amount;
          }

          // Check if this month
          if (bookingDate.year == now.year && bookingDate.month == now.month) {
            currentMonthDigital += amount;
          }
        } else if (isCompleted && status.isPending) {
          // Completed but payment pending
          pendingPayout += amount;
        }
      }
    }

    return EarningsSummary(
      totalDigitalEarnings: totalDigital,
      currentMonthDigitalEarnings: currentMonthDigital,
      todayDigitalEarnings: todayDigital,
      thisWeekDigitalEarnings: thisWeekDigital,
      completedJobsCount: completedJobs,
      totalJobsCount: bookings.length,
      pendingPayoutAmount: pendingPayout,
      cashTotalAmount: cashTotal,
      cashBookingsCount: cashCount,
      items: itemsList,
    );
  }

  /// Empty initial summary
  factory EarningsSummary.empty() {
    return const EarningsSummary(
      totalDigitalEarnings: 0.0,
      currentMonthDigitalEarnings: 0.0,
      todayDigitalEarnings: 0.0,
      thisWeekDigitalEarnings: 0.0,
      completedJobsCount: 0,
      totalJobsCount: 0,
      pendingPayoutAmount: 0.0,
      cashTotalAmount: 0.0,
      cashBookingsCount: 0,
      items: [],
    );
  }
}
