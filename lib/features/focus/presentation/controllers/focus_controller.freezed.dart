// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'focus_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$FocusState {
  FocusSession? get activeSession => throw _privateConstructorUsedError;
  List<FocusSession> get recentSessions => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  String get selectedMode => throw _privateConstructorUsedError;
  int get workDuration => throw _privateConstructorUsedError;
  int get breakDuration => throw _privateConstructorUsedError;
  int get longBreakDuration => throw _privateConstructorUsedError;
  int get sessionsBeforeLongBreak => throw _privateConstructorUsedError;
  String? get selectedHabitId => throw _privateConstructorUsedError;
  String? get projectName => throw _privateConstructorUsedError;

  /// Bumped on every timer tick so the state - and everything derived from
  /// it - actually changes. See [FocusController.tick].
  int get tickCount => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $FocusStateCopyWith<FocusState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FocusStateCopyWith<$Res> {
  factory $FocusStateCopyWith(
          FocusState value, $Res Function(FocusState) then) =
      _$FocusStateCopyWithImpl<$Res, FocusState>;
  @useResult
  $Res call(
      {FocusSession? activeSession,
      List<FocusSession> recentSessions,
      bool isLoading,
      String? error,
      String selectedMode,
      int workDuration,
      int breakDuration,
      int longBreakDuration,
      int sessionsBeforeLongBreak,
      String? selectedHabitId,
      String? projectName,
      int tickCount});

  $FocusSessionCopyWith<$Res>? get activeSession;
}

/// @nodoc
class _$FocusStateCopyWithImpl<$Res, $Val extends FocusState>
    implements $FocusStateCopyWith<$Res> {
  _$FocusStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeSession = freezed,
    Object? recentSessions = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? selectedMode = null,
    Object? workDuration = null,
    Object? breakDuration = null,
    Object? longBreakDuration = null,
    Object? sessionsBeforeLongBreak = null,
    Object? selectedHabitId = freezed,
    Object? projectName = freezed,
    Object? tickCount = null,
  }) {
    return _then(_value.copyWith(
      activeSession: freezed == activeSession
          ? _value.activeSession
          : activeSession // ignore: cast_nullable_to_non_nullable
              as FocusSession?,
      recentSessions: null == recentSessions
          ? _value.recentSessions
          : recentSessions // ignore: cast_nullable_to_non_nullable
              as List<FocusSession>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      selectedMode: null == selectedMode
          ? _value.selectedMode
          : selectedMode // ignore: cast_nullable_to_non_nullable
              as String,
      workDuration: null == workDuration
          ? _value.workDuration
          : workDuration // ignore: cast_nullable_to_non_nullable
              as int,
      breakDuration: null == breakDuration
          ? _value.breakDuration
          : breakDuration // ignore: cast_nullable_to_non_nullable
              as int,
      longBreakDuration: null == longBreakDuration
          ? _value.longBreakDuration
          : longBreakDuration // ignore: cast_nullable_to_non_nullable
              as int,
      sessionsBeforeLongBreak: null == sessionsBeforeLongBreak
          ? _value.sessionsBeforeLongBreak
          : sessionsBeforeLongBreak // ignore: cast_nullable_to_non_nullable
              as int,
      selectedHabitId: freezed == selectedHabitId
          ? _value.selectedHabitId
          : selectedHabitId // ignore: cast_nullable_to_non_nullable
              as String?,
      projectName: freezed == projectName
          ? _value.projectName
          : projectName // ignore: cast_nullable_to_non_nullable
              as String?,
      tickCount: null == tickCount
          ? _value.tickCount
          : tickCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $FocusSessionCopyWith<$Res>? get activeSession {
    if (_value.activeSession == null) {
      return null;
    }

    return $FocusSessionCopyWith<$Res>(_value.activeSession!, (value) {
      return _then(_value.copyWith(activeSession: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FocusStateImplCopyWith<$Res>
    implements $FocusStateCopyWith<$Res> {
  factory _$$FocusStateImplCopyWith(
          _$FocusStateImpl value, $Res Function(_$FocusStateImpl) then) =
      __$$FocusStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {FocusSession? activeSession,
      List<FocusSession> recentSessions,
      bool isLoading,
      String? error,
      String selectedMode,
      int workDuration,
      int breakDuration,
      int longBreakDuration,
      int sessionsBeforeLongBreak,
      String? selectedHabitId,
      String? projectName,
      int tickCount});

  @override
  $FocusSessionCopyWith<$Res>? get activeSession;
}

/// @nodoc
class __$$FocusStateImplCopyWithImpl<$Res>
    extends _$FocusStateCopyWithImpl<$Res, _$FocusStateImpl>
    implements _$$FocusStateImplCopyWith<$Res> {
  __$$FocusStateImplCopyWithImpl(
      _$FocusStateImpl _value, $Res Function(_$FocusStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeSession = freezed,
    Object? recentSessions = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? selectedMode = null,
    Object? workDuration = null,
    Object? breakDuration = null,
    Object? longBreakDuration = null,
    Object? sessionsBeforeLongBreak = null,
    Object? selectedHabitId = freezed,
    Object? projectName = freezed,
    Object? tickCount = null,
  }) {
    return _then(_$FocusStateImpl(
      activeSession: freezed == activeSession
          ? _value.activeSession
          : activeSession // ignore: cast_nullable_to_non_nullable
              as FocusSession?,
      recentSessions: null == recentSessions
          ? _value._recentSessions
          : recentSessions // ignore: cast_nullable_to_non_nullable
              as List<FocusSession>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      selectedMode: null == selectedMode
          ? _value.selectedMode
          : selectedMode // ignore: cast_nullable_to_non_nullable
              as String,
      workDuration: null == workDuration
          ? _value.workDuration
          : workDuration // ignore: cast_nullable_to_non_nullable
              as int,
      breakDuration: null == breakDuration
          ? _value.breakDuration
          : breakDuration // ignore: cast_nullable_to_non_nullable
              as int,
      longBreakDuration: null == longBreakDuration
          ? _value.longBreakDuration
          : longBreakDuration // ignore: cast_nullable_to_non_nullable
              as int,
      sessionsBeforeLongBreak: null == sessionsBeforeLongBreak
          ? _value.sessionsBeforeLongBreak
          : sessionsBeforeLongBreak // ignore: cast_nullable_to_non_nullable
              as int,
      selectedHabitId: freezed == selectedHabitId
          ? _value.selectedHabitId
          : selectedHabitId // ignore: cast_nullable_to_non_nullable
              as String?,
      projectName: freezed == projectName
          ? _value.projectName
          : projectName // ignore: cast_nullable_to_non_nullable
              as String?,
      tickCount: null == tickCount
          ? _value.tickCount
          : tickCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$FocusStateImpl implements _FocusState {
  const _$FocusStateImpl(
      {this.activeSession,
      final List<FocusSession> recentSessions = const [],
      this.isLoading = false,
      this.error,
      this.selectedMode = 'Pomodoro',
      this.workDuration = 25,
      this.breakDuration = 5,
      this.longBreakDuration = 15,
      this.sessionsBeforeLongBreak = 4,
      this.selectedHabitId,
      this.projectName,
      this.tickCount = 0})
      : _recentSessions = recentSessions;

  @override
  final FocusSession? activeSession;
  final List<FocusSession> _recentSessions;
  @override
  @JsonKey()
  List<FocusSession> get recentSessions {
    if (_recentSessions is EqualUnmodifiableListView) return _recentSessions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentSessions);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;
  @override
  @JsonKey()
  final String selectedMode;
  @override
  @JsonKey()
  final int workDuration;
  @override
  @JsonKey()
  final int breakDuration;
  @override
  @JsonKey()
  final int longBreakDuration;
  @override
  @JsonKey()
  final int sessionsBeforeLongBreak;
  @override
  final String? selectedHabitId;
  @override
  final String? projectName;

  /// Bumped on every timer tick so the state - and everything derived from
  /// it - actually changes. See [FocusController.tick].
  @override
  @JsonKey()
  final int tickCount;

  @override
  String toString() {
    return 'FocusState(activeSession: $activeSession, recentSessions: $recentSessions, isLoading: $isLoading, error: $error, selectedMode: $selectedMode, workDuration: $workDuration, breakDuration: $breakDuration, longBreakDuration: $longBreakDuration, sessionsBeforeLongBreak: $sessionsBeforeLongBreak, selectedHabitId: $selectedHabitId, projectName: $projectName, tickCount: $tickCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FocusStateImpl &&
            (identical(other.activeSession, activeSession) ||
                other.activeSession == activeSession) &&
            const DeepCollectionEquality()
                .equals(other._recentSessions, _recentSessions) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.selectedMode, selectedMode) ||
                other.selectedMode == selectedMode) &&
            (identical(other.workDuration, workDuration) ||
                other.workDuration == workDuration) &&
            (identical(other.breakDuration, breakDuration) ||
                other.breakDuration == breakDuration) &&
            (identical(other.longBreakDuration, longBreakDuration) ||
                other.longBreakDuration == longBreakDuration) &&
            (identical(
                    other.sessionsBeforeLongBreak, sessionsBeforeLongBreak) ||
                other.sessionsBeforeLongBreak == sessionsBeforeLongBreak) &&
            (identical(other.selectedHabitId, selectedHabitId) ||
                other.selectedHabitId == selectedHabitId) &&
            (identical(other.projectName, projectName) ||
                other.projectName == projectName) &&
            (identical(other.tickCount, tickCount) ||
                other.tickCount == tickCount));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      activeSession,
      const DeepCollectionEquality().hash(_recentSessions),
      isLoading,
      error,
      selectedMode,
      workDuration,
      breakDuration,
      longBreakDuration,
      sessionsBeforeLongBreak,
      selectedHabitId,
      projectName,
      tickCount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FocusStateImplCopyWith<_$FocusStateImpl> get copyWith =>
      __$$FocusStateImplCopyWithImpl<_$FocusStateImpl>(this, _$identity);
}

abstract class _FocusState implements FocusState {
  const factory _FocusState(
      {final FocusSession? activeSession,
      final List<FocusSession> recentSessions,
      final bool isLoading,
      final String? error,
      final String selectedMode,
      final int workDuration,
      final int breakDuration,
      final int longBreakDuration,
      final int sessionsBeforeLongBreak,
      final String? selectedHabitId,
      final String? projectName,
      final int tickCount}) = _$FocusStateImpl;

  @override
  FocusSession? get activeSession;
  @override
  List<FocusSession> get recentSessions;
  @override
  bool get isLoading;
  @override
  String? get error;
  @override
  String get selectedMode;
  @override
  int get workDuration;
  @override
  int get breakDuration;
  @override
  int get longBreakDuration;
  @override
  int get sessionsBeforeLongBreak;
  @override
  String? get selectedHabitId;
  @override
  String? get projectName;
  @override

  /// Bumped on every timer tick so the state - and everything derived from
  /// it - actually changes. See [FocusController.tick].
  int get tickCount;
  @override
  @JsonKey(ignore: true)
  _$$FocusStateImplCopyWith<_$FocusStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
