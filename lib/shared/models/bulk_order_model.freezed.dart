// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bulk_order_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BulkOrderModel _$BulkOrderModelFromJson(Map<String, dynamic> json) {
  return _BulkOrderModel.fromJson(json);
}

/// @nodoc
mixin _$BulkOrderModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'merchant_id')
  String get merchantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'driver_id')
  String? get driverId => throw _privateConstructorUsedError;
  @JsonKey(name: 'pickup_address')
  String get pickupAddress => throw _privateConstructorUsedError;
  @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
  double get pickupLatitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
  double get pickupLongitude => throw _privateConstructorUsedError;
  @JsonKey(name: 'neighborhoods')
  List<String> get neighborhoods => throw _privateConstructorUsedError;
  @JsonKey(name: 'neighborhood_items')
  List<BulkOrderItem>? get neighborhoodItems =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'per_delivery_fee', fromJson: _doubleFromJson)
  double get perDeliveryFee => throw _privateConstructorUsedError;
  @JsonKey(name: 'bulk_order_fee', fromJson: _doubleFromJson)
  double get bulkOrderFee => throw _privateConstructorUsedError;
  @JsonKey(name: 'vehicle_type')
  String? get vehicleType => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'order_date', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get orderDate => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'assigned_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get assignedAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'accepted_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get acceptedAt => throw _privateConstructorUsedError;

  /// Populated from a nested merchant join: pass merchant_name top-level or
  /// call .copyWith() after creation when working with Supabase joined selects.
  @JsonKey(name: 'merchant_name')
  String? get merchantName => throw _privateConstructorUsedError;
  @JsonKey(name: 'merchant_phone')
  String? get merchantPhone => throw _privateConstructorUsedError;

  /// Serializes this BulkOrderModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BulkOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BulkOrderModelCopyWith<BulkOrderModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BulkOrderModelCopyWith<$Res> {
  factory $BulkOrderModelCopyWith(
          BulkOrderModel value, $Res Function(BulkOrderModel) then) =
      _$BulkOrderModelCopyWithImpl<$Res, BulkOrderModel>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'merchant_id') String merchantId,
      @JsonKey(name: 'driver_id') String? driverId,
      @JsonKey(name: 'pickup_address') String pickupAddress,
      @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
      double pickupLatitude,
      @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
      double pickupLongitude,
      @JsonKey(name: 'neighborhoods') List<String> neighborhoods,
      @JsonKey(name: 'neighborhood_items')
      List<BulkOrderItem>? neighborhoodItems,
      @JsonKey(name: 'per_delivery_fee', fromJson: _doubleFromJson)
      double perDeliveryFee,
      @JsonKey(name: 'bulk_order_fee', fromJson: _doubleFromJson)
      double bulkOrderFee,
      @JsonKey(name: 'vehicle_type') String? vehicleType,
      String? notes,
      String status,
      @JsonKey(
          name: 'order_date',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime orderDate,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(
          name: 'assigned_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? assignedAt,
      @JsonKey(
          name: 'accepted_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? acceptedAt,
      @JsonKey(name: 'merchant_name') String? merchantName,
      @JsonKey(name: 'merchant_phone') String? merchantPhone});
}

/// @nodoc
class _$BulkOrderModelCopyWithImpl<$Res, $Val extends BulkOrderModel>
    implements $BulkOrderModelCopyWith<$Res> {
  _$BulkOrderModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BulkOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? driverId = freezed,
    Object? pickupAddress = null,
    Object? pickupLatitude = null,
    Object? pickupLongitude = null,
    Object? neighborhoods = null,
    Object? neighborhoodItems = freezed,
    Object? perDeliveryFee = null,
    Object? bulkOrderFee = null,
    Object? vehicleType = freezed,
    Object? notes = freezed,
    Object? status = null,
    Object? orderDate = null,
    Object? createdAt = null,
    Object? assignedAt = freezed,
    Object? acceptedAt = freezed,
    Object? merchantName = freezed,
    Object? merchantPhone = freezed,
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
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
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
      neighborhoods: null == neighborhoods
          ? _value.neighborhoods
          : neighborhoods // ignore: cast_nullable_to_non_nullable
              as List<String>,
      neighborhoodItems: freezed == neighborhoodItems
          ? _value.neighborhoodItems
          : neighborhoodItems // ignore: cast_nullable_to_non_nullable
              as List<BulkOrderItem>?,
      perDeliveryFee: null == perDeliveryFee
          ? _value.perDeliveryFee
          : perDeliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      bulkOrderFee: null == bulkOrderFee
          ? _value.bulkOrderFee
          : bulkOrderFee // ignore: cast_nullable_to_non_nullable
              as double,
      vehicleType: freezed == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      orderDate: null == orderDate
          ? _value.orderDate
          : orderDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      assignedAt: freezed == assignedAt
          ? _value.assignedAt
          : assignedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      merchantName: freezed == merchantName
          ? _value.merchantName
          : merchantName // ignore: cast_nullable_to_non_nullable
              as String?,
      merchantPhone: freezed == merchantPhone
          ? _value.merchantPhone
          : merchantPhone // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BulkOrderModelImplCopyWith<$Res>
    implements $BulkOrderModelCopyWith<$Res> {
  factory _$$BulkOrderModelImplCopyWith(_$BulkOrderModelImpl value,
          $Res Function(_$BulkOrderModelImpl) then) =
      __$$BulkOrderModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'merchant_id') String merchantId,
      @JsonKey(name: 'driver_id') String? driverId,
      @JsonKey(name: 'pickup_address') String pickupAddress,
      @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
      double pickupLatitude,
      @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
      double pickupLongitude,
      @JsonKey(name: 'neighborhoods') List<String> neighborhoods,
      @JsonKey(name: 'neighborhood_items')
      List<BulkOrderItem>? neighborhoodItems,
      @JsonKey(name: 'per_delivery_fee', fromJson: _doubleFromJson)
      double perDeliveryFee,
      @JsonKey(name: 'bulk_order_fee', fromJson: _doubleFromJson)
      double bulkOrderFee,
      @JsonKey(name: 'vehicle_type') String? vehicleType,
      String? notes,
      String status,
      @JsonKey(
          name: 'order_date',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime orderDate,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      DateTime createdAt,
      @JsonKey(
          name: 'assigned_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? assignedAt,
      @JsonKey(
          name: 'accepted_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      DateTime? acceptedAt,
      @JsonKey(name: 'merchant_name') String? merchantName,
      @JsonKey(name: 'merchant_phone') String? merchantPhone});
}

/// @nodoc
class __$$BulkOrderModelImplCopyWithImpl<$Res>
    extends _$BulkOrderModelCopyWithImpl<$Res, _$BulkOrderModelImpl>
    implements _$$BulkOrderModelImplCopyWith<$Res> {
  __$$BulkOrderModelImplCopyWithImpl(
      _$BulkOrderModelImpl _value, $Res Function(_$BulkOrderModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of BulkOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? driverId = freezed,
    Object? pickupAddress = null,
    Object? pickupLatitude = null,
    Object? pickupLongitude = null,
    Object? neighborhoods = null,
    Object? neighborhoodItems = freezed,
    Object? perDeliveryFee = null,
    Object? bulkOrderFee = null,
    Object? vehicleType = freezed,
    Object? notes = freezed,
    Object? status = null,
    Object? orderDate = null,
    Object? createdAt = null,
    Object? assignedAt = freezed,
    Object? acceptedAt = freezed,
    Object? merchantName = freezed,
    Object? merchantPhone = freezed,
  }) {
    return _then(_$BulkOrderModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      merchantId: null == merchantId
          ? _value.merchantId
          : merchantId // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
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
      neighborhoods: null == neighborhoods
          ? _value._neighborhoods
          : neighborhoods // ignore: cast_nullable_to_non_nullable
              as List<String>,
      neighborhoodItems: freezed == neighborhoodItems
          ? _value._neighborhoodItems
          : neighborhoodItems // ignore: cast_nullable_to_non_nullable
              as List<BulkOrderItem>?,
      perDeliveryFee: null == perDeliveryFee
          ? _value.perDeliveryFee
          : perDeliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      bulkOrderFee: null == bulkOrderFee
          ? _value.bulkOrderFee
          : bulkOrderFee // ignore: cast_nullable_to_non_nullable
              as double,
      vehicleType: freezed == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      orderDate: null == orderDate
          ? _value.orderDate
          : orderDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      assignedAt: freezed == assignedAt
          ? _value.assignedAt
          : assignedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      merchantName: freezed == merchantName
          ? _value.merchantName
          : merchantName // ignore: cast_nullable_to_non_nullable
              as String?,
      merchantPhone: freezed == merchantPhone
          ? _value.merchantPhone
          : merchantPhone // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BulkOrderModelImpl extends _BulkOrderModel {
  const _$BulkOrderModelImpl(
      {required this.id,
      @JsonKey(name: 'merchant_id') required this.merchantId,
      @JsonKey(name: 'driver_id') this.driverId,
      @JsonKey(name: 'pickup_address') required this.pickupAddress,
      @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
      required this.pickupLatitude,
      @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
      required this.pickupLongitude,
      @JsonKey(name: 'neighborhoods')
      final List<String> neighborhoods = const [],
      @JsonKey(name: 'neighborhood_items')
      final List<BulkOrderItem>? neighborhoodItems,
      @JsonKey(name: 'per_delivery_fee', fromJson: _doubleFromJson)
      required this.perDeliveryFee,
      @JsonKey(name: 'bulk_order_fee', fromJson: _doubleFromJson)
      this.bulkOrderFee = 1000.0,
      @JsonKey(name: 'vehicle_type') this.vehicleType,
      this.notes,
      this.status = 'pending',
      @JsonKey(
          name: 'order_date',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      required this.orderDate,
      @JsonKey(
          name: 'created_at',
          fromJson: _dateTimeFromJson,
          toJson: _dateTimeToJson)
      required this.createdAt,
      @JsonKey(
          name: 'assigned_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.assignedAt,
      @JsonKey(
          name: 'accepted_at',
          fromJson: _nullableDateTimeFromJson,
          toJson: _nullableDateTimeToJson)
      this.acceptedAt,
      @JsonKey(name: 'merchant_name') this.merchantName,
      @JsonKey(name: 'merchant_phone') this.merchantPhone})
      : _neighborhoods = neighborhoods,
        _neighborhoodItems = neighborhoodItems,
        super._();

  factory _$BulkOrderModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BulkOrderModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'merchant_id')
  final String merchantId;
  @override
  @JsonKey(name: 'driver_id')
  final String? driverId;
  @override
  @JsonKey(name: 'pickup_address')
  final String pickupAddress;
  @override
  @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
  final double pickupLatitude;
  @override
  @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
  final double pickupLongitude;
  final List<String> _neighborhoods;
  @override
  @JsonKey(name: 'neighborhoods')
  List<String> get neighborhoods {
    if (_neighborhoods is EqualUnmodifiableListView) return _neighborhoods;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_neighborhoods);
  }

  final List<BulkOrderItem>? _neighborhoodItems;
  @override
  @JsonKey(name: 'neighborhood_items')
  List<BulkOrderItem>? get neighborhoodItems {
    final value = _neighborhoodItems;
    if (value == null) return null;
    if (_neighborhoodItems is EqualUnmodifiableListView)
      return _neighborhoodItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'per_delivery_fee', fromJson: _doubleFromJson)
  final double perDeliveryFee;
  @override
  @JsonKey(name: 'bulk_order_fee', fromJson: _doubleFromJson)
  final double bulkOrderFee;
  @override
  @JsonKey(name: 'vehicle_type')
  final String? vehicleType;
  @override
  final String? notes;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(
      name: 'order_date', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime orderDate;
  @override
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime createdAt;
  @override
  @JsonKey(
      name: 'assigned_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? assignedAt;
  @override
  @JsonKey(
      name: 'accepted_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  final DateTime? acceptedAt;

  /// Populated from a nested merchant join: pass merchant_name top-level or
  /// call .copyWith() after creation when working with Supabase joined selects.
  @override
  @JsonKey(name: 'merchant_name')
  final String? merchantName;
  @override
  @JsonKey(name: 'merchant_phone')
  final String? merchantPhone;

  @override
  String toString() {
    return 'BulkOrderModel(id: $id, merchantId: $merchantId, driverId: $driverId, pickupAddress: $pickupAddress, pickupLatitude: $pickupLatitude, pickupLongitude: $pickupLongitude, neighborhoods: $neighborhoods, neighborhoodItems: $neighborhoodItems, perDeliveryFee: $perDeliveryFee, bulkOrderFee: $bulkOrderFee, vehicleType: $vehicleType, notes: $notes, status: $status, orderDate: $orderDate, createdAt: $createdAt, assignedAt: $assignedAt, acceptedAt: $acceptedAt, merchantName: $merchantName, merchantPhone: $merchantPhone)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BulkOrderModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.pickupAddress, pickupAddress) ||
                other.pickupAddress == pickupAddress) &&
            (identical(other.pickupLatitude, pickupLatitude) ||
                other.pickupLatitude == pickupLatitude) &&
            (identical(other.pickupLongitude, pickupLongitude) ||
                other.pickupLongitude == pickupLongitude) &&
            const DeepCollectionEquality()
                .equals(other._neighborhoods, _neighborhoods) &&
            const DeepCollectionEquality()
                .equals(other._neighborhoodItems, _neighborhoodItems) &&
            (identical(other.perDeliveryFee, perDeliveryFee) ||
                other.perDeliveryFee == perDeliveryFee) &&
            (identical(other.bulkOrderFee, bulkOrderFee) ||
                other.bulkOrderFee == bulkOrderFee) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.orderDate, orderDate) ||
                other.orderDate == orderDate) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.assignedAt, assignedAt) ||
                other.assignedAt == assignedAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.merchantName, merchantName) ||
                other.merchantName == merchantName) &&
            (identical(other.merchantPhone, merchantPhone) ||
                other.merchantPhone == merchantPhone));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        merchantId,
        driverId,
        pickupAddress,
        pickupLatitude,
        pickupLongitude,
        const DeepCollectionEquality().hash(_neighborhoods),
        const DeepCollectionEquality().hash(_neighborhoodItems),
        perDeliveryFee,
        bulkOrderFee,
        vehicleType,
        notes,
        status,
        orderDate,
        createdAt,
        assignedAt,
        acceptedAt,
        merchantName,
        merchantPhone
      ]);

  /// Create a copy of BulkOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BulkOrderModelImplCopyWith<_$BulkOrderModelImpl> get copyWith =>
      __$$BulkOrderModelImplCopyWithImpl<_$BulkOrderModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BulkOrderModelImplToJson(
      this,
    );
  }
}

abstract class _BulkOrderModel extends BulkOrderModel {
  const factory _BulkOrderModel(
          {required final String id,
          @JsonKey(name: 'merchant_id') required final String merchantId,
          @JsonKey(name: 'driver_id') final String? driverId,
          @JsonKey(name: 'pickup_address') required final String pickupAddress,
          @JsonKey(name: 'pickup_latitude', fromJson: _doubleFromJson)
          required final double pickupLatitude,
          @JsonKey(name: 'pickup_longitude', fromJson: _doubleFromJson)
          required final double pickupLongitude,
          @JsonKey(name: 'neighborhoods') final List<String> neighborhoods,
          @JsonKey(name: 'neighborhood_items')
          final List<BulkOrderItem>? neighborhoodItems,
          @JsonKey(name: 'per_delivery_fee', fromJson: _doubleFromJson)
          required final double perDeliveryFee,
          @JsonKey(name: 'bulk_order_fee', fromJson: _doubleFromJson)
          final double bulkOrderFee,
          @JsonKey(name: 'vehicle_type') final String? vehicleType,
          final String? notes,
          final String status,
          @JsonKey(
              name: 'order_date',
              fromJson: _dateTimeFromJson,
              toJson: _dateTimeToJson)
          required final DateTime orderDate,
          @JsonKey(
              name: 'created_at',
              fromJson: _dateTimeFromJson,
              toJson: _dateTimeToJson)
          required final DateTime createdAt,
          @JsonKey(
              name: 'assigned_at',
              fromJson: _nullableDateTimeFromJson,
              toJson: _nullableDateTimeToJson)
          final DateTime? assignedAt,
          @JsonKey(
              name: 'accepted_at',
              fromJson: _nullableDateTimeFromJson,
              toJson: _nullableDateTimeToJson)
          final DateTime? acceptedAt,
          @JsonKey(name: 'merchant_name') final String? merchantName,
          @JsonKey(name: 'merchant_phone') final String? merchantPhone}) =
      _$BulkOrderModelImpl;
  const _BulkOrderModel._() : super._();

  factory _BulkOrderModel.fromJson(Map<String, dynamic> json) =
      _$BulkOrderModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'merchant_id')
  String get merchantId;
  @override
  @JsonKey(name: 'driver_id')
  String? get driverId;
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
  @JsonKey(name: 'neighborhoods')
  List<String> get neighborhoods;
  @override
  @JsonKey(name: 'neighborhood_items')
  List<BulkOrderItem>? get neighborhoodItems;
  @override
  @JsonKey(name: 'per_delivery_fee', fromJson: _doubleFromJson)
  double get perDeliveryFee;
  @override
  @JsonKey(name: 'bulk_order_fee', fromJson: _doubleFromJson)
  double get bulkOrderFee;
  @override
  @JsonKey(name: 'vehicle_type')
  String? get vehicleType;
  @override
  String? get notes;
  @override
  String get status;
  @override
  @JsonKey(
      name: 'order_date', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get orderDate;
  @override
  @JsonKey(
      name: 'created_at', fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  DateTime get createdAt;
  @override
  @JsonKey(
      name: 'assigned_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get assignedAt;
  @override
  @JsonKey(
      name: 'accepted_at',
      fromJson: _nullableDateTimeFromJson,
      toJson: _nullableDateTimeToJson)
  DateTime? get acceptedAt;

  /// Populated from a nested merchant join: pass merchant_name top-level or
  /// call .copyWith() after creation when working with Supabase joined selects.
  @override
  @JsonKey(name: 'merchant_name')
  String? get merchantName;
  @override
  @JsonKey(name: 'merchant_phone')
  String? get merchantPhone;

  /// Create a copy of BulkOrderModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BulkOrderModelImplCopyWith<_$BulkOrderModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
