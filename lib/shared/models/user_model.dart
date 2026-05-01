
class UserModel {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isOnline;
  final bool manualVerified; // Deprecated: Use verificationStatus instead
  final String verificationStatus; // 'pending', 'approved', 'rejected'
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? fcmToken;
  final String? city; // 'najaf' or 'mosul'
  
  // Merchant-specific fields
  final String? storeName;
  
  // Driver-specific fields
  final String? vehicleType;
  final bool? hasDrivingLicense;
  final bool? ownsVehicle;
  final String? rank; // 'bronze', 'silver', 'gold'
  
  // Document URLs
  final String? idCardFrontUrl;
  final String? idCardBackUrl;
  final String? selfieWithIdUrl;
  
  // Walkthrough completion tracking
  final bool merchantWalkthroughCompleted;
  final bool driverWalkthroughCompleted;
  final DateTime? merchantWalkthroughCompletedAt;
  final DateTime? driverWalkthroughCompletedAt;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.isOnline = false,
    this.manualVerified = false, // Deprecated
    this.verificationStatus = 'pending', // New field
    this.address,
    this.latitude,
    this.longitude,
    this.fcmToken,
    this.city,
    this.storeName,
    this.vehicleType,
    this.hasDrivingLicense,
    this.ownsVehicle,
    this.rank,
    this.idCardFrontUrl,
    this.idCardBackUrl,
    this.selfieWithIdUrl,
    this.merchantWalkthroughCompleted = false,
    this.driverWalkthroughCompleted = false,
    this.merchantWalkthroughCompletedAt,
    this.driverWalkthroughCompletedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Parse verification_status (new field) or fallback to manual_verified (deprecated)
    final verificationStatus = json['verification_status'] as String? ?? 
      (json['manual_verified'] as bool? ?? false ? 'approved' : 'pending');
    
    // Normalize role to ensure consistent comparison
    final rawRole = json['role'] as String? ?? '';
    final normalizedRole = rawRole.trim().toLowerCase();
    final validRoles = ['driver', 'merchant', 'admin', 'customer'];
    final role = validRoles.contains(normalizedRole) ? normalizedRole : (rawRole.isNotEmpty ? rawRole : 'customer');
    
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String,
      role: role,
      isOnline: json['is_online'] as bool? ?? false,
      manualVerified: verificationStatus == 'approved', // Derived from verificationStatus
      verificationStatus: verificationStatus,
      address: json['address'] as String?,
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      fcmToken: json['fcm_token'] as String?,
      city: json['city'] as String?,
      storeName: json['store_name'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      hasDrivingLicense: json['has_driving_license'] as bool?,
      ownsVehicle: json['owns_vehicle'] as bool?,
      rank: json['rank'] as String? ?? 'bronze',
      idCardFrontUrl: json['id_card_front_url'] as String?,
      idCardBackUrl: json['id_card_back_url'] as String?,
      selfieWithIdUrl: json['selfie_with_id_url'] as String?,
      merchantWalkthroughCompleted: json['merchant_walkthrough_completed'] as bool? ?? false,
      driverWalkthroughCompleted: json['driver_walkthrough_completed'] as bool? ?? false,
      merchantWalkthroughCompletedAt: json['merchant_walkthrough_completed_at'] != null 
          ? DateTime.parse(json['merchant_walkthrough_completed_at'] as String) 
          : null,
      driverWalkthroughCompletedAt: json['driver_walkthrough_completed_at'] != null 
          ? DateTime.parse(json['driver_walkthrough_completed_at'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role,
      'is_online': isOnline,
      'manual_verified': manualVerified, // Keep for backward compatibility
      'verification_status': verificationStatus, // New field
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'fcm_token': fcmToken,
      'city': city,
      'store_name': storeName,
      'vehicle_type': vehicleType,
      'has_driving_license': hasDrivingLicense,
      'owns_vehicle': ownsVehicle,
      'rank': rank,
      'id_card_front_url': idCardFrontUrl,
      'id_card_back_url': idCardBackUrl,
      'selfie_with_id_url': selfieWithIdUrl,
      'merchant_walkthrough_completed': merchantWalkthroughCompleted,
      'driver_walkthrough_completed': driverWalkthroughCompleted,
      'merchant_walkthrough_completed_at': merchantWalkthroughCompletedAt?.toIso8601String(),
      'driver_walkthrough_completed_at': driverWalkthroughCompletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    bool? isOnline,
    bool? manualVerified,
    String? verificationStatus,
    String? address,
    double? latitude,
    double? longitude,
    String? fcmToken,
    String? city,
    String? storeName,
    String? vehicleType,
    bool? hasDrivingLicense,
    bool? ownsVehicle,
    String? rank,
    String? idCardFrontUrl,
    String? idCardBackUrl,
    String? selfieWithIdUrl,
    bool? merchantWalkthroughCompleted,
    bool? driverWalkthroughCompleted,
    DateTime? merchantWalkthroughCompletedAt,
    DateTime? driverWalkthroughCompletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      manualVerified: manualVerified ?? this.manualVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      fcmToken: fcmToken ?? this.fcmToken,
      city: city ?? this.city,
      storeName: storeName ?? this.storeName,
      vehicleType: vehicleType ?? this.vehicleType,
      hasDrivingLicense: hasDrivingLicense ?? this.hasDrivingLicense,
      ownsVehicle: ownsVehicle ?? this.ownsVehicle,
      rank: rank ?? this.rank,
      idCardFrontUrl: idCardFrontUrl ?? this.idCardFrontUrl,
      idCardBackUrl: idCardBackUrl ?? this.idCardBackUrl,
      selfieWithIdUrl: selfieWithIdUrl ?? this.selfieWithIdUrl,
      merchantWalkthroughCompleted: merchantWalkthroughCompleted ?? this.merchantWalkthroughCompleted,
      driverWalkthroughCompleted: driverWalkthroughCompleted ?? this.driverWalkthroughCompleted,
      merchantWalkthroughCompletedAt: merchantWalkthroughCompletedAt ?? this.merchantWalkthroughCompletedAt,
      driverWalkthroughCompletedAt: driverWalkthroughCompletedAt ?? this.driverWalkthroughCompletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isMerchant => role == 'merchant';
  bool get isDriver => role == 'driver';
  bool get isCustomer => role == 'customer';
  bool get isAdmin => role == 'admin';

  bool get isVerified => verificationStatus == 'approved';

  String get displayName => name.isNotEmpty ? name : phone;

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, phone: $phone, role: $role, isOnline: $isOnline, verificationStatus: $verificationStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
