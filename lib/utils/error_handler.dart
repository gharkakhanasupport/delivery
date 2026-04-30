import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';

/// Comprehensive error handling utility with graceful alerts
/// Professional apps focus on Feedback, not "flair"
class ErrorHandler {
  // Private constructor
  ErrorHandler._();

  static OverlayEntry? _currentBanner;
  static OverlayEntry? _progressBar;

  /// Show a red error banner at the top of the screen with Retry button
  static void showErrorBanner(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
  }) {
    // Remove existing banner if any
    _currentBanner?.remove();

    final overlay = Overlay.of(context);

    _currentBanner = OverlayEntry(
      builder: (context) => _ErrorBannerWidget(
        message: message,
        onRetry: onRetry,
        onDismiss: () {
          _currentBanner?.remove();
          _currentBanner = null;
        },
      ),
    );

    overlay.insert(_currentBanner!);

    // Auto-dismiss after 5 seconds if no retry needed
    if (onRetry == null) {
      Future.delayed(const Duration(seconds: 5), () {
        _currentBanner?.remove();
        _currentBanner = null;
      });
    }
  }

  /// Show a simple error snackbar (for less critical errors)
  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: AppColors.dangerOffline,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show linear progress bar at the top (under status bar)
  static void showTopProgressBar(BuildContext context) {
    _progressBar?.remove();

    final overlay = Overlay.of(context);

    _progressBar = OverlayEntry(builder: (context) => const _TopProgressBar());

    overlay.insert(_progressBar!);
  }

  /// Hide the top progress bar
  static void hideTopProgressBar() {
    _progressBar?.remove();
    _progressBar = null;
  }

  /// Trigger haptic feedback - short vibration for order acceptance
  static void triggerAcceptHaptic() {
    HapticFeedback.mediumImpact();
  }

  /// Trigger haptic feedback - double vibration for delivery completion
  static void triggerCompleteHaptic() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// Trigger haptic feedback - light tap for general interactions
  static void triggerLightHaptic() {
    HapticFeedback.lightImpact();
  }

  /// Wrap async operations with graceful error handling
  static Future<T?> handleGracefully<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? errorMessage,
    VoidCallback? onRetry,
    bool showProgress = true,
  }) async {
    // Capture overlay early before any async operation
    final overlay = Overlay.of(context);

    if (showProgress) {
      _showProgressBarWithOverlay(overlay);
    }

    try {
      final result = await operation();
      hideTopProgressBar();
      return result;
    } catch (e) {
      hideTopProgressBar();
      _showErrorBannerWithOverlay(
        overlay,
        message: errorMessage ?? 'Something went wrong. Please try again.',
        onRetry: onRetry,
      );
      return null;
    }
  }

  /// Internal method to show error banner using pre-captured overlay
  static void _showErrorBannerWithOverlay(
    OverlayState overlay, {
    required String message,
    VoidCallback? onRetry,
  }) {
    _currentBanner?.remove();

    _currentBanner = OverlayEntry(
      builder: (context) => _ErrorBannerWidget(
        message: message,
        onRetry: onRetry,
        onDismiss: () {
          _currentBanner?.remove();
          _currentBanner = null;
        },
      ),
    );

    overlay.insert(_currentBanner!);

    if (onRetry == null) {
      Future.delayed(const Duration(seconds: 5), () {
        _currentBanner?.remove();
        _currentBanner = null;
      });
    }
  }

  /// Internal method to show progress bar using pre-captured overlay
  static void _showProgressBarWithOverlay(OverlayState overlay) {
    _progressBar?.remove();

    _progressBar = OverlayEntry(builder: (context) => const _TopProgressBar());

    overlay.insert(_progressBar!);
  }

  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.successOnline,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Error banner widget displayed at top of screen
class _ErrorBannerWidget extends StatefulWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  const _ErrorBannerWidget({
    required this.message,
    this.onRetry,
    required this.onDismiss,
  });

  @override
  State<_ErrorBannerWidget> createState() => _ErrorBannerWidgetState();
}

class _ErrorBannerWidgetState extends State<_ErrorBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.fadeInDuration,
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.only(
                top: statusBarHeight + 8,
                bottom: 12,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.dangerOffline,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.onRetry != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _dismiss();
                        widget.onRetry!();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Linear progress bar at the top of the screen
class _TopProgressBar extends StatelessWidget {
  const _TopProgressBar();

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Positioned(
      top: statusBarHeight,
      left: 0,
      right: 0,
      child: const LinearProgressIndicator(
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAction),
        minHeight: 3,
      ),
    );
  }
}
