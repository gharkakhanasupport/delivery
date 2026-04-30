/// Vehicle type options for delivery agents
enum VehicleType { cycle, twoWheeler, others }

/// Engine type for two-wheelers
enum EngineType { electric, nonElectric }

/// ID document type for KYC verification
enum IdType { aadhar, pan }

/// Verification status for admin approval
enum VerificationStatus { pending, underReview, verified, rejected }

/// Gender options
enum Gender { male, female, other }

/// Complete delivery agent profile model
class DeliveryAgent {
  // Basic Details
  final String? id;
  final String name;
  final String email;
  final String phone;
  final int age;
  final Gender gender;
  final String address;
  final String? state;
  final String? city;
  final String? profilePhotoPath;
  
  // Financial Details
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;

  // KYC Details
  final IdType? idType;
  final String? idNumber;
  final String? idDocumentPath;
  final bool isKycVerified;

  // Vehicle Details
  final VehicleType vehicleType;
  final EngineType? engineType;
  final String? vehicleNumber;
  final String? vehicleMake;
  final String? drivingLicensePath;
  final String? vehiclePhotoPath;

  // Status
  final VerificationStatus verificationStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? verifiedAt;

  const DeliveryAgent({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.age,
    required this.gender,
    required this.address,
    this.state,
    this.city,
    this.profilePhotoPath,
    this.idType,
    this.idNumber,
    this.idDocumentPath,
    this.isKycVerified = false,
    this.vehicleType = VehicleType.cycle,
    this.engineType,
    this.vehicleNumber,
    this.vehicleMake,
    this.drivingLicensePath,
    this.vehiclePhotoPath,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.verificationStatus = VerificationStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.verifiedAt,
  });

  /// Check if driving license is required based on vehicle type
  bool get isLicenseRequired {
    if (vehicleType == VehicleType.cycle) return false;
    if (vehicleType == VehicleType.twoWheeler &&
        engineType == EngineType.electric) {
      return false; // Optional for electric
    }
    return true; // Required for non-electric two-wheelers and others
  }

  /// Check if basic details are complete
  bool get isBasicDetailsComplete {
    return name.isNotEmpty &&
        email.isNotEmpty &&
        phone.isNotEmpty &&
        age > 0 &&
        address.isNotEmpty &&
        state != null &&
        city != null;
  }

  /// Check if KYC is complete
  bool get isKycComplete {
    return idType != null &&
        idDocumentPath != null &&
        idDocumentPath!.isNotEmpty;
  }

  /// Check if vehicle details are complete
  bool get isVehicleDetailsComplete {
    if (vehicleType == VehicleType.cycle) {
      return true; // No additional details needed for cycle
    }

    bool hasBasicVehicleInfo =
        vehicleNumber != null && vehicleNumber!.isNotEmpty;

    if (isLicenseRequired) {
      return hasBasicVehicleInfo &&
          drivingLicensePath != null &&
          drivingLicensePath!.isNotEmpty;
    }

    return hasBasicVehicleInfo;
  }

  /// Check if profile is complete for submission
  bool get isProfileComplete {
    return isBasicDetailsComplete && isKycComplete && isVehicleDetailsComplete;
  }

  /// Get verification status label
  String get statusLabel {
    switch (verificationStatus) {
      case VerificationStatus.pending:
        return 'Pending Review';
      case VerificationStatus.underReview:
        return 'Under Review';
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }

  /// Copy with new values
  DeliveryAgent copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    int? age,
    Gender? gender,
    String? address,
    String? state,
    String? city,
    String? profilePhotoPath,
    IdType? idType,
    String? idNumber,
    String? idDocumentPath,
    bool? isKycVerified,
    VehicleType? vehicleType,
    EngineType? engineType,
    String? vehicleNumber,
    String? vehicleMake,
    String? drivingLicensePath,
    String? vehiclePhotoPath,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    VerificationStatus? verificationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? verifiedAt,
  }) {
    return DeliveryAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      state: state ?? this.state,
      city: city ?? this.city,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      idDocumentPath: idDocumentPath ?? this.idDocumentPath,
      isKycVerified: isKycVerified ?? this.isKycVerified,
      vehicleType: vehicleType ?? this.vehicleType,
      engineType: engineType ?? this.engineType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      drivingLicensePath: drivingLicensePath ?? this.drivingLicensePath,
      vehiclePhotoPath: vehiclePhotoPath ?? this.vehiclePhotoPath,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}
