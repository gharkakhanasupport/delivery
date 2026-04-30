import 'package:flutter/material.dart';

/// Reusable animated button widget with scale animation on press and loading state.
/// Follows modern UI patterns with gradient backgrounds and glassmorphism support.
class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AnimatedButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final Gradient? gradient;

  const AnimatedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AnimatedButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 56.0,
    this.gradient,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _controller.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = _getColors(isDark);

    Widget content = widget.isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(colors.textColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 22, color: colors.textColor),
                const SizedBox(width: 10),
              ],
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );

    final buttonDecoration = BoxDecoration(
      gradient: widget.gradient ?? colors.gradient,
      color: widget.gradient == null && colors.gradient == null
          ? colors.backgroundColor
          : null,
      borderRadius: BorderRadius.circular(14),
      border: widget.type == AnimatedButtonType.outline
          ? Border.all(
              color: colors.borderColor ?? colors.backgroundColor,
              width: 2,
            )
          : null,
      boxShadow: _isPressed || widget.type == AnimatedButtonType.outline
          ? null
          : [
              BoxShadow(
                color: (colors.gradient?.colors.first ?? colors.backgroundColor)
                    .withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.isFullWidth ? double.infinity : null,
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: buttonDecoration,
              alignment: Alignment.center,
              child: content,
            ),
          );
        },
      ),
    );
  }

  _ButtonColors _getColors(bool isDark) {
    switch (widget.type) {
      case AnimatedButtonType.primary:
        return _ButtonColors(
          backgroundColor: const Color(0xFF2da832),
          textColor: Colors.white,
          gradient: const LinearGradient(
            colors: [Color(0xFF2da832), Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case AnimatedButtonType.secondary:
        return _ButtonColors(
          backgroundColor: const Color(0xFFc2941b),
          textColor: Colors.white,
          gradient: const LinearGradient(
            colors: [Color(0xFFc2941b), Color(0xFFFFD54F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case AnimatedButtonType.outline:
        return _ButtonColors(
          backgroundColor: Colors.transparent,
          textColor: isDark ? Colors.white : Colors.black87,
          borderColor: isDark ? Colors.white54 : Colors.black54,
        );
      case AnimatedButtonType.danger:
        return _ButtonColors(
          backgroundColor: const Color(0xFFE53935),
          textColor: Colors.white,
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFEF5350)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case AnimatedButtonType.glass:
        return _ButtonColors(
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          textColor: isDark ? Colors.white : Colors.black87,
          borderColor: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.1),
        );
    }
  }
}

enum AnimatedButtonType { primary, secondary, outline, danger, glass }

class _ButtonColors {
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final Gradient? gradient;

  _ButtonColors({
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.gradient,
  });
}
