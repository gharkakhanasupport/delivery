import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage multiple database connections
/// 1. Delivery DB (Primary) — Agent profiles, locations, local order copies, wallets
/// 2. User DB (Secondary)   — Source of orders, customer data, payments
/// 3. Kitchen DB (Tertiary) — Kitchen/cook data, menu items
/// 4. Admin DB (Quaternary) — Admin verification, applications
///
/// ## ⚠️ SECURITY NOTE — Service Role Keys
/// The cross-database clients (User, Kitchen, Admin) currently use
/// SERVICE ROLE keys which bypass Row Level Security (RLS) entirely.
/// This is acceptable for beta/testing but MUST be migrated before
/// production launch.
///
/// ## Recommended Migration Path (Production)
/// 1. Deploy Edge Functions on each target DB that expose CRUD endpoints.
/// 2. Replace direct SupabaseClient calls with HTTP calls to those Edge Functions.
/// 3. Edge Functions authenticate via JWT or shared secret, not service role.
/// 4. Remove service role keys from client-side .env entirely.
/// 5. This ensures RLS policies are respected and keys aren't exposed in APK.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// Initialize all database connections
  static Future<void> initialize() async {
    // 1. Primary DB (Delivery App's own DB) — uses Supabase.initialize
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  // =========================================================================
  // CLIENT ACCESSORS
  // =========================================================================

  /// Get the Primary Client (Delivery DB) — authenticated via Supabase Auth
  SupabaseClient get primary => Supabase.instance.client;

  /// Deprecated: Cross-DB clients are removed in favor of Edge Functions.
  /// Returning null gracefully falls back in existing code.
  SupabaseClient? get userDb => null;
  SupabaseClient? get kitchenDb => null;

  // =========================================================================
  // CROSS-DB HELPERS (VIA EDGE FUNCTIONS)
  // =========================================================================

  /// Check verification status from Admin DB
  Future<String?> checkAdminVerification(String email) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'check-admin-status',
        body: {'email': email},
      );

      if (response.status == 200 && response.data != null) {
        final status = response.data['status'] as String?;
        return status == 'not_found' ? null : status;
      }
      return null;
    } catch (e) {
      debugPrint('[DatabaseService] Admin verification check failed: $e');
      return null;
    }
  }
}
