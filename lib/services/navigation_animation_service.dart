import 'package:flutter/material.dart';

/// Model for navigation bloom animation data
class NavigationBloomData {
  final Offset position;
  final int targetPageIndex;
  final Color color;

  NavigationBloomData({
    required this.position,
    required this.targetPageIndex,
    this.color = const Color(0xFF2da832), // emeraldGreen
  });
}

/// Service to trigger navigation bloom animations like Telegram
class NavigationAnimationService {
  /// Trigger for bloom animation
  static final ValueNotifier<NavigationBloomData?> bloomTrigger = ValueNotifier(
    null,
  );

  /// Trigger a bloom animation from a specific position to a target page
  static void triggerBloom({
    required Offset position,
    required int targetPageIndex,
    Color? color,
  }) {
    bloomTrigger.value = NavigationBloomData(
      position: position,
      targetPageIndex: targetPageIndex,
      color: color ?? const Color(0xFF2da832),
    );
  }

  /// Clear the trigger
  static void clear() {
    bloomTrigger.value = null;
  }
}
