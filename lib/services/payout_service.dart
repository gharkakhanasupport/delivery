import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads payout_requests for current delivery agent.
class PayoutService {
  final SupabaseClient _db = Supabase.instance.client;

  String? get _agentId => _db.auth.currentUser?.id;

  /// Stream payouts (newest first).
  Stream<List<Map<String, dynamic>>> streamMyPayouts() {
    final id = _agentId;
    if (id == null) return const Stream.empty();
    return _db
        .from('payout_requests')
        .stream(primaryKey: ['id'])
        .eq('agent_id', id)
        .order('created_at', ascending: false);
  }

  /// One-shot fetch.
  Future<List<Map<String, dynamic>>> listMyPayouts({int limit = 30}) async {
    final id = _agentId;
    if (id == null) return [];
    try {
      final rows = await _db
          .from('payout_requests')
          .select()
          .eq('agent_id', id)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('[PayoutService] listMyPayouts: $e');
      return [];
    }
  }

  /// Toggle auto-payout preference.
  Future<bool> setAutoPayoutEnabled(bool enabled) async {
    final id = _agentId;
    if (id == null) return false;
    try {
      await _db
          .from('delivery_profiles')
          .update({'auto_payout_enabled': enabled})
          .eq('agent_id', id);
      return true;
    } catch (e) {
      debugPrint('[PayoutService] setAutoPayoutEnabled: $e');
      return false;
    }
  }

  /// Read current auto-payout flag.
  Future<bool> isAutoPayoutEnabled() async {
    final id = _agentId;
    if (id == null) return false;
    try {
      final row = await _db
          .from('delivery_profiles')
          .select('auto_payout_enabled')
          .eq('agent_id', id)
          .maybeSingle();
      return (row?['auto_payout_enabled'] as bool?) ?? true;
    } catch (e) {
      debugPrint('[PayoutService] isAutoPayoutEnabled: $e');
      return true;
    }
  }
}
