import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../models/delivery_agent.dart';
import '../services/delivery_agent_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../widgets/main_navigation.dart';

/// Verification Pending Screen - Shown after signup while documents are reviewed
class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  VerificationStatus? _currentStatus;
  late AnimationController _animController;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _checkStatus();

    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    final agent = await DeliveryAgentService.fetchCurrentProfile();
    if (mounted) {
      if (agent?.verificationStatus == VerificationStatus.verified) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
        return;
      }
      setState(() {
        _isChecking = false;
        _currentStatus = agent?.verificationStatus;
      });
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri.parse('https://gharkakhana.delivery/legal/contact');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _currentStatus ?? VerificationStatus.underReview;
    final isRejected = status == VerificationStatus.rejected;

    final accentColor =
        isRejected ? AppColors.error : AppColors.emeraldGreen;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
      appBar: AppBar(
        title: Text(
          'Account Status',
          style: AppTypography.titleStyle(
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22),
            color: AppColors.error,
            onPressed: () {
              AuthService.signOut(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.responsivePadding(context),
              vertical: 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated illustration
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.15),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 52,
                          color: accentColor.withValues(alpha: 0.25),
                        ),
                        Positioned(
                          right: 20,
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isRejected
                                  ? Icons.close_rounded
                                  : Icons.hourglass_empty_rounded,
                              size: 28,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  isRejected
                      ? 'Application Rejected'
                      : 'Verification in Progress',
                  style: AppTypography.headingStyle(
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.06),
                    borderRadius: AppConstants.borderRadiusLarge,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isRejected
                            ? 'Unfortunately, your application does not meet our requirements. Please contact support for more details.'
                            : 'We are verifying your documents.\nThis usually takes 24–48 hours.',
                        style: AppTypography.bodyStyle(
                          color: isDark
                              ? AppColors.textLightSecondary
                              : AppColors.textSecondary,
                          size: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!isRejected) ...[
                        const SizedBox(height: 16),
                        // Progress steps
                        _buildProgressSteps(isDark),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Check Status Button (only for pending)
                if (!isRejected) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isChecking ? null : _checkStatus,
                      icon: _isChecking
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark
                                    ? AppColors.textLightSecondary
                                    : AppColors.textSecondary,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              color: isDark
                                  ? AppColors.textLightSecondary
                                  : AppColors.textSecondary,
                            ),
                      label: Text(
                        _isChecking ? 'Checking...' : 'Check Status',
                        style: AppTypography.bodyStyle(
                          color: isDark
                              ? AppColors.textLightSecondary
                              : AppColors.textSecondary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderSubtle,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppConstants.borderRadiusMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Contact Support Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isRejected
                            ? [AppColors.error, const Color(0xFFB71C1C)]
                            : AppColors.primaryGradient,
                      ),
                      borderRadius: AppConstants.borderRadiusMedium,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _contactSupport,
                      icon: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: Text(
                        'Contact Support',
                        style: AppTypography.bodyStyle(
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppConstants.borderRadiusMedium,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Info text
                AnimatedBuilder(
                  animation: _fadeAnim,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnim.value,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 15,
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'You\'ll be notified once verified',
                            style: AppTypography.captionStyle(
                              color: isDark
                                  ? AppColors.textLightSecondary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Visual progress steps for document review
  Widget _buildProgressSteps(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStep(
          'Submitted',
          isComplete: true,
          isDark: isDark,
        ),
        _buildStepConnector(isComplete: true, isDark: isDark),
        _buildStep(
          'Under Review',
          isComplete: false,
          isCurrent: true,
          isDark: isDark,
        ),
        _buildStepConnector(isComplete: false, isDark: isDark),
        _buildStep(
          'Approved',
          isComplete: false,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStep(
    String label, {
    required bool isDark,
    bool isComplete = false,
    bool isCurrent = false,
  }) {
    final color = isComplete
        ? AppColors.emeraldGreen
        : isCurrent
            ? AppColors.goldenMustard
            : (isDark ? AppColors.mediumGrey : AppColors.lightGrey);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(
            isComplete ? Icons.check_rounded : Icons.circle,
            size: isComplete ? 16 : 6,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.captionStyle(
            color: isCurrent
                ? (isDark ? AppColors.textLight : AppColors.textPrimary)
                : (isDark ? AppColors.textLightSecondary : AppColors.textSecondary),
            weight: isCurrent ? FontWeight.w600 : FontWeight.w400,
          ).copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildStepConnector({
    required bool isComplete,
    required bool isDark,
  }) {
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
      color: isComplete
          ? AppColors.emeraldGreen
          : (isDark ? AppColors.mediumGrey.withValues(alpha: 0.3) : AppColors.lightGrey),
    );
  }
}
