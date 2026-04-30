import 'package:flutter/material.dart';

/// Typography constants for High-Contrast Material Design
/// Font: Roboto (System standard) with Inter fallback
class AppTypography {
  // Font Family
  static const String fontFamily =
      'Roboto'; // System default, falls back to Inter

  // ===== FONT SIZES =====

  // Display (40px, Bold) - For hero numbers, splash titles
  static const double display = 40.0;

  // Headline (24px, Bold) - For earnings and ETA numbers
  static const double headline = 24.0;

  // Title (20px, Semi-Bold) - For section headers
  static const double title = 20.0;

  // Subtitle (18px, Medium) - For card titles
  static const double subtitle = 18.0;

  // Body (16px, Regular) - For customer names and addresses
  static const double body = 16.0;

  // Body Small (14px, Regular) - For secondary info
  static const double bodySmall = 14.0;

  // Labels (12px, Uppercase) - For status tags (e.g., "NEW ORDER")
  static const double label = 12.0;

  // Caption (11px) - For timestamps and minor details
  static const double caption = 11.0;

  // Overline (10px, Uppercase) - For category headers
  static const double overline = 10.0;

  // ===== FONT WEIGHTS =====

  static const fontWeightRegular = 400;
  static const fontWeightMedium = 500;
  static const fontWeightSemiBold = 600;
  static const fontWeightBold = 700;
  static const fontWeightExtraBold = 800;

  // ===== LINE HEIGHTS =====

  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.4;
  static const double lineHeightRelaxed = 1.6;

  // ===== LETTER SPACING =====

  static const double letterSpacingTight = -0.5;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.5;
  static const double letterSpacingLabels = 1.2; // For uppercase labels

  // ===== TEXT STYLE FACTORIES =====
  // Consistent, reusable text styles with optional overrides

  /// Display style — hero numbers, splash screen
  static TextStyle displayStyle({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: display,
      fontWeight: weight ?? FontWeight.w800,
      letterSpacing: letterSpacingTight,
      height: lineHeightTight,
      color: color,
    );
  }

  /// Heading style — screen titles, section headings
  static TextStyle headingStyle({
    Color? color,
    FontWeight? weight,
    double? size,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size ?? headline,
      fontWeight: weight ?? FontWeight.w700,
      letterSpacing: letterSpacingTight,
      height: lineHeightTight,
      color: color,
    );
  }

  /// Title style — card titles, section labels
  static TextStyle titleStyle({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: title,
      fontWeight: weight ?? FontWeight.w600,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  /// Body style — main content, descriptions
  static TextStyle bodyStyle({
    Color? color,
    FontWeight? weight,
    double? size,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size ?? body,
      fontWeight: weight ?? FontWeight.w400,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  /// Label style — small uppercase tags, badges
  static TextStyle labelStyle({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: label,
      fontWeight: weight ?? FontWeight.w600,
      letterSpacing: letterSpacingLabels,
      height: lineHeightTight,
      color: color,
    );
  }

  /// Caption style — timestamps, helper text
  static TextStyle captionStyle({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: caption,
      fontWeight: weight ?? FontWeight.w400,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  /// Overline style — section separators, category labels
  static TextStyle overlineStyle({
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: overline,
      fontWeight: FontWeight.w700,
      letterSpacing: letterSpacingLabels,
      height: lineHeightTight,
      color: color,
    );
  }

  /// Money/currency display — large financial figures
  static TextStyle moneyStyle({
    Color? color,
    double? size,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size ?? headline,
      fontWeight: FontWeight.w700,
      letterSpacing: letterSpacingTight,
      height: lineHeightTight,
      color: color,
    );
  }
}
