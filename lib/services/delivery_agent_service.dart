import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_agent.dart';
import 'auth_service.dart';

/// Service for managing delivery agent profile data
class DeliveryAgentService {
  static final DeliveryAgentService _instance =
      DeliveryAgentService._internal();
  factory DeliveryAgentService() => _instance;
  DeliveryAgentService._internal();

  /// Current agent profile
  static final ValueNotifier<DeliveryAgent?> currentAgent = ValueNotifier(null);

  /// Supabase client
  static final _supabase = Supabase.instance.client;

  /// Registration progress (0-3 steps completed)
  static final ValueNotifier<int> registrationStep = ValueNotifier(0);

  /// Start new registration
  static Future<void> startRegistration() async {
    registrationStep.value = 0;
    // Check if profile exists and load current step/data if needed
    await fetchCurrentProfile();
  }

  /// Upload a file to Supabase Storage and return the public URL
  static Future<String?> _uploadFile(
    String filePath,
    String bucket,
    String filenamePrefix,
  ) async {
    try {
      // If it's already a URL, return it
      if (filePath.startsWith('http')) return filePath;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('File does not exist: $filePath');
        return null;
      }

      final fileExt = filePath.split('.').last;
      final fileName =
          '${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = '$userId/$fileName';

      await _supabase.storage
          .from(bucket)
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      return _supabase.storage.from(bucket).getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('Error uploading file to $bucket: $e');
      return null;
    }
  }

  /// Save basic details (Step 1)
  static Future<void> saveBasicDetails({
    required String name,
    required String email,
    required String phone,
    required int age,
    required Gender gender,
    required String address,
    required String state,
    required String city,
    String? profilePhotoPath,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Upload profile photo if provided
      String? photoUrl;
      if (profilePhotoPath != null) {
        photoUrl = await _uploadFile(
          profilePhotoPath,
          'profile_photos',
          'profile',
        );
      }

      final updates = {
        'full_name': name,
        'email': email,
        'phone_number': phone,
        'age': age,
        'gender': gender.name, // Enum to string
        'current_address': address,
        'state': state,
        'city': city,
        if (photoUrl != null) 'profile_photo_url': photoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // We assume the profile row was created by trigger on signup
      await _supabase
          .from('delivery_profiles')
          .update(updates)
          .eq('id', userId);

      registrationStep.value = 1;

      // Update local state
      await fetchCurrentProfile();
    } catch (e) {
      debugPrint('Error saving basic details: $e');
      rethrow;
    }
  }

  /// Save KYC details (Step 2)
  static Future<void> saveKycDetails({
    required IdType idType,
    required String idDocumentPath,
    String? idNumber,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Upload KYC document
      final docUrl = await _uploadFile(
        idDocumentPath,
        'kyc_documents',
        idType.name,
      );

      if (docUrl == null) throw Exception('Failed to upload KYC document');

      final documentData = {
        'user_id': userId,
        'document_type': idType.name,
        'document_number': idNumber,
        'document_image_url': docUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert KYC document
      await _supabase
          .from('kyc_documents')
          .upsert(documentData, onConflict: 'user_id, document_type');

      registrationStep.value = 2;
    } catch (e) {
      debugPrint('Error saving KYC details: $e');
      rethrow;
    }
  }

  /// Save vehicle details and complete registration (Step 3)
  static Future<DeliveryAgent> saveVehicleDetailsAndComplete({
    required VehicleType vehicleType,
    EngineType? engineType,
    String? vehicleNumber,
    String? vehicleMake,
    String? drivingLicensePath,
    String? vehiclePhotoPath,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Upload vehicle documents
      String? licenseUrl;
      if (drivingLicensePath != null) {
        licenseUrl = await _uploadFile(
          drivingLicensePath,
          'vehicle_documents',
          'license',
        );
      }

      String? vehiclePhotoUrl;
      if (vehiclePhotoPath != null) {
        vehiclePhotoUrl = await _uploadFile(
          vehiclePhotoPath,
          'vehicle_documents',
          'vehicle',
        );
      }

      final vehicleData = {
        'user_id': userId,
        'vehicle_type': vehicleType.name,
        'engine_type': engineType?.name,
        'vehicle_number': vehicleNumber,
        'vehicle_make': vehicleMake,
        if (licenseUrl != null) 'driving_license_url': licenseUrl,
        if (vehiclePhotoUrl != null) 'vehicle_photo_url': vehiclePhotoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('vehicle_details')
          .upsert(vehicleData, onConflict: 'user_id');

      // Update status to 'underReview'
      await _supabase
          .from('delivery_profiles')
          .update({
            'verification_status': 'underReview',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Signal completion
      AuthService.markProfileComplete();

      // Fetch fresh data
      await fetchCurrentProfile();

      if (currentAgent.value == null) {
        throw Exception('Failed to load profile after save');
      }
      return currentAgent.value!;
    } catch (e) {
      debugPrint('Error completing profile: $e');
      rethrow;
    }
  }

  /// Update vehicle details (allow agents to change vehicle)
  static Future<void> updateVehicleDetails({
    required VehicleType vehicleType,
    EngineType? engineType,
    String? vehicleNumber,
    String? vehicleMake,
    String? drivingLicensePath,
    String? vehiclePhotoPath,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Upload new documents if provided (not URLs)
      String? licenseUrl;
      if (drivingLicensePath != null && !drivingLicensePath.startsWith('http')) {
        licenseUrl = await _uploadFile(
          drivingLicensePath,
          'vehicle_documents',
          'license',
        );
      }

      String? vehiclePhotoUrl;
      if (vehiclePhotoPath != null && !vehiclePhotoPath.startsWith('http')) {
        vehiclePhotoUrl = await _uploadFile(
          vehiclePhotoPath,
          'vehicle_documents',
          'vehicle',
        );
      }

      final vehicleData = <String, dynamic>{
        'user_id': userId,
        'vehicle_type': vehicleType.name,
        'engine_type': engineType?.name,
        'vehicle_number': vehicleNumber,
        'vehicle_make': vehicleMake,
        if (licenseUrl != null) 'driving_license_url': licenseUrl,
        if (vehiclePhotoUrl != null) 'vehicle_photo_url': vehiclePhotoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('vehicle_details')
          .upsert(vehicleData, onConflict: 'user_id');

      // Refresh local state
      await fetchCurrentProfile();
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      rethrow;
    }
  }

  /// Update personal information
  static Future<void> updatePersonalInfo({
    String? name,
    String? phone,
    String? address,
    String? state,
    String? city,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (name != null) updates['full_name'] = name;
      if (phone != null) updates['phone_number'] = phone;
      if (address != null) updates['current_address'] = address;
      if (state != null) updates['state'] = state;
      if (city != null) updates['city'] = city;

      await _supabase
          .from('delivery_profiles')
          .update(updates)
          .eq('id', userId);

      await fetchCurrentProfile();
    } catch (e) {
      debugPrint('Error updating personal info: $e');
      rethrow;
    }
  }

  /// Update bank/financial details for payouts
  static Future<void> updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? upiId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final updates = {
        'bank_name': bankName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'upi_id': upiId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('delivery_profiles')
          .update(updates)
          .eq('id', userId);

      await fetchCurrentProfile();
    } catch (e) {
      debugPrint('Error updating bank details: $e');
      rethrow;
    }
  }

  /// Get real delivery stats from DB
  static Future<Map<String, dynamic>> getDeliveryStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {'deliveries': 0, 'earned': 0.0, 'rating': 0.0};

      // Count completed deliveries
      final deliveriesResult = await _supabase
          .from('delivery_orders')
          .select('id')
          .eq('delivery_partner_id', userId)
          .eq('status', 'delivered');
      
      final deliveryCount = (deliveriesResult as List).length;

      // Get total earnings from wallet
      double totalEarned = 0;
      try {
        final walletResult = await _supabase
            .from('agent_wallets')
            .select('total_earnings')
            .eq('agent_id', userId)
            .maybeSingle();
        totalEarned = (walletResult?['total_earnings'] as num?)?.toDouble() ?? 0;
      } catch (_) {}

      // Get average rating
      double rating = 0;
      try {
        final ratingResult = await _supabase
            .from('delivery_ratings')
            .select('rating')
            .eq('agent_id', userId);
        if ((ratingResult as List).isNotEmpty) {
          final sum = ratingResult.fold<double>(
            0, (prev, r) => prev + (r['rating'] as num).toDouble(),
          );
          rating = sum / ratingResult.length;
        }
      } catch (_) {
        // Table may not exist yet — rating stays 0
      }

      return {
        'deliveries': deliveryCount,
        'earned': totalEarned,
        'rating': rating,
      };
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      return {'deliveries': 0, 'earned': 0.0, 'rating': 0.0};
    }
  }

  /// Update phone number
  static Future<void> updatePhoneNumber(String phone) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      await _supabase
          .from('delivery_profiles')
          .update({
            'phone_number': phone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Refresh local state
      await fetchCurrentProfile();
    } catch (e) {
      debugPrint('Error updating phone: $e');
      rethrow;
    }
  }

  /// Update profile photo
  static Future<void> updateProfilePhoto(String imagePath) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Upload new photo
      final photoUrl = await _uploadFile(
        imagePath,
        'profile_photos',
        'profile',
      );
      if (photoUrl == null) throw Exception('Failed to upload photo');

      await _supabase
          .from('delivery_profiles')
          .update({
            'profile_photo_url': photoUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Refresh local state
      await fetchCurrentProfile();
    } catch (e) {
      debugPrint('Error updating profile photo: $e');
      rethrow;
    }
  }

  /// Fetch full profile from Supabase
  static Future<DeliveryAgent?> fetchCurrentProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final userEmail = _supabase.auth.currentUser?.email;

      if (userId == null) {
        debugPrint('fetchCurrentProfile: No user logged in');
        return null;
      }

      debugPrint('fetchCurrentProfile: Fetching for user $userId');

      // Try nested query first (more efficient)
      try {
        final response = await _supabase
            .from('delivery_profiles')
            .select('*')
            .eq('id', userId)
            .maybeSingle();

        if (response != null) {
          debugPrint('fetchCurrentProfile: Got nested response');
          final agent = _mapSupabaseToAgent(response);
          currentAgent.value = agent;
          return agent;
        }
      } catch (nestedError) {
        debugPrint('fetchCurrentProfile: Nested query failed: $nestedError');
        // Fall through to simple query
      }

      // Fallback: Simple query without nested relations
      debugPrint('fetchCurrentProfile: Trying simple query');
      final profileResponse = await _supabase
          .from('delivery_profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse != null) {
        debugPrint('fetchCurrentProfile: Got simple profile response');

        // Fetch related data separately
        List<dynamic>? kycDocs;
        Map<String, dynamic>? vehicleData;

        try {
          final kycResponse = await _supabase
              .from('kyc_documents')
              .select('*')
              .eq('user_id', userId);
          kycDocs = kycResponse as List<dynamic>?;
        } catch (e) {
          debugPrint('fetchCurrentProfile: KYC fetch failed: $e');
        }

        try {
          final vehicleResponse = await _supabase
              .from('vehicle_details')
              .select('*')
              .eq('user_id', userId)
              .maybeSingle();
          vehicleData = vehicleResponse;
        } catch (e) {
          debugPrint('fetchCurrentProfile: Vehicle fetch failed: $e');
        }

        // Combine into expected format
        final combinedData = {
          ...profileResponse,
          'kyc_documents': kycDocs ?? [],
          'vehicle_details': vehicleData != null ? [vehicleData] : [],
        };

        final agent = _mapSupabaseToAgent(combinedData);
        currentAgent.value = agent;
        return agent;
      }

      // Last resort: Create a minimal agent from auth data if profile doesn't exist in DB
      debugPrint('fetchCurrentProfile: No profile in DB, using auth data');
      final minimalAgent = DeliveryAgent(
        id: userId,
        name:
            _supabase.auth.currentUser?.userMetadata?['full_name'] ??
            _supabase.auth.currentUser?.userMetadata?['name'] ??
            (userEmail?.split('@').first ?? 'User'),
        email: userEmail ?? '',
        phone: '',
        age: 0,
        gender: Gender.male,
        address: '',
        vehicleType: VehicleType.cycle,
        verificationStatus: VerificationStatus.pending,
        createdAt: DateTime.now(),
      );
      currentAgent.value = minimalAgent;
      return minimalAgent;
    } catch (e) {
      debugPrint('fetchCurrentProfile: Error: $e');
    }
    return null;
  }

  static DeliveryAgent _mapSupabaseToAgent(Map<String, dynamic> data) {
    // Helper to parse enums safely (handles nullable values)
    T enumFromString<T>(List<T> values, String? value, T defaultValue) {
      if (value == null) return defaultValue;
      for (final e in values) {
        if (e.toString().split('.').last == value) {
          return e;
        }
      }
      return defaultValue;
    }

    final kycDocs = data['kyc_documents'] as List<dynamic>?;
    final kyc = (kycDocs != null && kycDocs.isNotEmpty) ? kycDocs.first : null;

    final vehicleDocs = data['vehicle_details'] as List<dynamic>?;
    final vehicle = (vehicleDocs != null && vehicleDocs.isNotEmpty)
        ? vehicleDocs.first
        : null;

    return DeliveryAgent(
      id: data['id'],
      name: data['full_name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone_number'] ?? '',
      age: data['age'] ?? 0,
      gender: enumFromString(Gender.values, data['gender'], Gender.male),
      address: data['current_address'] ?? '',
      state: data['state'],
      city: data['city'],
      profilePhotoPath: data['profile_photo_url'],
      
      // Financial
      bankName: data['bank_name'],
      accountNumber: data['account_number'],
      ifscCode: data['ifsc_code'],
      upiId: data['upi_id'],

      // KYC
      idType: kyc != null
          ? enumFromString(IdType.values, kyc['document_type'], IdType.aadhar)
          : null,
      idNumber: kyc?['document_number'],
      idDocumentPath: kyc?['document_image_url'],
      isKycVerified: kyc?['is_verified'] ?? false,

      // Vehicle
      vehicleType: vehicle != null
          ? enumFromString(
              VehicleType.values,
              vehicle['vehicle_type'],
              VehicleType.cycle,
            )
          : VehicleType.cycle,
      engineType: vehicle != null
          ? enumFromString(
              EngineType.values,
              vehicle['engine_type'],
              EngineType.nonElectric,
            )
          : null,
      vehicleNumber: vehicle?['vehicle_number'],
      vehicleMake: vehicle?['vehicle_make'],
      drivingLicensePath: vehicle?['driving_license_url'],
      vehiclePhotoPath: vehicle?['vehicle_photo_url'],

      verificationStatus: enumFromString(
        VerificationStatus.values,
        data['verification_status'],
        VerificationStatus.pending,
      ),
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  /// Clear all data (for logout)
  static void clear() {
    currentAgent.value = null;
    registrationStep.value = 0;
  }
}
