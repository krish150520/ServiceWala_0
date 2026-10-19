import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Information describing a calculated driving route between two points
class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final String distanceText;
  final String durationText;

  const RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.distanceText,
    required this.durationText,
  });

  /// Factory creating an empty route
  factory RouteInfo.empty([LatLng? fallbackPoint]) {
    return RouteInfo(
      points: fallbackPoint != null ? [fallbackPoint] : const [],
      distanceKm: 0.0,
      durationMinutes: 0,
      distanceText: '-- km',
      durationText: '-- mins',
    );
  }
}

/// Computes driving routes and turn-by-turn ETA using OSRM with Haversine fallback
class RoutingService {
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  /// Calculate driving route from [origin] to [destination]
  static Future<RouteInfo> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final uri = Uri.parse(
        '$_osrmBaseUrl/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'ServiceWala-Partner-App/1.0.0',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final primaryRoute = routes.first;
          final double distanceMeters =
              (primaryRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final double durationSeconds =
              (primaryRoute['duration'] as num?)?.toDouble() ?? 0.0;

          final geometry = primaryRoute['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;

          final List<LatLng> points = [];
          if (coordinates != null) {
            for (final coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                final lng = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lng));
              }
            }
          }

          if (points.isEmpty) {
            points.addAll([origin, destination]);
          }

          final double distanceKm = distanceMeters / 1000.0;
          final int durationMinutes = (durationSeconds / 60.0).round().clamp(1, 9999);

          return RouteInfo(
            points: points,
            distanceKm: distanceKm,
            durationMinutes: durationMinutes,
            distanceText: '${distanceKm.toStringAsFixed(1)} km',
            durationText: '$durationMinutes mins',
          );
        }
      }
    } catch (e) {
      debugPrint('[RoutingService] OSRM routing notice (using fallback): $e');
    }

    // Haversine fallback calculation with urban driving speed estimation
    return _calculateHaversineFallback(origin, destination);
  }

  /// Estimates driving distance & route points using Haversine formula + road factor
  static RouteInfo _calculateHaversineFallback(LatLng start, LatLng dest) {
    const double earthRadiusKm = 6371.0;
    const double roadTortuosityFactor = 1.35; // Accounts for city street turns
    const double averageCitySpeedKmph = 25.0; // Urban travel speed

    final dLat = _degreesToRadians(dest.latitude - start.latitude);
    final dLon = _degreesToRadians(dest.longitude - start.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(start.latitude)) *
            math.cos(_degreesToRadians(dest.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double straightLineKm = earthRadiusKm * c;
    final double drivingKm = straightLineKm * roadTortuosityFactor;

    final int durationMinutes =
        ((drivingKm / averageCitySpeedKmph) * 60.0).round().clamp(2, 999);

    // Generate intermediate waypoints for smooth curve
    final List<LatLng> points = [
      start,
      LatLng(
        start.latitude + (dest.latitude - start.latitude) * 0.33,
        start.longitude + (dest.longitude - start.longitude) * 0.35,
      ),
      LatLng(
        start.latitude + (dest.latitude - start.latitude) * 0.66,
        start.longitude + (dest.longitude - start.longitude) * 0.68,
      ),
      dest,
    ];

    return RouteInfo(
      points: points,
      distanceKm: drivingKm,
      durationMinutes: durationMinutes,
      distanceText: '${drivingKm.toStringAsFixed(1)} km',
      durationText: '$durationMinutes mins',
    );
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
