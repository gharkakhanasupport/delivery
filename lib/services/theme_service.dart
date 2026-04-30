import 'package:flutter/material.dart';

class ThemeService {
  // Default to dark mode as per original design
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.dark,
  );

  // Animation trigger with button position
  static final ValueNotifier<Offset?> animationTrigger = ValueNotifier(null);

  /// Toggle theme with animation from a specific position
  static void toggleThemeWithAnimation(Offset buttonPosition) {
    animationTrigger.value = buttonPosition;
  }

  /// Toggle theme immediately without animation
  static void toggleTheme() {
    themeMode.value = themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  /// Set theme mode explicitly
  static void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
  }

  static bool get isDarkMode => themeMode.value == ThemeMode.dark;
}
