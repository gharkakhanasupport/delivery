import 'package:flutter/material.dart';

/// Reusable large button widget with consistent styling
/// Following delivery app best practices with 56dp height and clear touch targets
class LargeButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final LargeButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const LargeButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = LargeButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Get button colors based on type
    final ButtonColors colors = _getColors(isDark);

    Widget content = isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.textColor),
            ),
          )
        : (icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 24, color: colors.textColor),
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textColor,
                      ),
                    ),
                  ],
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textColor,
                  ),
                ));

    final button = type == LargeButtonType.outline
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.foregroundColor,
              side: BorderSide(
                color: colors.borderColor ?? colors.backgroundColor,
                width: 2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(0, 56),
            ),
            child: content,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.backgroundColor,
              foregroundColor: colors.textColor,
              disabledBackgroundColor: colors.disabledColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              minimumSize: const Size(0, 56),
            ),
            child: content,
          );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  ButtonColors _getColors(bool isDark) {
    switch (type) {
      case LargeButtonType.primary:
        return ButtonColors(
          backgroundColor: const Color(0xFF2da832), // emeraldGreen
          textColor: Colors.white,
          foregroundColor: const Color(0xFF2da832),
          disabledColor: Colors.grey[400]!,
        );
      case LargeButtonType.secondary:
        return ButtonColors(
          backgroundColor: const Color(0xFFc2941b), // goldenMustard
          textColor: Colors.white,
          foregroundColor: const Color(0xFFc2941b),
          disabledColor: Colors.grey[400]!,
        );
      case LargeButtonType.outline:
        return ButtonColors(
          backgroundColor: Colors.transparent,
          textColor: isDark ? Colors.white : Colors.black87,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          borderColor: isDark ? Colors.white : Colors.black87,
          disabledColor: Colors.grey[400]!,
        );
      case LargeButtonType.danger:
        return ButtonColors(
          backgroundColor: const Color(0xFFE53935), // error red
          textColor: Colors.white,
          foregroundColor: const Color(0xFFE53935),
          disabledColor: Colors.grey[400]!,
        );
    }
  }
}

/// Button type variants
enum LargeButtonType {
  primary, // Green, for main actions
  secondary, // Mustard, for financial actions
  outline, // Transparent with border
  danger, // Red, for destructive actions
}

/// Helper class to hold button colors
class ButtonColors {
  final Color backgroundColor;
  final Color textColor;
  final Color foregroundColor;
  final Color disabledColor;
  final Color? borderColor;

  ButtonColors({
    required this.backgroundColor,
    required this.textColor,
    required this.foregroundColor,
    required this.disabledColor,
    this.borderColor,
  });
}
