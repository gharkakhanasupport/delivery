import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../screens/home_map_screen.dart';
import '../screens/earnings_screen.dart';
import '../screens/current_orders_screen.dart';
import '../screens/profile_screen.dart';

/// Main navigation scaffold with 4-tab floating bottom navigation
/// Home (Map) | Orders | Earnings | Profile
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  MainNavigationState createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconAnimations;

  final List<Widget> _screens = const [
    HomeMapScreen(), // Main map interface
    CurrentOrdersScreen(), // Active deliveries
    EarningsScreen(), // Earnings and stats
    ProfileScreen(), // Driver profile
  ];

  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Orders',
    ),
    _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Earnings',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(
      _navItems.length,
      (i) => AnimationController(
        vsync: this,
        duration: AppConstants.durationStandard,
      ),
    );
    _iconAnimations = _iconControllers.map((c) {
      return Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: c, curve: AppConstants.curveSnap),
      );
    }).toList();
    // Animate the initial tab
    _iconControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;

    HapticFeedback.lightImpact();

    // Reverse the old tab animation
    _iconControllers[_currentIndex].reverse();
    // Forward the new tab animation
    _iconControllers[index].forward();

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCard.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.97),
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _navItems.length,
                (index) => _buildNavButton(
                  item: _navItems[index],
                  index: index,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required _NavItem item,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _iconAnimations[index],
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated pill background behind icon
                AnimatedContainer(
                  duration: AppConstants.durationStandard,
                  curve: AppConstants.curveStandard,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 20 : 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.emeraldGreen.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: AppConstants.borderRadiusCircular,
                  ),
                  child: Transform.scale(
                    scale: _iconAnimations[index].value,
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected
                          ? AppColors.emeraldGreen
                          : (isDark
                              ? AppColors.textLightSecondary
                              : AppColors.mediumGrey),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Label
                AnimatedDefaultTextStyle(
                  duration: AppConstants.durationFast,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.emeraldGreen
                        : (isDark
                            ? AppColors.textLightSecondary
                            : AppColors.mediumGrey),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: isSelected ? 0.3 : 0,
                  ),
                  child: Text(item.label),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
