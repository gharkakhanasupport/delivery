import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service for fetching accurate road routes using OSRM (Open Source Routing Machine)
/// Free API, no key required
class RoutingService {
  static const String _baseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  static final Map<String, RouteResult> _cache = {};

  /// Fetches a route between two points
  /// Returns a list of LatLng points representing the route, plus duration and distance
  static Future<RouteResult?> getRoute(LatLng from, LatLng to) async {
    // Use 3 decimal precision for better cache hits (~100m accuracy)
    final cacheKey =
        '${from.latitude.toStringAsFixed(3)},${from.longitude.toStringAsFixed(3)}_${to.latitude.toStringAsFixed(3)},${to.longitude.toStringAsFixed(3)}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final url =
          '$_baseUrl/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=simplified&steps=false&geometries=polyline';

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'GKK Delivery App/1.0'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'] as String;
          final duration = (route['duration'] as num).toDouble(); // seconds
          final distance = (route['distance'] as num).toDouble(); // meters

          final points = _decodePolyline(geometry);

          final result = RouteResult(
            points: points,
            durationSeconds: duration,
            distanceMeters: distance,
          );

          _cache[cacheKey] = result;
          return result;
        } else {
          // print('Routing API Error: ${data['code']}');
        }
      } else {
        // print('Routing HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      // print('Routing Exception: $e');
    }
    return null;
  }

  /// Decodes a polyline encoded string into a list of LatLng points
  /// Using the Polyline Algorithm: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Formats duration into human-readable string
  static String formatDuration(double seconds) {
    if (seconds < 60) {
      return '${seconds.round()} sec';
    } else if (seconds < 3600) {
      return '${(seconds / 60).round()} min';
    } else {
      final hours = (seconds / 3600).floor();
      final mins = ((seconds % 3600) / 60).round();
      return '$hours hr $mins min';
    }
  }

  /// Formats distance into human-readable string
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
}

/// Result of a route calculation
class RouteResult {
  final List<LatLng> points;
  final double durationSeconds;
  final double distanceMeters;

  RouteResult({
    required this.points,
    required this.durationSeconds,
    required this.distanceMeters,
  });

  /// Formatted ETA string
  String get etaString => RoutingService.formatDuration(durationSeconds);

  /// Formatted distance string
  String get distanceString => RoutingService.formatDistance(distanceMeters);
}
