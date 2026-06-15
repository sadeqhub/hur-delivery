// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_order_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ScheduledOrderModel _$ScheduledOrderModelFromJson(Map<String, dynamic> json) {
  return _ScheduledOrderModel.fromJson(json);
}

/// @nodoc
mixin _$ScheduledOrderModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'merchant_id')
  String get merchantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_name')
  String get customerName => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_phone')
  String get customerPhone => throw _privateConstructorUsedError;
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
  @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
  double get totalAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
  double get deliveryFee => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  @JsonKey(name: 'vehicle_type')
  String get vehicleType => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'scheduled_date',
      fromJson: _dateTimeFromJson,
      toJson: _dateOnlyToJson)
  DateTime get scheduledDate => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'scheduled_time',
      fromJson: _durationFromJson,
      toJson: _durationToJson)
  Duration get scheduledTime => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_order_id')
  String? get createdOrderId => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ScheduledOrderModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ScheduledOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScheduledOrderModelCopyWith<ScheduledOrderModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScheduledOrderModelCopyWith<$Res> {
  factory $ScheduledOrderModelCopyWith(
          ScheduledOrderModel value, $Res Function(ScheduledOrderModel) then) =
      _$ScheduledOrderModelCopyWithImpl<$Res, ScheduledOrderModel>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'merchant_id') String merchantId,
      @JsonKey(name: 'customer_name') String customerName,
      @JsonKey(name: 'customer_phone') String customerPhone,
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
      @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
      double totalAmount,
      @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
      double deliveryFee,
      String? notes,
      @JsonKey(name: 'vehicle_type') String vehicleType,
      @JsonKey(
          name: 'scheduled_date',
          fromJson: _dateTimeFromJson,
          toJson: _dateOnlyToJson)
      DateTime scheduledDate,
      @JsonKey(
          name: 'scheduled_time',
          fromJson: _durationFromJson,
          toJson: _durationToJson)
      Duration scheduledTime,
      String status,
      @JsonKey(name: 'created_order_id') String? createdOrderId,
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
class _$ScheduledOrderModelCopyWithImpl<$Res, $Val extends ScheduledOrderModel>
    implements $ScheduledOrderModelCopyWith<$Res> {
  _$ScheduledOrderModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScheduledOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? customerName = null,
    Object? customerPhone = null,
    Object? pickupAddress = null,
    Object? pickupLatitude = null,
    Object? pickupLongitude = null,
    Object? deliveryAddress = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
    Object? totalAmount = null,
    Object? deliveryFee = null,
    Object? notes = freezed,
    Object? vehicleType = null,
    Object? scheduledDate = null,
    Object? scheduledTime = null,
    Object? status = null,
    Object? createdOrderId = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
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
      customerName: null == customerName
          ? _value.customerName
          : customerName // ignore: cast_nullable_to_non_nullable
              as String,
      customerPhone: null == customerPhone
          ? _value.customerPhone
          : customerPhone // ignore: cast_nullable_to_non_nullable
              as String,
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
      scheduledDate: null == scheduledDate
          ? _value.scheduledDate
          : scheduledDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      scheduledTime: null == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdOrderId: freezed == createdOrderId
          ? _value.createdOrderId
          : createdOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
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
abstract class _$$ScheduledOrderModelImplCopyWith<$Res>
    implements $ScheduledOrderModelCopyWith<$Res> {
  factory _$$ScheduledOrderModelImplCopyWith(_$ScheduledOrderModelImpl value,
          $Res Function(_$ScheduledOrderModelImpl) then) =
      __$$ScheduledOrderModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'merchant_id') String merchantId,
      @JsonKey(name: 'customer_name') String customerName,
      @JsonKey(name: 'customer_phone') String customerPhone,
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
      @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
      double totalAmount,
      @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
      double deliveryFee,
      String? notes,
      @JsonKey(name: 'vehicle_type') String vehicleType,
      @JsonKey(
          name: 'scheduled_date',
          fromJson: _dateTimeFromJson,
          toJson: _dateOnlyToJson)
      DateTime scheduledDate,
      @JsonKey(
          name: 'scheduled_time',
          fromJson: _durationFromJson,
          toJson: _durationToJson)
      Duration scheduledTime,
      String status,
      @JsonKey(name: 'created_order_id') String? createdOrderId,
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
class __$$ScheduledOrderModelImplCopyWithImpl<$Res>
    extends _$ScheduledOrderModelCopyWithImpl<$Res, _$ScheduledOrderModelImpl>
    implements _$$ScheduledOrderModelImplCopyWith<$Res> {
  __$$ScheduledOrderModelImplCopyWithImpl(_$ScheduledOrderModelImpl _value,
      $Res Function(_$ScheduledOrderModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of ScheduledOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? customerName = null,
    Object? customerPhone = null,
    Object? pickupAddress = null,
    Object? pickupLatitude = null,
    Object? pickupLongitude = null,
    Object? deliveryAddress = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
    Object? totalAmount = null,
    Object? deliveryFee = null,
    Object? notes = freezed,
    Object? vehicleType = null,
    Object? scheduledDate = null,
    Object? scheduledTime = null,
    Object? status = null,
    Object? createdOrderId = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ScheduledOrderModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: null == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String,
      customerName: null == customerName
          ? _value.customerName
          : customerName // ignore: cast_nullable_to_non_nullable
              as String,
      customerPhone: null == customerPhone
          ? _value.customerPhone
          : customerPhone // ignore: cast_nullable_to_non_nullable
              as String,
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
      scheduledDate: null == scheduledDate
          ? _value.scheduledDate
          : scheduledDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      scheduledTime: null == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdOrderId: freezed == createdOrderId
          ? _value.createdOrderId
          : createdOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
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
class _$ScheduledOrderModelImpl extends _ScheduledOrderModel {
  const _$ScheduledOrderModelImpl(
      {required this.id,
      @JsonKey(name: 'merchant_id') required this.merchantId,
      @JsonKey(name: 'customer_name') required this.customerName,
      @JsonKey(name: 'customer_phone') required this.customerPhone,
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
      @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
      required this.totalAmount,
      @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
      required this.deliveryFee,
      this.notes,
      @JsonKey(name: 'vehicle_type') this.vehicleType = 'motorcycle',
      @JsonKey(
          name: 'scheduled_date',
          fromJson: _dateTimeFromJson,
          toJson: _dateOnlyToJson)
      required this.scheduledDate,
      @JsonKey(
          name: 'scheduled_time',
          fromJson: _durationFromJson,
          toJson: _durationToJson)
      required this.scheduledTime,
      this.status = 'scheduled',
      @JsonKey(name: 'created_order_id') this.createdOrderId,
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

  factory _$ScheduledOrderModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScheduledOrderModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'merchant_id')
  final String merchantId;
  @override
  @JsonKey(name: 'customer_name')
  final String customerName;
  @override
  @JsonKey(name: 'customer_phone')
  final String customerPhone;
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
  @JsonKey(
      name: 'scheduled_date',
      fromJson: _dateTimeFromJson,
      toJson: _dateOnlyToJson)
  final DateTime scheduledDate;
  @override
  @JsonKey(
      name: 'scheduled_time',
      fromJson: _durationFromJson,
      toJson: _durationToJson)
  final Duration scheduledTime;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(name: 'created_order_id')
  final String? createdOrderId;
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
    return 'ScheduledOrderModel(id: $id, merchantId: $merchantId, customerName: $customerName, customerPhone: $customerPhone, pickupAddress: $pickupAddress, pickupLatitude: $pickupLatitude, pickupLongitude: $pickupLongitude, deliveryAddress: $deliveryAddress, deliveryLatitude: $deliveryLatitude, deliveryLongitude: $deliveryLongitude, totalAmount: $totalAmount, deliveryFee: $deliveryFee, notes: $notes, vehicleType: $vehicleType, scheduledDate: $scheduledDate, scheduledTime: $scheduledTime, status: $status, createdOrderId: $createdOrderId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScheduledOrderModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
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
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.scheduledDate, scheduledDate) ||
                other.scheduledDate == scheduledDate) &&
            (identical(other.scheduledTime, scheduledTime) ||
                other.scheduledTime == scheduledTime) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdOrderId, createdOrderId) ||
                other.createdOrderId == createdOrderId) &&
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
        merchantId,
        customerName,
        customerPhone,
        pickupAddress,
        pickupLatitude,
        pickupLongitude,
        deliveryAddress,
        deliveryLatitude,
        deliveryLongitude,
        totalAmount,
        deliveryFee,
        notes,
        vehicleType,
        scheduledDate,
        scheduledTime,
        status,
        createdOrderId,
        createdAt,
        updatedAt
      ]);

  /// Create a copy of ScheduledOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScheduledOrderModelImplCopyWith<_$ScheduledOrderModelImpl> get copyWith =>
      __$$ScheduledOrderModelImplCopyWithImpl<_$ScheduledOrderModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScheduledOrderModelImplToJson(
      this,
    );
  }
}

abstract class _ScheduledOrderModel extends ScheduledOrderModel {
  const factory _ScheduledOrderModel(
      {required final String id,
      @JsonKey(name: 'merchant_id') required final String merchantId,
      @JsonKey(name: 'customer_name') required final String customerName,
      @JsonKey(name: 'customer_phone') required final String customerPhone,
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
      @JsonKey(name: 'total_amount', fromJson: _doubleFromJson)
      required final double totalAmount,
      @JsonKey(name: 'delivery_fee', fromJson: _doubleFromJson)
      required final double deliveryFee,
      final String? notes,
      @JsonKey(name: 'vehicle_type') final String vehicleType,
      @JsonKey(
          name: 'scheduled_date',
          fromJson: _dateTimeFromJson,
          toJson: _dateOnlyToJson)
      required final DateTime scheduledDate,
      @JsonKey(
          name: 'scheduled_time',
          fromJson: _durationFromJson,
          toJson: _durationToJson)
      required final Duration scheduledTime,
      final String status,
      @JsonKey(name: 'created_order_id') final String? createdOrderId,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      required final DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      final DateTime? updatedAt}) = _$ScheduledOrderModelImpl;
  const _ScheduledOrderModel._() : super._();

  factory _ScheduledOrderModel.fromJson(Map<String, dynamic> json) =
      _$ScheduledOrderModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'merchant_id')
  String get merchantId;
  @override
  @JsonKey(name: 'customer_name')
  String get customerName;
  @override
  @JsonKey(name: 'customer_phone')
  String get customerPhone;
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
  @JsonKey(
      name: 'scheduled_date',
      fromJson: _dateTimeFromJson,
      toJson: _dateOnlyToJson)
  DateTime get scheduledDate;
  @override
  @JsonKey(
      name: 'scheduled_time',
      fromJson: _durationFromJson,
      toJson: _durationToJson)
  Duration get scheduledTime;
  @override
  String get status;
  @override
  @JsonKey(name: 'created_order_id')
  String? get createdOrderId;
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

  /// Create a copy of ScheduledOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScheduledOrderModelImplCopyWith<_$ScheduledOrderModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
