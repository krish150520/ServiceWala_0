import 'package:flutter/material.dart';
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:intl/intl.dart';

/// Card for displaying a booking/job in lists
class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;
  final bool showActions;

  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final service = ServiceCategory.findById(booking.serviceType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Circular Icon + Title + Status Pill
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: service?.bgColor ?? AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    service?.icon ?? Icons.build_rounded,
                    color: service?.iconColor ?? AppColors.primary,
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
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            booking.customerName,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              size: 13, color: AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 12),

            // Date, time & Price Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a')
                        .format(booking.appointmentTime),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (booking.agreedPrice != null) ...[
                    Text(
                      '₹${booking.agreedPrice!.toStringAsFixed(0)}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (showActions && onTap != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.primary, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    booking.status.isActive ? 'View & Manage Job' : 'View Details',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color badgeBg;
    Color badgeText;

    switch (booking.status) {
      case BookingStatus.confirmed:
      case BookingStatus.onTheWay:
      case BookingStatus.arrived:
      case BookingStatus.workStarted:
        badgeBg = AppColors.primaryLight;
        badgeText = AppColors.primary;
        break;
      case BookingStatus.completed:
        badgeBg = AppColors.successLight;
        badgeText = AppColors.success;
        break;
      case BookingStatus.accepted:
        badgeBg = AppColors.warningLight;
        badgeText = AppColors.warning;
        break;
      default:
        badgeBg = AppColors.surfaceLight;
        badgeText = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        booking.status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: badgeText,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
