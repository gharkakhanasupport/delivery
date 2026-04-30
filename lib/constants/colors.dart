import 'package:flutter/material.dart';

/// Brand colors for GHAR KA KHANAA Delivery Partner App
/// Optimized for outdoor visibility and driver use cases
class AppColors {
  // Brand Colors
  static const Color emeraldGreen = Color(0xFF2da832); // Primary actions
  static const Color goldenMustard = Color(
    0xFFc2941b,
  ); // Financial data & earnings

  // ===== HIGH-CONTRAST MATERIAL DESIGN PALETTE =====
  // Optimized for driver visibility while driving/walking

  /// Primary Action - Cobalt Blue (Trustworthy, standard "tap" color)
  static const Color primaryAction = Color(0xFF1A73E8);

  /// Success / Online - Deep Green (Signals "Go" or "Money Earned")
  static const Color successOnline = Color(0xFF0F9D58);

  /// Danger / Offline - Signal Red (Stops, errors, or "Offline" status)
  static const Color dangerOffline = Color(0xFFD93025);

  /// Background - Off-White (Reduces eye strain; separates white cards)
  static const Color backgroundOffWhite = Color(0xFFF8F9FA);

  /// Text Primary - Near Black (Maximum readability)
  static const Color hcTextPrimary = Color(0xFF202124);

  /// Text Secondary - Slate Grey (Diminishes less important labels)
  static const Color hcTextSecondary = Color(0xFF5F6368);

  /// Navigation Border - Light Grey (1px borders)
  static const Color navBorder = Color(0xFFEEEEEE);

  /// Card Border - Standard border for cards
  static const Color cardBorder = Color(0xFFE0E0E0);

  // High Contrast Variants (for outdoor visibility)
  static const Color emeraldGreenDark = Color(
    0xFF1d7a21,
  ); // Darker green for better contrast
  static const Color goldenMustardDark = Color(
    0xFF9a7516,
  ); // Darker mustard for better contrast

  // Dark Mode Colors
  static const Color deepNavy = Color(0xFF0D1117); // Main background (AMOLED)
  static const Color darkCard = Color(0xFF161B22); // Card backgrounds
  static const Color darkSurface = Color(0xFF1C2333); // Elevated surfaces

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF6F8FA); // Main background
  static const Color lightCard = Color(0xFFFFFFFF); // Card backgrounds
  static const Color lightSurface = Color(0xFFF0F2F5); // Elevated surfaces

  // ===== SEMANTIC SURFACE TOKENS =====
  // For layered card designs and depth

  /// Elevated surface for cards that sit above background
  static Color surfaceElevatedLight = const Color(0xFFFFFFFF);
  static Color surfaceElevatedDark = const Color(0xFF1C2333);

  /// Overlay surface for bottom sheets, modals, dialogs
  static Color surfaceOverlayLight = Colors.white.withValues(alpha: 0.95);
  static Color surfaceOverlayDark = const Color(0xFF161B22).withValues(alpha: 0.95);

  /// Subtle surface for section backgrounds
  static Color surfaceSubtleLight = const Color(0xFFF6F8FA);
  static Color surfaceSubtleDark = const Color(0xFF0D1117);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFE0E0E0);
  static const Color mediumGrey = Color(0xFF9E9E9E);
  static const Color darkGrey = Color(0xFF424242);
  static const Color black = Color(0xFF000000);

  // Accent Colors for Stats
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentPurple = Color(0xFF9C27B0);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentTeal = Color(0xFF00BCD4);
  static const Color accentPink = Color(0xFFE91E63);

  // Status Colors
  static const Color success = emeraldGreen;
  static const Color warning = goldenMustard;
  static const Color error = Color(0xFFE53935);
  static const Color info = accentBlue;

  // Online/Offline Status
  static const Color statusOnline = emeraldGreen;
  static const Color statusOffline = mediumGrey;
  static const Color statusBusy = goldenMustard;

  // Order Status Colors
  static const Color orderPending = goldenMustard;
  static const Color orderAccepted = emeraldGreen;
  static const Color orderCompleted = accentBlue;
  static const Color orderCancelled = error;

  // Text Colors (High Contrast for WCAG AAA compliance)
  static const Color textPrimary = Color(0xFF212121); // For light backgrounds
  static const Color textSecondary = Color(0xFF757575); // For light backgrounds
  static const Color textTertiary = Color(0xFF9E9E9E); // For hints/disabled
  static const Color textLight = Color(0xFFFFFFFF); // For dark backgrounds
  static const Color textLightSecondary = Color(0xFFB0B8C8); // Muted on dark
  static const Color textDark = Color(0xFF121826); // For light backgrounds
  static const Color textDisabled = Color(0xFFBDBDBD);

  // Divider/Border Colors
  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF2D333B);
  static const Color border = Color(0xFFBDBDBD);
  static const Color borderDark = Color(0xFF30363D);
  static const Color borderSubtle = Color(0xFFEAEEF2);

  // Shadow Colors
  static Color shadowLight = Colors.black.withValues(alpha: 0.06);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.12);
  static Color shadowDark = Colors.black.withValues(alpha: 0.20);
  static Color shadowEmerald = emeraldGreen.withValues(alpha: 0.25);

  // Map Colors
  static const Color hotspotOverlay = Color(
    0x40FF5722,
  ); // Translucent red-orange for hotspots
  static const Color routeLine = emeraldGreen; // Route line on map
  static const Color currentLocation = accentBlue; // Current location marker

  // ===== GLASSMORPHISM DESIGN SYSTEM =====
  // Blur values
  static const double glassBlurSigma = 20.0;
  static const double glassBlurSigmaLight = 10.0;
  static const double glassBlurSigmaSubtle = 5.0;

  // Glass container colors (semi-transparent)
  static Color glassLight = Colors.white.withValues(alpha: 0.12);
  static Color glassDark = Colors.black.withValues(alpha: 0.20);
  static Color glassBorderLight = Colors.white.withValues(alpha: 0.20);
  static Color glassBorderDark = Colors.white.withValues(alpha: 0.08);

  // ===== GRADIENT PRESETS =====

  static const List<Color> primaryGradient = [
    Color(0xFF2da832),
    Color(0xFF4CAF50),
  ];
  static const List<Color> goldGradient = [
    Color(0xFFc2941b),
    Color(0xFFFFD54F),
  ];
  static const List<Color> darkGradient = [
    Color(0xFF1C2333),
    Color(0xFF0D1117),
  ];

  /// Hero gradient for splash & login backgrounds
  static const List<Color> heroGradient = [
    Color(0xFF0D1117),
    Color(0xFF112240),
    Color(0xFF1d7a21),
  ];

  /// Accent gradient for premium cards
  static const List<Color> accentGradient = [
    Color(0xFF2da832),
    Color(0xFF00BCD4),
  ];

  /// Dark surface gradient for elevated cards in dark mode
  static const List<Color> darkSurfaceGradient = [
    Color(0xFF1C2333),
    Color(0xFF161B22),
  ];

  /// Earnings card gradient
  static const List<Color> earningsGradient = [
    Color(0xFF1a1a2e),
    Color(0xFF16213e),
    Color(0xFF0f3460),
  ];

  // Animated theme toggle colors
  static const Color sunYellow = Color(0xFFFFC107);
  static const Color moonBlue = Color(0xFF3F51B5);
  static const Color skyBlue = Color(0xFF87CEEB);
  static const Color nightBlue = Color(0xFF1A237E);

  // ===== STATUS BADGE COLORS =====
  // Small rounded pills for order status display

  /// NEW order badge - Blue background
  static const Color badgeNew = Color(0xFF1A73E8);

  /// PICKING UP badge - Orange background
  static const Color badgePickingUp = Color(0xFFFF9800);

  /// EN ROUTE badge - Teal
  static const Color badgeEnRoute = Color(0xFF00BCD4);

  /// DELIVERED badge - Green background
  static const Color badgeDelivered = Color(0xFF0F9D58);

  /// CANCELLED badge - Red background
  static const Color badgeCancelled = Color(0xFFD93025);

  // ===== SHIMMER LOADING COLORS =====

  static Color shimmerBaseLight = const Color(0xFFE8E8E8);
  static Color shimmerHighlightLight = const Color(0xFFF5F5F5);
  static Color shimmerBaseDark = const Color(0xFF1C2333);
  static Color shimmerHighlightDark = const Color(0xFF2D333B);

  // ===== HELPER METHODS =====

  /// Get adaptive color based on theme brightness
  static Color adaptive(BuildContext context, {
    required Color light,
    required Color dark,
  }) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  /// Get surface color for current theme
  static Color surface(BuildContext context) {
    return adaptive(context,
      light: lightCard,
      dark: darkCard,
    );
  }

  /// Get surface elevated color for current theme
  static Color surfaceElevated(BuildContext context) {
    return adaptive(context,
      light: surfaceElevatedLight,
      dark: surfaceElevatedDark,
    );
  }

  /// Get text primary color for current theme
  static Color text(BuildContext context) {
    return adaptive(context,
      light: textPrimary,
      dark: textLight,
    );
  }

  /// Get text secondary color for current theme
  static Color textSub(BuildContext context) {
    return adaptive(context,
      light: textSecondary,
      dark: textLightSecondary,
    );
  }
}
