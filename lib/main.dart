import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/colors.dart';
import 'constants/typography.dart';
import 'firebase_options.dart';
import 'services/theme_service.dart';
import 'services/tile_cache_service.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/fcm_service.dart';
import 'services/offline_sync_service.dart';
import 'services/background_location_service.dart';
import 'screens/splash_screen.dart';
import 'widgets/theme_animation_overlay.dart';

/// Global navigator key — used by FCM handler to show incoming order sheet
/// without needing a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Firebase (required for firebase_auth + FCM)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase init failed: $e');
  }

  // Initialize Database Service (Handles Primary & Future Secondary DBs)
  await DatabaseService.initialize();

  // Initialize map tile caching for offline support & faster loading
  await TileCacheService.initialize();

  // Initialize Auth Service to start listening to auth changes
  AuthService(); // This triggers the singleton instantiation and listener setup

  // Initialize FCM push notifications (non-blocking)
  // Token registration happens after partner logs in via home screen.
  FCMService().initialize();

  // Initialize Offline Elevator Mode Sync
  OfflineSyncService().initialize();

  // Background GPS Tracking — disabled at startup, will be started when delivery begins
  // BackgroundLocationService init causes JNI crashes on emulator
  // await BackgroundLocationService().initialize();

  // Check 'Remember Me' preference
  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('remember_me') ?? true; // default to true
  if (!rememberMe) {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const GKKDeliveryApp());
}

class GKKDeliveryApp extends StatelessWidget {
  const GKKDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, currentMode, child) {
        return ThemeAnimationOverlay(
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'GKK Delivery Partner',
            debugShowCheckedModeBanner: false,
            themeMode: currentMode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const SplashScreen(),
          ),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.emeraldGreen,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.emeraldGreen,
        primary: AppColors.emeraldGreen,
        secondary: AppColors.goldenMustard,
        surface: AppColors.lightCard,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      cardColor: AppColors.lightCard,
      dividerColor: AppColors.borderSubtle,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: AppTypography.title,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emeraldGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.textSecondary,
        ),
        hintStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.textTertiary,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emeraldGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emeraldGreen,
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.emeraldGreen,
        unselectedItemColor: AppColors.mediumGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayStyle(color: AppColors.textPrimary),
        headlineLarge: AppTypography.headingStyle(color: AppColors.textPrimary),
        titleLarge: AppTypography.titleStyle(color: AppColors.textPrimary),
        bodyLarge: AppTypography.bodyStyle(color: AppColors.textPrimary),
        bodyMedium: AppTypography.bodyStyle(
          color: AppColors.textSecondary,
          size: AppTypography.bodySmall,
        ),
        labelLarge: AppTypography.labelStyle(color: AppColors.textPrimary),
        bodySmall: AppTypography.captionStyle(color: AppColors.textSecondary),
      ),

      // Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      useMaterial3: true,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.deepNavy,
      primaryColor: AppColors.emeraldGreen,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.emeraldGreen,
        primary: AppColors.emeraldGreen,
        secondary: AppColors.goldenMustard,
        surface: AppColors.darkCard,
        error: AppColors.error,
        brightness: Brightness.dark,
      ),
      cardColor: AppColors.darkCard,
      dividerColor: AppColors.borderDark,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textLight),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: AppTypography.title,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emeraldGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.textLightSecondary,
        ),
        hintStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.textLightSecondary.withValues(alpha: 0.5),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emeraldGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emeraldGreen,
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkCard,
        selectedItemColor: AppColors.emeraldGreen,
        unselectedItemColor: AppColors.mediumGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayStyle(color: AppColors.textLight),
        headlineLarge: AppTypography.headingStyle(color: AppColors.textLight),
        titleLarge: AppTypography.titleStyle(color: AppColors.textLight),
        bodyLarge: AppTypography.bodyStyle(color: AppColors.textLight),
        bodyMedium: AppTypography.bodyStyle(
          color: AppColors.textLightSecondary,
          size: AppTypography.bodySmall,
        ),
        labelLarge: AppTypography.labelStyle(color: AppColors.textLight),
        bodySmall: AppTypography.captionStyle(
          color: AppColors.textLightSecondary,
        ),
      ),

      // Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      useMaterial3: true,
    );
  }
}
