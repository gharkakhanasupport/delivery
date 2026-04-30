import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';

import '../services/location_service.dart';

/// Premium permission request screen with animated checklist
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin {
  Map<String, bool> _permissionStatus = {
    'location': false,
    'phone': false,
    'notification': false,
  };

  bool _isChecking = true;
  bool _isLocationServiceEnabled = true;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _checkPermissions();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission locationPerm = await Geolocator.checkPermission();
    bool locationGranted =
        locationPerm == LocationPermission.always ||
        locationPerm == LocationPermission.whileInUse;

    bool phoneGranted = false;
    try {
      phoneGranted = await Permission.phone.isGranted.timeout(
        const Duration(milliseconds: 2000),
        onTimeout: () => false,
      );
    } catch (e) {
      phoneGranted = false;
    }

    bool notificationGranted = false;
    try {
      notificationGranted = await Permission.notification.isGranted.timeout(
        const Duration(milliseconds: 2000),
        onTimeout: () => false,
      );
    } catch (e) {
      notificationGranted = false;
    }

    if (!mounted) return;

    setState(() {
      _isLocationServiceEnabled = locationServiceEnabled;
      _permissionStatus = {
        'location': locationGranted && locationServiceEnabled,
        'phone': phoneGranted,
        'notification': notificationGranted,
      };
      _isChecking = false;
    });

    if (_areAllGranted()) {
      await LocationService.initialize();
      _navigateToMain();
    }
  }

  bool _areAllGranted() {
    return !_permissionStatus.containsValue(false);
  }

  Future<void> _requestLocationPermission() async {
    if (!_isLocationServiceEnabled) {
      await Geolocator.openLocationSettings();
      await _checkPermissions();
      return;
    }

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showPermissionPermanentlyDeniedDialog('Location');
      }
    }
    await _checkPermissions();
  }

  Future<void> _requestPhonePermission() async {
    PermissionStatus status = await Permission.phone.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionPermanentlyDeniedDialog('Phone');
      }
    }
    await _checkPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionPermanentlyDeniedDialog('Notification');
      }
    }
    await _checkPermissions();
  }

  void _showPermissionPermanentlyDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
            'This permission is required for the app to function correctly. Please enable it in the system settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestAllPermissions() async {
    if (!_permissionStatus['location']!) await _requestLocationPermission();
    if (!_permissionStatus['phone']!) await _requestPhonePermission();
    if (!_permissionStatus['notification']!) await _requestNotificationPermission();
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AppConstants.durationMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isChecking) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.emeraldGreen,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    final grantedCount = _permissionStatus.values.where((v) => v).length;
    final allGranted = _areAllGranted();

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,

      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
              width: 1,
            ),
          ),
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: allGranted ? _navigateToMain : _requestAllPermissions,
            style: ElevatedButton.styleFrom(
              backgroundColor: allGranted
                  ? AppColors.emeraldGreen
                  : (isDark ? AppColors.darkSurface : AppColors.textPrimary),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppConstants.borderRadiusLarge,
              ),
            ),
            child: Text(
              allGranted ? 'Continue' : 'Grant All Permissions',
              style: AppTypography.bodyStyle(
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOut,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // Shield icon
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 36,
                      color: AppColors.emeraldGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Permissions Required',
                  textAlign: TextAlign.center,
                  style: AppTypography.headingStyle(
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'We need these to ensure seamless deliveries',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyStyle(
                    color: isDark
                        ? AppColors.textLightSecondary
                        : AppColors.textSecondary,
                    size: 14,
                  ),
                ),
                const SizedBox(height: 12),

                // Progress indicator
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.08),
                      borderRadius: AppConstants.borderRadiusCircular,
                    ),
                    child: Text(
                      '$grantedCount of 3 granted',
                      style: AppTypography.captionStyle(
                        color: AppColors.emeraldGreen,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Location Service Warning
                if (!_isLocationServiceEnabled)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.08),
                      borderRadius: AppConstants.borderRadiusMedium,
                      border: Border.all(
                        color: AppColors.accentOrange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_off_rounded,
                            color: AppColors.accentOrange, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Location Services are disabled. Tap the location item below to enable.',
                            style: AppTypography.captionStyle(
                              color: AppColors.accentOrange,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Permission items
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPermissionTile(
                          key: 'location',
                          icon: Icons.my_location_rounded,
                          title: 'Location Access',
                          subtitle: _isLocationServiceEnabled
                              ? 'Track routes & nearby orders'
                              : 'Location Services are OFF',
                          onRequest: _requestLocationPermission,
                          isDark: isDark,
                          staggerIndex: 0,
                        ),
                        _buildPermissionTile(
                          key: 'phone',
                          icon: Icons.phone_rounded,
                          title: 'Phone Access',
                          subtitle: 'Call customers for delivery',
                          onRequest: _requestPhonePermission,
                          isDark: isDark,
                          staggerIndex: 1,
                        ),
                        _buildPermissionTile(
                          key: 'notification',
                          icon: Icons.notifications_rounded,
                          title: 'Notifications',
                          subtitle: 'Receive order alerts instantly',
                          onRequest: _requestNotificationPermission,
                          isDark: isDark,
                          staggerIndex: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bottom security label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: isDark
                          ? AppColors.textLightSecondary
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your data is encrypted and secure',
                      style: AppTypography.captionStyle(
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onRequest,
    required bool isDark,
    required int staggerIndex,
  }) {
    final isGranted = _permissionStatus[key] ?? false;

    return AnimatedContainer(
      duration: AppConstants.durationStandard,
      curve: AppConstants.curveStandard,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isGranted
            ? AppColors.emeraldGreen.withValues(alpha: isDark ? 0.08 : 0.05)
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isGranted
              ? AppColors.emeraldGreen.withValues(alpha: 0.3)
              : (isDark ? AppColors.borderDark : AppColors.borderSubtle),
          width: isGranted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Icon
              AnimatedContainer(
                duration: AppConstants.durationStandard,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGranted
                      ? AppColors.emeraldGreen.withValues(alpha: 0.12)
                      : (isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.5)
                          : AppColors.lightSurface),
                  borderRadius: AppConstants.borderRadiusMedium,
                ),
                child: Icon(
                  icon,
                  color: isGranted
                      ? AppColors.emeraldGreen
                      : (isDark
                          ? AppColors.textLightSecondary
                          : AppColors.mediumGrey),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyStyle(
                        color: isDark ? AppColors.textLight : AppColors.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.captionStyle(
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Status (Checkmark if granted)
              if (isGranted)
                AnimatedSwitcher(
                  duration: AppConstants.durationStandard,
                  switchInCurve: Curves.elasticOut,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.emeraldGreen,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),

          // Action Button below text if NOT granted
          if (!isGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.darkSurface
                      : AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppConstants.borderRadiusCircular,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Allow $title Access',
                  style: AppTypography.captionStyle(
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

}
