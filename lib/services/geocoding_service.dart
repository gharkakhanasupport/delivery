import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// GeocodingService — Converts text addresses to lat/lng coordinates
/// Uses OpenStreetMap Nominatim API (free, no API key needed)
///
/// Includes an in-memory cache to avoid repeat lookups for the same address.
class GeocodingService {
  static final Map<String, LatLng> _cache = {};

  /// Geocode an address string → LatLng
  /// Returns null if geocoding fails or address is empty.
  static Future<LatLng?> geocodeAddress(String? address) async {
    if (address == null || address.trim().isEmpty) return null;
    if (address == 'Not provided' || address == 'N/A') return null;

    // Check cache first
    final cacheKey = address.trim().toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final encodedAddress = Uri.encodeComponent(address.trim());
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$encodedAddress'
        '&format=json'
        '&limit=1'
        '&countrycodes=in', // Restrict to India for better results
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'GKK-Delivery-App/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final lat = double.tryParse(results[0]['lat'].toString()) ?? 0;
          final lng = double.tryParse(results[0]['lon'].toString()) ?? 0;

          if (lat != 0 && lng != 0) {
            final location = LatLng(lat, lng);
            _cache[cacheKey] = location; // Cache it
            debugPrint('[Geocoding] ✅ "$address" → ($lat, $lng)');
            return location;
          }
        }
      }

      debugPrint('[Geocoding] ❌ No result for "$address"');
      return null;
    } catch (e) {
      debugPrint('[Geocoding] Error for "$address": $e');
      return null;
    }
  }

  /// Reverse geocode lat/lng → address string
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat'
        '&lon=$lng'
        '&format=json',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'GKK-Delivery-App/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['display_name'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[Geocoding] Reverse error: $e');
      return null;
    }
  }

  /// Check if a string looks like a UUID (saved_address reference)
  static bool isUuid(String? value) {
    if (value == null) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  /// Clear the geocoding cache
  static void clearCache() => _cache.clear();
}
