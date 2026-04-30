import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../models/earnings_data.dart';
import '../services/earnings_service.dart';
import '../services/wallet_service.dart';
import '../services/delivery_agent_service.dart';
import '../services/payment_service.dart';
import '../utils/app_dialogs.dart';
import '../widgets/shimmer_loading.dart';
import 'payout_history_screen.dart';

/// Earnings Dashboard — premium card-based layout with realtime updates
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  EarningsData _earningsData = EarningsData.empty();
  double _currentBalance = 0.0;
  bool _isLoading = true;
  late TabController _tabController;

  // Real stats
  double _rating = 0.0;
  double _lastWeekTotal = 0.0;
  Map<String, double> _categoryBreakdown = {};

  /// Supabase realtime channel for wallet_transactions
  RealtimeChannel? _walletChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializePayment();
    _loadData();
    _subscribeToWalletUpdates();
  }

  void _initializePayment() {
    PaymentService().initialize(
      onSuccess: _onPaymentSuccess,
      onFailure: _onPaymentFailure,
    );
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    // Settle cash in DB
    final success = await WalletService.settleCodCash(
      amount: _earningsData.cashOnHand,
      reference: response.paymentId,
    );
    
    if (success && mounted) {
      AppDialogs.showSuccess(context, 'Cash settled successfully!');
      _loadData();
    }
  }

  void _onPaymentFailure(PaymentFailureResponse response) {
    if (mounted) {
      AppDialogs.showError(context, 'Payment failed: ${response.message}');
    }
  }

  @override
  void dispose() {
    PaymentService().dispose();
    _walletChannel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  /// Subscribe to realtime wallet updates (agent_wallets + wallet_transactions)
  void _subscribeToWalletUpdates() {
    _walletChannel = WalletService.subscribeToWalletUpdates(() {
      // Any wallet change — refresh everything
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await EarningsService.fetchWeeklyStats();
    final balance = await EarningsService.getCurrentBalance();
    final stats = await DeliveryAgentService.getDeliveryStats();
    final lastWeek = await EarningsService.getLastWeekTotal();
    final breakdown = await EarningsService.getCategoryBreakdown();
    if (mounted) {
      setState(() {
        _earningsData = data;
        _currentBalance = balance;
        _rating = (stats['rating'] as num?)?.toDouble() ?? 0;
        _lastWeekTotal = lastWeek;
        _categoryBreakdown = breakdown;
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
      body: _isLoading
          ? _buildShimmerLoading()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.emeraldGreen,
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppConstants.responsivePadding(context),
                          12,
                          AppConstants.responsivePadding(context),
                          4,
                        ),
                        child: Text(
                          'Earnings',
                          style: AppTypography.headingStyle(
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Balance Card
                  SliverToBoxAdapter(child: _buildBalanceCard(isDark)),

                  // Quick Stats
                  SliverToBoxAdapter(child: _buildQuickStats(isDark)),

                  // Period Tabs
                  SliverToBoxAdapter(child: _buildPeriodTabs(isDark)),

                  // Earnings Breakdown
                  SliverToBoxAdapter(child: _buildEarningsBreakdown(isDark)),

                  // Weekly Chart
                  SliverToBoxAdapter(child: _buildWeeklyChart(isDark)),

                  // Recent Activity Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppConstants.responsivePadding(context),
                        24,
                        AppConstants.responsivePadding(context),
                        8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activity',
                            style: AppTypography.titleStyle(
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'See All',
                              style: AppTypography.captionStyle(
                                color: AppColors.emeraldGreen,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Transaction List
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppConstants.responsivePadding(context),
                      0,
                      AppConstants.responsivePadding(context),
                      MediaQuery.of(context).padding.bottom + 100,
                    ),
                    sliver: _earningsData.recentTransactions.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 44,
                                      color: isDark
                                          ? AppColors.textLightSecondary
                                              .withValues(alpha: 0.3)
                                          : AppColors.mediumGrey
                                              .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No recent transactions',
                                      style: AppTypography.bodyStyle(
                                        color: isDark
                                            ? AppColors.textLightSecondary
                                            : AppColors.textSecondary,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final tx =
                                    _earningsData.recentTransactions[index];
                                return _buildTransactionItem(tx, isDark);
                              },
                              childCount:
                                  _earningsData.recentTransactions.length,
                            ),
                          ),
                  ),
                ],
              ),
            ),
      // Floating Withdraw Button
      floatingActionButton: _isLoading
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'payouts_fab',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()),
                  ),
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.emeraldGreen,
                  elevation: 2,
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: Text(
                    'Payouts',
                    style: AppTypography.bodyStyle(
                      color: AppColors.emeraldGreen,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'withdraw_fab',
                  onPressed: _showWithdrawSheet,
                  backgroundColor: AppColors.emeraldGreen,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 20),
                  label: Text(
                    'Withdraw',
                    style: AppTypography.bodyStyle(
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildShimmerLoading() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ShimmerLoading.card(height: 160),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ShimmerLoading.card(height: 100)),
              const SizedBox(width: 10),
              Expanded(child: ShimmerLoading.card(height: 100)),
              const SizedBox(width: 10),
              Expanded(child: ShimmerLoading.card(height: 100)),
            ],
          ),
          const SizedBox(height: 12),
          ShimmerLoading.card(height: 200),
          const SizedBox(height: 12),
          ShimmerLoading.card(height: 120),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppConstants.responsivePadding(context),
        vertical: 8,
      ),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.earningsGradient,
        ),
        borderRadius: AppConstants.borderRadiusXL,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Balance',
                style: AppTypography.bodyStyle(
                  color: Colors.white70,
                  size: 13,
                  weight: FontWeight.w500,
                ),
              ),
              if (_earningsData.totalWeekly > 0 || _lastWeekTotal > 0)
                Builder(builder: (_) {
                  final pct = _lastWeekTotal > 0
                      ? ((_earningsData.totalWeekly - _lastWeekTotal) / _lastWeekTotal * 100)
                      : 0.0;
                  final isUp = pct >= 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isUp ? AppColors.emeraldGreen : Colors.redAccent).withValues(alpha: 0.2),
                      borderRadius: AppConstants.borderRadiusCircular,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: isUp ? AppColors.emeraldGreen : Colors.redAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isUp ? "+" : ""}${pct.toStringAsFixed(0)}%',
                          style: AppTypography.captionStyle(
                            color: isUp ? AppColors.emeraldGreen : Colors.redAccent,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '₹${_currentBalance.toStringAsFixed(2)}',
            style: AppTypography.headingStyle(
              color: Colors.white,
              size: 38,
            ).copyWith(letterSpacing: -1),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildBalanceMiniStat(
                'Today',
                '₹${_earningsData.earningsToday.toStringAsFixed(0)}',
              ),
              const SizedBox(width: 24),
              _buildBalanceMiniStat(
                'Deliveries',
                '${_earningsData.totalDeliveries}',
              ),
              if (_earningsData.cashOnHand > 0) ...[
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceMiniStat(
                      'COD Cash',
                      '₹${_earningsData.cashOnHand.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        final user = Supabase.instance.client.auth.currentUser;
                        PaymentService().startPayment(
                          amount: _earningsData.cashOnHand,
                          contact: user?.phone ?? '',
                          email: user?.email ?? '',
                          description: 'COD Cash Settlement',
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Settle Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.captionStyle(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodyStyle(
            color: Colors.white,
            weight: FontWeight.w700,
            size: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.responsivePadding(context),
        vertical: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.timer_outlined,
              label: 'Hours',
              value: '${_earningsData.totalHours.toStringAsFixed(1)}h',
              color: AppColors.accentBlue,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              icon: Icons.speed_rounded,
              label: 'Avg/Delivery',
              value:
                  '₹${_earningsData.averagePerDelivery.toStringAsFixed(0)}',
              color: AppColors.goldenMustard,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              icon: Icons.star_rounded,
              label: 'Rating',
              value: _rating > 0 ? _rating.toStringAsFixed(1) : 'New',
              color: AppColors.accentPurple,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppConstants.borderRadiusMedium,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.titleStyle(
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.captionStyle(
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.textSecondary,
            ).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs(bool isDark) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppConstants.responsivePadding(context),
        16,
        AppConstants.responsivePadding(context),
        4,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: AppConstants.borderRadiusMedium,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: AppConstants.borderRadiusSmall,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: isDark ? AppColors.textLight : AppColors.textPrimary,
        unselectedLabelColor:
            isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
        labelStyle: AppTypography.captionStyle(weight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Today'),
          Tab(text: 'This Week'),
          Tab(text: 'This Month'),
        ],
      ),
    );
  }

  Widget _buildEarningsBreakdown(bool isDark) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppConstants.responsivePadding(context),
        12,
        AppConstants.responsivePadding(context),
        0,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Breakdown',
            style: AppTypography.titleStyle(
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildBreakdownRow(
            'Delivery Fees',
            '₹${(_categoryBreakdown['delivery_pay'] ?? 0).toStringAsFixed(0)}',
            isDark,
          ),
          const SizedBox(height: 10),
          _buildBreakdownRow(
            'Tips',
            '₹${(_categoryBreakdown['tip'] ?? 0).toStringAsFixed(0)}',
            isDark,
          ),
          const SizedBox(height: 10),
          _buildBreakdownRow(
            'Bonuses',
            '₹${(_categoryBreakdown['bonus'] ?? 0).toStringAsFixed(0)}',
            isDark,
          ),
          const SizedBox(height: 10),
          _buildBreakdownRow(
            'Adjustments',
            '₹${(_categoryBreakdown['adjustment'] ?? 0).toStringAsFixed(0)}',
            isDark,
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTypography.bodyStyle(
                  color: isDark
                      ? AppColors.textLight
                      : AppColors.textPrimary,
                  weight: FontWeight.w600,
                ),
              ),
              Text(
                '₹${_earningsData.totalWeekly.toStringAsFixed(0)}',
                style: AppTypography.titleStyle(
                  color: AppColors.emeraldGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyStyle(
            color: isDark
                ? AppColors.textLightSecondary
                : AppColors.textSecondary,
            size: 14,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyStyle(
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
            weight: FontWeight.w600,
            size: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(bool isDark) {
    final days = _earningsData.weeklyBreakdown;
    final maxAmount = days.fold<double>(
      0,
      (max, day) => day.amount > max ? day.amount : max,
    );

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppConstants.responsivePadding(context),
        12,
        AppConstants.responsivePadding(context),
        0,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Overview',
            style: AppTypography.titleStyle(
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final heightRatio =
                    maxAmount > 0 ? day.amount / maxAmount : 0.0;
                final isToday = day.day == _getTodayShort();
                return _buildChartBar(day.day, heightRatio, isToday, isDark);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getTodayShort() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[DateTime.now().weekday - 1];
  }

  Widget _buildChartBar(
    String day,
    double heightRatio,
    bool isToday,
    bool isDark,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  height: heightRatio * 75 + 6,
                  decoration: BoxDecoration(
                    gradient: isToday
                        ? const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: AppColors.primaryGradient,
                          )
                        : null,
                    color: isToday
                        ? null
                        : (isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              day,
              style: AppTypography.captionStyle(
                color: isToday
                    ? AppColors.emeraldGreen
                    : (isDark
                        ? AppColors.textLightSecondary
                        : AppColors.textSecondary),
                weight: isToday ? FontWeight.w600 : FontWeight.w400,
              ).copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransaction tx, bool isDark) {
    IconData icon;
    Color color;

    switch (tx.category) {
      case TransactionCategory.deliveryPay:
        icon = Icons.delivery_dining;
        color = AppColors.emeraldGreen;
        break;
      case TransactionCategory.tip:
        icon = Icons.volunteer_activism;
        color = AppColors.goldenMustard;
        break;
      case TransactionCategory.bonus:
        icon = Icons.star_rounded;
        color = AppColors.accentPurple;
        break;
      case TransactionCategory.withdrawal:
        icon = Icons.account_balance_rounded;
        color = Colors.deepOrange;
        break;
      case TransactionCategory.penalty:
        icon = Icons.warning_rounded;
        color = Colors.red;
        break;
      case TransactionCategory.adjustment:
        icon = Icons.build_rounded;
        color = Colors.grey;
        break;
      case TransactionCategory.codCollection:
        icon = Icons.money;
        color = Colors.red;
        break;
      case TransactionCategory.codSettlement:
        icon = Icons.check_circle_rounded;
        color = AppColors.emeraldGreen;
        break;
    }

    final isPositive = tx.isPositive;
    final displayColor = isPositive ? AppColors.emeraldGreen : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppConstants.borderRadiusMedium,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.categoryLabel,
                  style: AppTypography.bodyStyle(
                    color: isDark
                        ? AppColors.textLight
                        : AppColors.textPrimary,
                    weight: FontWeight.w600,
                    size: 14,
                  ),
                ),
                if (tx.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    tx.description!,
                    style: AppTypography.captionStyle(
                      color: isDark
                          ? AppColors.textLightSecondary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : '-'}₹${tx.amount.toStringAsFixed(0)}',
                style: AppTypography.bodyStyle(
                  color: displayColor,
                  weight: FontWeight.w700,
                  size: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTime(tx.createdAt),
                style: AppTypography.captionStyle(
                  color: isDark
                      ? AppColors.textLightSecondary
                      : AppColors.textTertiary,
                ).copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  void _showWithdrawSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.mediumGrey.withValues(alpha: 0.3)
                    : AppColors.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Withdraw Funds',
                    style: AppTypography.headingStyle(
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Transfer your earnings to your bank account',
                    style: AppTypography.bodyStyle(
                      color: isDark
                          ? AppColors.textLightSecondary
                          : AppColors.textSecondary,
                      size: 14,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Available Balance
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.06),
                      borderRadius: AppConstants.borderRadiusLarge,
                      border: Border.all(
                        color:
                            AppColors.emeraldGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Balance',
                          style: AppTypography.bodyStyle(
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textSecondary,
                            size: 14,
                          ),
                        ),
                        Text(
                          '₹${_currentBalance.toStringAsFixed(2)}',
                          style: AppTypography.titleStyle(
                            color: AppColors.emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount Input
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: AppTypography.headingStyle(
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      size: 24,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '₹0.00',
                      hintStyle: AppTypography.headingStyle(
                        color: isDark
                            ? AppColors.textLightSecondary
                                .withValues(alpha: 0.3)
                            : AppColors.textTertiary,
                        size: 24,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppConstants.borderRadiusLarge,
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bank Info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: AppConstants.borderRadiusMedium,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : Colors.white,
                            borderRadius: AppConstants.borderRadiusMedium,
                          ),
                          child: Icon(
                            Icons.account_balance_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bank Transfer',
                                style: AppTypography.bodyStyle(
                                  color: isDark
                                      ? AppColors.textLight
                                      : AppColors.textPrimary,
                                  weight: FontWeight.w600,
                                  size: 14,
                                ),
                              ),
                              Text(
                                'Direct to your linked account',
                                style: AppTypography.captionStyle(
                                  color: isDark
                                      ? AppColors.textLightSecondary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.emeraldGreen.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                        ),
                        borderRadius: AppConstants.borderRadiusMedium,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldGreen
                                .withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount =
                              double.tryParse(amountController.text);
                          if (amount == null || amount <= 0) {
                            AppDialogs.showError(
                              context,
                              'Enter a valid amount',
                            );
                            return;
                          }
                          if (amount > _currentBalance) {
                            AppDialogs.showError(
                              context,
                              'Insufficient balance',
                            );
                            return;
                          }
                          Navigator.pop(context);
                          final success =
                              await EarningsService.requestWithdrawal(
                            amount,
                            {'method': 'bank_transfer', 'requested_at': DateTime.now().toIso8601String()},
                          );
                          if (success && mounted) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Withdrawal request submitted!',
                                ),
                                backgroundColor: AppColors.emeraldGreen,
                              ),
                            );
                            _loadData();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppConstants.borderRadiusMedium,
                          ),
                        ),
                        child: Text(
                          'Withdraw Now',
                          style: AppTypography.bodyStyle(
                            color: Colors.white,
                            weight: FontWeight.w600,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
