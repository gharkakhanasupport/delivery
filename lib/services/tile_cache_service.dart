import 'package:flutter/foundation.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

/// Service for managing offline map tile caching
class TileCacheService {
  static const String _storeName = 'gkkDeliveryMapStore';
  static bool _isInitialized = false;
  static FMTCStore? _store;

  /// Initialize the tile caching system
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize FMTC backend
      await FMTCObjectBoxBackend().initialise();

      // Create or get the store
      _store = FMTCStore(_storeName);

      // Create the store if it doesn't exist
      await _store!.manage.create();

      _isInitialized = true;
      if (kDebugMode) print('TileCacheService: Initialized successfully');
    } catch (e) {
      if (kDebugMode) print('TileCacheService: Initialization error: $e');
    }
  }

  /// Get the tile provider for cached tiles
  static FMTCTileProvider? getTileProvider() {
    if (!_isInitialized || _store == null) return null;
    return FMTCTileProvider(stores: {_storeName: null});
  }

  /// Get the store for advanced operations
  static FMTCStore? get store => _store;

  /// Check if caching is ready
  static bool get isReady => _isInitialized && _store != null;

  /// Get cache statistics
  static Future<Map<String, dynamic>> getStats() async {
    if (!isReady) return {'status': 'not_initialized'};

    try {
      final stats = await _store!.stats.all;
      return {
        'status': 'ready',
        'tileCount': stats.length,
        'size': stats.size,
        'sizeFormatted': _formatBytes(stats.size.round()),
      };
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Clear all cached tiles
  static Future<void> clearCache() async {
    if (!isReady) return;

    try {
      await _store!.manage.reset();
      if (kDebugMode) print('TileCacheService: Cache cleared');
    } catch (e) {
      if (kDebugMode) print('TileCacheService: Error clearing cache: $e');
    }
  }

  /// Format bytes to human readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
