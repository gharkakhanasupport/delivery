import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../widgets/openstreetmap_widget.dart';
import '../widgets/large_button.dart';
import '../widgets/otp_display_card.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../services/navigation_service.dart';
import '../services/order_service.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/geofence_service.dart';
import '../services/earnings_credit_service.dart';
import '../services/offline_sync_service.dart';
import '../services/background_location_service.dart';

/// Delivery steps enum for better state management
enum DeliveryStep {
  goingToRestaurant, // Navigate to pickup location
  atRestaurant, // Arrived, confirm pickup
  goingToCustomer, // Navigate to delivery location
  atCustomer, // Arrived, confirm delivery
  delivered,
}

/// Delivery Navigation Screen - Full-screen map with step-based actions
class DeliveryNavigationScreen extends StatefulWidget {
  final Order order;
  const DeliveryNavigationScreen({super.key, required this.order});

  @override
  State<DeliveryNavigationScreen> createState() =>
      _DeliveryNavigationScreenState();
}

class _DeliveryNavigationScreenState extends State<DeliveryNavigationScreen> {
  DeliveryStep _currentStep = DeliveryStep.goingToRestaurant;

  /// Timer that streams the agent's GPS position to the order row
  /// while out_for_delivery so the customer's radar tracks in real time.
  Timer? _locationStreamTimer;
  bool _isProcessing = false;

  /// Cancels the active geofence watcher. Replaced each step transition.
  VoidCallback? _cancelGeofence;

  /// Prevents duplicate geofence fire when auto and manual both trigger.
  bool _geofenceReachedForStep = false;

  /// Credited earnings (₹) after delivery OTP verified. Shown on completion card.
  double? _creditedEarnings;

  @override
  void initState() {
    super.initState();
    // Arm geofence for the first leg (pickup).
    _armGeofenceForCurrentStep();
  }

  @override
  void dispose() {
    _locationStreamTimer?.cancel();
    _cancelGeofence?.call();
    super.dispose();
  }

  /// Arms a 200m geofence around the target for the current step.
  /// On reach: auto-advances state + haptic snackbar.
  void _armGeofenceForCurrentStep() {
    _cancelGeofence?.call();
    _geofenceReachedForStep = false;

    // Geofence only fires during the "going to" phases.
    if (_currentStep != DeliveryStep.goingToRestaurant &&
        _currentStep != DeliveryStep.goingToCustomer) {
      return;
    }

    final target = _currentDestination;
    _cancelGeofence = GeofenceService.watchUntilReached(
      target: target,
      meters: 200,
      onReached: _onGeofenceReached,
    );
  }

  void _onGeofenceReached() {
    if (!mounted || _geofenceReachedForStep) return;
    _geofenceReachedForStep = true;

    final reachedName = _currentStep == DeliveryStep.goingToRestaurant
        ? 'kitchen'
        : 'customer';

    setState(() {
      if (_currentStep == DeliveryStep.goingToRestaurant) {
        _currentStep = DeliveryStep.atRestaurant;
      } else if (_currentStep == DeliveryStep.goingToCustomer) {
        _currentStep = DeliveryStep.atCustomer;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Reached $reachedName — showing OTP.'),
        backgroundColor: AppColors.emeraldGreen,
        duration: const Duration(seconds: 2),
      ),
    );

    // Auto-trigger OTP flow — user expects OTP immediately on reach.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleConfirmButton();
    });
  }

  /// Push the agent's current GPS to the order.current_location field.
  /// Called every 10 seconds while out_for_delivery.
  Future<void> _pushLocationToOrder() async {
    try {
      final pos = LocationService.currentLocation.value;
      if (pos == null) return;
      await OrderService.streamLocationToOrder(
        widget.order.id,
        pos.latitude,
        pos.longitude,
      );
    } catch (e) {
      debugPrint('delivery_nav: location push failed: $e');
    }
  }

  void _startLocationStreaming() {
    _locationStreamTimer?.cancel();
    // Push once immediately, then every 10s
    _pushLocationToOrder();
    _locationStreamTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pushLocationToOrder(),
    );

    // Start Foreground Service Tracking (Ghost Bike Fix)
    BackgroundLocationService().startTracking();
    debugPrint('[DeliveryNavigation] Location streaming & background service started.');
  }

  /// Stop streaming location (e.g. after delivery complete)
  void _stopLocationStreaming() {
    _locationStreamTimer?.cancel();
    _locationStreamTimer = null;

    // Stop Foreground Service Tracking
    BackgroundLocationService().stopTracking();
    debugPrint('[DeliveryNavigation] Location streaming & background service stopped.');
  }

  /// Get current destination based on step
  LatLng get _currentDestination {
    if (_currentStep == DeliveryStep.goingToRestaurant ||
        _currentStep == DeliveryStep.atRestaurant) {
      return widget.order.location; // Restaurant location
    }
    return widget.order.deliveryLocation; // Customer location
  }

  /// Get current destination name
  String get _destinationName {
    if (_currentStep == DeliveryStep.goingToRestaurant ||
        _currentStep == DeliveryStep.atRestaurant) {
      return widget.order.restaurantName;
    }
    return 'Customer';
  }

  /// Get current destination address
  String get _destinationAddress {
    if (_currentStep == DeliveryStep.goingToRestaurant ||
        _currentStep == DeliveryStep.atRestaurant) {
      return widget.order.restaurantAddress;
    }
    return widget.order.userAddress;
  }

  /// Get step indicator text
  String get _stepIndicator {
    switch (_currentStep) {
      case DeliveryStep.goingToRestaurant:
      case DeliveryStep.atRestaurant:
        return 'STEP 1: PICKUP';
      case DeliveryStep.goingToCustomer:
      case DeliveryStep.atCustomer:
        return 'STEP 2: DELIVER';
      case DeliveryStep.delivered:
        return 'COMPLETED';
    }
  }

  /// Get step indicator color
  Color get _stepColor {
    switch (_currentStep) {
      case DeliveryStep.goingToRestaurant:
      case DeliveryStep.atRestaurant:
        return AppColors.goldenMustard;
      case DeliveryStep.goingToCustomer:
      case DeliveryStep.atCustomer:
        return AppColors.emeraldGreen;
      case DeliveryStep.delivered:
        return AppColors.emeraldGreen;
    }
  }

  /// Phone number for current step (pickup → kitchen, delivery → customer).
  String? get _currentCallPhone {
    if (_currentStep == DeliveryStep.goingToRestaurant ||
        _currentStep == DeliveryStep.atRestaurant) {
      return widget.order.restaurantPhone;
    }
    return widget.order.userPhone;
  }

  Future<void> _callContact() async {
    final phone = _currentCallPhone;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
      return;
    }
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  /// Open Google Maps for navigation
  void _openNavigation() async {
    final success = await NavigationService.launchNavigation(
      _currentDestination,
      label: _destinationName,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open navigation. Please check if Google Maps is installed.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Handle navigation button press.
  /// Launches Google Maps. Does NOT auto-advance state — geofence does that
  /// when partner physically enters 200m radius, or manual button as fallback.
  void _handleNavigationButton() {
    _openNavigation();
  }

  /// Handle confirm button press.
  /// Module 3 flow: show OTP card; wait for cook/customer to verify on their
  /// app; status transitions happen server-side via RPC. We poll the row.
  Future<void> _handleConfirmButton() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (_currentStep == DeliveryStep.atRestaurant) {
        await _showPickupOtpAndWait();
      } else if (_currentStep == DeliveryStep.atCustomer) {
        await _showDeliveryOtpAndWait();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Fetch delivery_otp from delivery_orders (User DB's OTP synced via trigger).
  /// Pickup OTP is NOT fetched here — it lives only in Kitchen DB and is
  /// fetched via RPC get_pickup_otp_for_partner (see [_fetchPickupOtp]).
  Future<Map<String, String?>> _fetchOtps() async {
    final row = await Supabase.instance.client
        .from('delivery_orders')
        .select('delivery_otp, status')
        .eq('id', widget.order.id)
        .maybeSingle();
    return {
      'delivery_otp': row?['delivery_otp']?.toString(),
      'status': row?['status']?.toString(),
    };
  }

  /// Fetch pickup OTP cross-DB from Kitchen DB via auth-guarded RPC.
  /// Returns null + shows snackbar on error (caller should abort).
  Future<String?> _fetchPickupOtp() async {
    final kitchen = DatabaseService().kitchenDb;
    if (kitchen == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kitchen DB unreachable — check connection.')),
        );
      }
      return null;
    }
    final partnerId = Supabase.instance.client.auth.currentUser?.id;
    if (partnerId == null) return null;

    try {
      final result = await kitchen.rpc(
        'get_pickup_otp_for_partner',
        params: {
          'p_order_id': widget.order.id,
          'p_partner_id': partnerId,
        },
      );
      if (result == null) return null;
      return result.toString();
    } catch (e) {
      final msg = e.toString();
      String friendly = 'Could not fetch pickup OTP.';
      if (msg.contains('not_your_order')) {
        friendly = 'This order is not assigned to you.';
      } else if (msg.contains('order_not_assigned')) {
        friendly = 'Order not yet assigned — try Accept again.';
      } else if (msg.contains('no_otp_set')) {
        friendly = 'Kitchen has not generated OTP yet — try again in a few seconds.';
      } else if (msg.contains('order_not_found')) {
        friendly = 'Order not found in kitchen records.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendly)));
      }
      return null;
    }
  }

  /// Poll delivery_orders.status until it matches [target] or timeout.
  /// Uses exponential backoff (3s → 6s → 12s → 30s max) to reduce DB load.
  Future<bool> _pollForStatus(String target, {int maxSeconds = 180}) async {
    final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
    int delaySeconds = 3; // Start with 3s
    while (DateTime.now().isBefore(deadline)) {
      if (!mounted) return false;
      await Future.delayed(Duration(seconds: delaySeconds));
      try {
        final row = await Supabase.instance.client
            .from('delivery_orders')
            .select('status')
            .eq('id', widget.order.id)
            .maybeSingle();
        if (row?['status']?.toString() == target) return true;
      } catch (e) {
        debugPrint('[DeliveryNav] poll error: $e');
      }
      delaySeconds = min(delaySeconds * 2, 30); // Exponential backoff, cap at 30s
    }
    return false;
  }

  Future<void> _showPickupOtpAndWait() async {
    final pickupOtp = await _fetchPickupOtp();
    if (pickupOtp == null || pickupOtp.isEmpty) {
      // Error snackbar already shown by _fetchPickupOtp.
      return;
    }

    if (!mounted) return;

    // Launch the poll CONCURRENTLY with the dialog — not after it closes.
    // When cook verifies (status=picked_up), we auto-dismiss the dialog.
    bool cookVerified = false;
    final dialogCompleter = Completer<void>();

    // Start polling in background
    _pollForStatus('picked_up').then((verified) {
      cookVerified = verified;
      // Auto-close dialog if it's still open
      if (!dialogCompleter.isCompleted) {
        dialogCompleter.complete();
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Dismiss the OTP dialog
        }
      }
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OtpDisplayCard(
              label: 'PICKUP OTP',
              otp: pickupOtp,
              instruction: 'Read this code to the cook. They will verify it in their app.',
              accent: AppColors.emeraldGreen,
              icon: Icons.restaurant,
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Waiting for cook to verify…'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!dialogCompleter.isCompleted) dialogCompleter.complete();
              Navigator.of(ctx).pop();
            },
            child: const Text('Hide'),
          ),
        ],
      ),
    );

    // Mark completer as done if dialog was manually closed
    if (!dialogCompleter.isCompleted) dialogCompleter.complete();

    // Wait for the poll if dialog was closed manually (Hide button)
    if (!cookVerified) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still waiting for cook verification. We\'ll notify you when done.'),
          backgroundColor: AppColors.goldenMustard,
        ),
      );
      // Continue polling in background
      cookVerified = await _pollForStatus('picked_up');
    }

    if (!mounted) return;

    if (!cookVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cook has not verified yet. Tap Confirm Pickup again when ready.')),
      );
      return;
    }

    // Transition to out_for_delivery + start GPS streaming
    final pos = LocationService.currentLocation.value;
    await OrderService.updateOrderStatus(
      widget.order.id,
      OrderStatus.outForDelivery,
      previousStatus: 'picked_up',
      latitude: pos?.latitude,
      longitude: pos?.longitude,
    );
    _startLocationStreaming();

    if (!mounted) return;
    setState(() => _currentStep = DeliveryStep.goingToCustomer);

    // Re-arm geofence around customer address (200m auto-detect).
    _armGeofenceForCurrentStep();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Pickup verified! Navigating to customer…'),
        backgroundColor: AppColors.emeraldGreen,
      ),
    );

    // Auto-launch Maps to customer.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _openNavigation();
  }

  /// Delivery OTP Verification — Agent ENTERS the code the customer reads aloud.
  /// The correct flow: Customer sees OTP in User App → reads it to agent →
  /// agent types it here → verified against stored delivery_otp → delivery complete.
  Future<void> _showDeliveryOtpAndWait() async {
    String? storedOtp;
    try {
      final otps = await _fetchOtps();
      storedOtp = otps['delivery_otp'];
    } catch (e) {
      // Offline fallback: Use the OTP that was cached in the order model when it was assigned
      storedOtp = widget.order.deliveryOtp;
    }

    if (storedOtp == null || storedOtp.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery OTP not found. Ask customer to generate it or check your connection.')),
      );
      return;
    }

    if (!mounted) return;

    final otpController = TextEditingController();
    String? errorText;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.all(24),
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.goldenMustard.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppColors.goldenMustard,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Enter Delivery OTP',
                    style: AppTypography.headingStyle(
                      color: isDark ? AppColors.textLight : AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask the customer to read the 4-digit code from their app',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyStyle(
                      color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
                      size: 13,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // OTP Input Field — 4 digits only
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    autofocus: true,
                    style: AppTypography.headingStyle(
                      color: isDark ? AppColors.textLight : AppColors.textPrimary,
                      size: 32,
                    ).copyWith(letterSpacing: 16),
                    decoration: InputDecoration(
                      hintText: '• • • •',
                      hintStyle: AppTypography.headingStyle(
                        color: isDark
                            ? AppColors.textLightSecondary.withValues(alpha: 0.3)
                            : AppColors.textTertiary,
                        size: 32,
                      ).copyWith(letterSpacing: 16),
                      counterText: '',
                      errorText: errorText,
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: errorText != null ? AppColors.error : AppColors.borderSubtle,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.emeraldGreen,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.error, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final enteredOtp = otpController.text.trim();
                        if (enteredOtp.length != 4) {
                          setDialogState(() => errorText = 'Enter the full 4-digit code');
                          return;
                        }
                        if (enteredOtp != storedOtp) {
                          setDialogState(() => errorText = 'Incorrect OTP. Ask the customer again.');
                          otpController.clear();
                          return;
                        }
                        // OTP matches!
                        Navigator.of(ctx).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Verify & Complete Delivery',
                        style: AppTypography.bodyStyle(
                          color: Colors.white,
                          weight: FontWeight.w700,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (verified != true || !mounted) return;

    if (!await _confirmCashCollectedIfNeeded()) {
      return;
    }

    final isOffline = await OfflineSyncService.isOffline();
        
    if (isOffline) {
      // Elevator Mode: Queue the completion for background sync
      await OfflineSyncService().queueDeliveryCompletion(
        orderId: widget.order.id,
        deliveryFee: widget.order.deliveryFee,
        isCod: widget.order.isCashOnDelivery,
        codAmount: widget.order.totalAmount,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📶 Network offline. Delivery saved locally and will sync automatically!'),
          backgroundColor: AppColors.goldenMustard,
        ),
      );
    } else {
      // Online Mode: Process normally
      await OrderService.updateOrderStatus(
        widget.order.id,
        OrderStatus.delivered,
        previousStatus: 'out_for_delivery',
        isCod: widget.order.isCashOnDelivery,
        orderTotal: widget.order.totalAmount,
      );

      final credited = await EarningsCreditService.creditForCompletedDelivery(
        widget.order.id,
      );

      if (!mounted) return;

      if (credited != null && credited > 0) {
        setState(() => _creditedEarnings = credited);
      }
    }

    if (!mounted) return;
    setState(() {
      _currentStep = DeliveryStep.delivered;
    });

    _stopLocationStreaming();
    _showCompletionDialog();
  }

  Future<bool> _confirmCashCollectedIfNeeded() async {
    final isCod = widget.order.isCashOnDelivery;
    if (!isCod) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          title: Text(
            'Confirm Cash Collected',
            style: AppTypography.headingStyle(
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
              size: 18,
            ),
          ),
          content: Text(
            'This order is marked as Cash on Delivery. Confirm that you have collected ₹${widget.order.totalAmount.toStringAsFixed(2)} from the customer before completing delivery.',
            style: AppTypography.bodyStyle(
              color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
              size: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cash Collected'),
            ),
          ],
        );
      },
    );

    if (confirmed != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery paused until cash is confirmed.'),
          backgroundColor: AppColors.goldenMustard,
        ),
      );
    }

    return confirmed == true;
  }

  void _showCompletionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: AppConstants.borderRadiusXL,
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.emeraldGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.emeraldGreen,
                size: 56,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Delivery Completed!',
              style: AppTypography.headingStyle(
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
                size: 22,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.goldGradient,
                ),
                borderRadius: AppConstants.borderRadiusMedium,
              ),
              child: Text(
                '₹${(_creditedEarnings ?? widget.order.earnings).toInt()}',
                style: AppTypography.headingStyle(
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Added to your earnings',
              style: AppTypography.captionStyle(
                color: isDark
                    ? AppColors.textLightSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          LargeButton(
            text: 'Back to Home',
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to Home
            },
            type: LargeButtonType.primary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // FULL SCREEN MAP
          Positioned.fill(
            child: OpenStreetMapWidget(
              orders: const [],
              highlightedDestination: _currentDestination,
              highlightedLabel: _destinationName,
              showControls: false,
            ),
          ),

          // Top Bar - Back button + Step indicator
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: AppConstants.borderRadiusMedium,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowMedium,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Step indicator
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _stepColor,
                        borderRadius: AppConstants.borderRadiusCircular,
                        boxShadow: [
                          BoxShadow(
                            color: _stepColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _stepIndicator,
                        style: AppTypography.labelStyle(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Call button (kitchen or customer based on step)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen,
                      borderRadius: AppConstants.borderRadiusMedium,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldGreen.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _callContact,
                      tooltip: 'Call',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Panel - Destination info + Actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Destination Name
                    Text(
                      _destinationName,
                      style: AppTypography.headingStyle(
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Destination Address
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 15,
                          color: isDark
                              ? AppColors.textLightSecondary
                              : AppColors.mediumGrey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _destinationAddress,
                            style: AppTypography.bodyStyle(
                              color: isDark
                                  ? AppColors.textLightSecondary
                                  : AppColors.textSecondary,
                              size: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Order Info Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(
                          Icons.schedule_rounded,
                          '${widget.order.estimatedTime} min',
                          isDark,
                        ),
                        _buildInfoItem(
                          Icons.route_rounded,
                          '${widget.order.distance} km',
                          isDark,
                        ),
                        _buildInfoItem(
                          Icons.currency_rupee_rounded,
                          '${widget.order.earnings.toInt()}',
                          isDark,
                          isHighlighted: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Action Buttons
                    if (_currentStep == DeliveryStep.goingToRestaurant ||
                        _currentStep == DeliveryStep.goingToCustomer) ...[
                      LargeButton(
                        text: 'Open in Google Maps',
                        icon: Icons.navigation_rounded,
                        onPressed: _handleNavigationButton,
                        type: LargeButtonType.primary,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          _cancelGeofence?.call();
                          _geofenceReachedForStep = true;
                          setState(() {
                            _currentStep = _currentStep == DeliveryStep.goingToRestaurant
                                ? DeliveryStep.atRestaurant
                                : DeliveryStep.atCustomer;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _handleConfirmButton();
                          });
                        },
                        icon: const Icon(Icons.flag_rounded),
                        label: Text(
                          _currentStep == DeliveryStep.goingToRestaurant
                              ? "I've Reached Kitchen"
                              : "I've Reached Customer",
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AppColors.emeraldGreen),
                          foregroundColor: AppColors.emeraldGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ] else
                      LargeButton(
                        text: _currentStep == DeliveryStep.atRestaurant
                            ? 'Show Pickup OTP'
                            : 'Enter Customer OTP',
                        icon: _currentStep == DeliveryStep.atRestaurant
                            ? Icons.qr_code_rounded
                            : Icons.pin_rounded,
                        onPressed: _handleConfirmButton,
                        type: LargeButtonType.primary,
                      ),
                  ],
                ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String text,
    bool isDark, {
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.goldenMustard.withValues(alpha: 0.08)
            : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
        borderRadius: AppConstants.borderRadiusMedium,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color:
                isHighlighted ? AppColors.goldenMustard : AppColors.mediumGrey,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: AppTypography.bodyStyle(
              color: isHighlighted
                  ? AppColors.goldenMustard
                  : (isDark ? AppColors.textLight : AppColors.textPrimary),
              weight: FontWeight.w600,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}
