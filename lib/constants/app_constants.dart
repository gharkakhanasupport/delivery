import 'package:flutter/material.dart';

/// Application-wide constants for consistent UI/UX
/// Based on delivery app best practices and accessibility guidelines
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // ============================================================================
  // TOUCH TARGETS (Based on Material Design & Accessibility Guidelines)
  // ============================================================================

  /// Minimum touch target size for all interactive elements
  /// Following WCAG 2.1 Level AAA and Material Design guidelines
  static const double minTouchTarget = 48.0;

  /// Standard button height for primary actions
  static const double buttonHeight = 56.0;

  /// Compact button height for secondary actions
  static const double compactButtonHeight = 44.0;

  /// Large icon size for bottom navigation and primary actions
  static const double largeIconSize = 24.0;

  /// Standard icon size for lists and cards
  static const double standardIconSize = 20.0;

  // ============================================================================
  // SPACING SCALE (8dp grid system)
  // ============================================================================

  static const double space0 = 0.0;
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;
  static const double space80 = 80.0;

  // ============================================================================
  // TYPOGRAPHY (Optimized for outdoor visibility)
  // ============================================================================

  /// Large heading (screen titles)
  static const double fontSizeLarge = 24.0;

  /// Medium heading (section titles)
  static const double fontSizeMedium = 18.0;

  /// Body text (default for most content)
  static const double fontSizeBody = 16.0;

  /// Small text (labels, captions)
  static const double fontSizeSmall = 14.0;

  /// Extra small text (timestamps, hints)
  static const double fontSizeExtraSmall = 12.0;

  /// Extra large text (key metrics like earnings)
  static const double fontSizeExtraLarge = 32.0;

  /// Huge text (balance displays)
  static const double fontSizeHuge = 48.0;

  // ============================================================================
  // ELEVATION (Flat design preferred for clarity)
  // ============================================================================

  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationFloat = 12.0;

  // ============================================================================
  // BORDER RADIUS (Consistent rounded corners)
  // ============================================================================

  static const double radiusXSmall = 4.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 28.0;
  static const double radiusCircular = 999.0;

  /// Convenience BorderRadius constants
  static final BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);
  static final BorderRadius borderRadiusXL = BorderRadius.circular(radiusXL);
  static final BorderRadius borderRadiusXXL = BorderRadius.circular(radiusXXL);
  static final BorderRadius borderRadiusCircular = BorderRadius.circular(radiusCircular);

  // ============================================================================
  // ANIMATION DURATIONS
  // ============================================================================

  /// Instant feedback (button presses, color changes)
  static const Duration durationInstant = Duration(milliseconds: 100);

  /// Fast animation for button press feedback
  static const Duration durationFast = Duration(milliseconds: 150);

  /// Standard animation for most transitions
  static const Duration durationStandard = Duration(milliseconds: 300);

  /// Medium animation for page transitions, card expansions
  static const Duration durationMedium = Duration(milliseconds: 400);

  /// Slow animation for complex state changes
  static const Duration durationSlow = Duration(milliseconds: 500);

  /// Long animation for splash, onboarding
  static const Duration durationLong = Duration(milliseconds: 800);

  /// Fade-in duration for content (saves battery, no sliding/zooming)
  static const Duration fadeInDuration = Duration(milliseconds: 200);

  /// Stagger delay between list items
  static const Duration staggerDelay = Duration(milliseconds: 60);

  // ============================================================================
  // ANIMATION CURVES
  // ============================================================================

  /// Standard ease for general transitions
  static const Curve curveStandard = Curves.easeInOut;

  /// Decelerate for elements entering the screen
  static const Curve curveEnter = Curves.easeOutCubic;

  /// Accelerate for elements leaving the screen
  static const Curve curveExit = Curves.easeInCubic;

  /// Bounce effect for playful interactions
  static const Curve curveBounce = Curves.elasticOut;

  /// Spring-like snapping for snapping animations
  static const Curve curveSnap = Curves.easeOutBack;

  /// Smooth deceleration for page transitions
  static const Curve curveSmooth = Curves.fastOutSlowIn;

  // ============================================================================
  // RESPONSIVE BREAKPOINTS
  // ============================================================================

  /// Small phones (< 360dp)
  static const double breakpointSmallPhone = 360.0;

  /// Standard phones (360dp - 428dp)
  static const double breakpointPhone = 428.0;

  /// Small tablets (428dp - 600dp)
  static const double breakpointSmallTablet = 600.0;

  /// Tablets (600dp - 900dp)
  static const double breakpointTablet = 900.0;

  /// Check if screen is small phone
  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < breakpointSmallPhone;

  /// Check if screen is tablet or larger
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointSmallTablet;

  /// Get responsive padding based on screen width
  static double responsivePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpointSmallPhone) return space12;
    if (width < breakpointPhone) return space16;
    if (width < breakpointSmallTablet) return space20;
    return space24;
  }

  // ============================================================================
  // MAP CONSTANTS
  // ============================================================================

  /// Default map zoom level
  static const double mapDefaultZoom = 15.0;

  /// Hotspot circle radius on map (in meters)
  static const double hotspotRadius = 1000.0;

  /// Marker size for orders on map
  static const double markerSize = 40.0;

  // ============================================================================
  // ORDER CARD CONSTANTS
  // ============================================================================

  /// Maximum distance to show in "nearby" orders (km)
  static const double maxNearbyDistance = 10.0;

  /// Minimum order value to highlight
  static const double highlightOrderValue = 100.0;

  // ============================================================================
  // PADDING HELPERS
  // ============================================================================

  static const EdgeInsets paddingAll8 = EdgeInsets.all(space8);
  static const EdgeInsets paddingAll12 = EdgeInsets.all(space12);
  static const EdgeInsets paddingAll16 = EdgeInsets.all(space16);
  static const EdgeInsets paddingAll20 = EdgeInsets.all(space20);
  static const EdgeInsets paddingAll24 = EdgeInsets.all(space24);
  static const EdgeInsets paddingHorizontal16 = EdgeInsets.symmetric(
    horizontal: space16,
  );
  static const EdgeInsets paddingHorizontal20 = EdgeInsets.symmetric(
    horizontal: space20,
  );
  static const EdgeInsets paddingVertical8 = EdgeInsets.symmetric(
    vertical: space8,
  );
  static const EdgeInsets paddingVertical16 = EdgeInsets.symmetric(
    vertical: space16,
  );

  static const EdgeInsets paddingScreen = EdgeInsets.all(space16);
  static const EdgeInsets paddingCard = EdgeInsets.all(space16);
  static const EdgeInsets paddingCardCompact = EdgeInsets.all(space12);
  static const EdgeInsets paddingButton = EdgeInsets.symmetric(
    horizontal: space24,
    vertical: space16,
  );

  // ============================================================================
  // DECORATION HELPERS
  // ============================================================================

  /// Standard card box decoration (light mode)
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      borderRadius: borderRadiusLarge,
      border: Border.all(
        color: isDark ? const Color(0xFF30363D) : const Color(0xFFEAEEF2),
        width: 1,
      ),
      boxShadow: isDark
          ? []
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }
}
