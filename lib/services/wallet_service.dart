import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

/// Agent Wallet data model
class AgentWallet {
  final double balance;
  final double earningsToday;
  final double cashOnHand;
  final double totalEarnings;
  final double totalWithdrawn;

  const AgentWallet({
    this.balance = 0,
    this.earningsToday = 0,
    this.cashOnHand = 0,
    this.totalEarnings = 0,
    this.totalWithdrawn = 0,
  });

  static AgentWallet empty() => const AgentWallet();
}

/// WalletService — Manages agent wallet, COD tracking, and earnings.
///
/// Uses the unified wallet architecture:
/// - `agent_wallets` table for quick reads (balance, COD, today's earnings)
/// - `wallet_transactions` ledger for audit trail
/// - Atomic RPCs to prevent double-spending/double-crediting
class WalletService {
  static final SupabaseClient _client = DatabaseService().primary;

  // ===========================================================================
  // WALLET STATE
  // ===========================================================================

  /// Fetch the agent's current wallet state
  static Future<AgentWallet> getWallet() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return AgentWallet.empty();

    try {
      // Try using the get_agent_wallet RPC (most efficient)
      final rpcResult = await _client.rpc(
        'get_agent_wallet',
        params: {'p_agent_id': userId},
      );

      if (rpcResult != null && (rpcResult as List).isNotEmpty) {
        final row = rpcResult[0];
        return AgentWallet(
          balance: (row['balance'] as num?)?.toDouble() ?? 0,
          earningsToday: (row['earnings_today'] as num?)?.toDouble() ?? 0,
          cashOnHand: (row['cash_on_hand'] as num?)?.toDouble() ?? 0,
          totalEarnings: (row['total_earnings'] as num?)?.toDouble() ?? 0,
          totalWithdrawn: (row['total_withdrawn'] as num?)?.toDouble() ?? 0,
        );
      }

      return await _getWalletFallback(userId);
    } catch (e) {
      debugPrint('[WalletService] RPC get_agent_wallet failed: $e');
      return await _getWalletFallback(userId);
    }
  }

  /// Fallback: Read directly from agent_wallets table
  static Future<AgentWallet> _getWalletFallback(String userId) async {
    try {
      final row = await _client
          .from('agent_wallets')
          .select('*')
          .eq('agent_id', userId)
          .maybeSingle();

      if (row == null) return AgentWallet.empty();

      // Calculate balance from ledger
      final balance = await _calculateLedgerBalance(userId);

      return AgentWallet(
        balance: balance,
        earningsToday: (row['earnings_today'] as num?)?.toDouble() ?? 0,
        cashOnHand: (row['cash_on_hand'] as num?)?.toDouble() ?? 0,
        totalEarnings: (row['total_earnings'] as num?)?.toDouble() ?? 0,
        totalWithdrawn: (row['total_withdrawn'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('[WalletService] Wallet fallback failed: $e');
      return AgentWallet.empty();
    }
  }

  /// Calculate balance from wallet_transactions ledger (source of truth)
  static Future<double> _calculateLedgerBalance(String userId) async {
    try {
      final transactions = await _client
          .from('wallet_transactions')
          .select('amount, type')
          .eq('agent_id', userId);

      double balance = 0;
      for (var tx in transactions) {
        final amount = (tx['amount'] as num).toDouble();
        if (tx['type'] == 'credit') {
          balance += amount;
        } else {
          balance -= amount;
        }
      }
      return balance;
    } catch (e) {
      debugPrint('[WalletService] Ledger calc failed: $e');
      return 0;
    }
  }

  // ===========================================================================
  // DELIVERY EARNINGS (Called when a delivery is completed)
  // ===========================================================================

  /// Process delivery earnings — atomic operation via RPC
  /// Prevents double-crediting for the same order.
  static Future<bool> processDeliveryEarnings({
    required String orderId,
    required double deliveryFee,
    bool isCod = false,
    double codAmount = 0,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      // Use the atomic RPC function
      await _client.rpc('process_delivery_earnings', params: {
        'p_agent_id': userId,
        'p_order_id': orderId,
        'p_delivery_fee': deliveryFee,
        'p_is_cod': isCod,
        'p_cod_amount': codAmount,
      });

      debugPrint('[WalletService] Earnings processed: ₹$deliveryFee for order $orderId');
      return true;
    } catch (e) {
      debugPrint('[WalletService] RPC process_delivery_earnings failed: $e');
      // Fallback: manual insert (less safe but ensures earnings aren't lost)
      return _processEarningsManually(
        userId: userId,
        orderId: orderId,
        deliveryFee: deliveryFee,
        isCod: isCod,
        codAmount: codAmount,
      );
    }
  }

  /// Manual fallback for earnings processing
  static Future<bool> _processEarningsManually({
    required String userId,
    required String orderId,
    required double deliveryFee,
    required bool isCod,
    required double codAmount,
  }) async {
    try {
      // Check for duplicate
      final existing = await _client
          .from('wallet_transactions')
          .select('id')
          .eq('agent_id', userId)
          .eq('order_id', orderId)
          .eq('category', 'delivery_pay')
          .maybeSingle();

      if (existing != null) {
        debugPrint('[WalletService] Duplicate prevented for order $orderId');
        return true; // Already processed
      }

      // Credit delivery fee
      await _client.from('wallet_transactions').insert({
        'agent_id': userId,
        'amount': deliveryFee,
        'type': 'credit',
        'category': 'delivery_pay',
        'description': 'Delivery completed',
        'order_id': orderId,
        'reference_id': orderId,
      });

      // COD tracking
      if (isCod && codAmount > 0) {
        await _client.from('wallet_transactions').insert({
          'agent_id': userId,
          'amount': codAmount,
          'type': 'debit',
          'category': 'cod_collection',
          'description': 'COD cash collected from customer',
          'order_id': orderId,
          'reference_id': orderId,
        });
      }

      // Update agent_wallets — READ existing values first, then INCREMENT
      final existingWallet = await _client
          .from('agent_wallets')
          .select('earnings_today, cash_on_hand, total_earnings')
          .eq('agent_id', userId)
          .maybeSingle();

      final prevEarningsToday = (existingWallet?['earnings_today'] as num?)?.toDouble() ?? 0;
      final prevCashOnHand = (existingWallet?['cash_on_hand'] as num?)?.toDouble() ?? 0;
      final prevTotalEarnings = (existingWallet?['total_earnings'] as num?)?.toDouble() ?? 0;

      await _client.from('agent_wallets').upsert({
        'agent_id': userId,
        'earnings_today': prevEarningsToday + deliveryFee,
        'cash_on_hand': prevCashOnHand + (isCod ? codAmount : 0),
        'total_earnings': prevTotalEarnings + deliveryFee,
      }, onConflict: 'agent_id');

      // Legacy: agent_earnings
      await _client.from('agent_earnings').insert({
        'agent_id': userId,
        'order_id': orderId,
        'amount': deliveryFee,
        'earning_type': 'delivery',
      });

      return true;
    } catch (e) {
      debugPrint('[WalletService] Manual earnings failed: $e');
      return false;
    }
  }

  // ===========================================================================
  // COD OPERATIONS
  // ===========================================================================

  /// Get current cash on hand (COD money agent has collected)
  static Future<double> getCashOnHand() async {
    final wallet = await getWallet();
    return wallet.cashOnHand;
  }

  /// Settle COD cash (called after successful payment)
  static Future<bool> settleCodCash({
    required double amount,
    String? reference,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _client.rpc('settle_cod_cash', params: {
        'p_agent_id': userId,
        'p_amount': amount,
        'p_reference': reference,
      });
      return true;
    } catch (e) {
      debugPrint('[WalletService] settleCodCash failed: $e');
      return false;
    }
  }

  // ===========================================================================
  // WITHDRAWALS
  // ===========================================================================

  /// Request a withdrawal from available balance
  static Future<bool> requestWithdrawal(
    double amount,
    Map<String, dynamic> bankDetails,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final wallet = await getWallet();
      if (wallet.balance < amount) {
        throw 'Insufficient balance. Available: ₹${wallet.balance.toStringAsFixed(2)}';
      }

      // Create withdrawal request
      await _client.from('withdrawal_requests').insert({
        'agent_id': userId,
        'amount': amount,
        'bank_details': bankDetails,
        'status': 'pending',
      });

      return true;
    } catch (e) {
      debugPrint('[WalletService] Withdrawal error: $e');
      return false;
    }
  }

  // ===========================================================================
  // REALTIME SUBSCRIPTION
  // ===========================================================================

  /// Subscribe to wallet changes (agent_wallets + wallet_transactions)
  static RealtimeChannel subscribeToWalletUpdates(
    void Function() onUpdate,
  ) {
    final userId = _client.auth.currentUser?.id;

    return _client
        .channel('agent-wallet-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'agent_wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'agent_id',
            value: userId,
          ),
          callback: (_) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'wallet_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'agent_id',
            value: userId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}
