import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/chat/chat_screen.dart';
import 'package:service_wala_business/screens/calling/calling_screen.dart';
import 'package:service_wala_business/services/agent_location_publisher.dart';
import 'package:service_wala_business/widgets/agent_booking_tracking_map.dart';

/// Navigation screen guiding the agent to the customer's service location
class NavigationScreen extends StatefulWidget {
  final Booking booking;

  const NavigationScreen({super.key, required this.booking});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final GlobalKey<AgentBookingTrackingMapState> _mapKey =
      GlobalKey<AgentBookingTrackingMapState>();

  void _callCustomer() {
    CallingScreen.start(
      context: context,
      customerName: widget.booking.customerName,
      customerPhone: widget.booking.customerPhone,
      serviceTitle: widget.booking.serviceType,
      bookingId: widget.booking.id,
      customerId: widget.booking.customerId,
    );
  }

  Future<void> _markAsArrived() async {
    final appState = context.read<AppState>();
    final current = appState.bookings.where((b) => b.id == widget.booking.id);
    if (current.isEmpty || current.first.status != BookingStatus.arrived) {
      await appState.updateBookingStatus(
        widget.booking.id,
        BookingStatus.arrived,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📍 Marked as Arrived at customer location!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address =
        widget.booking.customerAddress ??
        '42, 3rd Cross, Koramangala 5th Block, Bangalore';

    final customerLoc = LatLng(
      widget.booking.customerLatitude ?? 31.6340,
      widget.booking.customerLongitude ?? 74.8723,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Route to Customer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Interactive OpenStreetMap Tracking Area
          Column(
            children: [
              Expanded(
                child: AgentBookingTrackingMap(
                  key: _mapKey,
                  booking: widget.booking,
                  height: double.infinity,
                  onArrivedPressed: _markAsArrived,
                ),
              ),
              const SizedBox(height: 250),
            ],
          ),

          // Bottom Navigation Card Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.75),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic ETA and distance listening to live location updates
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<LatLng?>(
                            valueListenable: AgentLocationPublisher()
                                .currentLocationNotifier,
                            builder: (context, currentLoc, _) {
                              final distMeters = currentLoc != null
                                  ? const Distance().as(
                                      LengthUnit.Meter,
                                      currentLoc,
                                      customerLoc,
                                    )
                                  : 2400.0;
                              final distText = distMeters >= 1000
                                  ? '${(distMeters / 1000).toStringAsFixed(1)} km'
                                  : '${distMeters.round()} m';
                              final mins = (distMeters / (30 * 1000 / 60))
                                  .round()
                                  .clamp(1, 180);
                              final etaText = distMeters < 50
                                  ? 'Arrived'
                                  : '$mins mins';

                              return Row(
                                children: [
                                  Text(
                                    etaText,
                                    style: AppTextStyles.headingMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '($distText)',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const Text(
                            'Fastest route • Usual traffic',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.turn_right_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Customer details & Address
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceLight,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.booking.customerName
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.booking.customerName,
                                  style: AppTextStyles.labelMedium,
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              address,
                              style: AppTextStyles.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.phone_rounded,
                          color: AppColors.success,
                          size: 22,
                        ),
                        onPressed: _callCustomer,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatScreen(booking: widget.booking),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons: Demo Location Simulation & Arrived Confirmation
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _mapKey.currentState?.advance100Meters();
                          },
                          icon: const Icon(
                            Icons.navigation_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          label: const Text(
                            'Move 100m Forward',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: AppColors.primary,
                            backgroundColor: AppColors.surfaceLight,
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _markAsArrived,
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                          ),
                          label: const Text("I've Arrived"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
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
