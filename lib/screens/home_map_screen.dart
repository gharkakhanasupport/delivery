import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../widgets/slide_to_online_bar.dart';
import '../widgets/openstreetmap_widget.dart';
import '../widgets/glass_container.dart';
import '../services/online_service.dart';
import '../services/order_service.dart';
import '../utils/app_dialogs.dart';

/// Home Map Screen - Full-screen map with floating overlays + Realtime orders
/// Primary screen where drivers see location, nearby orders, and go online
class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  double _todayEarnings = 0.0;

  /// Supabase realtime channel for order updates
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToOrders();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Orders arrive via FCM — no polling of delivery_orders table.
    // Only earnings update from wallet.
    final earnings = await OrderService.getTodayEarnings();
    if (mounted) {
      setState(() {
        _todayEarnings = earnings;
      });
    }
  }

  /// Subscribe to realtime changes on delivery_orders
  void _subscribeToOrders() {
    _ordersChannel = Supabase.instance.client
        .channel('home-map-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_orders',
          callback: (payload) {
            // Re-fetch data on any order change
            _loadData();
          },
        )
        .subscribe();
  }


  void _goOnline() {
    OnlineService.goOnline();
  }

  void _goOffline() {
    AppDialogs.showOfflineConfirmation(context);
  }

  void _showEarningsDetails() {
    // Handled by main navigation
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: OnlineService.isOnline,
      builder: (context, isOnline, child) {
        return Scaffold(
          body: Stack(
            children: [
              // FULL SCREEN MAP
              Positioned.fill(
                child: OpenStreetMapWidget(
                  orders: const [],
                  selectedOrder: null,
                  onOrderSelected: (_) {},
                  showControls: true,
                  controlsBottomOffset: 200,
                ),
              ),

              // Top floating pills
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(isOnline, isDark),
              ),

              // Bottom Panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: isOnline
                    ? _buildOnlinePanel(isDark)
                    : _buildOfflinePanel(isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Top bar with floating status pill and earnings chip
  Widget _buildTopBar(bool isOnline, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Row(
        children: [
          // Status badge (floating pill)
          GlassContainer.subtle(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            borderRadius: AppConstants.radiusCircular,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(isActive: isOnline),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: AppTypography.labelStyle(
                    color: isOnline
                        ? AppColors.emeraldGreen
                        : AppColors.textLightSecondary,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Earnings pill
          GestureDetector(
            onTap: _showEarningsDetails,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE6A817),
                    Color(0xFFD4941A),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldenMustard.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.currency_rupee_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _todayEarnings.toStringAsFixed(0),
                    style: AppTypography.bodyStyle(
                      color: Colors.white,
                      weight: FontWeight.w700,
                      size: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom panel when offline — shows slide to go online
  Widget _buildOfflinePanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.97)
            : Colors.white.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.mediumGrey.withValues(alpha: 0.3)
                    : AppColors.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'You\'re Offline',
              style: AppTypography.headingStyle(
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Slide to start receiving delivery requests',
              style: AppTypography.bodyStyle(
                color: isDark
                    ? AppColors.textLightSecondary
                    : AppColors.textSecondary,
                size: 14,
              ),
            ),
            const SizedBox(height: 16),
            SlideToOnlineBar(onSlideComplete: _goOnline),
          ],
        ),
      ),
    );
  }

  /// Bottom panel when online — always scanning card.
  /// Orders arrive via FCM push (IncomingOrderSheet), not a list.
  Widget _buildOnlinePanel(bool isDark) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _buildScanningCard(isDark),
      ),
    );
  }

  /// Card shown when scanning for orders
  Widget _buildScanningCard(bool isDark) {
    return GlassContainer.elevated(
      padding: const EdgeInsets.all(16),
      borderRadius: AppConstants.radiusXL,
      child: Row(
        children: [
          // Radar icon with subtle animation
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.emeraldGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.radar_rounded,
              color: AppColors.emeraldGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Scanning for orders...',
                  style: AppTypography.bodyStyle(
                    color: isDark
                        ? AppColors.textLight
                        : AppColors.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Looking for deliveries nearby',
                  style: AppTypography.captionStyle(
                    color: isDark
                        ? AppColors.textLightSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Go offline button
          IconButton(
            onPressed: _goOffline,
            icon: const Icon(Icons.power_settings_new_rounded, size: 22),
            color: AppColors.error,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.1),
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: AppConstants.borderRadiusMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// Pulsing green dot for online status
class _PulseDot extends StatefulWidget {
  final bool isActive;
  const _PulseDot({required this.isActive});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? AppColors.emeraldGreen
        : AppColors.statusOffline;

    if (!widget.isActive) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _animation.value * 0.5),
                blurRadius: 6,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
