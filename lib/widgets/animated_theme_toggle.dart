import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/theme_service.dart';

/// An animated day/night toggle switch for theme switching.
/// Features smooth sun/moon animations and color transitions.
class AnimatedThemeToggle extends StatefulWidget {
  final double width;
  final double height;

  const AnimatedThemeToggle({super.key, this.width = 70, this.height = 36});

  @override
  State<AnimatedThemeToggle> createState() => _AnimatedThemeToggleState();
}

class _AnimatedThemeToggleState extends State<AnimatedThemeToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<Color?> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    _backgroundAnimation = ColorTween(
      begin: AppColors.skyBlue,
      end: AppColors.nightBlue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Initialize based on current theme
    if (ThemeService.themeMode.value == ThemeMode.dark) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.value == 0.0) {
      _controller.forward();
      ThemeService.setThemeMode(ThemeMode.dark);
    } else {
      _controller.reverse();
      ThemeService.setThemeMode(ThemeMode.light);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggleWidth = widget.width;
    final toggleHeight = widget.height;
    final thumbSize = toggleHeight - 8;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: toggleWidth,
            height: toggleHeight,
            decoration: BoxDecoration(
              color: _backgroundAnimation.value,
              borderRadius: BorderRadius.circular(toggleHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Stars (visible in dark mode)
                if (_slideAnimation.value > 0.3)
                  Positioned(
                    left: 12,
                    top: 8,
                    child: Opacity(
                      opacity: (_slideAnimation.value - 0.3) / 0.7,
                      child: const Icon(
                        Icons.star,
                        size: 8,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                if (_slideAnimation.value > 0.5)
                  Positioned(
                    left: 20,
                    top: 18,
                    child: Opacity(
                      opacity: (_slideAnimation.value - 0.5) / 0.5,
                      child: const Icon(
                        Icons.star,
                        size: 6,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                // Clouds (visible in light mode)
                if (_slideAnimation.value < 0.7)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Opacity(
                      opacity: 1 - (_slideAnimation.value / 0.7),
                      child: Icon(
                        Icons.cloud,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                // Thumb (Sun/Moon)
                Positioned(
                  left:
                      4 +
                      (_slideAnimation.value * (toggleWidth - thumbSize - 8)),
                  top: 4,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value * 3.14159,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _slideAnimation.value < 0.5
                            ? AppColors.sunYellow
                            : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: _slideAnimation.value < 0.5
                                ? AppColors.sunYellow.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _slideAnimation.value < 0.5
                          ? const Icon(
                              Icons.wb_sunny,
                              size: 16,
                              color: Colors.orange,
                            )
                          : Icon(
                              Icons.nightlight_round,
                              size: 16,
                              color: AppColors.nightBlue.withValues(alpha: 0.8),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
