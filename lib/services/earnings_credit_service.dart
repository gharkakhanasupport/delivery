import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'wallet_service.dart';

/// Thin wrapper called from DeliveryNavigationScreen after verify_delivery_otp
/// succeeds. Reads delivery_orders row (earnings + payment method) and dispatches
/// to [WalletService.processDeliveryEarnings] which already has double-credit
/// guard via RPC `process_delivery_earnings`.
///
/// Returns credited rupee amount on success (for "+₹XX earned" toast), or null
/// on any failure. Never throws — UI should not block on earnings glitch.
class EarningsCreditService {
  static final _db = DatabaseService().primary;

  static bool _isCashOnDelivery(String? paymentMethod) {
    final method = paymentMethod?.trim().toLowerCase() ?? 'online';
    return method == 'cash' || method == 'cod' || method == 'cod_cash';
  }

  /// Credit delivery fee for a completed order.
  /// Safe to call more than once — RPC guards against double-credit.
  static Future<double?> creditForCompletedDelivery(String orderId) async {
    try {
      final row = await _db
          .from('delivery_orders')
          .select('agent_earnings, payment_method, total_amount')
          .eq('id', orderId)
          .maybeSingle();

      if (row == null) {
        debugPrint('[EarningsCredit] order $orderId not found');
        return null;
      }

      final earnings = ((row['agent_earnings'] as num?) ?? 0).toDouble();
      final paymentMethod =
          (row['payment_method'] as String?)?.toLowerCase() ?? 'online';
      final totalAmount = ((row['total_amount'] as num?) ?? 0).toDouble();
        final isCod = _isCashOnDelivery(paymentMethod);

      if (earnings <= 0) {
        debugPrint('[EarningsCredit] no agent_earnings set on $orderId');
        return null;
      }

      final ok = await WalletService.processDeliveryEarnings(
        orderId: orderId,
        deliveryFee: earnings,
        isCod: isCod,
        codAmount: isCod ? totalAmount : 0,
      );

      if (!ok) {
        debugPrint('[EarningsCredit] processDeliveryEarnings returned false');
        return null;
      }

      // Update profile total
      try {
        final agentId = _db.auth.currentUser?.id;
        if (agentId != null) {
          final profile = await _db
              .from('delivery_profiles')
              .select('total_earnings, total_deliveries')
              .eq('id', agentId)
              .maybeSingle();

          if (profile != null) {
            await _db
                .from('delivery_profiles')
                .update({
                  'total_earnings': ((profile['total_earnings'] as num?)?.toDouble() ?? 0) + earnings,
                  'total_deliveries': ((profile['total_deliveries'] as num?)?.toInt() ?? 0) + 1,
                })
                .eq('id', agentId);
          }
        }
      } catch (_) {}

      debugPrint('[EarningsCredit] credited ₹$earnings for $orderId');
      return earnings;
    } catch (e) {
      debugPrint('[EarningsCredit] failed for $orderId: $e');
      return null;
    }
  }
}
