// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'progress_metrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$FocusBreakdown {
  int get totalMinutes => throw _privateConstructorUsedError;
  Map<String, int> get byCategory => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $FocusBreakdownCopyWith<FocusBreakdown> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FocusBreakdownCopyWith<$Res> {
  factory $FocusBreakdownCopyWith(
          FocusBreakdown value, $Res Function(FocusBreakdown) then) =
      _$FocusBreakdownCopyWithImpl<$Res, FocusBreakdown>;
  @useResult
  $Res call({int totalMinutes, Map<String, int> byCategory});
}

/// @nodoc
class _$FocusBreakdownCopyWithImpl<$Res, $Val extends FocusBreakdown>
    implements $FocusBreakdownCopyWith<$Res> {
  _$FocusBreakdownCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalMinutes = null,
    Object? byCategory = null,
  }) {
    return _then(_value.copyWith(
      totalMinutes: null == totalMinutes
          ? _value.totalMinutes
          : totalMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      byCategory: null == byCategory
          ? _value.byCategory
          : byCategory // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FocusBreakdownImplCopyWith<$Res>
    implements $FocusBreakdownCopyWith<$Res> {
  factory _$$FocusBreakdownImplCopyWith(_$FocusBreakdownImpl value,
          $Res Function(_$FocusBreakdownImpl) then) =
      __$$FocusBreakdownImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int totalMinutes, Map<String, int> byCategory});
}

/// @nodoc
class __$$FocusBreakdownImplCopyWithImpl<$Res>
    extends _$FocusBreakdownCopyWithImpl<$Res, _$FocusBreakdownImpl>
    implements _$$FocusBreakdownImplCopyWith<$Res> {
  __$$FocusBreakdownImplCopyWithImpl(
      _$FocusBreakdownImpl _value, $Res Function(_$FocusBreakdownImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalMinutes = null,
    Object? byCategory = null,
  }) {
    return _then(_$FocusBreakdownImpl(
      totalMinutes: null == totalMinutes
          ? _value.totalMinutes
          : totalMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      byCategory: null == byCategory
          ? _value._byCategory
          : byCategory // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
}

/// @nodoc

class _$FocusBreakdownImpl implements _FocusBreakdown {
  const _$FocusBreakdownImpl(
      {this.totalMinutes = 0, final Map<String, int> byCategory = const {}})
      : _byCategory = byCategory;

  @override
  @JsonKey()
  final int totalMinutes;
  final Map<String, int> _byCategory;
  @override
  @JsonKey()
  Map<String, int> get byCategory {
    if (_byCategory is EqualUnmodifiableMapView) return _byCategory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_byCategory);
  }

  @override
  String toString() {
    return 'FocusBreakdown(totalMinutes: $totalMinutes, byCategory: $byCategory)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FocusBreakdownImpl &&
            (identical(other.totalMinutes, totalMinutes) ||
                other.totalMinutes == totalMinutes) &&
            const DeepCollectionEquality()
                .equals(other._byCategory, _byCategory));
  }

  @override
  int get hashCode => Object.hash(runtimeType, totalMinutes,
      const DeepCollectionEquality().hash(_byCategory));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FocusBreakdownImplCopyWith<_$FocusBreakdownImpl> get copyWith =>
      __$$FocusBreakdownImplCopyWithImpl<_$FocusBreakdownImpl>(
          this, _$identity);
}

abstract class _FocusBreakdown implements FocusBreakdown {
  const factory _FocusBreakdown(
      {final int totalMinutes,
      final Map<String, int> byCategory}) = _$FocusBreakdownImpl;

  @override
  int get totalMinutes;
  @override
  Map<String, int> get byCategory;
  @override
  @JsonKey(ignore: true)
  _$$FocusBreakdownImplCopyWith<_$FocusBreakdownImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ProjectProgress {
  int get doneTaskCount => throw _privateConstructorUsedError;
  int get totalTaskCount => throw _privateConstructorUsedError;
  int get recurringTaskCount => throw _privateConstructorUsedError;
  int get habitCount => throw _privateConstructorUsedError;
  int get habitCompletionCount => throw _privateConstructorUsedError;
  int get focusMinutes => throw _privateConstructorUsedError;
  double get completionRatio => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ProjectProgressCopyWith<ProjectProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProjectProgressCopyWith<$Res> {
  factory $ProjectProgressCopyWith(
          ProjectProgress value, $Res Function(ProjectProgress) then) =
      _$ProjectProgressCopyWithImpl<$Res, ProjectProgress>;
  @useResult
  $Res call(
      {int doneTaskCount,
      int totalTaskCount,
      int recurringTaskCount,
      int habitCount,
      int habitCompletionCount,
      int focusMinutes,
      double completionRatio});
}

/// @nodoc
class _$ProjectProgressCopyWithImpl<$Res, $Val extends ProjectProgress>
    implements $ProjectProgressCopyWith<$Res> {
  _$ProjectProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? doneTaskCount = null,
    Object? totalTaskCount = null,
    Object? recurringTaskCount = null,
    Object? habitCount = null,
    Object? habitCompletionCount = null,
    Object? focusMinutes = null,
    Object? completionRatio = null,
  }) {
    return _then(_value.copyWith(
      doneTaskCount: null == doneTaskCount
          ? _value.doneTaskCount
          : doneTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTaskCount: null == totalTaskCount
          ? _value.totalTaskCount
          : totalTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      recurringTaskCount: null == recurringTaskCount
          ? _value.recurringTaskCount
          : recurringTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      habitCount: null == habitCount
          ? _value.habitCount
          : habitCount // ignore: cast_nullable_to_non_nullable
              as int,
      habitCompletionCount: null == habitCompletionCount
          ? _value.habitCompletionCount
          : habitCompletionCount // ignore: cast_nullable_to_non_nullable
              as int,
      focusMinutes: null == focusMinutes
          ? _value.focusMinutes
          : focusMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      completionRatio: null == completionRatio
          ? _value.completionRatio
          : completionRatio // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ProjectProgressImplCopyWith<$Res>
    implements $ProjectProgressCopyWith<$Res> {
  factory _$$ProjectProgressImplCopyWith(_$ProjectProgressImpl value,
          $Res Function(_$ProjectProgressImpl) then) =
      __$$ProjectProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int doneTaskCount,
      int totalTaskCount,
      int recurringTaskCount,
      int habitCount,
      int habitCompletionCount,
      int focusMinutes,
      double completionRatio});
}

/// @nodoc
class __$$ProjectProgressImplCopyWithImpl<$Res>
    extends _$ProjectProgressCopyWithImpl<$Res, _$ProjectProgressImpl>
    implements _$$ProjectProgressImplCopyWith<$Res> {
  __$$ProjectProgressImplCopyWithImpl(
      _$ProjectProgressImpl _value, $Res Function(_$ProjectProgressImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? doneTaskCount = null,
    Object? totalTaskCount = null,
    Object? recurringTaskCount = null,
    Object? habitCount = null,
    Object? habitCompletionCount = null,
    Object? focusMinutes = null,
    Object? completionRatio = null,
  }) {
    return _then(_$ProjectProgressImpl(
      doneTaskCount: null == doneTaskCount
          ? _value.doneTaskCount
          : doneTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTaskCount: null == totalTaskCount
          ? _value.totalTaskCount
          : totalTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      recurringTaskCount: null == recurringTaskCount
          ? _value.recurringTaskCount
          : recurringTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      habitCount: null == habitCount
          ? _value.habitCount
          : habitCount // ignore: cast_nullable_to_non_nullable
              as int,
      habitCompletionCount: null == habitCompletionCount
          ? _value.habitCompletionCount
          : habitCompletionCount // ignore: cast_nullable_to_non_nullable
              as int,
      focusMinutes: null == focusMinutes
          ? _value.focusMinutes
          : focusMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      completionRatio: null == completionRatio
          ? _value.completionRatio
          : completionRatio // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$ProjectProgressImpl extends _ProjectProgress {
  const _$ProjectProgressImpl(
      {this.doneTaskCount = 0,
      this.totalTaskCount = 0,
      this.recurringTaskCount = 0,
      this.habitCount = 0,
      this.habitCompletionCount = 0,
      this.focusMinutes = 0,
      this.completionRatio = 0.0})
      : super._();

  @override
  @JsonKey()
  final int doneTaskCount;
  @override
  @JsonKey()
  final int totalTaskCount;
  @override
  @JsonKey()
  final int recurringTaskCount;
  @override
  @JsonKey()
  final int habitCount;
  @override
  @JsonKey()
  final int habitCompletionCount;
  @override
  @JsonKey()
  final int focusMinutes;
  @override
  @JsonKey()
  final double completionRatio;

  @override
  String toString() {
    return 'ProjectProgress(doneTaskCount: $doneTaskCount, totalTaskCount: $totalTaskCount, recurringTaskCount: $recurringTaskCount, habitCount: $habitCount, habitCompletionCount: $habitCompletionCount, focusMinutes: $focusMinutes, completionRatio: $completionRatio)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectProgressImpl &&
            (identical(other.doneTaskCount, doneTaskCount) ||
                other.doneTaskCount == doneTaskCount) &&
            (identical(other.totalTaskCount, totalTaskCount) ||
                other.totalTaskCount == totalTaskCount) &&
            (identical(other.recurringTaskCount, recurringTaskCount) ||
                other.recurringTaskCount == recurringTaskCount) &&
            (identical(other.habitCount, habitCount) ||
                other.habitCount == habitCount) &&
            (identical(other.habitCompletionCount, habitCompletionCount) ||
                other.habitCompletionCount == habitCompletionCount) &&
            (identical(other.focusMinutes, focusMinutes) ||
                other.focusMinutes == focusMinutes) &&
            (identical(other.completionRatio, completionRatio) ||
                other.completionRatio == completionRatio));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      doneTaskCount,
      totalTaskCount,
      recurringTaskCount,
      habitCount,
      habitCompletionCount,
      focusMinutes,
      completionRatio);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectProgressImplCopyWith<_$ProjectProgressImpl> get copyWith =>
      __$$ProjectProgressImplCopyWithImpl<_$ProjectProgressImpl>(
          this, _$identity);
}

abstract class _ProjectProgress extends ProjectProgress {
  const factory _ProjectProgress(
      {final int doneTaskCount,
      final int totalTaskCount,
      final int recurringTaskCount,
      final int habitCount,
      final int habitCompletionCount,
      final int focusMinutes,
      final double completionRatio}) = _$ProjectProgressImpl;
  const _ProjectProgress._() : super._();

  @override
  int get doneTaskCount;
  @override
  int get totalTaskCount;
  @override
  int get recurringTaskCount;
  @override
  int get habitCount;
  @override
  int get habitCompletionCount;
  @override
  int get focusMinutes;
  @override
  double get completionRatio;
  @override
  @JsonKey(ignore: true)
  _$$ProjectProgressImplCopyWith<_$ProjectProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$GoalProgress {
  int get projectCount => throw _privateConstructorUsedError;
  int get completedProjectCount => throw _privateConstructorUsedError;
  int get doneTaskCount => throw _privateConstructorUsedError;
  int get totalTaskCount => throw _privateConstructorUsedError;
  int get focusMinutes => throw _privateConstructorUsedError;
  double get completionRatio => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $GoalProgressCopyWith<GoalProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GoalProgressCopyWith<$Res> {
  factory $GoalProgressCopyWith(
          GoalProgress value, $Res Function(GoalProgress) then) =
      _$GoalProgressCopyWithImpl<$Res, GoalProgress>;
  @useResult
  $Res call(
      {int projectCount,
      int completedProjectCount,
      int doneTaskCount,
      int totalTaskCount,
      int focusMinutes,
      double completionRatio});
}

/// @nodoc
class _$GoalProgressCopyWithImpl<$Res, $Val extends GoalProgress>
    implements $GoalProgressCopyWith<$Res> {
  _$GoalProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? projectCount = null,
    Object? completedProjectCount = null,
    Object? doneTaskCount = null,
    Object? totalTaskCount = null,
    Object? focusMinutes = null,
    Object? completionRatio = null,
  }) {
    return _then(_value.copyWith(
      projectCount: null == projectCount
          ? _value.projectCount
          : projectCount // ignore: cast_nullable_to_non_nullable
              as int,
      completedProjectCount: null == completedProjectCount
          ? _value.completedProjectCount
          : completedProjectCount // ignore: cast_nullable_to_non_nullable
              as int,
      doneTaskCount: null == doneTaskCount
          ? _value.doneTaskCount
          : doneTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTaskCount: null == totalTaskCount
          ? _value.totalTaskCount
          : totalTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      focusMinutes: null == focusMinutes
          ? _value.focusMinutes
          : focusMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      completionRatio: null == completionRatio
          ? _value.completionRatio
          : completionRatio // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GoalProgressImplCopyWith<$Res>
    implements $GoalProgressCopyWith<$Res> {
  factory _$$GoalProgressImplCopyWith(
          _$GoalProgressImpl value, $Res Function(_$GoalProgressImpl) then) =
      __$$GoalProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int projectCount,
      int completedProjectCount,
      int doneTaskCount,
      int totalTaskCount,
      int focusMinutes,
      double completionRatio});
}

/// @nodoc
class __$$GoalProgressImplCopyWithImpl<$Res>
    extends _$GoalProgressCopyWithImpl<$Res, _$GoalProgressImpl>
    implements _$$GoalProgressImplCopyWith<$Res> {
  __$$GoalProgressImplCopyWithImpl(
      _$GoalProgressImpl _value, $Res Function(_$GoalProgressImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? projectCount = null,
    Object? completedProjectCount = null,
    Object? doneTaskCount = null,
    Object? totalTaskCount = null,
    Object? focusMinutes = null,
    Object? completionRatio = null,
  }) {
    return _then(_$GoalProgressImpl(
      projectCount: null == projectCount
          ? _value.projectCount
          : projectCount // ignore: cast_nullable_to_non_nullable
              as int,
      completedProjectCount: null == completedProjectCount
          ? _value.completedProjectCount
          : completedProjectCount // ignore: cast_nullable_to_non_nullable
              as int,
      doneTaskCount: null == doneTaskCount
          ? _value.doneTaskCount
          : doneTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTaskCount: null == totalTaskCount
          ? _value.totalTaskCount
          : totalTaskCount // ignore: cast_nullable_to_non_nullable
              as int,
      focusMinutes: null == focusMinutes
          ? _value.focusMinutes
          : focusMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      completionRatio: null == completionRatio
          ? _value.completionRatio
          : completionRatio // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$GoalProgressImpl extends _GoalProgress {
  const _$GoalProgressImpl(
      {this.projectCount = 0,
      this.completedProjectCount = 0,
      this.doneTaskCount = 0,
      this.totalTaskCount = 0,
      this.focusMinutes = 0,
      this.completionRatio = 0.0})
      : super._();

  @override
  @JsonKey()
  final int projectCount;
  @override
  @JsonKey()
  final int completedProjectCount;
  @override
  @JsonKey()
  final int doneTaskCount;
  @override
  @JsonKey()
  final int totalTaskCount;
  @override
  @JsonKey()
  final int focusMinutes;
  @override
  @JsonKey()
  final double completionRatio;

  @override
  String toString() {
    return 'GoalProgress(projectCount: $projectCount, completedProjectCount: $completedProjectCount, doneTaskCount: $doneTaskCount, totalTaskCount: $totalTaskCount, focusMinutes: $focusMinutes, completionRatio: $completionRatio)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GoalProgressImpl &&
            (identical(other.projectCount, projectCount) ||
                other.projectCount == projectCount) &&
            (identical(other.completedProjectCount, completedProjectCount) ||
                other.completedProjectCount == completedProjectCount) &&
            (identical(other.doneTaskCount, doneTaskCount) ||
                other.doneTaskCount == doneTaskCount) &&
            (identical(other.totalTaskCount, totalTaskCount) ||
                other.totalTaskCount == totalTaskCount) &&
            (identical(other.focusMinutes, focusMinutes) ||
                other.focusMinutes == focusMinutes) &&
            (identical(other.completionRatio, completionRatio) ||
                other.completionRatio == completionRatio));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      projectCount,
      completedProjectCount,
      doneTaskCount,
      totalTaskCount,
      focusMinutes,
      completionRatio);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GoalProgressImplCopyWith<_$GoalProgressImpl> get copyWith =>
      __$$GoalProgressImplCopyWithImpl<_$GoalProgressImpl>(this, _$identity);
}

abstract class _GoalProgress extends GoalProgress {
  const factory _GoalProgress(
      {final int projectCount,
      final int completedProjectCount,
      final int doneTaskCount,
      final int totalTaskCount,
      final int focusMinutes,
      final double completionRatio}) = _$GoalProgressImpl;
  const _GoalProgress._() : super._();

  @override
  int get projectCount;
  @override
  int get completedProjectCount;
  @override
  int get doneTaskCount;
  @override
  int get totalTaskCount;
  @override
  int get focusMinutes;
  @override
  double get completionRatio;
  @override
  @JsonKey(ignore: true)
  _$$GoalProgressImplCopyWith<_$GoalProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
