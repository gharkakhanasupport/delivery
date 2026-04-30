import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'location_service.dart';

/// Fires [onReached] once when the partner's GPS enters [meters] of the target.
///
/// Pure Dart Haversine — no extra dependency. Uses [LocationService.currentLocation]
/// (ValueNotifier already streaming via 10s GPS poll), so the geofence reacts
/// within one GPS tick (≤10s) of the partner crossing the radius.
///
/// Returns a cancel function. Call it on widget dispose / step exit.
/// [onReached] fires at most once; listener auto-detaches after first hit.
class GeofenceService {
  /// Watch partner GPS until within [meters] of (targetLat, targetLng).
  /// [onReached] fires exactly once, then listener unsubscribes.
  /// Returned closure also cancels manually (safe to call anytime).
  static VoidCallback watchUntilWithin({
    required double targetLat,
    required double targetLng,
    required double meters,
    required VoidCallback onReached,
  }) {
    bool fired = false;
    bool cancelled = false;
    late final VoidCallback listener;

    void cancel() {
      if (cancelled) return;
      cancelled = true;
      LocationService.currentLocation.removeListener(listener);
    }

    listener = () {
      if (fired || cancelled) return;
      final pos = LocationService.currentLocation.value;
      if (pos == null) return;
      final d = _haversineMeters(pos.latitude, pos.longitude, targetLat, targetLng);
      debugPrint('[Geofence] distance to target: ${d.toStringAsFixed(1)}m');
      if (d <= meters) {
        fired = true;
        cancel();
        onReached();
      }
    };

    LocationService.currentLocation.addListener(listener);

    // Check immediately in case partner already inside radius.
    final pos = LocationService.currentLocation.value;
    if (pos != null) {
      final d = _haversineMeters(pos.latitude, pos.longitude, targetLat, targetLng);
      if (d <= meters) {
        fired = true;
        cancel();
        onReached();
      }
    }

    return cancel;
  }

  /// Convenience: watch until within 200m.
  static VoidCallback watchUntilReached({
    required LatLng target,
    required VoidCallback onReached,
    double meters = 200,
  }) {
    return watchUntilWithin(
      targetLat: target.latitude,
      targetLng: target.longitude,
      meters: meters,
      onReached: onReached,
    );
  }

  static double _haversineMeters(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * asin(sqrt(a));
    return earthRadiusM * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);
}
