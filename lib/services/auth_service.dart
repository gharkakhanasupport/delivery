import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_sign_in;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fcm_service.dart';

/// App user model mapping Supabase user
class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  factory AppUser.fromSupabase(User user) {
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['full_name'] as String?,
      photoUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }
}

/// Authentication service integrating Supabase and Google Sign-In
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    // 1. Check for existing session immediately on startup
    // Supabase persists session automatically, so we just need to load it
    final initialSession = Supabase.instance.client.auth.currentSession;
    if (initialSession != null) {
      final user = initialSession.user;
      currentUser.value = AppUser.fromSupabase(user);
      _checkProfileCompletion(user.id);
      // Register FCM token for already-authenticated session (fire-and-forget)
      FCMService().registerTokenWithSupabase(user.id);
    }

    // 2. Listen to subsequent Supabase auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final user = session?.user;
      if (user != null) {
        currentUser.value = AppUser.fromSupabase(user);
        // Check profile completion logic here if needed, or query db
        AuthService._checkProfileCompletion(user.id);
        // Register FCM token for push notifications (fire-and-forget)
        FCMService().registerTokenWithSupabase(user.id);
      } else {
        currentUser.value = null;
        hasCompletedProfile.value = false;
        // Also reset verified status
        isVerified.value = false;
      }
    });
  }

  /// Current user state
  // Renaming functionality to match previous API but using AppUser (was MockUser)
  // We use AppUser alias to match the field structure expected by consumers
  static final ValueNotifier<AppUser?> currentUser = ValueNotifier(null);

  /// Whether user is authenticated
  static bool get isAuthenticated => currentUser.value != null;

  /// Whether user is explicitly verified by admin
  static final ValueNotifier<bool> isVerified = ValueNotifier(false);

  /// Whether user has completed profile setup (initial submission)
  static final ValueNotifier<bool> hasCompletedProfile = ValueNotifier(false);

  /// Sign in with Google
  static Future<AppUser?> signInWithGoogle() async {
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];

      final g_sign_in.GoogleSignIn googleSignIn = g_sign_in.GoogleSignIn(
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      final googleAuth = await googleUser?.authentication;
      final accessToken = googleAuth?.accessToken;
      final idToken = googleAuth?.idToken;

      if (accessToken == null) {
        throw 'No Access Token found.';
      }
      if (idToken == null) {
        throw 'No ID Token found.';
      }

      final AuthResponse response = await Supabase.instance.client.auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );

      final user = response.user;
      if (user != null) {
        final appUser = AppUser.fromSupabase(user);
        currentUser.value = appUser;
        // Explicitly check profile to ensure UI updates
        await _checkProfileCompletion(user.id);
        return appUser;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In Error: $e');
      }
      rethrow;
    }
    return null;
  }

  /// Sign in with Email (Verified Agents Only)
  static Future<void> signInWithVerifiedEmail(String email) async {
    try {
      // --------------------------------------------------
      // TESTER BYPASS
      // --------------------------------------------------
      if (email == 'tester@gkk.com' || email == 'test@gkk.delivery') {
        return;
      }
      
      // 1. Check verification status directly from delivery_profiles
      //    (The check_agent_status RPC has a broken column reference,
      //     so we query the table directly instead)
      final result = await Supabase.instance.client
          .from('delivery_profiles')
          .select('verification_status')
          .eq('email', email)
          .maybeSingle();

      if (result == null) {
        throw 'Email is not registered.';
      }

      final status = result['verification_status']?.toString() ?? '';
      if (status != 'verified') {
        throw 'Access restricted: Your account is not verified by Admin yet. Status: $status';
      }

      // 2. Send OTP
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
    } catch (e) {
      if (e is PostgrestException) {
        if (e.message.contains('function') &&
            e.message.contains('does not exist')) {
          throw 'System Error: Validation check failed. Please ensure DB migrations are applied.';
        }
      }
      rethrow;
    }
  }

  /// Verify Email OTP
  static Future<AppUser?> verifyEmailOtp(String email, String otp) async {
    try {
      // --------------------------------------------------
      // TESTER BYPASS
      // --------------------------------------------------
      if ((email == 'tester@gkk.com' || email == 'test@gkk.delivery') && otp == '123456') {
        // Create mock user without requiring Supabase Auth account
        final appUser = AppUser(
          id: 'tester-delivery-agent',
          email: email,
          displayName: 'Test Delivery Agent',
        );
        currentUser.value = appUser;
        hasCompletedProfile.value = true;
        isVerified.value = true;
        return appUser;
      }
      // --------------------------------------------------

      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        token: otp,
        email: email,
      );

      final user = response.user;
      if (user != null) {
        final appUser = AppUser.fromSupabase(user);
        currentUser.value = appUser;
        await _checkProfileCompletion(user.id);
        return appUser;
      }
    } catch (e) {
      if (kDebugMode) {
        print('OTP Verification Error: $e');
      }
      rethrow;
    }
    return null;
  }

  /// Sign out
  static Future<void> signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    currentUser.value = null;
    hasCompletedProfile.value = false;
    isVerified.value = false;
  }

  static Future<void> _checkProfileCompletion(String userId) async {
    try {
      // Check delivery_profiles for this user
      final response = await Supabase.instance.client
          .from('delivery_profiles')
          .select('id, verification_status')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        // Profile exists, so they have at least started.
        // We assume 'completed profile' means they hit the Vehicle Details submit which updates 'verification_status' from 'pending' (default? no, trigger makes it pending)
        // Actually, trigger makes it 'pending'.
        // 'underReview', 'verified', 'rejected' imply they finished the form.

        final status = response['verification_status'] as String?;

        // If they are strictly 'pending', they might be new or half-way.
        // Our Service logic upserts, so we consider 'hasCompleted' if status is NOT 'pending' or checking vehicle table.
        // For simplicity: If we have a row, they are "registered" in auth, but maybe not finished forms.
        // Let's assume: hasCompletedProfile = true if verification_status != 'pending' (meaning they submitted everything).
        // Wait, trigger creates it as 'pending'. So 'pending' = Incomplete forms.

        if (status != null && status != 'pending') {
          hasCompletedProfile.value = true;
          isVerified.value = (status == 'verified');
        } else {
          // Still in form filling stage
          hasCompletedProfile.value = false;
          isVerified.value = false;
        }
      } else {
        hasCompletedProfile.value = false;
        isVerified.value = false;
      }
    } catch (_) {
      hasCompletedProfile.value = false;
      isVerified.value = false;
    }
  }

  /// Mark profile as complete (manually called after registration form)
  static void markProfileComplete() {
    hasCompletedProfile.value = true;
    // Do NOT set verified true here; admin must do it.
  }

  /// Check if this is a new user (needs registration)
  static bool get isNewUser => !hasCompletedProfile.value;
}
