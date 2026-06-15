// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

OrderModel _$OrderModelFromJson(Map<String, dynamic> json) {
  return _OrderModel.fromJson(json);
}

/// @nodoc
mixin _$OrderModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'merchant_id')
  String get merchantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'merchant_name')
  String? get merchantName => throw _privateConstructorUsedError;
  @JsonKey(name: 'merchant_phone')
  String? get merchantPhone => throw _privateConstructorUsedError;
  @JsonKey(name: 'driver_id')
  String? get driverId => throw _privateConstructorUsedError;
  @JsonKey(name: 'driver_name')
  String? get driverName => throw _privateConstructorUsedError;
  @JsonKey(name: 'driver_phone')
  String? get driverPhone => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_name')
  String get customerName => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_phone')
  String? get customerPhone => throw _privateConstructorUsedError;
  @JsonKey(name: 'pickup_address')
  String get pickupAddress => throw _privateConstructorUsedError;
  @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
  double get pickupLatitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
  double get pickupLongitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_address')
  String get deliveryAddress => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_latitude', fromJson: _doubleFromJson)
  double get deliveryLatitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_longitude', fromJson: _doubleFromJson)
  double get deliveryLongitude => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
  double get totalAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
  double get deliveryFee => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  @JsonKey(name: 'vehicle_type')
  String get vehicleType => throw _privateConstructorUsedError;
  @JsonKey(name: 'bulk_order_id')
  String? get bulkOrderId => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'driver_assigned_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get driverAssignedAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'accepted_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get acceptedAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'rejected_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get rejectedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'timeout_remaining_seconds')
  int? get timeoutRemainingSeconds => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'ready_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get readyAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'ready_countdown')
  int? get readyCountdown => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_location_provided')
  bool? get customerLocationProvided => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_friendly_code')
  String? get userFriendlyCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_time_limit_seconds')
  int? get deliveryTimeLimitSeconds => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'delivery_timer_started_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get deliveryTimerStartedAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'delivery_timer_stopped_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get deliveryTimerStoppedAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'delivery_timer_expires_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get deliveryTimerExpiresAt => throw _privateConstructorUsedError;
  List<OrderItemModel> get items => throw _privateConstructorUsedError;

  /// Serializes this OrderModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderModelCopyWith<OrderModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderModelCopyWith<$Res> {
  factory $OrderModelCopyWith(
          OrderModel value, $Res Function(OrderModel) then) =
      _$OrderModelCopyWithImpl<$Res, OrderModel>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'merchant_id') String merchantId,
      @JsonKey(name: 'merchant_name') String? merchantName,
      @JsonKey(name: 'merchant_phone') String? merchantPhone,
      @JsonKey(name: 'driver_id') String? driverId,
      @JsonKey(name: 'driver_name') String? driverName,
      @JsonKey(name: 'driver_phone') String? driverPhone,
      @JsonKey(name: 'customer_name') String customerName,
      @JsonKey(name: 'customer_phone') String? customerPhone,
      @JsonKey(name: 'pickup_address') String pickupAddress,
      @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
      double pickupLatitude,
      @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
      double pickupLongitude,
      @JsonKey(name: 'delivery_address') String deliveryAddress,
      @JsonKey(name: 'delivery_latitude', fromJson: _doubleFromJson)
      double deliveryLatitude,
      @JsonKey(name: 'delivery_longitude', fromJson: _doubleFromJson)
      double deliveryLongitude,
      String status,
      @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
      double totalAmount,
      @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
      double deliveryFee,
      String? notes,
      @JsonKey(name: 'vehicle_type') String vehicleType,
      @JsonKey(name: 'bulk_order_id') String? bulkOrderId,
      @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(name: 'updated_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      DateTime? updatedAt,
      @JsonKey(
          name: 'driver_assigned_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? driverAssignedAt,
      @JsonKey(name: 'accepted_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      DateTime? acceptedAt,
      @JsonKey(
          name: 'rejected_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? rejectedAt,
      @JsonKey(name: 'timeout_remaining_seconds') int? timeoutRemainingSeconds,
      @JsonKey(name: 'ready_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      DateTime? readyAt,
      @JsonKey(name: 'ready_countdown') int? readyCountdown,
      @JsonKey(name: 'customer_location_provided')
      bool? customerLocationProvided,
      @JsonKey(name: 'user_friendly_code') String? userFriendlyCode,
      @JsonKey(name: 'delivery_time_limit_seconds')
      int? deliveryTimeLimitSeconds,
      @JsonKey(
          name: 'delivery_timer_started_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? deliveryTimerStartedAt,
      @JsonKey(
          name: 'delivery_timer_stopped_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? deliveryTimerStoppedAt,
      @JsonKey(
          name: 'delivery_timer_expires_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? deliveryTimerExpiresAt,
      List<OrderItemModel> items});
}

/// @nodoc
class _$OrderModelCopyWithImpl<$Res, $Val extends OrderModel>
    implements $OrderModelCopyWith<$Res> {
  _$OrderModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? merchantName = freezed,
    Object? merchantPhone = freezed,
    Object? driverId = freezed,
    Object? driverName = freezed,
    Object? driverPhone = freezed,
    Object? customerName = null,
    Object? customerPhone = freezed,
    Object? pickupAddress = null,
    Object? pickupLatitude = null,
    Object? pickupLongitude = null,
    Object? deliveryAddress = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
    Object? status = null,
    Object? totalAmount = null,
    Object? deliveryFee = null,
    Object? notes = freezed,
    Object? vehicleType = null,
    Object? bulkOrderId = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? driverAssignedAt = freezed,
    Object? acceptedAt = freezed,
    Object? rejectedAt = freezed,
    Object? timeoutRemainingSeconds = freezed,
    Object? readyAt = freezed,
    Object? readyCountdown = freezed,
    Object? customerLocationProvided = freezed,
    Object? userFriendlyCode = freezed,
    Object? deliveryTimeLimitSeconds = freezed,
    Object? deliveryTimerStartedAt = freezed,
    Object? deliveryTimerStoppedAt = freezed,
    Object? deliveryTimerExpiresAt = freezed,
    Object? items = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: null == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String,
      merchantName: freezed == merchantName
          ? _value.merchantName
          : merchantName // ignore: cast_nullable_to_non_nullable
              as String?,
      merchantPhone: freezed == merchantPhone
          ? _value.merchantPhone
          : merchantPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String?,
      driverName: freezed == driverName
          ? _value.driverName
          : driverName // ignore: cast_nullable_to_non_nullable
              as String?,
      driverPhone: freezed == driverPhone
          ? _value.driverPhone
          : driverPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      customerName: null == customerName
          ? _value.customerName
          : customerName // ignore: cast_nullable_to_non_nullable
              as String,
      customerPhone: freezed == customerPhone
          ? _value.customerPhone
          : customerPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      pickupAddress: null == pickupAddress
          ? _value.pickupAddress
          : pickupAddress // ignore: cast_nullable_to_non_nullable
              as String,
      pickupLatitude: null == pickupLatitude
          ? _value.pickupLatitude
          : pickupLatitude // ignore: cast_nullable_to_non_nullable
              as double,
      pickupLongitude: null == pickupLongitude
          ? _value.pickupLongitude
          : pickupLongitude // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryAddress: null == deliveryAddress
          ? _value.deliveryAddress
          : deliveryAddress // ignore: cast_nullable_to_non_nullable
              as String,
      deliveryLatitude: null == deliveryLatitude
          ? _value.deliveryLatitude
          : deliveryLatitude // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryLongitude: null == deliveryLongitude
          ? _value.deliveryLongitude
          : deliveryLongitude // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      totalAmount: null == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryFee: null == deliveryFee
          ? _value.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      bulkOrderId: freezed == bulkOrderId
          ? _value.bulkOrderId
          : bulkOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      driverAssignedAt: freezed == driverAssignedAt
          ? _value.driverAssignedAt
          : driverAssignedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rejectedAt: freezed == rejectedAt
          ? _value.rejectedAt
          : rejectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      timeoutRemainingSeconds: freezed == timeoutRemainingSeconds
          ? _value.timeoutRemainingSeconds
          : timeoutRemainingSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      readyAt: freezed == readyAt
          ? _value.readyAt
          : readyAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      readyCountdown: freezed == readyCountdown
          ? _value.readyCountdown
          : readyCountdown // ignore: cast_nullable_to_non_nullable
              as int?,
      customerLocationProvided: freezed == customerLocationProvided
          ? _value.customerLocationProvided
          : customerLocationProvided // ignore: cast_nullable_to_non_nullable
              as bool?,
      userFriendlyCode: freezed == userFriendlyCode
          ? _value.userFriendlyCode
          : userFriendlyCode // ignore: cast_nullable_to_non_nullable
              as String?,
      deliveryTimeLimitSeconds: freezed == deliveryTimeLimitSeconds
          ? _value.deliveryTimeLimitSeconds
          : deliveryTimeLimitSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      deliveryTimerStartedAt: freezed == deliveryTimerStartedAt
          ? _value.deliveryTimerStartedAt
          : deliveryTimerStartedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deliveryTimerStoppedAt: freezed == deliveryTimerStoppedAt
          ? _value.deliveryTimerStoppedAt
          : deliveryTimerStoppedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deliveryTimerExpiresAt: freezed == deliveryTimerExpiresAt
          ? _value.deliveryTimerExpiresAt
          : deliveryTimerExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<OrderItemModel>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderModelImplCopyWith<$Res>
    implements $OrderModelCopyWith<$Res> {
  factory _$$OrderModelImplCopyWith(
          _$OrderModelImpl value, $Res Function(_$OrderModelImpl) then) =
      __$$OrderModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'merchant_id') String merchantId,
      @JsonKey(name: 'merchant_name') String? merchantName,
      @JsonKey(name: 'merchant_phone') String? merchantPhone,
      @JsonKey(name: 'driver_id') String? driverId,
      @JsonKey(name: 'driver_name') String? driverName,
      @JsonKey(name: 'driver_phone') String? driverPhone,
      @JsonKey(name: 'customer_name') String customerName,
      @JsonKey(name: 'customer_phone') String? customerPhone,
      @JsonKey(name: 'pickup_address') String pickupAddress,
      @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
      double pickupLatitude,
      @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
      double pickupLongitude,
      @JsonKey(name: 'delivery_address') String deliveryAddress,
      @JsonKey(name: 'delivery_latitude', fromJson: _doubleFromJson)
      double deliveryLatitude,
      @JsonKey(name: 'delivery_longitude', fromJson: _doubleFromJson)
      double deliveryLongitude,
      String status,
      @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
      double totalAmount,
      @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
      double deliveryFee,
      String? notes,
      @JsonKey(name: 'vehicle_type') String vehicleType,
      @JsonKey(name: 'bulk_order_id') String? bulkOrderId,
      @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(name: 'updated_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      DateTime? updatedAt,
      @JsonKey(
          name: 'driver_assigned_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? driverAssignedAt,
      @JsonKey(name: 'accepted_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      DateTime? acceptedAt,
      @JsonKey(
          name: 'rejected_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? rejectedAt,
      @JsonKey(name: 'timeout_remaining_seconds') int? timeoutRemainingSeconds,
      @JsonKey(name: 'ready_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      DateTime? readyAt,
      @JsonKey(name: 'ready_countdown') int? readyCountdown,
      @JsonKey(name: 'customer_location_provided')
      bool? customerLocationProvided,
      @JsonKey(name: 'user_friendly_code') String? userFriendlyCode,
      @JsonKey(name: 'delivery_time_limit_seconds')
      int? deliveryTimeLimitSeconds,
      @JsonKey(
          name: 'delivery_timer_started_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? deliveryTimerStartedAt,
      @JsonKey(
          name: 'delivery_timer_stopped_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? deliveryTimerStoppedAt,
      @JsonKey(
          name: 'delivery_timer_expires_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? deliveryTimerExpiresAt,
      List<OrderItemModel> items});
}

/// @nodoc
class __$$OrderModelImplCopyWithImpl<$Res>
    extends _$OrderModelCopyWithImpl<$Res, _$OrderModelImpl>
    implements _$$OrderModelImplCopyWith<$Res> {
  __$$OrderModelImplCopyWithImpl(
      _$OrderModelImpl _value, $Res Function(_$OrderModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? merchantName = freezed,
    Object? merchantPhone = freezed,
    Object? driverId = freezed,
    Object? driverName = freezed,
    Object? driverPhone = freezed,
    Object? customerName = null,
    Object? customerPhone = freezed,
    Object? pickupAddress = null,
    Object? pickupLatitude = null,
    Object? pickupLongitude = null,
    Object? deliveryAddress = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
    Object? status = null,
    Object? totalAmount = null,
    Object? deliveryFee = null,
    Object? notes = freezed,
    Object? vehicleType = null,
    Object? bulkOrderId = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? driverAssignedAt = freezed,
    Object? acceptedAt = freezed,
    Object? rejectedAt = freezed,
    Object? timeoutRemainingSeconds = freezed,
    Object? readyAt = freezed,
    Object? readyCountdown = freezed,
    Object? customerLocationProvided = freezed,
    Object? userFriendlyCode = freezed,
    Object? deliveryTimeLimitSeconds = freezed,
    Object? deliveryTimerStartedAt = freezed,
    Object? deliveryTimerStoppedAt = freezed,
    Object? deliveryTimerExpiresAt = freezed,
    Object? items = null,
  }) {
    return _then(_$OrderModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: null == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String,
      merchantName: freezed == merchantName
          ? _value.merchantName
          : merchantName // ignore: cast_nullable_to_non_nullable
              as String?,
      merchantPhone: freezed == merchantPhone
          ? _value.merchantPhone
          : merchantPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String?,
      driverName: freezed == driverName
          ? _value.driverName
          : driverName // ignore: cast_nullable_to_non_nullable
              as String?,
      driverPhone: freezed == driverPhone
          ? _value.driverPhone
          : driverPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      customerName: null == customerName
          ? _value.customerName
          : customerName // ignore: cast_nullable_to_non_nullable
              as String,
      customerPhone: freezed == customerPhone
          ? _value.customerPhone
          : customerPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      pickupAddress: null == pickupAddress
          ? _value.pickupAddress
          : pickupAddress // ignore: cast_nullable_to_non_nullable
              as String,
      pickupLatitude: null == pickupLatitude
          ? _value.pickupLatitude
          : pickupLatitude // ignore: cast_nullable_to_non_nullable
              as double,
      pickupLongitude: null == pickupLongitude
          ? _value.pickupLongitude
          : pickupLongitude // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryAddress: null == deliveryAddress
          ? _value.deliveryAddress
          : deliveryAddress // ignore: cast_nullable_to_non_nullable
              as String,
      deliveryLatitude: null == deliveryLatitude
          ? _value.deliveryLatitude
          : deliveryLatitude // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryLongitude: null == deliveryLongitude
          ? _value.deliveryLongitude
          : deliveryLongitude // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      totalAmount: null == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryFee: null == deliveryFee
          ? _value.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      bulkOrderId: freezed == bulkOrderId
          ? _value.bulkOrderId
          : bulkOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      driverAssignedAt: freezed == driverAssignedAt
          ? _value.driverAssignedAt
          : driverAssignedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rejectedAt: freezed == rejectedAt
          ? _value.rejectedAt
          : rejectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      timeoutRemainingSeconds: freezed == timeoutRemainingSeconds
          ? _value.timeoutRemainingSeconds
          : timeoutRemainingSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      readyAt: freezed == readyAt
          ? _value.readyAt
          : readyAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      readyCountdown: freezed == readyCountdown
          ? _value.readyCountdown
          : readyCountdown // ignore: cast_nullable_to_non_nullable
              as int?,
      customerLocationProvided: freezed == customerLocationProvided
          ? _value.customerLocationProvided
          : customerLocationProvided // ignore: cast_nullable_to_non_nullable
              as bool?,
      userFriendlyCode: freezed == userFriendlyCode
          ? _value.userFriendlyCode
          : userFriendlyCode // ignore: cast_nullable_to_non_nullable
              as String?,
      deliveryTimeLimitSeconds: freezed == deliveryTimeLimitSeconds
          ? _value.deliveryTimeLimitSeconds
          : deliveryTimeLimitSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      deliveryTimerStartedAt: freezed == deliveryTimerStartedAt
          ? _value.deliveryTimerStartedAt
          : deliveryTimerStartedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deliveryTimerStoppedAt: freezed == deliveryTimerStoppedAt
          ? _value.deliveryTimerStoppedAt
          : deliveryTimerStoppedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deliveryTimerExpiresAt: freezed == deliveryTimerExpiresAt
          ? _value.deliveryTimerExpiresAt
          : deliveryTimerExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<OrderItemModel>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderModelImpl extends _OrderModel {
  const _$OrderModelImpl(
      {required this.id,
      @JsonKey(name: 'merchant_id') required this.merchantId,
      @JsonKey(name: 'merchant_name') this.merchantName,
      @JsonKey(name: 'merchant_phone') this.merchantPhone,
      @JsonKey(name: 'driver_id') this.driverId,
      @JsonKey(name: 'driver_name') this.driverName,
      @JsonKey(name: 'driver_phone') this.driverPhone,
      @JsonKey(name: 'customer_name') required this.customerName,
      @JsonKey(name: 'customer_phone') this.customerPhone,
      @JsonKey(name: 'pickup_address') required this.pickupAddress,
      @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
      required this.pickupLatitude,
      @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
      required this.pickupLongitude,
      @JsonKey(name: 'delivery_address') required this.deliveryAddress,
      @JsonKey(name: 'delivery_latitude', fromJson: _doubleFromJson)
      required this.deliveryLatitude,
      @JsonKey(name: 'delivery_longitude', fromJson: _doubleFromJson)
      required this.deliveryLongitude,
      this.status = 'pending',
      @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
      this.totalAmount = 0.0,
      @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
      this.deliveryFee = 0.0,
      this.notes,
      @JsonKey(name: 'vehicle_type') this.vehicleType = 'motorbike',
      @JsonKey(name: 'bulk_order_id') this.bulkOrderId,
      @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      required this.createdAt,
      @JsonKey(name: 'updated_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      this.updatedAt,
      @JsonKey(
          name: 'driver_assigned_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.driverAssignedAt,
      @JsonKey(name: 'accepted_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      this.acceptedAt,
      @JsonKey(
          name: 'rejected_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.rejectedAt,
      @JsonKey(name: 'timeout_remaining_seconds') this.timeoutRemainingSeconds,
      @JsonKey(name: 'ready_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      this.readyAt,
      @JsonKey(name: 'ready_countdown') this.readyCountdown,
      @JsonKey(name: 'customer_location_provided')
      this.customerLocationProvided,
      @JsonKey(name: 'user_friendly_code') this.userFriendlyCode,
      @JsonKey(name: 'delivery_time_limit_seconds')
      this.deliveryTimeLimitSeconds,
      @JsonKey(
          name: 'delivery_timer_started_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.deliveryTimerStartedAt,
      @JsonKey(
          name: 'delivery_timer_stopped_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.deliveryTimerStoppedAt,
      @JsonKey(
          name: 'delivery_timer_expires_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.deliveryTimerExpiresAt,
      final List<OrderItemModel> items = const []})
      : _items = items,
        super._();

  factory _$OrderModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'merchant_id')
  final String merchantId;
  @override
  @JsonKey(name: 'merchant_name')
  final String? merchantName;
  @override
  @JsonKey(name: 'merchant_phone')
  final String? merchantPhone;
  @override
  @JsonKey(name: 'driver_id')
  final String? driverId;
  @override
  @JsonKey(name: 'driver_name')
  final String? driverName;
  @override
  @JsonKey(name: 'driver_phone')
  final String? driverPhone;
  @override
  @JsonKey(name: 'customer_name')
  final String customerName;
  @override
  @JsonKey(name: 'customer_phone')
  final String? customerPhone;
  @override
  @JsonKey(name: 'pickup_address')
  final String pickupAddress;
  @override
  @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
  final double pickupLatitude;
  @override
  @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
  final double pickupLongitude;
  @override
  @JsonKey(name: 'delivery_address')
  final String deliveryAddress;
  @override
  @JsonKey(name: 'delivery_latitude', fromJson: _doubleFromJson)
  final double deliveryLatitude;
  @override
  @JsonKey(name: 'delivery_longitude', fromJson: _doubleFromJson)
  final double deliveryLongitude;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
  final double totalAmount;
  @override
  @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
  final double deliveryFee;
  @override
  final String? notes;
  @override
  @JsonKey(name: 'vehicle_type')
  final String vehicleType;
  @override
  @JsonKey(name: 'bulk_order_id')
  final String? bulkOrderId;
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
  @JsonKey(
      name: 'driver_assigned_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? driverAssignedAt;
  @override
  @JsonKey(
      name: 'accepted_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? acceptedAt;
  @override
  @JsonKey(
      name: 'rejected_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? rejectedAt;
  @override
  @JsonKey(name: 'timeout_remaining_seconds')
  final int? timeoutRemainingSeconds;
  @override
  @JsonKey(
      name: 'ready_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? readyAt;
  @override
  @JsonKey(name: 'ready_countdown')
  final int? readyCountdown;
  @override
  @JsonKey(name: 'customer_location_provided')
  final bool? customerLocationProvided;
  @override
  @JsonKey(name: 'user_friendly_code')
  final String? userFriendlyCode;
  @override
  @JsonKey(name: 'delivery_time_limit_seconds')
  final int? deliveryTimeLimitSeconds;
  @override
  @JsonKey(
      name: 'delivery_timer_started_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? deliveryTimerStartedAt;
  @override
  @JsonKey(
      name: 'delivery_timer_stopped_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? deliveryTimerStoppedAt;
  @override
  @JsonKey(
      name: 'delivery_timer_expires_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? deliveryTimerExpiresAt;
  final List<OrderItemModel> _items;
  @override
  @JsonKey()
  List<OrderItemModel> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  String toString() {
    return 'OrderModel(id: $id, merchantId: $merchantId, merchantName: $merchantName, merchantPhone: $merchantPhone, driverId: $driverId, driverName: $driverName, driverPhone: $driverPhone, customerName: $customerName, customerPhone: $customerPhone, pickupAddress: $pickupAddress, pickupLatitude: $pickupLatitude, pickupLongitude: $pickupLongitude, deliveryAddress: $deliveryAddress, deliveryLatitude: $deliveryLatitude, deliveryLongitude: $deliveryLongitude, status: $status, totalAmount: $totalAmount, deliveryFee: $deliveryFee, notes: $notes, vehicleType: $vehicleType, bulkOrderId: $bulkOrderId, createdAt: $createdAt, updatedAt: $updatedAt, driverAssignedAt: $driverAssignedAt, acceptedAt: $acceptedAt, rejectedAt: $rejectedAt, timeoutRemainingSeconds: $timeoutRemainingSeconds, readyAt: $readyAt, readyCountdown: $readyCountdown, customerLocationProvided: $customerLocationProvided, userFriendlyCode: $userFriendlyCode, deliveryTimeLimitSeconds: $deliveryTimeLimitSeconds, deliveryTimerStartedAt: $deliveryTimerStartedAt, deliveryTimerStoppedAt: $deliveryTimerStoppedAt, deliveryTimerExpiresAt: $deliveryTimerExpiresAt, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
            (identical(other.merchantName, merchantName) ||
                other.merchantName == merchantName) &&
            (identical(other.merchantPhone, merchantPhone) ||
                other.merchantPhone == merchantPhone) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.driverName, driverName) ||
                other.driverName == driverName) &&
            (identical(other.driverPhone, driverPhone) ||
                other.driverPhone == driverPhone) &&
            (identical(other.customerName, customerName) ||
                other.customerName == customerName) &&
            (identical(other.customerPhone, customerPhone) ||
                other.customerPhone == customerPhone) &&
            (identical(other.pickupAddress, pickupAddress) ||
                other.pickupAddress == pickupAddress) &&
            (identical(other.pickupLatitude, pickupLatitude) ||
                other.pickupLatitude == pickupLatitude) &&
            (identical(other.pickupLongitude, pickupLongitude) ||
                other.pickupLongitude == pickupLongitude) &&
            (identical(other.deliveryAddress, deliveryAddress) ||
                other.deliveryAddress == deliveryAddress) &&
            (identical(other.deliveryLatitude, deliveryLatitude) ||
                other.deliveryLatitude == deliveryLatitude) &&
            (identical(other.deliveryLongitude, deliveryLongitude) ||
                other.deliveryLongitude == deliveryLongitude) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.bulkOrderId, bulkOrderId) ||
                other.bulkOrderId == bulkOrderId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.driverAssignedAt, driverAssignedAt) ||
                other.driverAssignedAt == driverAssignedAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.rejectedAt, rejectedAt) ||
                other.rejectedAt == rejectedAt) &&
            (identical(
                    other.timeoutRemainingSeconds, timeoutRemainingSeconds) ||
                other.timeoutRemainingSeconds == timeoutRemainingSeconds) &&
            (identical(other.readyAt, readyAt) || other.readyAt == readyAt) &&
            (identical(other.readyCountdown, readyCountdown) ||
                other.readyCountdown == readyCountdown) &&
            (identical(
                    other.customerLocationProvided, customerLocationProvided) ||
                other.customerLocationProvided == customerLocationProvided) &&
            (identical(other.userFriendlyCode, userFriendlyCode) ||
                other.userFriendlyCode == userFriendlyCode) &&
            (identical(
                    other.deliveryTimeLimitSeconds, deliveryTimeLimitSeconds) ||
                other.deliveryTimeLimitSeconds == deliveryTimeLimitSeconds) &&
            (identical(other.deliveryTimerStartedAt, deliveryTimerStartedAt) ||
                other.deliveryTimerStartedAt == deliveryTimerStartedAt) &&
            (identical(other.deliveryTimerStoppedAt, deliveryTimerStoppedAt) ||
                other.deliveryTimerStoppedAt == deliveryTimerStoppedAt) &&
            (identical(other.deliveryTimerExpiresAt, deliveryTimerExpiresAt) ||
                other.deliveryTimerExpiresAt == deliveryTimerExpiresAt) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        merchantId,
        merchantName,
        merchantPhone,
        driverId,
        driverName,
        driverPhone,
        customerName,
        customerPhone,
        pickupAddress,
        pickupLatitude,
        pickupLongitude,
        deliveryAddress,
        deliveryLatitude,
        deliveryLongitude,
        status,
        totalAmount,
        deliveryFee,
        notes,
        vehicleType,
        bulkOrderId,
        createdAt,
        updatedAt,
        driverAssignedAt,
        acceptedAt,
        rejectedAt,
        timeoutRemainingSeconds,
        readyAt,
        readyCountdown,
        customerLocationProvided,
        userFriendlyCode,
        deliveryTimeLimitSeconds,
        deliveryTimerStartedAt,
        deliveryTimerStoppedAt,
        deliveryTimerExpiresAt,
        const DeepCollectionEquality().hash(_items)
      ]);

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      __$$OrderModelImplCopyWithImpl<_$OrderModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderModelImplToJson(
      this,
    );
  }
}

abstract class _OrderModel extends OrderModel {
  const factory _OrderModel(
      {required final String id,
      @JsonKey(name: 'merchant_id') required final String merchantId,
      @JsonKey(name: 'merchant_name') final String? merchantName,
      @JsonKey(name: 'merchant_phone') final String? merchantPhone,
      @JsonKey(name: 'driver_id') final String? driverId,
      @JsonKey(name: 'driver_name') final String? driverName,
      @JsonKey(name: 'driver_phone') final String? driverPhone,
      @JsonKey(name: 'customer_name') required final String customerName,
      @JsonKey(name: 'customer_phone') final String? customerPhone,
      @JsonKey(name: 'pickup_address') required final String pickupAddress,
      @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
      required final double pickupLatitude,
      @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
      required final double pickupLongitude,
      @JsonKey(name: 'delivery_address') required final String deliveryAddress,
      @JsonKey(name: 'delivery_latitude', fromJson: _doubleFromJson)
      required final double deliveryLatitude,
      @JsonKey(name: 'delivery_longitude', fromJson: _doubleFromJson)
      required final double deliveryLongitude,
      final String status,
      @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
      final double totalAmount,
      @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
      final double deliveryFee,
      final String? notes,
      @JsonKey(name: 'vehicle_type') final String vehicleType,
      @JsonKey(name: 'bulk_order_id') final String? bulkOrderId,
      @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
      required final DateTime createdAt,
      @JsonKey(name: 'updated_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      final DateTime? updatedAt,
      @JsonKey(
          name: 'driver_assigned_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? driverAssignedAt,
      @JsonKey(
          name: 'accepted_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? acceptedAt,
      @JsonKey(
          name: 'rejected_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? rejectedAt,
      @JsonKey(name: 'timeout_remaining_seconds')
      final int? timeoutRemainingSeconds,
      @JsonKey(name: 'ready_at', fromJson: _nullableDateTimeFromJson, toJson: _nullableDateTimeToJson)
      final DateTime? readyAt,
      @JsonKey(name: 'ready_countdown') final int? readyCountdown,
      @JsonKey(name: 'customer_location_provided')
      final bool? customerLocationProvided,
      @JsonKey(name: 'user_friendly_code') final String? userFriendlyCode,
      @JsonKey(name: 'delivery_time_limit_seconds')
      final int? deliveryTimeLimitSeconds,
      @JsonKey(
          name: 'delivery_timer_started_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? deliveryTimerStartedAt,
      @JsonKey(
          name: 'delivery_timer_stopped_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? deliveryTimerStoppedAt,
      @JsonKey(
          name: 'delivery_timer_expires_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? deliveryTimerExpiresAt,
      final List<OrderItemModel> items}) = _$OrderModelImpl;
  const _OrderModel._() : super._();

  factory _OrderModel.fromJson(Map<String, dynamic> json) =
      _$OrderModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'merchant_id')
  String get merchantId;
  @override
  @JsonKey(name: 'merchant_name')
  String? get merchantName;
  @override
  @JsonKey(name: 'merchant_phone')
  String? get merchantPhone;
  @override
  @JsonKey(name: 'driver_id')
  String? get driverId;
  @override
  @JsonKey(name: 'driver_name')
  String? get driverName;
  @override
  @JsonKey(name: 'driver_phone')
  String? get driverPhone;
  @override
  @JsonKey(name: 'customer_name')
  String get customerName;
  @override
  @JsonKey(name: 'customer_phone')
  String? get customerPhone;
  @override
  @JsonKey(name: 'pickup_address')
  String get pickupAddress;
  @override
  @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
  double get pickupLatitude;
  @override
  @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
  double get pickupLongitude;
  @override
  @JsonKey(name: 'delivery_address')
  String get deliveryAddress;
  @override
  @JsonKey(name: 'delivery_latitude', fromJson: _doubleFromJson)
  double get deliveryLatitude;
  @override
  @JsonKey(name: 'delivery_longitude', fromJson: _doubleFromJson)
  double get deliveryLongitude;
  @override
  String get status;
  @override
  @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
  double get totalAmount;
  @override
  @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
  double get deliveryFee;
  @override
  String? get notes;
  @override
  @JsonKey(name: 'vehicle_type')
  String get vehicleType;
  @override
  @JsonKey(name: 'bulk_order_id')
  String? get bulkOrderId;
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
  @override
  @JsonKey(
      name: 'driver_assigned_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get driverAssignedAt;
  @override
  @JsonKey(
      name: 'accepted_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get acceptedAt;
  @override
  @JsonKey(
      name: 'rejected_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get rejectedAt;
  @override
  @JsonKey(name: 'timeout_remaining_seconds')
  int? get timeoutRemainingSeconds;
  @override
  @JsonKey(
      name: 'ready_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get readyAt;
  @override
  @JsonKey(name: 'ready_countdown')
  int? get readyCountdown;
  @override
  @JsonKey(name: 'customer_location_provided')
  bool? get customerLocationProvided;
  @override
  @JsonKey(name: 'user_friendly_code')
  String? get userFriendlyCode;
  @override
  @JsonKey(name: 'delivery_time_limit_seconds')
  int? get deliveryTimeLimitSeconds;
  @override
  @JsonKey(
      name: 'delivery_timer_started_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get deliveryTimerStartedAt;
  @override
  @JsonKey(
      name: 'delivery_timer_stopped_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get deliveryTimerStoppedAt;
  @override
  @JsonKey(
      name: 'delivery_timer_expires_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get deliveryTimerExpiresAt;
  @override
  List<OrderItemModel> get items;

  /// Create a copy of OrderModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderModelImplCopyWith<_$OrderModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderItemModel _$OrderItemModelFromJson(Map<String, dynamic> json) {
  return _OrderItemModel.fromJson(json);
}

/// @nodoc
mixin _$OrderItemModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'order_id')
  String get orderId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _doubleFromJson)
  double get price => throw _privateConstructorUsedError;

  /// Serializes this OrderItemModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderItemModelCopyWith<OrderItemModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderItemModelCopyWith<$Res> {
  factory $OrderItemModelCopyWith(
          OrderItemModel value, $Res Function(OrderItemModel) then) =
      _$OrderItemModelCopyWithImpl<$Res, OrderItemModel>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'order_id') String orderId,
      String name,
      int quantity,
      @JsonKey(fromJson: _doubleFromJson) double price});
}

/// @nodoc
class _$OrderItemModelCopyWithImpl<$Res, $Val extends OrderItemModel>
    implements $OrderItemModelCopyWith<$Res> {
  _$OrderItemModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? name = null,
    Object? quantity = null,
    Object? price = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: null == orderId
          ? _value.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderItemModelImplCopyWith<$Res>
    implements $OrderItemModelCopyWith<$Res> {
  factory _$$OrderItemModelImplCopyWith(_$OrderItemModelImpl value,
          $Res Function(_$OrderItemModelImpl) then) =
      __$$OrderItemModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'order_id') String orderId,
      String name,
      int quantity,
      @JsonKey(fromJson: _doubleFromJson) double price});
}

/// @nodoc
class __$$OrderItemModelImplCopyWithImpl<$Res>
    extends _$OrderItemModelCopyWithImpl<$Res, _$OrderItemModelImpl>
    implements _$$OrderItemModelImplCopyWith<$Res> {
  __$$OrderItemModelImplCopyWithImpl(
      _$OrderItemModelImpl _value, $Res Function(_$OrderItemModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? name = null,
    Object? quantity = null,
    Object? price = null,
  }) {
    return _then(_$OrderItemModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: null == orderId
          ? _value.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderItemModelImpl extends _OrderItemModel {
  const _$OrderItemModelImpl(
      {required this.id,
      @JsonKey(name: 'order_id') required this.orderId,
      required this.name,
      this.quantity = 1,
      @JsonKey(fromJson: _doubleFromJson) this.price = 0.0})
      : super._();

  factory _$OrderItemModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderItemModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'order_id')
  final String orderId;
  @override
  final String name;
  @override
  @JsonKey()
  final int quantity;
  @override
  @JsonKey(fromJson: _doubleFromJson)
  final double price;

  @override
  String toString() {
    return 'OrderItemModel(id: $id, orderId: $orderId, name: $name, quantity: $quantity, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderItemModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.price, price) || other.price == price));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, orderId, name, quantity, price);

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderItemModelImplCopyWith<_$OrderItemModelImpl> get copyWith =>
      __$$OrderItemModelImplCopyWithImpl<_$OrderItemModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderItemModelImplToJson(
      this,
    );
  }
}

abstract class _OrderItemModel extends OrderItemModel {
  const factory _OrderItemModel(
          {required final String id,
          @JsonKey(name: 'order_id') required final String orderId,
          required final String name,
          final int quantity,
          @JsonKey(fromJson: _doubleFromJson) final double price}) =
      _$OrderItemModelImpl;
  const _OrderItemModel._() : super._();

  factory _OrderItemModel.fromJson(Map<String, dynamic> json) =
      _$OrderItemModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'order_id')
  String get orderId;
  @override
  String get name;
  @override
  int get quantity;
  @override
  @JsonKey(fromJson: _doubleFromJson)
  double get price;

  /// Create a copy of OrderItemModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderItemModelImplCopyWith<_$OrderItemModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
