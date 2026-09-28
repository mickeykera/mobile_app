// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'premium_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$PremiumState {
  bool get isPremium => throw _privateConstructorUsedError;
  String get planType => throw _privateConstructorUsedError;
  DateTime? get premiumSince => throw _privateConstructorUsedError;
  String get billingCycle => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PremiumStateCopyWith<PremiumState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PremiumStateCopyWith<$Res> {
  factory $PremiumStateCopyWith(
          PremiumState value, $Res Function(PremiumState) then) =
      _$PremiumStateCopyWithImpl<$Res, PremiumState>;
  @useResult
  $Res call(
      {bool isPremium,
      String planType,
      DateTime? premiumSince,
      String billingCycle});
}

/// @nodoc
class _$PremiumStateCopyWithImpl<$Res, $Val extends PremiumState>
    implements $PremiumStateCopyWith<$Res> {
  _$PremiumStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isPremium = null,
    Object? planType = null,
    Object? premiumSince = freezed,
    Object? billingCycle = null,
  }) {
    return _then(_value.copyWith(
      isPremium: null == isPremium
          ? _value.isPremium
          : isPremium // ignore: cast_nullable_to_non_nullable
              as bool,
      planType: null == planType
          ? _value.planType
          : planType // ignore: cast_nullable_to_non_nullable
              as String,
      premiumSince: freezed == premiumSince
          ? _value.premiumSince
          : premiumSince // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      billingCycle: null == billingCycle
          ? _value.billingCycle
          : billingCycle // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PremiumStateImplCopyWith<$Res>
    implements $PremiumStateCopyWith<$Res> {
  factory _$$PremiumStateImplCopyWith(
          _$PremiumStateImpl value, $Res Function(_$PremiumStateImpl) then) =
      __$$PremiumStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isPremium,
      String planType,
      DateTime? premiumSince,
      String billingCycle});
}

/// @nodoc
class __$$PremiumStateImplCopyWithImpl<$Res>
    extends _$PremiumStateCopyWithImpl<$Res, _$PremiumStateImpl>
    implements _$$PremiumStateImplCopyWith<$Res> {
  __$$PremiumStateImplCopyWithImpl(
      _$PremiumStateImpl _value, $Res Function(_$PremiumStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isPremium = null,
    Object? planType = null,
    Object? premiumSince = freezed,
    Object? billingCycle = null,
  }) {
    return _then(_$PremiumStateImpl(
      isPremium: null == isPremium
          ? _value.isPremium
          : isPremium // ignore: cast_nullable_to_non_nullable
              as bool,
      planType: null == planType
          ? _value.planType
          : planType // ignore: cast_nullable_to_non_nullable
              as String,
      premiumSince: freezed == premiumSince
          ? _value.premiumSince
          : premiumSince // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      billingCycle: null == billingCycle
          ? _value.billingCycle
          : billingCycle // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$PremiumStateImpl implements _PremiumState {
  const _$PremiumStateImpl(
      {this.isPremium = false,
      this.planType = 'free',
      this.premiumSince,
      this.billingCycle = 'monthly'});

  @override
  @JsonKey()
  final bool isPremium;
  @override
  @JsonKey()
  final String planType;
  @override
  final DateTime? premiumSince;
  @override
  @JsonKey()
  final String billingCycle;

  @override
  String toString() {
    return 'PremiumState(isPremium: $isPremium, planType: $planType, premiumSince: $premiumSince, billingCycle: $billingCycle)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PremiumStateImpl &&
            (identical(other.isPremium, isPremium) ||
                other.isPremium == isPremium) &&
            (identical(other.planType, planType) ||
                other.planType == planType) &&
            (identical(other.premiumSince, premiumSince) ||
                other.premiumSince == premiumSince) &&
            (identical(other.billingCycle, billingCycle) ||
                other.billingCycle == billingCycle));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, isPremium, planType, premiumSince, billingCycle);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PremiumStateImplCopyWith<_$PremiumStateImpl> get copyWith =>
      __$$PremiumStateImplCopyWithImpl<_$PremiumStateImpl>(this, _$identity);
}

abstract class _PremiumState implements PremiumState {
  const factory _PremiumState(
      {final bool isPremium,
      final String planType,
      final DateTime? premiumSince,
      final String billingCycle}) = _$PremiumStateImpl;

  @override
  bool get isPremium;
  @override
  String get planType;
  @override
  DateTime? get premiumSince;
  @override
  String get billingCycle;
  @override
  @JsonKey(ignore: true)
  _$$PremiumStateImplCopyWith<_$PremiumStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
