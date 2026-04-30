/// Transaction type enum
enum TransactionType { credit, debit }

/// Transaction category enum
enum TransactionCategory {
  deliveryPay,
  tip,
  bonus,
  codCollection,
  codSettlement,
  withdrawal,
  penalty,
  adjustment,
}

/// Model representing a single wallet transaction
class WalletTransaction {
  final String id;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final String? description;
  final String? referenceId;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    this.referenceId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] == 'credit'
          ? TransactionType.credit
          : TransactionType.debit,
      category: _categoryFromString(json['category'] as String),
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static TransactionCategory _categoryFromString(String value) {
    switch (value) {
      case 'delivery_pay':
        return TransactionCategory.deliveryPay;
      case 'tip':
        return TransactionCategory.tip;
      case 'bonus':
        return TransactionCategory.bonus;
      case 'cod_collection':
        return TransactionCategory.codCollection;
      case 'cod_settlement':
        return TransactionCategory.codSettlement;
      case 'withdrawal':
        return TransactionCategory.withdrawal;
      case 'penalty':
        return TransactionCategory.penalty;
      case 'adjustment':
        return TransactionCategory.adjustment;
      default:
        return TransactionCategory.adjustment;
    }
  }

  /// Get display label for category
  String get categoryLabel {
    switch (category) {
      case TransactionCategory.deliveryPay:
        return 'Delivery Pay';
      case TransactionCategory.tip:
        return 'Tip';
      case TransactionCategory.bonus:
        return 'Bonus';
      case TransactionCategory.codCollection:
        return 'Cash Collected';
      case TransactionCategory.codSettlement:
        return 'Cash Settled';
      case TransactionCategory.withdrawal:
        return 'Withdrawal';
      case TransactionCategory.penalty:
        return 'Penalty';
      case TransactionCategory.adjustment:
        return 'Adjustment';
    }
  }

  /// Whether this transaction adds money (positive)
  bool get isPositive => type == TransactionType.credit;
}

/// Model representing daily earnings data
class DailyEarnings {
  final String day;
  final double amount;

  DailyEarnings({required this.day, required this.amount});
}

/// Model representing earnings statistics
class EarningsData {
  final double totalWeekly;
  final int totalDeliveries;
  final double averagePerDelivery;
  final double totalHours;
  final List<DailyEarnings> weeklyBreakdown;
  final double currentBalance;
  final double cashOnHand;
  final double earningsToday;
  final List<WalletTransaction> recentTransactions;

  EarningsData({
    required this.totalWeekly,
    required this.totalDeliveries,
    required this.averagePerDelivery,
    required this.totalHours,
    required this.weeklyBreakdown,
    this.currentBalance = 0.0,
    this.cashOnHand = 0.0,
    this.earningsToday = 0.0,
    this.recentTransactions = const [],
  });

  // Factory from DB aggregation
  factory EarningsData.fromMap(Map<String, dynamic> map) {
    return EarningsData(
      totalWeekly: (map['total_weekly'] as num?)?.toDouble() ?? 0.0,
      totalDeliveries: (map['total_deliveries'] as num?)?.toInt() ?? 0,
      averagePerDelivery: (map['avg_per_delivery'] as num?)?.toDouble() ?? 0.0,
      totalHours: (map['total_hours'] as num?)?.toDouble() ?? 0.0,
      weeklyBreakdown: [], // Populate separately
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
      cashOnHand: (map['cash_on_hand'] as num?)?.toDouble() ?? 0.0,
      earningsToday: (map['earnings_today'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static EarningsData empty() {
    return EarningsData(
      totalWeekly: 0,
      totalDeliveries: 0,
      averagePerDelivery: 0,
      totalHours: 0,
      weeklyBreakdown: [],
      currentBalance: 0,
      cashOnHand: 0,
      earningsToday: 0,
      recentTransactions: [],
    );
  }
}

