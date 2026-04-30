import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../services/auth_service.dart';
import '../services/delivery_agent_service.dart';
import '../models/delivery_agent.dart';
import 'permission_screen.dart';
import 'login_screen.dart';
import '../widgets/main_navigation.dart';
import 'verification_pending_screen.dart';

/// Animated splash screen with gradient background and logo animation
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _loaderOpacity;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();

    // Status bar for splash
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Logo entrance animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.6, 0.85, curve: Curves.easeOut),
      ),
    );
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    // Fade-out animation for transition
    _fadeController = AnimationController(
      vsync: this,
      duration: AppConstants.durationStandard,
    );

    _logoController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Ensure minimum splash display time
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    setState(() => _isInitializing = false);

    // Check authentication state
    final isLoggedIn = AuthService.isAuthenticated;

    if (!isLoggedIn) {
      _navigateTo(const PermissionScreen());
      return;
    }

    // Check if profile is complete
    try {
      final agent = await DeliveryAgentService.fetchCurrentProfile();
      if (agent == null) {
        _navigateTo(const PermissionScreen());
      } else if (!agent.isProfileComplete) {
        _navigateTo(const LoginScreen());
      } else if (agent.verificationStatus != VerificationStatus.verified) {
        _navigateTo(const VerificationPendingScreen());
      } else {
        _navigateTo(const MainNavigation());
      }
    } catch (e) {
      _navigateTo(const PermissionScreen());
    }
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AppConstants.durationMedium,
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradient,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Logo with scale + opacity animation
                  Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.emeraldGreen.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emeraldGreen.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          size: 52,
                          color: AppColors.emeraldGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // App name
                  Opacity(
                    opacity: _textOpacity.value,
                    child: Text(
                      'GKK Delivery',
                      style: AppTypography.displayStyle(
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Opacity(
                    opacity: _subtitleOpacity.value,
                    child: Text(
                      'Partner App',
                      style: AppTypography.bodyStyle(
                        color: AppColors.textLightSecondary,
                        size: 18,
                        weight: FontWeight.w300,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Loading indicator
                  Opacity(
                    opacity: _loaderOpacity.value,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.emeraldGreen.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: AppConstants.durationStandard,
                          child: Text(
                            _isInitializing ? 'Setting up...' : 'Almost ready...',
                            key: ValueKey(_isInitializing),
                            style: AppTypography.captionStyle(
                              color: AppColors.textLightSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Bottom branding
                  Opacity(
                    opacity: _subtitleOpacity.value,
                    child: Text(
                      'GHAR KA KHANAA',
                      style: AppTypography.overlineStyle(
                        color: AppColors.textLightSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
