// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  return _UserModel.fromJson(json);
}

/// @nodoc
mixin _$UserModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _normalizeRole)
  String get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_online')
  bool get isOnline => throw _privateConstructorUsedError;
  @JsonKey(name: 'manual_verified')
  bool get manualVerified => throw _privateConstructorUsedError;
  @JsonKey(name: 'verification_status', fromJson: _verificationStatusFromJson)
  String get verificationStatus => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'fcm_token')
  String? get fcmToken => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  @JsonKey(name: 'store_name')
  String? get storeName => throw _privateConstructorUsedError;
  @JsonKey(name: 'vehicle_type')
  String? get vehicleType => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_driving_license')
  bool? get hasDrivingLicense => throw _privateConstructorUsedError;
  @JsonKey(name: 'owns_vehicle')
  bool? get ownsVehicle => throw _privateConstructorUsedError;
  String? get rank => throw _privateConstructorUsedError;
  @JsonKey(name: 'id_card_front_url')
  String? get idCardFrontUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'id_card_back_url')
  String? get idCardBackUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'selfie_with_id_url')
  String? get selfieWithIdUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'merchant_walkthrough_completed')
  bool get merchantWalkthroughCompleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'driver_walkthrough_completed')
  bool get driverWalkthroughCompleted => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'merchant_walkthrough_completed_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get merchantWalkthroughCompletedAt =>
      throw _privateConstructorUsedError;
  @JsonKey(
      name: 'driver_walkthrough_completed_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get driverWalkthroughCompletedAt =>
      throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this UserModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserModelCopyWith<UserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) then) =
      _$UserModelCopyWithImpl<$Res, UserModel>;
  @useResult
  $Res call(
      {String id,
      String name,
      String phone,
      @JsonKey(fromJson: _normalizeRole) String role,
      @JsonKey(name: 'is_online') bool isOnline,
      @JsonKey(name: 'manual_verified') bool manualVerified,
      @JsonKey(
          name: 'verification_status', fromJson: _verificationStatusFromJson)
      String verificationStatus,
      String? address,
      double? latitude,
      double? longitude,
      @JsonKey(name: 'fcm_token') String? fcmToken,
      String? city,
      @JsonKey(name: 'store_name') String? storeName,
      @JsonKey(name: 'vehicle_type') String? vehicleType,
      @JsonKey(name: 'has_driving_license') bool? hasDrivingLicense,
      @JsonKey(name: 'owns_vehicle') bool? ownsVehicle,
      String? rank,
      @JsonKey(name: 'id_card_front_url') String? idCardFrontUrl,
      @JsonKey(name: 'id_card_back_url') String? idCardBackUrl,
      @JsonKey(name: 'selfie_with_id_url') String? selfieWithIdUrl,
      @JsonKey(name: 'merchant_walkthrough_completed')
      bool merchantWalkthroughCompleted,
      @JsonKey(name: 'driver_walkthrough_completed')
      bool driverWalkthroughCompleted,
      @JsonKey(
          name: 'merchant_walkthrough_completed_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? merchantWalkthroughCompletedAt,
      @JsonKey(
          name: 'driver_walkthrough_completed_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? driverWalkthroughCompletedAt,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? updatedAt});
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res, $Val extends UserModel>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
    Object? role = null,
    Object? isOnline = null,
    Object? manualVerified = null,
    Object? verificationStatus = null,
    Object? address = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? fcmToken = freezed,
    Object? city = freezed,
    Object? storeName = freezed,
    Object? vehicleType = freezed,
    Object? hasDrivingLicense = freezed,
    Object? ownsVehicle = freezed,
    Object? rank = freezed,
    Object? idCardFrontUrl = freezed,
    Object? idCardBackUrl = freezed,
    Object? selfieWithIdUrl = freezed,
    Object? merchantWalkthroughCompleted = null,
    Object? driverWalkthroughCompleted = null,
    Object? merchantWalkthroughCompletedAt = freezed,
    Object? driverWalkthroughCompletedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      manualVerified: null == manualVerified
          ? _value.manualVerified
          : manualVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      verificationStatus: null == verificationStatus
          ? _value.verificationStatus
          : verificationStatus // ignore: cast_nullable_to_non_nullable
              as String,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: freezed == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: freezed == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      fcmToken: freezed == fcmToken
          ? _value.fcmToken
          : fcmToken // ignore: cast_nullable_to_non_nullable
              as String?,
      city: freezed == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String?,
      storeName: freezed == storeName
          ? _value.storeName
          : storeName // ignore: cast_nullable_to_non_nullable
              as String?,
      vehicleType: freezed == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String?,
      hasDrivingLicense: freezed == hasDrivingLicense
          ? _value.hasDrivingLicense
          : hasDrivingLicense // ignore: cast_nullable_to_non_nullable
              as bool?,
      ownsVehicle: freezed == ownsVehicle
          ? _value.ownsVehicle
          : ownsVehicle // ignore: cast_nullable_to_non_nullable
              as bool?,
      rank: freezed == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as String?,
      idCardFrontUrl: freezed == idCardFrontUrl
          ? _value.idCardFrontUrl
          : idCardFrontUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      idCardBackUrl: freezed == idCardBackUrl
          ? _value.idCardBackUrl
          : idCardBackUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      selfieWithIdUrl: freezed == selfieWithIdUrl
          ? _value.selfieWithIdUrl
          : selfieWithIdUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      merchantWalkthroughCompleted: null == merchantWalkthroughCompleted
          ? _value.merchantWalkthroughCompleted
          : merchantWalkthroughCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      driverWalkthroughCompleted: null == driverWalkthroughCompleted
          ? _value.driverWalkthroughCompleted
          : driverWalkthroughCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      merchantWalkthroughCompletedAt: freezed == merchantWalkthroughCompletedAt
          ? _value.merchantWalkthroughCompletedAt
          : merchantWalkthroughCompletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      driverWalkthroughCompletedAt: freezed == driverWalkthroughCompletedAt
          ? _value.driverWalkthroughCompletedAt
          : driverWalkthroughCompletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserModelImplCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$$UserModelImplCopyWith(
          _$UserModelImpl value, $Res Function(_$UserModelImpl) then) =
      __$$UserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String phone,
      @JsonKey(fromJson: _normalizeRole) String role,
      @JsonKey(name: 'is_online') bool isOnline,
      @JsonKey(name: 'manual_verified') bool manualVerified,
      @JsonKey(
          name: 'verification_status', fromJson: _verificationStatusFromJson)
      String verificationStatus,
      String? address,
      double? latitude,
      double? longitude,
      @JsonKey(name: 'fcm_token') String? fcmToken,
      String? city,
      @JsonKey(name: 'store_name') String? storeName,
      @JsonKey(name: 'vehicle_type') String? vehicleType,
      @JsonKey(name: 'has_driving_license') bool? hasDrivingLicense,
      @JsonKey(name: 'owns_vehicle') bool? ownsVehicle,
      String? rank,
      @JsonKey(name: 'id_card_front_url') String? idCardFrontUrl,
      @JsonKey(name: 'id_card_back_url') String? idCardBackUrl,
      @JsonKey(name: 'selfie_with_id_url') String? selfieWithIdUrl,
      @JsonKey(name: 'merchant_walkthrough_completed')
      bool merchantWalkthroughCompleted,
      @JsonKey(name: 'driver_walkthrough_completed')
      bool driverWalkthroughCompleted,
      @JsonKey(
          name: 'merchant_walkthrough_completed_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? merchantWalkthroughCompletedAt,
      @JsonKey(
          name: 'driver_walkthrough_completed_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? driverWalkthroughCompletedAt,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? updatedAt});
}

/// @nodoc
class __$$UserModelImplCopyWithImpl<$Res>
    extends _$UserModelCopyWithImpl<$Res, _$UserModelImpl>
    implements _$$UserModelImplCopyWith<$Res> {
  __$$UserModelImplCopyWithImpl(
      _$UserModelImpl _value, $Res Function(_$UserModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
    Object? role = null,
    Object? isOnline = null,
    Object? manualVerified = null,
    Object? verificationStatus = null,
    Object? address = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? fcmToken = freezed,
    Object? city = freezed,
    Object? storeName = freezed,
    Object? vehicleType = freezed,
    Object? hasDrivingLicense = freezed,
    Object? ownsVehicle = freezed,
    Object? rank = freezed,
    Object? idCardFrontUrl = freezed,
    Object? idCardBackUrl = freezed,
    Object? selfieWithIdUrl = freezed,
    Object? merchantWalkthroughCompleted = null,
    Object? driverWalkthroughCompleted = null,
    Object? merchantWalkthroughCompletedAt = freezed,
    Object? driverWalkthroughCompletedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_$UserModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      manualVerified: null == manualVerified
          ? _value.manualVerified
          : manualVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      verificationStatus: null == verificationStatus
          ? _value.verificationStatus
          : verificationStatus // ignore: cast_nullable_to_non_nullable
              as String,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: freezed == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: freezed == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      fcmToken: freezed == fcmToken
          ? _value.fcmToken
          : fcmToken // ignore: cast_nullable_to_non_nullable
              as String?,
      city: freezed == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String?,
      storeName: freezed == storeName
          ? _value.storeName
          : storeName // ignore: cast_nullable_to_non_nullable
              as String?,
      vehicleType: freezed == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String?,
      hasDrivingLicense: freezed == hasDrivingLicense
          ? _value.hasDrivingLicense
          : hasDrivingLicense // ignore: cast_nullable_to_non_nullable
              as bool?,
      ownsVehicle: freezed == ownsVehicle
          ? _value.ownsVehicle
          : ownsVehicle // ignore: cast_nullable_to_non_nullable
              as bool?,
      rank: freezed == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as String?,
      idCardFrontUrl: freezed == idCardFrontUrl
          ? _value.idCardFrontUrl
          : idCardFrontUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      idCardBackUrl: freezed == idCardBackUrl
          ? _value.idCardBackUrl
          : idCardBackUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      selfieWithIdUrl: freezed == selfieWithIdUrl
          ? _value.selfieWithIdUrl
          : selfieWithIdUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      merchantWalkthroughCompleted: null == merchantWalkthroughCompleted
          ? _value.merchantWalkthroughCompleted
          : merchantWalkthroughCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      driverWalkthroughCompleted: null == driverWalkthroughCompleted
          ? _value.driverWalkthroughCompleted
          : driverWalkthroughCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      merchantWalkthroughCompletedAt: freezed == merchantWalkthroughCompletedAt
          ? _value.merchantWalkthroughCompletedAt
          : merchantWalkthroughCompletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      driverWalkthroughCompletedAt: freezed == driverWalkthroughCompletedAt
          ? _value.driverWalkthroughCompletedAt
          : driverWalkthroughCompletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserModelImpl extends _UserModel {
  const _$UserModelImpl(
      {required this.id,
      required this.name,
      required this.phone,
      @JsonKey(fromJson: _normalizeRole) required this.role,
      @JsonKey(name: 'is_online') this.isOnline = false,
      @JsonKey(name: 'manual_verified') this.manualVerified = false,
      @JsonKey(
          name: 'verification_status', fromJson: _verificationStatusFromJson)
      this.verificationStatus = 'pending',
      this.address,
      this.latitude,
      this.longitude,
      @JsonKey(name: 'fcm_token') this.fcmToken,
      this.city,
      @JsonKey(name: 'store_name') this.storeName,
      @JsonKey(name: 'vehicle_type') this.vehicleType,
      @JsonKey(name: 'has_driving_license') this.hasDrivingLicense,
      @JsonKey(name: 'owns_vehicle') this.ownsVehicle,
      this.rank = 'bronze',
      @JsonKey(name: 'id_card_front_url') this.idCardFrontUrl,
      @JsonKey(name: 'id_card_back_url') this.idCardBackUrl,
      @JsonKey(name: 'selfie_with_id_url') this.selfieWithIdUrl,
      @JsonKey(name: 'merchant_walkthrough_completed')
      this.merchantWalkthroughCompleted = false,
      @JsonKey(name: 'driver_walkthrough_completed')
      this.driverWalkthroughCompleted = false,
      @JsonKey(
          name: 'merchant_walkthrough_completed_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.merchantWalkthroughCompletedAt,
      @JsonKey(
          name: 'driver_walkthrough_completed_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.driverWalkthroughCompletedAt,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      required this.createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.updatedAt})
      : super._();

  factory _$UserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String phone;
  @override
  @JsonKey(fromJson: _normalizeRole)
  final String role;
  @override
  @JsonKey(name: 'is_online')
  final bool isOnline;
  @override
  @JsonKey(name: 'manual_verified')
  final bool manualVerified;
  @override
  @JsonKey(name: 'verification_status', fromJson: _verificationStatusFromJson)
  final String verificationStatus;
  @override
  final String? address;
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  @JsonKey(name: 'fcm_token')
  final String? fcmToken;
  @override
  final String? city;
  @override
  @JsonKey(name: 'store_name')
  final String? storeName;
  @override
  @JsonKey(name: 'vehicle_type')
  final String? vehicleType;
  @override
  @JsonKey(name: 'has_driving_license')
  final bool? hasDrivingLicense;
  @override
  @JsonKey(name: 'owns_vehicle')
  final bool? ownsVehicle;
  @override
  @JsonKey()
  final String? rank;
  @override
  @JsonKey(name: 'id_card_front_url')
  final String? idCardFrontUrl;
  @override
  @JsonKey(name: 'id_card_back_url')
  final String? idCardBackUrl;
  @override
  @JsonKey(name: 'selfie_with_id_url')
  final String? selfieWithIdUrl;
  @override
  @JsonKey(name: 'merchant_walkthrough_completed')
  final bool merchantWalkthroughCompleted;
  @override
  @JsonKey(name: 'driver_walkthrough_completed')
  final bool driverWalkthroughCompleted;
  @override
  @JsonKey(
      name: 'merchant_walkthrough_completed_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? merchantWalkthroughCompletedAt;
  @override
  @JsonKey(
      name: 'driver_walkthrough_completed_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? driverWalkthroughCompletedAt;
  @override
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, phone: $phone, role: $role, isOnline: $isOnline, manualVerified: $manualVerified, verificationStatus: $verificationStatus, address: $address, latitude: $latitude, longitude: $longitude, fcmToken: $fcmToken, city: $city, storeName: $storeName, vehicleType: $vehicleType, hasDrivingLicense: $hasDrivingLicense, ownsVehicle: $ownsVehicle, rank: $rank, idCardFrontUrl: $idCardFrontUrl, idCardBackUrl: $idCardBackUrl, selfieWithIdUrl: $selfieWithIdUrl, merchantWalkthroughCompleted: $merchantWalkthroughCompleted, driverWalkthroughCompleted: $driverWalkthroughCompleted, merchantWalkthroughCompletedAt: $merchantWalkthroughCompletedAt, driverWalkthroughCompletedAt: $driverWalkthroughCompletedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.manualVerified, manualVerified) ||
                other.manualVerified == manualVerified) &&
            (identical(other.verificationStatus, verificationStatus) ||
                other.verificationStatus == verificationStatus) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.fcmToken, fcmToken) ||
                other.fcmToken == fcmToken) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.storeName, storeName) ||
                other.storeName == storeName) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.hasDrivingLicense, hasDrivingLicense) ||
                other.hasDrivingLicense == hasDrivingLicense) &&
            (identical(other.ownsVehicle, ownsVehicle) ||
                other.ownsVehicle == ownsVehicle) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.idCardFrontUrl, idCardFrontUrl) ||
                other.idCardFrontUrl == idCardFrontUrl) &&
            (identical(other.idCardBackUrl, idCardBackUrl) ||
                other.idCardBackUrl == idCardBackUrl) &&
            (identical(other.selfieWithIdUrl, selfieWithIdUrl) ||
                other.selfieWithIdUrl == selfieWithIdUrl) &&
            (identical(other.merchantWalkthroughCompleted,
                    merchantWalkthroughCompleted) ||
                other.merchantWalkthroughCompleted ==
                    merchantWalkthroughCompleted) &&
            (identical(other.driverWalkthroughCompleted,
                    driverWalkthroughCompleted) ||
                other.driverWalkthroughCompleted ==
                    driverWalkthroughCompleted) &&
            (identical(other.merchantWalkthroughCompletedAt,
                    merchantWalkthroughCompletedAt) ||
                other.merchantWalkthroughCompletedAt ==
                    merchantWalkthroughCompletedAt) &&
            (identical(other.driverWalkthroughCompletedAt,
                    driverWalkthroughCompletedAt) ||
                other.driverWalkthroughCompletedAt ==
                    driverWalkthroughCompletedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        phone,
        role,
        isOnline,
        manualVerified,
        verificationStatus,
        address,
        latitude,
        longitude,
        fcmToken,
        city,
        storeName,
        vehicleType,
        hasDrivingLicense,
        ownsVehicle,
        rank,
        idCardFrontUrl,
        idCardBackUrl,
        selfieWithIdUrl,
        merchantWalkthroughCompleted,
        driverWalkthroughCompleted,
        merchantWalkthroughCompletedAt,
        driverWalkthroughCompletedAt,
        createdAt,
        updatedAt
      ]);

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      __$$UserModelImplCopyWithImpl<_$UserModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserModelImplToJson(
      this,
    );
  }
}

abstract class _UserModel extends UserModel {
  const factory _UserModel(
      {required final String id,
      required final String name,
      required final String phone,
      @JsonKey(fromJson: _normalizeRole) required final String role,
      @JsonKey(name: 'is_online') final bool isOnline,
      @JsonKey(name: 'manual_verified') final bool manualVerified,
      @JsonKey(
          name: 'verification_status', fromJson: _verificationStatusFromJson)
      final String verificationStatus,
      final String? address,
      final double? latitude,
      final double? longitude,
      @JsonKey(name: 'fcm_token') final String? fcmToken,
      final String? city,
      @JsonKey(name: 'store_name') final String? storeName,
      @JsonKey(name: 'vehicle_type') final String? vehicleType,
      @JsonKey(name: 'has_driving_license') final bool? hasDrivingLicense,
      @JsonKey(name: 'owns_vehicle') final bool? ownsVehicle,
      final String? rank,
      @JsonKey(name: 'id_card_front_url') final String? idCardFrontUrl,
      @JsonKey(name: 'id_card_back_url') final String? idCardBackUrl,
      @JsonKey(name: 'selfie_with_id_url') final String? selfieWithIdUrl,
      @JsonKey(name: 'merchant_walkthrough_completed')
      final bool merchantWalkthroughCompleted,
      @JsonKey(name: 'driver_walkthrough_completed')
      final bool driverWalkthroughCompleted,
      @JsonKey(
          name: 'merchant_walkthrough_completed_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? merchantWalkthroughCompletedAt,
      @JsonKey(
          name: 'driver_walkthrough_completed_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? driverWalkthroughCompletedAt,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      required final DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? updatedAt}) = _$UserModelImpl;
  const _UserModel._() : super._();

  factory _UserModel.fromJson(Map<String, dynamic> json) =
      _$UserModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get phone;
  @override
  @JsonKey(fromJson: _normalizeRole)
  String get role;
  @override
  @JsonKey(name: 'is_online')
  bool get isOnline;
  @override
  @JsonKey(name: 'manual_verified')
  bool get manualVerified;
  @override
  @JsonKey(name: 'verification_status', fromJson: _verificationStatusFromJson)
  String get verificationStatus;
  @override
  String? get address;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  @JsonKey(name: 'fcm_token')
  String? get fcmToken;
  @override
  String? get city;
  @override
  @JsonKey(name: 'store_name')
  String? get storeName;
  @override
  @JsonKey(name: 'vehicle_type')
  String? get vehicleType;
  @override
  @JsonKey(name: 'has_driving_license')
  bool? get hasDrivingLicense;
  @override
  @JsonKey(name: 'owns_vehicle')
  bool? get ownsVehicle;
  @override
  String? get rank;
  @override
  @JsonKey(name: 'id_card_front_url')
  String? get idCardFrontUrl;
  @override
  @JsonKey(name: 'id_card_back_url')
  String? get idCardBackUrl;
  @override
  @JsonKey(name: 'selfie_with_id_url')
  String? get selfieWithIdUrl;
  @override
  @JsonKey(name: 'merchant_walkthrough_completed')
  bool get merchantWalkthroughCompleted;
  @override
  @JsonKey(name: 'driver_walkthrough_completed')
  bool get driverWalkthroughCompleted;
  @override
  @JsonKey(
      name: 'merchant_walkthrough_completed_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get merchantWalkthroughCompletedAt;
  @override
  @JsonKey(
      name: 'driver_walkthrough_completed_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get driverWalkthroughCompletedAt;
  @override
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get updatedAt;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
