// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: _normalizeRole(json['role']),
      isOnline: json['is_online'] as bool? ?? false,
      manualVerified: json['manual_verified'] as bool? ?? false,
      verificationStatus: json['verification_status'] == null
          ? 'pending'
          : _verificationStatusFromJson(json['verification_status']),
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
      merchantWalkthroughCompleted:
          json['merchant_walkthrough_completed'] as bool? ?? false,
      driverWalkthroughCompleted:
          json['driver_walkthrough_completed'] as bool? ?? false,
      merchantWalkthroughCompletedAt:
          _nullableDateTimeFromJson(json['merchant_walkthrough_completed_at']),
      driverWalkthroughCompletedAt:
          _nullableDateTimeFromJson(json['driver_walkthrough_completed_at']),
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _nullableDateTimeFromJson(json['updated_at']),
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'role': instance.role,
      'is_online': instance.isOnline,
      'manual_verified': instance.manualVerified,
      'verification_status': instance.verificationStatus,
      'address': instance.address,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'fcm_token': instance.fcmToken,
      'city': instance.city,
      'store_name': instance.storeName,
      'vehicle_type': instance.vehicleType,
      'has_driving_license': instance.hasDrivingLicense,
      'owns_vehicle': instance.ownsVehicle,
      'rank': instance.rank,
      'id_card_front_url': instance.idCardFrontUrl,
      'id_card_back_url': instance.idCardBackUrl,
      'selfie_with_id_url': instance.selfieWithIdUrl,
      'merchant_walkthrough_completed': instance.merchantWalkthroughCompleted,
      'driver_walkthrough_completed': instance.driverWalkthroughCompleted,
      'merchant_walkthrough_completed_at':
          _nullableDateTimeToJson(instance.merchantWalkthroughCompletedAt),
      'driver_walkthrough_completed_at':
          _nullableDateTimeToJson(instance.driverWalkthroughCompletedAt),
      'created_at': _dateTimeToJson(instance.createdAt),
      'updated_at': _nullableDateTimeToJson(instance.updatedAt),
    };
