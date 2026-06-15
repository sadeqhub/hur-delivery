import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

DateTime _dateTimeFromJson(dynamic v) => DateTime.parse(v as String);
DateTime? _nullableDateTimeFromJson(dynamic v) =>
    v == null ? null : DateTime.parse(v as String);
String _dateTimeToJson(DateTime dt) => dt.toIso8601String();
String? _nullableDateTimeToJson(DateTime? dt) => dt?.toIso8601String();

String _normalizeRole(dynamic v) {
  final raw = (v as String? ?? '').trim().toLowerCase();
  const valid = ['driver', 'merchant', 'admin', 'customer'];
  if (valid.contains(raw)) return raw;
  if (raw.isNotEmpty) return raw;
  return 'customer';
}

String _verificationStatusFromJson(dynamic v) => (v as String?) ?? 'pending';

@freezed
class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String name,
    required String phone,
    @JsonKey(fromJson: _normalizeRole) required String role,
    @JsonKey(name: 'is_online') @Default(false) bool isOnline,
    @JsonKey(name: 'manual_verified') @Default(false) bool manualVerified,
    @JsonKey(name: 'verification_status', fromJson: _verificationStatusFromJson)
    @Default('pending')
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
    @Default('bronze') String? rank,
    @JsonKey(name: 'id_card_front_url') String? idCardFrontUrl,
    @JsonKey(name: 'id_card_back_url') String? idCardBackUrl,
    @JsonKey(name: 'selfie_with_id_url') String? selfieWithIdUrl,
    @JsonKey(name: 'merchant_walkthrough_completed')
    @Default(false)
    bool merchantWalkthroughCompleted,
    @JsonKey(name: 'driver_walkthrough_completed')
    @Default(false)
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
    required DateTime createdAt,
    @JsonKey(
        name: 'updated_at',
        fromJson: _nullableDateTimeFromJson,
        toJson: _nullableDateTimeToJson)
    DateTime? updatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  bool get isMerchant => role == 'merchant';
  bool get isDriver => role == 'driver';
  bool get isCustomer => role == 'customer';
  bool get isAdmin => role == 'admin';
  bool get isVerified => verificationStatus == 'approved';
  String get displayName => name.isNotEmpty ? name : phone;
}
