// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$GoalState {
  List<Goal> get goals => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isSaving => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $GoalStateCopyWith<GoalState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GoalStateCopyWith<$Res> {
  factory $GoalStateCopyWith(GoalState value, $Res Function(GoalState) then) =
      _$GoalStateCopyWithImpl<$Res, GoalState>;
  @useResult
  $Res call({List<Goal> goals, bool isLoading, bool isSaving, String? error});
}

/// @nodoc
class _$GoalStateCopyWithImpl<$Res, $Val extends GoalState>
    implements $GoalStateCopyWith<$Res> {
  _$GoalStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goals = null,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      goals: null == goals
          ? _value.goals
          : goals // ignore: cast_nullable_to_non_nullable
              as List<Goal>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isSaving: null == isSaving
          ? _value.isSaving
          : isSaving // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GoalStateImplCopyWith<$Res>
    implements $GoalStateCopyWith<$Res> {
  factory _$$GoalStateImplCopyWith(
          _$GoalStateImpl value, $Res Function(_$GoalStateImpl) then) =
      __$$GoalStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Goal> goals, bool isLoading, bool isSaving, String? error});
}

/// @nodoc
class __$$GoalStateImplCopyWithImpl<$Res>
    extends _$GoalStateCopyWithImpl<$Res, _$GoalStateImpl>
    implements _$$GoalStateImplCopyWith<$Res> {
  __$$GoalStateImplCopyWithImpl(
      _$GoalStateImpl _value, $Res Function(_$GoalStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goals = null,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? error = freezed,
  }) {
    return _then(_$GoalStateImpl(
      goals: null == goals
          ? _value._goals
          : goals // ignore: cast_nullable_to_non_nullable
              as List<Goal>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isSaving: null == isSaving
          ? _value.isSaving
          : isSaving // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$GoalStateImpl implements _GoalState {
  const _$GoalStateImpl(
      {final List<Goal> goals = const [],
      this.isLoading = false,
      this.isSaving = false,
      this.error})
      : _goals = goals;

  final List<Goal> _goals;
  @override
  @JsonKey()
  List<Goal> get goals {
    if (_goals is EqualUnmodifiableListView) return _goals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_goals);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isSaving;
  @override
  final String? error;

  @override
  String toString() {
    return 'GoalState(goals: $goals, isLoading: $isLoading, isSaving: $isSaving, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GoalStateImpl &&
            const DeepCollectionEquality().equals(other._goals, _goals) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isSaving, isSaving) ||
                other.isSaving == isSaving) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_goals), isLoading, isSaving, error);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GoalStateImplCopyWith<_$GoalStateImpl> get copyWith =>
      __$$GoalStateImplCopyWithImpl<_$GoalStateImpl>(this, _$identity);
}

abstract class _GoalState implements GoalState {
  const factory _GoalState(
      {final List<Goal> goals,
      final bool isLoading,
      final bool isSaving,
      final String? error}) = _$GoalStateImpl;

  @override
  List<Goal> get goals;
  @override
  bool get isLoading;
  @override
  bool get isSaving;
  @override
  String? get error;
  @override
  @JsonKey(ignore: true)
  _$$GoalStateImplCopyWith<_$GoalStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
