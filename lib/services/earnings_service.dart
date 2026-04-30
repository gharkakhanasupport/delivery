import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/earnings_data.dart';
import 'database_service.dart';
import 'wallet_service.dart';

/// Service for agent earnings, wallet balance, and withdrawal management.
///
/// Unified Wallet Architecture:
/// - `agent_wallets` — fast read for today's earnings, COD cash, totals
/// - `wallet_transactions` — immutable ledger (source of truth)
/// - `WalletService` — atomic operations (process earnings, settlements)
class EarningsService {
  static final SupabaseClient _client = DatabaseService().primary;

  /// Fetch weekly earnings statistics from wallet_transactions + agent_wallets
  static Future<EarningsData> fetchWeeklyStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return EarningsData.empty();

    try {
      final now = DateTime.now();
      // Start of week (Monday)
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));

      // Fetch credit transactions for the week
      final transactionsResponse = await _client
          .from('wallet_transactions')
          .select('amount, type, category, created_at')
          .eq('agent_id', userId)
          .eq('type', 'credit')
          .gte('created_at', startOfWeek.toIso8601String());

      double totalWeekly = 0;
      int totalDeliveries = 0;
      Map<String, double> dailyMap = {};

      // Initialize daily map
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var day in days) {
        dailyMap[day] = 0;
      }

      for (var record in transactionsResponse) {
        final amount = (record['amount'] as num).toDouble();
        totalWeekly += amount;

        // Count deliveries (only for delivery_pay category)
        if (record['category'] == 'delivery_pay') {
          totalDeliveries++;
        }

        final date = DateTime.parse(record['created_at']);
        final dayName = days[date.weekday - 1]; // weekday 1 = Mon
        dailyMap[dayName] = (dailyMap[dayName] ?? 0) + amount;
      }

      // Convert daily map to list
      final weeklyBreakdown = days
          .map((day) => DailyEarnings(day: day, amount: dailyMap[day]!))
          .toList();

      // Estimate hours: ~30 mins per delivery on avg
      final totalHours = totalDeliveries * 0.5;

      // Get wallet state (balance + COD + today)
      final wallet = await WalletService.getWallet();

      // Get recent transactions
      final recentTransactions = await getRecentTransactions(limit: 10);

      return EarningsData(
        totalWeekly: totalWeekly,
        totalDeliveries: totalDeliveries,
        averagePerDelivery: totalDeliveries > 0
            ? totalWeekly / totalDeliveries
            : 0,
        totalHours: totalHours,
        weeklyBreakdown: weeklyBreakdown,
        currentBalance: wallet.balance,
        cashOnHand: wallet.cashOnHand,
        earningsToday: wallet.earningsToday,
        recentTransactions: recentTransactions,
      );
    } catch (e) {
      debugPrint('[EarningsService] Error fetching weekly: $e');
      // Fallback: try agent_earnings table
      return _fetchFromAgentEarnings();
    }
  }

  /// Fallback: fetch from agent_earnings table (simpler structure)
  static Future<EarningsData> _fetchFromAgentEarnings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return EarningsData.empty();

    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      final response = await _client
          .from('agent_earnings')
          .select('amount, created_at')
          .eq('agent_id', userId)
          .gte('created_at', startOfWeek.toIso8601String());

      double totalWeekly = 0;
      int totalDeliveries = 0;
      Map<String, double> dailyMap = {};

      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var day in days) {
        dailyMap[day] = 0;
      }

      for (var record in response) {
        final amount = (record['amount'] as num).toDouble();
        totalWeekly += amount;
        totalDeliveries++;

        final date = DateTime.parse(record['created_at']);
        final dayName = days[date.weekday - 1];
        dailyMap[dayName] = (dailyMap[dayName] ?? 0) + amount;
      }

      final weeklyBreakdown = days
          .map((day) => DailyEarnings(day: day, amount: dailyMap[day]!))
          .toList();

      return EarningsData(
        totalWeekly: totalWeekly,
        totalDeliveries: totalDeliveries,
        averagePerDelivery: totalDeliveries > 0
            ? totalWeekly / totalDeliveries
            : 0,
        totalHours: totalDeliveries * 0.5,
        weeklyBreakdown: weeklyBreakdown,
      );
    } catch (e) {
      debugPrint('[EarningsService] Agent earnings fallback failed: $e');
      return EarningsData.empty();
    }
  }

  /// Get recent wallet transactions
  static Future<List<WalletTransaction>> getRecentTransactions({
    int limit = 20,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('wallet_transactions')
          .select('*')
          .eq('agent_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => WalletTransaction.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[EarningsService] Error fetching transactions: $e');
      return [];
    }
  }

  /// Get current balance — delegates to WalletService
  static Future<double> getCurrentBalance() async {
    final wallet = await WalletService.getWallet();
    return wallet.balance;
  }

  /// Get today's earnings from agent_wallets (fast read)
  static Future<double> getTodayEarnings() async {
    final wallet = await WalletService.getWallet();
    return wallet.earningsToday;
  }

  /// Get COD cash on hand
  static Future<double> getCashOnHand() async {
    final wallet = await WalletService.getWallet();
    return wallet.cashOnHand;
  }

  /// Request a withdrawal — delegates to WalletService
  static Future<bool> requestWithdrawal(
    double amount,
    Map<String, dynamic> bankDetails,
  ) async {
    return WalletService.requestWithdrawal(amount, bankDetails);
  }

  /// Get last week's total earnings for trend calculation
  static Future<double> getLastWeekTotal() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final now = DateTime.now();
      // Start of current week (Monday)
      final startOfThisWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      // Previous week range
      final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));

      final response = await _client
          .from('wallet_transactions')
          .select('amount')
          .eq('agent_id', userId)
          .eq('type', 'credit')
          .gte('created_at', startOfLastWeek.toIso8601String())
          .lt('created_at', startOfThisWeek.toIso8601String());

      double total = 0;
      for (var r in response) {
        total += (r['amount'] as num).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('[EarningsService] getLastWeekTotal error: $e');
      return 0;
    }
  }

  /// Get category-wise earnings breakdown for the current week
  static Future<Map<String, double>> getCategoryBreakdown() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    try {
      final now = DateTime.now();
      final startOfWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));

      final response = await _client
          .from('wallet_transactions')
          .select('amount, category')
          .eq('agent_id', userId)
          .eq('type', 'credit')
          .gte('created_at', startOfWeek.toIso8601String());

      final Map<String, double> breakdown = {};
      for (var r in response) {
        final cat = r['category'] as String? ?? 'other';
        final amt = (r['amount'] as num).toDouble();
        breakdown[cat] = (breakdown[cat] ?? 0) + amt;
      }
      return breakdown;
    } catch (e) {
      debugPrint('[EarningsService] getCategoryBreakdown error: $e');
      return {};
    }
  }
}
