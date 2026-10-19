import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/services/agent_location_publisher.dart';
import 'package:service_wala_business/services/routing_service.dart';

/// Interactive live customer navigation & map tracking widget matching the Customer (Cx) app.
///
/// Features:
/// - Inverted perspective: Agent is origin ("You (Agent)"), Customer is destination ("Customer Location").
/// - Real-time road route polyline from OSRM strictly anchored to road geometry.
/// - Floating driving distance & ETA overlay with live updating GPS coordinates.
/// - On-click 100m manual progression: advances 100 meters along the route per click.
/// - Dead-center marker alignment ensuring the marker sticks precisely on the road polyline.
/// - Directional arrowhead rotation matching each road segment's azimuth.
/// - Auto-syncs arrived status to Job Details upon reaching destination.
/// - Re-center / Fit bounds camera button.
/// - Pulsing live GPS radar ring on the Agent marker.
class AgentBookingTrackingMap extends StatefulWidget {
  final Booking booking;
  final double height;
  final bool isInteractive;
  final VoidCallback? onArrivedPressed;

  const AgentBookingTrackingMap({
    super.key,
    required this.booking,
    this.height = 360,
    this.isInteractive = true,
    this.onArrivedPressed,
  });

  @override
  State<AgentBookingTrackingMap> createState() =>
      AgentBookingTrackingMapState();
}

class AgentBookingTrackingMapState extends State<AgentBookingTrackingMap>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _radarController;
  final AgentLocationPublisher _locationPublisher = AgentLocationPublisher();

  LatLng? _agentLocation;
  late LatLng _customerLocation;
  RouteInfo _routeInfo = RouteInfo.empty();
  bool _isLoadingRoute = true;
  StreamSubscription? _locationSubscription;

  // Heading bearing in degrees for directional marker rotation
  double _headingDegrees = 0.0;

  // Discrete 100m on-click progression along polyline
  double _distanceTraveledMeters = 0.0;
  static const double _stepDistanceMeters = 100.0;

  final List<double> _cumulativeDistances = [];
  double _totalRouteDistanceMeters = 0.0;
  LatLng? _originalAgentLocation;
  bool _hasAutoArrived = false;

  bool get isAtCustomer {
    if (_agentLocation == null) return false;
    final total = _totalRouteDistanceMeters > 0
        ? _totalRouteDistanceMeters
        : const Distance().as(
            LengthUnit.Meter,
            _originalAgentLocation ?? _agentLocation!,
            _customerLocation,
          );
    if (_distanceTraveledMeters >= total - 1.0) return true;
    final dist = const Distance().as(LengthUnit.Meter, _agentLocation!, _customerLocation);
    return dist <= 100.0;
  }

  /// Automatically updates booking status to 'arrived' in database when agent reaches Cx location
  Future<void> _triggerAutoArrival() async {
    if (_hasAutoArrived) return;
    final currentStatus = widget.booking.status;
    if (currentStatus != BookingStatus.confirmed &&
        currentStatus != BookingStatus.onTheWay) {
      return;
    }

    _hasAutoArrived = true;
    debugPrint('[AgentBookingTrackingMap] Auto-arrived within customer radius! Updating to arrived in Supabase.');

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🏁 Arrived at Customer! Status auto-updated to Arrived.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) {
      try {
        final appState = context.read<AppState>();
        final currentBooking = appState.bookings.firstWhere(
          (b) => b.id == widget.booking.id,
          orElse: () => widget.booking,
        );
        if (currentBooking.status == BookingStatus.confirmed) {
          await appState.updateBookingStatus(
            widget.booking.id,
            BookingStatus.onTheWay,
          );
        }
        await appState.updateBookingStatus(
          widget.booking.id,
          BookingStatus.arrived,
        );
      } catch (e) {
        debugPrint('[AgentBookingTrackingMap] Auto-arrival update notice: $e');
      }
    }

    if (mounted) {
      widget.onArrivedPressed?.call();
    }
  }

  /// Checks if [position] is within 100m of customer and auto-updates to arrived
  void _checkAutoArrival(LatLng position) {
    if (_hasAutoArrived) return;
    final currentStatus = widget.booking.status;
    if (currentStatus != BookingStatus.confirmed &&
        currentStatus != BookingStatus.onTheWay) {
      return;
    }
    final dist = const Distance().as(LengthUnit.Meter, position, _customerLocation);
    if (dist <= 100.0) {
      _triggerAutoArrival();
    }
  }

  // Colors matching the Customer app tracking design system
  static const Color _skyBlue = Color(0xFF0EA5E9);
  static const Color _navyAccent = Color(0xFF0F172A);
  static const Color _routeBlue = Color(0xFF0284C7);
  static const Color _liveGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.booking.status == BookingStatus.arrived ||
        widget.booking.status == BookingStatus.workStarted ||
        widget.booking.status == BookingStatus.completed) {
      _hasAutoArrived = true;
    }

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Determine customer coordinates (fallback to Amritsar center if unconfigured)
    _customerLocation = LatLng(
      widget.booking.customerLatitude ?? 31.6340,
      widget.booking.customerLongitude ?? 74.8723,
    );

    // Initial GPS resolution and route calculation
    _initLiveLocationAndRoute();

    // Listen to location publisher changes
    _locationPublisher.currentLocationNotifier.addListener(_onLocationUpdated);

    // Start live broadcasting during active delivery stages
    if (widget.booking.status == BookingStatus.onTheWay ||
        widget.booking.status == BookingStatus.confirmed) {
      _locationPublisher.startBroadcasting();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationPublisher.currentLocationNotifier
        .removeListener(_onLocationUpdated);
    _radarController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Calculates the geographical bearing angle in degrees [0, 360) from [start] to [dest].
  double _calculateBearing(LatLng start, LatLng dest) {
    final double startLat = start.latitude * (math.pi / 180.0);
    final double startLng = start.longitude * (math.pi / 180.0);
    final double destLat = dest.latitude * (math.pi / 180.0);
    final double destLng = dest.longitude * (math.pi / 180.0);

    final double dLng = destLng - startLng;

    final double y = math.sin(dLng) * math.cos(destLat);
    final double x = math.cos(startLat) * math.sin(destLat) -
        math.sin(startLat) * math.cos(destLat) * math.cos(dLng);

    final double bearingRad = math.atan2(y, x);
    final double bearingDeg = (bearingRad * (180.0 / math.pi) + 360.0) % 360.0;
    return bearingDeg;
  }

  /// Smoothly updates heading using shortest rotational arc
  void _updateHeading(LatLng from, LatLng to) {
    if ((from.latitude - to.latitude).abs() < 0.00001 &&
        (from.longitude - to.longitude).abs() < 0.00001) {
      return;
    }
    final newDeg = _calculateBearing(from, to);
    double diff = (newDeg - (_headingDegrees % 360.0));
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    setState(() {
      _headingDegrees += diff;
    });
  }

  void _onLocationUpdated() {
    final newLoc = _locationPublisher.currentLocationNotifier.value;
    if (newLoc != null && mounted) {
      if (_agentLocation != null) {
        _updateHeading(_agentLocation!, newLoc);
      }
      setState(() => _agentLocation = newLoc);
      _checkAutoArrival(newLoc);
      _fetchRoute(newLoc, _customerLocation);
    }
  }

  Future<void> _initLiveLocationAndRoute() async {
    final gpsLoc = await _locationPublisher.getCurrentLocation();
    final agentLoc = gpsLoc ??
        LatLng(
          _customerLocation.latitude - 0.018,
          _customerLocation.longitude - 0.015,
        );

    if (!mounted) return;
    final initialBearing = _calculateBearing(agentLoc, _customerLocation);
    setState(() {
      _agentLocation = agentLoc;
      _originalAgentLocation = agentLoc;
      _headingDegrees = initialBearing;
    });

    _checkAutoArrival(agentLoc);

    await _fetchRoute(agentLoc, _customerLocation);
    if (mounted && _routeInfo.points.length >= 2) {
      final routeBearing = _calculateBearing(
        _routeInfo.points[0],
        _routeInfo.points[1],
      );
      setState(() {
        _headingDegrees = routeBearing;
      });
    }
    _fitMapBounds();
  }

  Future<void> _fetchRoute(LatLng start, LatLng dest) async {
    setState(() => _isLoadingRoute = true);
    final route = await RoutingService.getDrivingRoute(
      origin: start,
      destination: dest,
    );
    if (!mounted) return;
    setState(() {
      _routeInfo = route;
      _isLoadingRoute = false;
    });
    _computeCumulativeDistances();
  }

  void _computeCumulativeDistances() {
    _cumulativeDistances.clear();
    if (_routeInfo.points.isEmpty) {
      _totalRouteDistanceMeters = const Distance().as(
        LengthUnit.Meter,
        _originalAgentLocation ?? _agentLocation ?? _customerLocation,
        _customerLocation,
      );
      return;
    }
    const distanceCalc = Distance();
    _cumulativeDistances.add(0.0);
    double accum = 0.0;
    for (int i = 0; i < _routeInfo.points.length - 1; i++) {
      accum += distanceCalc.as(
        LengthUnit.Meter,
        _routeInfo.points[i],
        _routeInfo.points[i + 1],
      );
      _cumulativeDistances.add(accum);
    }
    _totalRouteDistanceMeters = accum;
  }

  /// Calculates the exact interpolated position and road segment bearing at [targetDistance]
  ({LatLng position, double heading}) _getPositionAndHeading(double targetDistance) {
    if (_routeInfo.points.isEmpty) {
      final start = _originalAgentLocation ?? _agentLocation ?? _customerLocation;
      final total = const Distance().as(LengthUnit.Meter, start, _customerLocation);
      if (total <= 0) {
        return (position: _customerLocation, heading: _headingDegrees);
      }
      final t = (targetDistance / total).clamp(0.0, 1.0);
      final pos = LatLng(
        start.latitude + t * (_customerLocation.latitude - start.latitude),
        start.longitude + t * (_customerLocation.longitude - start.longitude),
      );
      final bearing = _calculateBearing(start, _customerLocation);
      return (position: pos, heading: bearing);
    }

    if (_routeInfo.points.length == 1) {
      return (position: _routeInfo.points.first, heading: _headingDegrees);
    }

    if (targetDistance <= 0.0) {
      final p1 = _routeInfo.points[0];
      final p2 = _routeInfo.points[1];
      return (position: p1, heading: _calculateBearing(p1, p2));
    }

    if (targetDistance >= _totalRouteDistanceMeters) {
      final lastIdx = _routeInfo.points.length - 1;
      final pPrev = _routeInfo.points[lastIdx - 1];
      final pLast = _routeInfo.points[lastIdx];
      return (position: pLast, heading: _calculateBearing(pPrev, pLast));
    }

    for (int i = 0; i < _cumulativeDistances.length - 1; i++) {
      final d1 = _cumulativeDistances[i];
      final d2 = _cumulativeDistances[i + 1];
      if (targetDistance >= d1 && targetDistance <= d2) {
        final segLen = d2 - d1;
        final p1 = _routeInfo.points[i];
        final p2 = _routeInfo.points[i + 1];
        final segBearing = _calculateBearing(p1, p2);

        if (segLen <= 0.0001) {
          return (position: p1, heading: segBearing);
        }

        final t = ((targetDistance - d1) / segLen).clamp(0.0, 1.0);
        final interpolated = LatLng(
          p1.latitude + t * (p2.latitude - p1.latitude),
          p1.longitude + t * (p2.longitude - p1.longitude),
        );
        return (position: interpolated, heading: segBearing);
      }
    }

    final pLast = _routeInfo.points.last;
    return (position: pLast, heading: _headingDegrees);
  }

  /// Returns the polyline of the path already traveled behind the agent
  List<LatLng> get _traveledRoutePoints {
    if (_routeInfo.points.isEmpty ||
        _agentLocation == null ||
        _distanceTraveledMeters <= 0) {
      return const [];
    }

    int segIdx = 0;
    for (int i = 0; i < _cumulativeDistances.length - 1; i++) {
      if (_distanceTraveledMeters >= _cumulativeDistances[i] &&
          _distanceTraveledMeters <= _cumulativeDistances[i + 1]) {
        segIdx = i;
        break;
      }
    }

    return [
      ..._routeInfo.points.sublist(0, segIdx + 1),
      _agentLocation!,
    ];
  }

  /// Returns the active polyline extending from the agent marker to the customer destination
  List<LatLng> get _remainingRoutePoints {
    if (_routeInfo.points.isEmpty) {
      if (_agentLocation != null) {
        return [_agentLocation!, _customerLocation];
      }
      return [_customerLocation];
    }

    if (_agentLocation == null || _distanceTraveledMeters <= 0) {
      return _routeInfo.points;
    }

    int segIdx = 0;
    for (int i = 0; i < _cumulativeDistances.length - 1; i++) {
      if (_distanceTraveledMeters >= _cumulativeDistances[i] &&
          _distanceTraveledMeters <= _cumulativeDistances[i + 1]) {
        segIdx = i;
        break;
      }
    }

    if (segIdx >= _routeInfo.points.length - 1) {
      return [_agentLocation!, _customerLocation];
    }

    return [
      _agentLocation!,
      ..._routeInfo.points.sublist(segIdx + 1),
    ];
  }

  void _fitMapBounds() {
    if (_agentLocation == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final allPoints = [
          _agentLocation!,
          _customerLocation,
          ..._routeInfo.points,
        ];
        final bounds = LatLngBounds.fromPoints(allPoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(40, 80, 40, 70),
          ),
        );
      } catch (e) {
        debugPrint('[AgentBookingTrackingMap] Fit bounds notice: $e');
      }
    });
  }

  /// Advances the agent location forward by exactly 100 meters on each button click.
  /// The position strictly adheres to the road polyline geometry with segment-accurate bearing.
  Future<void> advance100Meters() async {
    _originalAgentLocation ??= _agentLocation ??
        LatLng(
          _customerLocation.latitude - 0.018,
          _customerLocation.longitude - 0.015,
        );

    if (_totalRouteDistanceMeters <= 0) {
      _computeCumulativeDistances();
    }

    final totalDist = _totalRouteDistanceMeters > 0
        ? _totalRouteDistanceMeters
        : const Distance().as(
            LengthUnit.Meter,
            _originalAgentLocation!,
            _customerLocation,
          );

    if (isAtCustomer) {
      resetSimulation();
      return;
    }

    // Auto advance to onTheWay as soon as partner begins moving forward
    if (widget.booking.status == BookingStatus.confirmed) {
      try {
        context.read<AppState>().updateBookingStatus(
          widget.booking.id,
          BookingStatus.onTheWay,
        );
      } catch (e) {
        debugPrint('[AgentBookingTrackingMap] Transition to onTheWay notice: $e');
      }
    }

    // Check remaining distance before advancing
    final double remainingDistance = (totalDist - _distanceTraveledMeters).clamp(0.0, totalDist);
    final bool willReachInThisStep = remainingDistance <= _stepDistanceMeters;

    final LatLng nextPos;
    final double nextHeading;
    final bool reached;

    if (willReachInThisStep || remainingDistance <= 100.0) {
      // Last step: Jump EXACTLY to customer location (no gap or overshoot)
      _distanceTraveledMeters = totalDist;
      nextPos = _customerLocation;
      nextHeading = _calculateBearing(_agentLocation ?? _originalAgentLocation!, _customerLocation);
      reached = true;
    } else {
      _distanceTraveledMeters += _stepDistanceMeters;
      final result = _getPositionAndHeading(_distanceTraveledMeters);
      nextPos = result.position;
      nextHeading = result.heading;
      reached = false;
    }

    // Smooth shortest-arc heading update
    double diff = (nextHeading - (_headingDegrees % 360.0));
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;

    setState(() {
      _agentLocation = nextPos;
      _headingDegrees += diff;
    });

    // Pan camera to follow the moving agent smoothly
    try {
      _mapController.move(nextPos, _mapController.camera.zoom);
    } catch (_) {}

    // Broadcast live location to Supabase with bookingId and heading for real-time customer sync
    await _locationPublisher.publishCustomLocation(
      nextPos,
      bookingId: widget.booking.id,
      heading: _headingDegrees,
    );

    if (reached) {
      await _triggerAutoArrival();
    } else {
      if (mounted) {
        final remText = _getRemainingDistanceText();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Moved 100m forward along route • $remText to destination'),
            backgroundColor: _skyBlue,
            duration: const Duration(milliseconds: 1400),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Resets position back to starting origin
  void resetSimulation() {
    _hasAutoArrived = false;
    _distanceTraveledMeters = 0.0;
    final startLoc = _originalAgentLocation!;
    _updateHeading(_agentLocation ?? startLoc, _customerLocation);
    _agentLocation = startLoc;
    _locationPublisher.publishCustomLocation(
      startLoc,
      bookingId: widget.booking.id,
      heading: _headingDegrees,
    );
    _fitMapBounds();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Reset: Returned to origin location'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    }
  }

  // Alias for backwards compatibility
  Future<void> simulateStepForward() => advance100Meters();

  String _getRemainingDistanceText() {
    final total = _totalRouteDistanceMeters > 0
        ? _totalRouteDistanceMeters
        : (_originalAgentLocation != null
            ? const Distance().as(
                LengthUnit.Meter,
                _originalAgentLocation!,
                _customerLocation,
              )
            : 2400.0);
    final rem = (total - _distanceTraveledMeters).clamp(0.0, total);
    if (rem >= 1000) {
      return '${(rem / 1000).toStringAsFixed(1)} km';
    } else {
      return '${rem.round()} m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentLoc = _agentLocation ??
        LatLng(
          _customerLocation.latitude - 0.018,
          _customerLocation.longitude - 0.015,
        );

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. OpenStreetMap Interactive Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                (agentLoc.latitude + _customerLocation.latitude) / 2,
                (agentLoc.longitude + _customerLocation.longitude) / 2,
              ),
              initialZoom: 14.2,
              interactionOptions: InteractionOptions(
                flags: widget.isInteractive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              // OpenStreetMap Standard Tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.servicewala.business',
                maxZoom: 19,
              ),

              // Road Route Polyline Layer
              if (_routeInfo.points.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // A. Traveled road portion (subtle grey path behind agent)
                    if (_traveledRoutePoints.isNotEmpty)
                      Polyline(
                        points: _traveledRoutePoints,
                        strokeWidth: 4.0,
                        color: const Color(0xFF94A3B8).withValues(alpha: 0.5),
                      ),

                    // B. Remaining road path (outer glow)
                    if (_remainingRoutePoints.isNotEmpty)
                      Polyline(
                        points: _remainingRoutePoints,
                        strokeWidth: 7.0,
                        color: _routeBlue.withValues(alpha: 0.25),
                      ),

                    // C. Remaining road path (high-contrast primary line starting directly at agent)
                    if (_remainingRoutePoints.isNotEmpty)
                      Polyline(
                        points: _remainingRoutePoints,
                        strokeWidth: 4.8,
                        color: _routeBlue,
                      ),
                  ],
                ),

              // Markers Layer - Anchored dead-center on coordinates
              MarkerLayer(
                markers: [
                  // Destination: Customer Location Pin (Anchored dead center)
                  Marker(
                    point: _customerLocation,
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: _buildCustomerMarker(),
                  ),

                  // Origin: Agent Live Location Marker (Anchored dead center on route)
                  Marker(
                    point: agentLoc,
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: _buildAgentMarker(),
                  ),
                ],
              ),
            ],
          ),

          // 2. Floating Distance & ETA Overlay (Top Bar)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _buildTopEtaCard(),
          ),

          // 3. Floating Bottom Controls: Re-center & Move 100m Forward
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Re-center Fit Bounds Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.my_location_rounded,
                        color: _navyAccent),
                    onPressed: _fitMapBounds,
                    tooltip: 'Re-center map',
                  ),
                ),
                const SizedBox(width: 10),

                // Primary One-Tap Move 100m Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: advance100Meters,
                    icon: Icon(
                      isAtCustomer
                          ? Icons.refresh_rounded
                          : Icons.navigation_rounded,
                      size: 20,
                    ),
                    label: Text(
                      isAtCustomer
                          ? 'Arrived! Reset Route'
                          : 'Move 100m Forward (${_getRemainingDistanceText()} left)',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isAtCustomer ? const Color(0xFF10B981) : _skyBlue,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: (isAtCustomer
                              ? const Color(0xFF10B981)
                              : _skyBlue)
                          .withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Top Floating Driving Distance & ETA Banner
  Widget _buildTopEtaCard() {
    final agentLoc = _agentLocation ??
        LatLng(
          _customerLocation.latitude - 0.018,
          _customerLocation.longitude - 0.015,
        );

    final total = _totalRouteDistanceMeters > 0
        ? _totalRouteDistanceMeters
        : (_originalAgentLocation != null
            ? const Distance().as(
                LengthUnit.Meter,
                _originalAgentLocation!,
                _customerLocation,
              )
            : 2400.0);
    final remMeters = (total - _distanceTraveledMeters).clamp(0.0, total);
    final remDistText = remMeters >= 1000
        ? '${(remMeters / 1000).toStringAsFixed(1)} km'
        : '${remMeters.round()} m';
    final remMins = (remMeters / (30 * 1000 / 60)).round().clamp(1, 180);
    final remDurationText = remMeters <= 35 ? 'Arrived' : '$remMins mins';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _skyBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: _skyBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _isLoadingRoute ? 'Calculating...' : remDurationText,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _navyAccent,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '($remDistText)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live GPS: ${agentLoc.latitude.toStringAsFixed(4)}, ${agentLoc.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Live Broadcasting Status Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _liveGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _liveGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'GPS Live',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _liveGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Marker representing the Customer Destination (Centered precisely on coordinate)
  Widget _buildCustomerMarker() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Pill Label floating directly above the pin
        Positioned(
          bottom: 44,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
            ),
            child: const Text(
              'Customer Location',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _navyAccent,
              ),
            ),
          ),
        ),

        // Home Icon Pin centered exactly on the coordinate
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _skyBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: _skyBlue.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.home_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  /// Marker representing the Agent's Live Location with Radar Pulse (Centered on coordinate)
  Widget _buildAgentMarker() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Pill Label with Green Live Dot floating above the pin
        Positioned(
          bottom: 44,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _navyAccent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _liveGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'You (Agent)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Radar pulse ring
        AnimatedBuilder(
          animation: _radarController,
          builder: (context, child) {
            return Container(
              width: 36 + (_radarController.value * 14),
              height: 36 + (_radarController.value * 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _skyBlue.withValues(
                      alpha: 1.0 - _radarController.value),
                  width: 1.5,
                ),
              ),
            );
          },
        ),

        // Inner dark navy badge (36x36) centered directly on the road coordinate
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _navyAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: _navyAccent.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: AnimatedRotation(
              turns: _headingDegrees / 360.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
