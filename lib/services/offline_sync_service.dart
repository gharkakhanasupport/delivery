import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_service.dart';
import 'wallet_service.dart';
import '../models/order.dart';

/// Service to handle offline mode operations ("Elevator Mode")
/// Caches critical actions when network drops and syncs them when it returns.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queueKey = 'offline_action_queue';
  final Connectivity _connectivity = Connectivity();
  bool _isSyncing = false;

  /// Initialize the listener
  Future<void> initialize() async {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || 
          results.contains(ConnectivityResult.wifi)) {
        _syncQueue();
      }
    });

    // Check on startup
    final initial = await _connectivity.checkConnectivity();
    if (initial.contains(ConnectivityResult.mobile) || 
        initial.contains(ConnectivityResult.wifi)) {
      _syncQueue();
    }
  }

  /// Queue an order status update & earnings credit if offline
  Future<void> queueDeliveryCompletion({
    required String orderId,
    required double deliveryFee,
    required bool isCod,
    required double codAmount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];

    final action = {
      'type': 'delivery_completion',
      'orderId': orderId,
      'deliveryFee': deliveryFee,
      'isCod': isCod,
      'codAmount': codAmount,
      'timestamp': DateTime.now().toIso8601String(),
    };

    queue.add(jsonEncode(action));
    await prefs.setStringList(_queueKey, queue);
    debugPrint('📶 [OfflineSync] Queued delivery completion for $orderId (Elevator Mode Active)');
  }

  /// Process the queue when network is back
  Future<void> _syncQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(_queueKey) ?? [];
      
      if (queue.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('📶 [OfflineSync] Network restored! Syncing ${queue.length} offline actions...');

      List<String> remainingQueue = [];

      for (String item in queue) {
        final action = jsonDecode(item);
        bool success = false;

        try {
          if (action['type'] == 'delivery_completion') {
            // 1. Update Order Status
            await OrderService.updateOrderStatus(action['orderId'], OrderStatus.delivered);
            
            // 2. Process Earnings
            await WalletService.processDeliveryEarnings(
              orderId: action['orderId'],
              deliveryFee: action['deliveryFee'],
              isCod: action['isCod'],
              codAmount: action['codAmount'],
            );
            success = true;
            debugPrint('📶 [OfflineSync] Successfully synced delivery ${action['orderId']}');
          }
        } catch (e) {
          debugPrint('📶 [OfflineSync] Failed to sync action: $e');
          success = false; // Keep in queue if it failed (maybe server is down)
        }

        if (!success) {
          remainingQueue.add(item);
        }
      }

      await prefs.setStringList(_queueKey, remainingQueue);
      
      if (remainingQueue.isEmpty) {
        debugPrint('📶 [OfflineSync] Queue cleared successfully.');
      }

    } finally {
      _isSyncing = false;
    }
  }

  /// Check if we are currently offline
  static Future<bool> isOffline() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.none) || results.isEmpty;
  }
}
