import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';
import 'registration/basic_details_screen.dart';
import 'otp_verification_screen.dart';


/// Premium Login Screen with gradient background and floating card layout
/// Clean, easy-to-understand flow with proper validation and loading states
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isGoogleLoading = false;
  bool _isEmailLoading = false;
  bool _isValidEmail = false;
  bool _rememberMe = true;
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _entranceController;
  late Animation<double> _logoAnim;
  late Animation<double> _cardAnim;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);

    // Staggered entrance animation
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _logoAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    );
    _cardAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_cardAnim);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  /// Real-time email validation (check for @ symbol)
  void _validateEmail() {
    final email = _emailController.text.trim();
    final isValid =
        email.isNotEmpty &&
        email.contains('@') &&
        email.indexOf('@') > 0 &&
        email.indexOf('@') < email.length - 1;

    if (isValid != _isValidEmail) {
      setState(() => _isValidEmail = isValid);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
      
      final user = await AuthService.signInWithGoogle();

      if (user != null && mounted) {
        ErrorHandler.triggerAcceptHaptic();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BasicDetailsScreen(googleUser: user),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorBanner(
          context,
          message: 'Sign-in failed. Please try again.',
          onRetry: _signInWithGoogle,
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_isValidEmail) {
      ErrorHandler.showErrorSnackbar(
        context,
        'Please enter a valid email address',
      );
      return;
    }

    final email = _emailController.text.trim();

    setState(() => _isEmailLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);

      await AuthService.signInWithVerifiedEmail(email);
      if (mounted) {
        ErrorHandler.triggerAcceptHaptic();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(email: email),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorBanner(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          onRetry: _signInWithEmail,
        );
      }
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  /// Open URL in external browser
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnyLoading = _isGoogleLoading || _isEmailLoading;

    return Scaffold(

      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.heroGradient,
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppConstants.responsivePadding(context),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: constraints.maxHeight * 0.08),

                        // Logo section
                        FadeTransition(
                          opacity: _logoAnim,
                          child: _buildLogoSection(),
                        ),

                        SizedBox(height: constraints.maxHeight * 0.06),

                        // Login card
                        SlideTransition(
                          position: _cardSlide,
                          child: FadeTransition(
                            opacity: _cardAnim,
                            child: _buildLoginCard(isAnyLoading),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Remember Me Checkbox
                        FadeTransition(
                          opacity: _cardAnim,
                          child: _buildRememberMeCheckbox(Theme.of(context).brightness == Brightness.dark),
                        ),

                        const SizedBox(height: 16),

                        // Terms text
                        FadeTransition(
                          opacity: _cardAnim,
                          child: _buildTermsText(),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Logo with glow
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.emeraldGreen.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.delivery_dining_rounded,
            size: 44,
            color: AppColors.emeraldGreen,
          ),
        ),
        const SizedBox(height: 20),

        // App name
        Text(
          'GKK Delivery',
          style: AppTypography.headingStyle(
            color: AppColors.textLight,
            size: 30,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: AppConstants.borderRadiusCircular,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            'DELIVERY PARTNER',
            style: AppTypography.labelStyle(
              color: AppColors.textLightSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(bool isAnyLoading) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: AppConstants.borderRadiusXXL,
        border: Border.all(
          color: isDark
              ? AppColors.borderDark
              : Colors.white.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Welcome text
          Text(
            'Welcome',
            style: AppTypography.headingStyle(
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to start delivering',
            style: AppTypography.bodyStyle(
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.textSecondary,
              size: 14,
            ),
          ),
          const SizedBox(height: 28),

          // Google Sign In
          _buildGoogleButton(isAnyLoading, isDark),
          const SizedBox(height: 20),

          // OR divider
          _buildOrDivider(isDark),
          const SizedBox(height: 20),

          // Email Form
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildEmailField(isDark),
                const SizedBox(height: 14),
                _buildEmailButton(isAnyLoading, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(bool isAnyLoading, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: isAnyLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppConstants.borderRadiusLarge,
          ),
          backgroundColor: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.5)
              : Colors.white,
        ),
        child: _isGoogleLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" icon
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 28,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: AppTypography.bodyStyle(
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      weight: FontWeight.w600,
                      size: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildOrDivider(bool isDark) {
    final lineColor = isDark
        ? AppColors.borderDark
        : AppColors.lightGrey;

    return Row(
      children: [
        Expanded(child: Container(height: 1, color: lineColor)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.5)
                : AppColors.lightSurface,
            borderRadius: AppConstants.borderRadiusCircular,
          ),
          child: Text(
            'OR',
            style: AppTypography.labelStyle(
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: lineColor)),
      ],
    );
  }

  Widget _buildEmailField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Agent Email',
            style: AppTypography.bodyStyle(
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.textSecondary,
              size: 13,
              weight: FontWeight.w500,
            ),
          ),
        ),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signInWithEmail(),
          style: AppTypography.bodyStyle(
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'yourname@example.com',
            hintStyle: AppTypography.bodyStyle(
              color: isDark
                  ? AppColors.textLightSecondary.withValues(alpha: 0.4)
                  : AppColors.textTertiary,
            ),
            filled: true,
            fillColor: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.5)
                : AppColors.lightSurface,
            prefixIcon: Icon(
              Icons.email_outlined,
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.mediumGrey,
              size: 20,
            ),
            suffixIcon: AnimatedSwitcher(
              duration: AppConstants.durationFast,
              child: _isValidEmail
                  ? const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.emeraldGreen,
                        size: 22,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            border: OutlineInputBorder(
              borderRadius: AppConstants.borderRadiusMedium,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppConstants.borderRadiusMedium,
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppConstants.borderRadiusMedium,
              borderSide: const BorderSide(
                color: AppColors.emeraldGreen,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailButton(bool isAnyLoading, bool isDark) {
    final isDisabled = isAnyLoading || !_isValidEmail;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: AppConstants.durationStandard,
        decoration: BoxDecoration(
          gradient: _isValidEmail
              ? const LinearGradient(colors: AppColors.primaryGradient)
              : null,
          color: _isValidEmail
              ? null
              : (isDark
                  ? AppColors.darkSurface
                  : AppColors.lightGrey.withValues(alpha: 0.5)),
          borderRadius: AppConstants.borderRadiusLarge,
          boxShadow: _isValidEmail
              ? [
                  BoxShadow(
                    color: AppColors.emeraldGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: isDisabled ? null : _signInWithEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: AppConstants.borderRadiusLarge,
            ),
          ),
          child: _isEmailLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue with Email',
                      style: AppTypography.bodyStyle(
                        color: _isValidEmail
                            ? Colors.white
                            : (isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textTertiary),
                        weight: FontWeight.w600,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: _isValidEmail
                          ? Colors.white
                          : (isDark
                              ? AppColors.textLightSecondary
                              : AppColors.textTertiary),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRememberMeCheckbox(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Theme(
          data: ThemeData(
            unselectedWidgetColor: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
          ),
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) {
              setState(() {
                _rememberMe = value ?? true;
              });
            },
            activeColor: AppColors.emeraldGreen,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _rememberMe = !_rememberMe;
            });
          },
          child: Text(
            'Remember me',
            style: AppTypography.bodyStyle(
              color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsText() {
    return Column(
      children: [
        Text(
          'By continuing, you agree to our',
          style: AppTypography.captionStyle(
            color: AppColors.textLightSecondary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () =>
                  _openUrl('https://gharkakhana.delivery/legal/terms'),
              child: Text(
                'Terms of Service',
                style: AppTypography.captionStyle(
                  color: AppColors.textLightSecondary,
                  weight: FontWeight.w600,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textLightSecondary,
                ),
              ),
            ),
            Text(
              '  and  ',
              style: AppTypography.captionStyle(
                color: AppColors.textLightSecondary.withValues(alpha: 0.5),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  _openUrl('https://gharkakhana.delivery/legal/privacy'),
              child: Text(
                'Privacy Policy',
                style: AppTypography.captionStyle(
                  color: AppColors.textLightSecondary,
                  weight: FontWeight.w600,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textLightSecondary,
                ),
              ),
            ),
          ],
        ),

      ],
    );
  }
}
