import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Centralized Location Service for real-time GPS tracking
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Current location as a ValueNotifier for reactive UI updates
  static final ValueNotifier<LatLng?> currentLocation = ValueNotifier(null);

  /// Location stream subscription
  static StreamSubscription<Position>? _positionSubscription;

  /// Whether location services are available and enabled
  static final ValueNotifier<bool> isLocationAvailable = ValueNotifier(false);

  /// Error message if any
  static final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  /// Current heading/bearing in degrees (0-360, where 0 = North)
  static final ValueNotifier<double> currentHeading = ValueNotifier(0);

  /// Check if location services are enabled on the device
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      if (kDebugMode) print('LocationService: Error checking service: $e');
      return false;
    }
  }

  /// Check current permission status
  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      if (kDebugMode) print('LocationService: Error checking permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Request location permission
  static Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      if (kDebugMode) print('LocationService: Error requesting permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Initialize location tracking - call this after permissions are granted
  static Future<bool> initialize() async {
    try {
      // 1. Check if location service is enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        errorMessage.value =
            'Please enable Location Services in your device settings.';
        isLocationAvailable.value = false;
        return false;
      }

      // 2. Check permission
      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
      }

      if (permission == LocationPermission.denied) {
        errorMessage.value =
            'Location permission denied. Please grant location access.';
        isLocationAvailable.value = false;
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        errorMessage.value =
            'Location permission permanently denied. Please enable in App Settings.';
        isLocationAvailable.value = false;
        return false;
      }

      // 3. Get initial position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      currentLocation.value = LatLng(position.latitude, position.longitude);
      // Update heading if available (valid heading is 0-360)
      if (position.heading >= 0 && position.heading <= 360) {
        currentHeading.value = position.heading;
      }
      errorMessage.value = null;
      isLocationAvailable.value = true;

      // 4. Start listening to location updates
      _startLocationStream();

      return true;
    } catch (e) {
      if (kDebugMode) print('LocationService: Initialization error: $e');
      errorMessage.value = 'Error getting location: ${e.toString()}';
      isLocationAvailable.value = false;
      return false;
    }
  }

  /// Start continuous location updates
  static void _startLocationStream() {
    _positionSubscription?.cancel();

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // Update every 5 meters of movement
          ),
        ).listen(
          (Position position) {
            currentLocation.value = LatLng(
              position.latitude,
              position.longitude,
            );
            // Update heading for bike rotation (valid heading is 0-360)
            if (position.heading >= 0 && position.heading <= 360) {
              currentHeading.value = position.heading;
            }
            isLocationAvailable.value = true;
            errorMessage.value = null;
          },
          onError: (error) {
            if (kDebugMode) print('LocationService: Stream error: $error');
            errorMessage.value = 'Location stream error: $error';
          },
        );
  }

  /// Stop location tracking
  static void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Open device location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permission)
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Request user to enable location service via Android dialog
  /// Returns true if location service is enabled after the request
  static Future<bool> requestEnableLocationService() async {
    try {
      bool serviceEnabled = await isLocationServiceEnabled();
      if (serviceEnabled) return true;

      // Open location settings dialog to prompt user to enable location
      await Geolocator.openLocationSettings();

      // Wait a moment for user to potentially enable it
      await Future.delayed(const Duration(milliseconds: 500));

      // Check again
      serviceEnabled = await isLocationServiceEnabled();
      if (serviceEnabled) {
        errorMessage.value = null;
        // Try to initialize after enabling
        await initialize();
      }
      return serviceEnabled;
    } catch (e) {
      if (kDebugMode) print('LocationService: Error requesting enable: $e');
      return false;
    }
  }

  /// Check and ensure location is available, prompting user if needed
  /// This is the main method to call when user clicks "locate me" button
  static Future<bool> ensureLocationAvailable() async {
    try {
      // First check if service is enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Prompt user to enable location service
        return await requestEnableLocationService();
      }

      // Check permission
      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
      }

      if (permission == LocationPermission.denied) {
        errorMessage.value = 'Location permission denied.';
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        errorMessage.value =
            'Location permission permanently denied. Enable in Settings.';
        await openAppSettings();
        return false;
      }

      // If we have permission but no current location, initialize
      if (currentLocation.value == null) {
        return await initialize();
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('LocationService: ensureLocationAvailable error: $e');
      }
      return false;
    }
  }

  /// Dispose resources
  static void dispose() {
    stopTracking();
    currentLocation.value = null;
    currentHeading.value = 0;
    isLocationAvailable.value = false;
    errorMessage.value = null;
  }
}
