import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../services/auth_service.dart';
import '../widgets/main_navigation.dart';
import 'verification_pending_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.verifyEmailOtp(widget.email, otp);
      if (user != null && mounted) {
        if (AuthService.isVerified.value) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const VerificationPendingScreen(),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification Failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.responsivePadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Back + title
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard
                          : AppColors.lightSurface,
                      borderRadius: AppConstants.borderRadiusMedium,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Verify OTP',
                    style: AppTypography.headingStyle(
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Lock icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.emeraldGreen.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 44,
                  color: AppColors.emeraldGreen,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Enter the code sent to',
                style: AppTypography.bodyStyle(
                  color: isDark
                      ? AppColors.textLightSecondary
                      : AppColors.textSecondary,
                  size: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: AppTypography.titleStyle(
                  color: isDark
                      ? AppColors.textLight
                      : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // OTP Input
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppTypography.headingStyle(
                  color: isDark
                      ? AppColors.textLight
                      : AppColors.textPrimary,
                  size: 28,
                ).copyWith(letterSpacing: 14),
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: AppTypography.headingStyle(
                    color: isDark
                        ? AppColors.textLightSecondary.withValues(alpha: 0.2)
                        : AppColors.textTertiary,
                    size: 28,
                  ).copyWith(letterSpacing: 14, fontWeight: FontWeight.w300),
                  counterText: '',
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkCard
                      : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: AppConstants.borderRadiusLarge,
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderSubtle,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppConstants.borderRadiusLarge,
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderSubtle,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppConstants.borderRadiusLarge,
                    borderSide: const BorderSide(
                      color: AppColors.emeraldGreen,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),

              const SizedBox(height: 28),

              // Verify button
              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                    color: _isLoading
                        ? (isDark
                            ? AppColors.darkSurface
                            : AppColors.lightGrey)
                        : null,
                    borderRadius: AppConstants.borderRadiusMedium,
                    boxShadow: _isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.emeraldGreen
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppConstants.borderRadiusMedium,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.emeraldGreen,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Verify',
                            style: AppTypography.bodyStyle(
                              color: Colors.white,
                              weight: FontWeight.w600,
                              size: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
