// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bulk_order_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BulkOrderItem _$BulkOrderItemFromJson(Map<String, dynamic> json) {
  return _BulkOrderItem.fromJson(json);
}

/// @nodoc
mixin _$BulkOrderItem {
  @JsonKey(
      name: 'neighborhood',
      fromJson: _neighborhoodFromJson,
      toJson: _neighborhoodToJson)
  Neighborhood get neighborhood => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_phone')
  String? get customerPhone => throw _privateConstructorUsedError;

  /// Serializes this BulkOrderItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BulkOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BulkOrderItemCopyWith<BulkOrderItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BulkOrderItemCopyWith<$Res> {
  factory $BulkOrderItemCopyWith(
          BulkOrderItem value, $Res Function(BulkOrderItem) then) =
      _$BulkOrderItemCopyWithImpl<$Res, BulkOrderItem>;
  @useResult
  $Res call(
      {@JsonKey(
          name: 'neighborhood',
          fromJson: _neighborhoodFromJson,
          toJson: _neighborhoodToJson)
      Neighborhood neighborhood,
      @JsonKey(name: 'customer_phone') String? customerPhone});
}

/// @nodoc
class _$BulkOrderItemCopyWithImpl<$Res, $Val extends BulkOrderItem>
    implements $BulkOrderItemCopyWith<$Res> {
  _$BulkOrderItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BulkOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? neighborhood = null,
    Object? customerPhone = freezed,
  }) {
    return _then(_value.copyWith(
      neighborhood: null == neighborhood
          ? _value.neighborhood
          : neighborhood // ignore: cast_nullable_to_non_nullable
              as Neighborhood,
      customerPhone: freezed == customerPhone
          ? _value.customerPhone
          : customerPhone // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BulkOrderItemImplCopyWith<$Res>
    implements $BulkOrderItemCopyWith<$Res> {
  factory _$$BulkOrderItemImplCopyWith(
          _$BulkOrderItemImpl value, $Res Function(_$BulkOrderItemImpl) then) =
      __$$BulkOrderItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(
          name: 'neighborhood',
          fromJson: _neighborhoodFromJson,
          toJson: _neighborhoodToJson)
      Neighborhood neighborhood,
      @JsonKey(name: 'customer_phone') String? customerPhone});
}

/// @nodoc
class __$$BulkOrderItemImplCopyWithImpl<$Res>
    extends _$BulkOrderItemCopyWithImpl<$Res, _$BulkOrderItemImpl>
    implements _$$BulkOrderItemImplCopyWith<$Res> {
  __$$BulkOrderItemImplCopyWithImpl(
      _$BulkOrderItemImpl _value, $Res Function(_$BulkOrderItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of BulkOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? neighborhood = null,
    Object? customerPhone = freezed,
  }) {
    return _then(_$BulkOrderItemImpl(
      neighborhood: null == neighborhood
          ? _value.neighborhood
          : neighborhood // ignore: cast_nullable_to_non_nullable
              as Neighborhood,
      customerPhone: freezed == customerPhone
          ? _value.customerPhone
          : customerPhone // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BulkOrderItemImpl implements _BulkOrderItem {
  const _$BulkOrderItemImpl(
      {@JsonKey(
          name: 'neighborhood',
          fromJson: _neighborhoodFromJson,
          toJson: _neighborhoodToJson)
      required this.neighborhood,
      @JsonKey(name: 'customer_phone') this.customerPhone});

  factory _$BulkOrderItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$BulkOrderItemImplFromJson(json);

  @override
  @JsonKey(
      name: 'neighborhood',
      fromJson: _neighborhoodFromJson,
      toJson: _neighborhoodToJson)
  final Neighborhood neighborhood;
  @override
  @JsonKey(name: 'customer_phone')
  final String? customerPhone;

  @override
  String toString() {
    return 'BulkOrderItem(neighborhood: $neighborhood, customerPhone: $customerPhone)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BulkOrderItemImpl &&
            (identical(other.neighborhood, neighborhood) ||
                other.neighborhood == neighborhood) &&
            (identical(other.customerPhone, customerPhone) ||
                other.customerPhone == customerPhone));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, neighborhood, customerPhone);

  /// Create a copy of BulkOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BulkOrderItemImplCopyWith<_$BulkOrderItemImpl> get copyWith =>
      __$$BulkOrderItemImplCopyWithImpl<_$BulkOrderItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BulkOrderItemImplToJson(
      this,
    );
  }
}

abstract class _BulkOrderItem implements BulkOrderItem {
  const factory _BulkOrderItem(
          {@JsonKey(
              name: 'neighborhood',
              fromJson: _neighborhoodFromJson,
              toJson: _neighborhoodToJson)
          required final Neighborhood neighborhood,
          @JsonKey(name: 'customer_phone') final String? customerPhone}) =
      _$BulkOrderItemImpl;

  factory _BulkOrderItem.fromJson(Map<String, dynamic> json) =
      _$BulkOrderItemImpl.fromJson;

  @override
  @JsonKey(
      name: 'neighborhood',
      fromJson: _neighborhoodFromJson,
      toJson: _neighborhoodToJson)
  Neighborhood get neighborhood;
  @override
  @JsonKey(name: 'customer_phone')
  String? get customerPhone;

  /// Create a copy of BulkOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BulkOrderItemImplCopyWith<_$BulkOrderItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
