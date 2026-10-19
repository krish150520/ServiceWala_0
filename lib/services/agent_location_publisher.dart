import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';

/// Service that captures the provider's GPS coordinates and broadcasts them
/// to Supabase via `update_provider_location` RPC and Realtime broadcast so the
/// Customer app can track the agent live on the map.
class AgentLocationPublisher {
  static final AgentLocationPublisher _instance =
      AgentLocationPublisher._internal();
  factory AgentLocationPublisher() => _instance;
  AgentLocationPublisher._internal();

  Timer? _broadcastTimer;
  bool _isPublishing = false;
  LatLng? _lastKnownLocation;
  final ValueNotifier<LatLng?> currentLocationNotifier = ValueNotifier(null);

  RealtimeChannel? _realtimeBroadcastChannel;
  String? _cachedProviderId;

  LatLng? get lastKnownLocation => _lastKnownLocation;
  bool get isPublishing => _isPublishing;

  /// Default fallback location (Amritsar, Punjab center: 31.6340, 74.8723)
  static const LatLng defaultLocation = LatLng(31.6340, 74.8723);

  /// Ensure location permissions are granted and get current position
  Future<LatLng?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[AgentLocationPublisher] Location services are disabled.');
        return _lastKnownLocation ?? defaultLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[AgentLocationPublisher] Location permissions are denied');
          return _lastKnownLocation ?? defaultLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            '[AgentLocationPublisher] Location permissions are permanently denied.');
        return _lastKnownLocation ?? defaultLocation;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      _lastKnownLocation = latLng;
      currentLocationNotifier.value = latLng;
      return latLng;
    } catch (e) {
      debugPrint('[AgentLocationPublisher] Error getting GPS position: $e');
      return _lastKnownLocation ?? defaultLocation;
    }
  }

  /// Start periodic live broadcasting (every 5-6 seconds for smooth live tracking)
  void startBroadcasting({Duration interval = const Duration(seconds: 6)}) {
    if (_isPublishing) return;
    _isPublishing = true;
    debugPrint('[AgentLocationPublisher] Starting live location broadcasting (interval: ${interval.inSeconds}s)...');

    // Broadcast immediately on start
    _publishLocation();

    // Run periodic timer
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(interval, (_) => _publishLocation());
  }

  /// Stop live broadcasting
  void stopBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _isPublishing = false;
    debugPrint('[AgentLocationPublisher] Location broadcasting stopped.');
  }

  /// Capture location and broadcast to Supabase
  Future<void> _publishLocation() async {
    try {
      final loc = await getCurrentLocation();
      if (loc == null) return;
      await _sendLocationToBackend(loc);
    } catch (e) {
      debugPrint('[AgentLocationPublisher] _publishLocation error: $e');
    }
  }

  RealtimeChannel _getBroadcastChannel(SupabaseClient client) {
    if (_realtimeBroadcastChannel == null) {
      _realtimeBroadcastChannel = client.channel('public:agent_locations');
      _realtimeBroadcastChannel!.subscribe();
    }
    return _realtimeBroadcastChannel!;
  }

  /// Broadcast a specific location coordinate (used for live tracking simulation or testing)
  Future<void> publishCustomLocation(
    LatLng loc, {
    String? bookingId,
    double? heading,
  }) async {
    _lastKnownLocation = loc;
    currentLocationNotifier.value = loc;
    await _sendLocationToBackend(loc, bookingId: bookingId, heading: heading);
  }

  /// Core dispatch function: Updates Supabase via RPC, direct table writes, and Realtime broadcast
  Future<void> _sendLocationToBackend(
    LatLng loc, {
    String? bookingId,
    double? heading,
  }) async {
    _lastKnownLocation = loc;
    currentLocationNotifier.value = loc;

    if (!SupabaseService.isInitialized) {
      debugPrint(
          '[AgentLocationPublisher] Supabase not initialized; location captured locally ($loc).');
      return;
    }

    final client = SupabaseService.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Resolve provider ID if not cached yet
    if (_cachedProviderId == null) {
      try {
        final prov = await client
            .from('providers')
            .select('id')
            .eq('user_id', authUser.id)
            .maybeSingle();
        if (prov != null && prov['id'] != null) {
          _cachedProviderId = prov['id'].toString();
        }
      } catch (e) {
        debugPrint('[AgentLocationPublisher] Provider ID resolve error: $e');
      }
    }

    // 1. Primary: Invoke the canonical update_provider_location database RPC
    try {
      await client.rpc('update_provider_location', params: {
        'p_latitude': loc.latitude,
        'p_longitude': loc.longitude,
      });
      debugPrint(
          '[AgentLocationPublisher] RPC update_provider_location SUCCESS: ${loc.latitude}, ${loc.longitude}');
    } catch (e) {
      debugPrint('[AgentLocationPublisher] Broadcast RPC notice: $e; attempting direct table writes');
    }

    // 2. Direct Fallback: Update public.providers where user_id = authUser.id or id = _cachedProviderId
    try {
      if (_cachedProviderId != null) {
        await client.from('providers').update({
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'last_location_updated_at': nowIso,
        }).eq('id', _cachedProviderId!);
      }
      await client.from('providers').update({
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'last_location_updated_at': nowIso,
      }).eq('user_id', authUser.id);
      debugPrint('[AgentLocationPublisher] Directly updated public.providers coordinates');
    } catch (e) {
      debugPrint('[AgentLocationPublisher] Direct providers update notice: $e');
    }

    // 3. Fallback: Update public.users table so customer can always locate provider
    try {
      await client.from('users').update({
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'location_updated_at': nowIso,
      }).eq('id', authUser.id);
    } catch (_) {}

    // 4. Realtime Broadcast Channel: push instant location to any listening customer
    try {
      final channel = _getBroadcastChannel(client);
      await channel.sendBroadcastMessage(
        event: 'location_update',
        payload: {
          'booking_id': bookingId ?? '',
          'provider_id': _cachedProviderId ?? '',
          'user_id': authUser.id,
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'heading': heading ?? 0.0,
          'timestamp': nowIso,
        },
      );
    } catch (e) {
      debugPrint('[AgentLocationPublisher] Realtime broadcast notice: $e');
    }
  }
}
