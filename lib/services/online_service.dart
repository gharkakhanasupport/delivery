import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

/// Service for managing driver online/offline status
/// Uses Geolocator position STREAM to avoid hanging on GPS acquisition.
/// All DB calls have strict timeouts so the UI never freezes.
class OnlineService {
  static final SupabaseClient _client = DatabaseService().primary;

  /// Observable online status
  static final ValueNotifier<bool> isOnline = ValueNotifier(false);

  /// Active position stream subscription (only running when online)
  static StreamSubscription<Position>? _positionStreamSub;

  /// Timer for periodic heartbeat when stream provides no updates
  static Timer? _heartbeatTimer;

  /// Last known position (cached to avoid blocking calls)
  static Position? _lastPosition;

  // ─────────────────────────────────────────────────────
  // GO ONLINE
  // ─────────────────────────────────────────────────────

  /// Go online - update DB and start continuous location streaming.
  /// This will NEVER hang — geolocation is done via a stream,
  /// and the DB upsert has a strict 5-second timeout.
  static Future<void> goOnline() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Immediately flip the local flag so UI reacts instantly
    isOnline.value = true;

    try {
      // Try to get a quick initial position (non-blocking, 5s max)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        ).timeout(
          const Duration(seconds: 6),
          onTimeout: () => throw TimeoutException('GPS timeout'),
        );
        _lastPosition = position;
      } catch (e) {
        debugPrint('[OnlineService] Initial position unavailable: $e');
        // Use last known position if available
        try {
          position = await Geolocator.getLastKnownPosition();
          _lastPosition = position;
        } catch (_) {}
      }

      // Upsert agent_locations with whatever position we have
      await _upsertLocation(userId, position, true);
    } catch (e) {
      debugPrint('[OnlineService] Error during goOnline: $e');
      // Online is already set, DB will catch up on next heartbeat
    }

    // Start streaming location updates
    _startLocationStream(userId);

    // Start heartbeat timer (sync every 30s even if position doesn't change)
    _startHeartbeat(userId);
  }

  // ─────────────────────────────────────────────────────
  // GO OFFLINE
  // ─────────────────────────────────────────────────────

  /// Go offline - stop all streams, cancel timers, update DB
  static Future<void> goOffline() async {
    // Stop streams first
    _stopLocationStream();
    _stopHeartbeat();

    final userId = _client.auth.currentUser?.id;
    isOnline.value = false;

    if (userId == null) return;

    try {
      await _client
          .from('agent_locations')
          .upsert({
            'agent_id': userId,
            'is_online': false,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'agent_id')
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[OnlineService] Error going offline: $e');
    }
  }

  // ─────────────────────────────────────────────────────
  // LOCATION STREAM (Continuous — no hanging)
  // ─────────────────────────────────────────────────────

  /// Start listening to the device GPS stream.
  /// Each position update is forwarded to Supabase without blocking the UI.
  static void _startLocationStream(String userId) {
    _stopLocationStream(); // Ensure no duplicate subscription

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,  // Only report every 20m of movement
    );

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _lastPosition = position;
        // Fire-and-forget: don't await this, it runs in the background
        _upsertLocation(userId, position, true).catchError((e) {
          debugPrint('[OnlineService] Stream upsert error: $e');
        });
      },
      onError: (error) {
        debugPrint('[OnlineService] Position stream error: $error');
      },
    );
  }

  /// Stop listening to the device GPS stream
  static void _stopLocationStream() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }

  // ─────────────────────────────────────────────────────
  // HEARTBEAT TIMER
  // ─────────────────────────────────────────────────────

  /// Periodic sync to keep the agent "alive" in the DB even if
  /// they are stationary and the GPS stream emits nothing.
  static void _startHeartbeat(String userId) {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (!isOnline.value) return;
        try {
          await _upsertLocation(userId, _lastPosition, true);
        } catch (e) {
          debugPrint('[OnlineService] Heartbeat error: $e');
        }
      },
    );
  }

  static void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ─────────────────────────────────────────────────────
  // DB HELPER (always has a timeout)
  // ─────────────────────────────────────────────────────

  /// Upsert location with a strict 5-second timeout on the DB call.
  static Future<void> _upsertLocation(
    String userId,
    Position? position,
    bool online,
  ) async {
    final data = <String, dynamic>{
      'agent_id': userId,
      'is_online': online,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (position != null) {
      data['latitude'] = position.latitude;
      data['longitude'] = position.longitude;
      data['heading'] = position.heading;
      data['speed'] = position.speed;
    }

    await _client
        .from('agent_locations')
        .upsert(data, onConflict: 'agent_id')
        .timeout(const Duration(seconds: 5));
  }

  // ─────────────────────────────────────────────────────
  // RESTORE STATUS (on app startup / auth restore)
  // ─────────────────────────────────────────────────────

  /// Restore online status from DB (call on app startup after auth)
  static Future<void> restoreStatus() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _client
          .from('agent_locations')
          .select('is_online')
          .eq('agent_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (response != null && response['is_online'] == true) {
        isOnline.value = true;
        // Resume streaming if they were online
        _startLocationStream(userId);
        _startHeartbeat(userId);
      }
    } catch (e) {
      debugPrint('[OnlineService] Error restoring status: $e');
    }
  }

  /// Call this when the agent logs out or auth session expires
  static Future<void> dispose() async {
    _stopLocationStream();
    _stopHeartbeat();
    isOnline.value = false;
  }
}
