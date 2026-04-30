import 'package:flutter/material.dart';
import 'dart:ui';
import '../constants/colors.dart';

/// Interactive "Slide to Go Online" bar widget with premium design
class SlideToOnlineBar extends StatefulWidget {
  final VoidCallback onSlideComplete;

  const SlideToOnlineBar({super.key, required this.onSlideComplete});

  @override
  State<SlideToOnlineBar> createState() => _SlideToOnlineBarState();
}

class _SlideToOnlineBarState extends State<SlideToOnlineBar>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDragDistance = screenWidth - 120;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          height: 64,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.emeraldGreen.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.emeraldGreen.withValues(alpha: 0.2),
                blurRadius: 12 + _pulseAnimation.value,
                spreadRadius: _pulseAnimation.value / 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Stack(
                children: [
                  // Green progress fill with gradient
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: _dragPosition + 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.emeraldGreen.withValues(alpha: 0.4),
                          AppColors.emeraldGreen.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),

                  // Shimmer effect hint
                  if (!_isCompleted)
                    Positioned(
                      left: 70,
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: Row(
                        children: [
                          Icon(
                            Icons.chevron_right,
                            color:
                                (isDark
                                        ? AppColors.lightGrey
                                        : AppColors.mediumGrey)
                                    .withValues(alpha: 0.5),
                            size: 20,
                          ),
                          Icon(
                            Icons.chevron_right,
                            color:
                                (isDark
                                        ? AppColors.lightGrey
                                        : AppColors.mediumGrey)
                                    .withValues(alpha: 0.3),
                            size: 20,
                          ),
                          Icon(
                            Icons.chevron_right,
                            color:
                                (isDark
                                        ? AppColors.lightGrey
                                        : AppColors.mediumGrey)
                                    .withValues(alpha: 0.15),
                            size: 20,
                          ),
                        ],
                      ),
                    ),

                  // Text
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isCompleted ? 'You are Online!' : 'Slide to Go Online',
                        key: ValueKey(_isCompleted),
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Draggable handle with premium styling
                  AnimatedPositioned(
                    duration: _isCompleted
                        ? const Duration(milliseconds: 300)
                        : Duration.zero,
                    curve: Curves.easeOutBack,
                    left: _dragPosition,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        if (!_isCompleted) {
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx)
                                .clamp(0.0, maxDragDistance);
                          });
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        if (_dragPosition >= maxDragDistance * 0.75) {
                          setState(() {
                            _dragPosition = maxDragDistance;
                            _isCompleted = true;
                          });
                          _pulseController.stop();
                          widget.onSlideComplete();
                        } else {
                          setState(() => _dragPosition = 0.0);
                        }
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isCompleted
                                ? [
                                    AppColors.emeraldGreen,
                                    const Color(0xFF1a8c1f),
                                  ]
                                : [Colors.white, const Color(0xFFF5F5F5)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isCompleted
                                          ? AppColors.emeraldGreen
                                          : Colors.black)
                                      .withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            _isCompleted
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            key: ValueKey(_isCompleted),
                            color: _isCompleted
                                ? Colors.white
                                : AppColors.emeraldGreen,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
