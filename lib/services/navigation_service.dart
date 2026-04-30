import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

/// NavigationService — Opens Google Maps app with turn-by-turn directions
///
/// Supports:
/// - Navigate to pickup (kitchen) location
/// - Navigate to delivery (customer) location
/// - Fallback to browser if Google Maps app not installed
class NavigationService {
  /// Open Google Maps with driving directions to a destination.
  ///
  /// [destinationLat] / [destinationLng] — target coordinates
  /// [destinationLabel] — label for the destination pin
  /// [originLat] / [originLng] — optional origin (uses current location if null)
  static Future<bool> navigateTo({
    required double destinationLat,
    required double destinationLng,
    String? destinationLabel,
    double? originLat,
    double? originLng,
  }) async {
    if (destinationLat == 0.0 && destinationLng == 0.0) {
      debugPrint('[Navigation] ❌ Invalid destination coordinates (0,0)');
      return false;
    }

    // Build Google Maps URL with directions
    // travelmode=driving for delivery agents
    String url;
    if (originLat != null && originLng != null) {
      url = 'https://www.google.com/maps/dir/?api=1'
          '&origin=$originLat,$originLng'
          '&destination=$destinationLat,$destinationLng'
          '&travelmode=driving';
    } else {
      // No origin = Google Maps uses current GPS location
      url = 'https://www.google.com/maps/dir/?api=1'
          '&destination=$destinationLat,$destinationLng'
          '&travelmode=driving';
    }

    if (destinationLabel != null && destinationLabel.isNotEmpty) {
      url += '&destination_place_id=${Uri.encodeComponent(destinationLabel)}';
    }

    try {
      // Try Google Maps app first (android intent)
      final googleMapsUri = Uri.parse(
        'google.navigation:q=$destinationLat,$destinationLng&mode=d',
      );
      
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri);
        debugPrint('[Navigation] ✅ Opened Google Maps app');
        return true;
      }

      // Fallback: open in browser/maps via https URL
      final webUri = Uri.parse(url);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        debugPrint('[Navigation] ✅ Opened Google Maps via browser');
        return true;
      }

      debugPrint('[Navigation] ❌ Could not launch maps');
      return false;
    } catch (e) {
      debugPrint('[Navigation] Error: $e');
      return false;
    }
  }

  /// Navigate to pickup (kitchen) location
  static Future<bool> navigateToPickup({
    required double lat,
    required double lng,
    String? kitchenName,
  }) {
    return navigateTo(
      destinationLat: lat,
      destinationLng: lng,
      destinationLabel: kitchenName,
    );
  }

  /// Navigate to delivery (customer) location
  static Future<bool> navigateToDelivery({
    required double lat,
    required double lng,
    String? customerName,
  }) {
    return navigateTo(
      destinationLat: lat,
      destinationLng: lng,
      destinationLabel: customerName,
    );
  }

  /// Navigate using a LatLng object
  static Future<bool> navigateToLatLng(LatLng destination, {String? label}) {
    return navigateTo(
      destinationLat: destination.latitude,
      destinationLng: destination.longitude,
      destinationLabel: label,
    );
  }

  /// Backward-compatible alias — used by DeliveryNavigationScreen
  static Future<bool> launchNavigation(LatLng destination, {String? label}) {
    return navigateToLatLng(destination, label: label);
  }

  /// Open Google Maps showing just a location pin (no directions)
  static Future<bool> showOnMap({
    required double lat,
    required double lng,
    String? label,
  }) async {
    if (lat == 0.0 && lng == 0.0) return false;

    try {
      final url = Uri.parse(
        'geo:$lat,$lng?q=$lat,$lng${label != null ? "(${Uri.encodeComponent(label)})" : ""}',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return true;
      }

      // Fallback
      final webUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      return true;
    } catch (e) {
      debugPrint('[Navigation] Show on map error: $e');
      return false;
    }
  }
}
