// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Task {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;
  TaskStatus get status => throw _privateConstructorUsedError;
  TaskSchedule get schedule => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get projectId => throw _privateConstructorUsedError;
  String? get goalId => throw _privateConstructorUsedError;
  String? get category => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  DateTime? get archivedAt => throw _privateConstructorUsedError;

  /// How much counts as done on one due day.
  int get targetCount => throw _privateConstructorUsedError;

  /// The intended duration of one occurrence.
  ///
  /// Aimed-at, not measured: a *measured* duration lives on the occurrence
  /// row (`HabitCompletion.duration`), so overwriting this with what actually
  /// happened would erase the target.
  Duration get targetDuration => throw _privateConstructorUsedError;

  /// Free-text cue or trigger ("After brushing teeth").
  String get cue => throw _privateConstructorUsedError;

  /// Morning/Afternoon/Evening label. Presentation and scheduling *intent*
  /// only - it is never consulted by [Recurring], `dueAt`, snooze, reschedule
  /// or the streak readers, and L1.3 did not change that.
  String get timeOfDay => throw _privateConstructorUsedError;

  /// Streak freezes spent on this item.
  StreakFreezeUsage get streakFreezeUsage => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TaskCopyWith<Task> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskCopyWith<$Res> {
  factory $TaskCopyWith(Task value, $Res Function(Task) then) =
      _$TaskCopyWithImpl<$Res, Task>;
  @useResult
  $Res call(
      {String id,
      String title,
      DateTime createdAt,
      DateTime updatedAt,
      int sortOrder,
      TaskStatus status,
      TaskSchedule schedule,
      String? description,
      String? projectId,
      String? goalId,
      String? category,
      DateTime? completedAt,
      DateTime? archivedAt,
      int targetCount,
      Duration targetDuration,
      String cue,
      String timeOfDay,
      StreakFreezeUsage streakFreezeUsage});
}

/// @nodoc
class _$TaskCopyWithImpl<$Res, $Val extends Task>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? sortOrder = null,
    Object? status = null,
    Object? schedule = null,
    Object? description = freezed,
    Object? projectId = freezed,
    Object? goalId = freezed,
    Object? category = freezed,
    Object? completedAt = freezed,
    Object? archivedAt = freezed,
    Object? targetCount = null,
    Object? targetDuration = null,
    Object? cue = null,
    Object? timeOfDay = null,
    Object? streakFreezeUsage = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      schedule: null == schedule
          ? _value.schedule
          : schedule // ignore: cast_nullable_to_non_nullable
              as TaskSchedule,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      projectId: freezed == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      goalId: freezed == goalId
          ? _value.goalId
          : goalId // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      archivedAt: freezed == archivedAt
          ? _value.archivedAt
          : archivedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      targetCount: null == targetCount
          ? _value.targetCount
          : targetCount // ignore: cast_nullable_to_non_nullable
              as int,
      targetDuration: null == targetDuration
          ? _value.targetDuration
          : targetDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      cue: null == cue
          ? _value.cue
          : cue // ignore: cast_nullable_to_non_nullable
              as String,
      timeOfDay: null == timeOfDay
          ? _value.timeOfDay
          : timeOfDay // ignore: cast_nullable_to_non_nullable
              as String,
      streakFreezeUsage: null == streakFreezeUsage
          ? _value.streakFreezeUsage
          : streakFreezeUsage // ignore: cast_nullable_to_non_nullable
              as StreakFreezeUsage,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskImplCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$$TaskImplCopyWith(
          _$TaskImpl value, $Res Function(_$TaskImpl) then) =
      __$$TaskImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      DateTime createdAt,
      DateTime updatedAt,
      int sortOrder,
      TaskStatus status,
      TaskSchedule schedule,
      String? description,
      String? projectId,
      String? goalId,
      String? category,
      DateTime? completedAt,
      DateTime? archivedAt,
      int targetCount,
      Duration targetDuration,
      String cue,
      String timeOfDay,
      StreakFreezeUsage streakFreezeUsage});
}

/// @nodoc
class __$$TaskImplCopyWithImpl<$Res>
    extends _$TaskCopyWithImpl<$Res, _$TaskImpl>
    implements _$$TaskImplCopyWith<$Res> {
  __$$TaskImplCopyWithImpl(_$TaskImpl _value, $Res Function(_$TaskImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? sortOrder = null,
    Object? status = null,
    Object? schedule = null,
    Object? description = freezed,
    Object? projectId = freezed,
    Object? goalId = freezed,
    Object? category = freezed,
    Object? completedAt = freezed,
    Object? archivedAt = freezed,
    Object? targetCount = null,
    Object? targetDuration = null,
    Object? cue = null,
    Object? timeOfDay = null,
    Object? streakFreezeUsage = null,
  }) {
    return _then(_$TaskImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      schedule: null == schedule
          ? _value.schedule
          : schedule // ignore: cast_nullable_to_non_nullable
              as TaskSchedule,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      projectId: freezed == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      goalId: freezed == goalId
          ? _value.goalId
          : goalId // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      archivedAt: freezed == archivedAt
          ? _value.archivedAt
          : archivedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      targetCount: null == targetCount
          ? _value.targetCount
          : targetCount // ignore: cast_nullable_to_non_nullable
              as int,
      targetDuration: null == targetDuration
          ? _value.targetDuration
          : targetDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      cue: null == cue
          ? _value.cue
          : cue // ignore: cast_nullable_to_non_nullable
              as String,
      timeOfDay: null == timeOfDay
          ? _value.timeOfDay
          : timeOfDay // ignore: cast_nullable_to_non_nullable
              as String,
      streakFreezeUsage: null == streakFreezeUsage
          ? _value.streakFreezeUsage
          : streakFreezeUsage // ignore: cast_nullable_to_non_nullable
              as StreakFreezeUsage,
    ));
  }
}

/// @nodoc

class _$TaskImpl extends _Task {
  const _$TaskImpl(
      {required this.id,
      required this.title,
      required this.createdAt,
      required this.updatedAt,
      required this.sortOrder,
      required this.status,
      required this.schedule,
      this.description,
      this.projectId,
      this.goalId,
      this.category,
      this.completedAt,
      this.archivedAt,
      this.targetCount = 1,
      this.targetDuration = Duration.zero,
      this.cue = '',
      this.timeOfDay = AppConstants.timeOfDayMorning,
      this.streakFreezeUsage = const StreakFreezeUsage()})
      : super._();

  @override
  final String id;
  @override
  final String title;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final int sortOrder;
  @override
  final TaskStatus status;
  @override
  final TaskSchedule schedule;
  @override
  final String? description;
  @override
  final String? projectId;
  @override
  final String? goalId;
  @override
  final String? category;
  @override
  final DateTime? completedAt;
  @override
  final DateTime? archivedAt;

  /// How much counts as done on one due day.
  @override
  @JsonKey()
  final int targetCount;

  /// The intended duration of one occurrence.
  ///
  /// Aimed-at, not measured: a *measured* duration lives on the occurrence
  /// row (`HabitCompletion.duration`), so overwriting this with what actually
  /// happened would erase the target.
  @override
  @JsonKey()
  final Duration targetDuration;

  /// Free-text cue or trigger ("After brushing teeth").
  @override
  @JsonKey()
  final String cue;

  /// Morning/Afternoon/Evening label. Presentation and scheduling *intent*
  /// only - it is never consulted by [Recurring], `dueAt`, snooze, reschedule
  /// or the streak readers, and L1.3 did not change that.
  @override
  @JsonKey()
  final String timeOfDay;

  /// Streak freezes spent on this item.
  @override
  @JsonKey()
  final StreakFreezeUsage streakFreezeUsage;

  @override
  String toString() {
    return 'Task(id: $id, title: $title, createdAt: $createdAt, updatedAt: $updatedAt, sortOrder: $sortOrder, status: $status, schedule: $schedule, description: $description, projectId: $projectId, goalId: $goalId, category: $category, completedAt: $completedAt, archivedAt: $archivedAt, targetCount: $targetCount, targetDuration: $targetDuration, cue: $cue, timeOfDay: $timeOfDay, streakFreezeUsage: $streakFreezeUsage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.schedule, schedule) ||
                other.schedule == schedule) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.goalId, goalId) || other.goalId == goalId) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.archivedAt, archivedAt) ||
                other.archivedAt == archivedAt) &&
            (identical(other.targetCount, targetCount) ||
                other.targetCount == targetCount) &&
            (identical(other.targetDuration, targetDuration) ||
                other.targetDuration == targetDuration) &&
            (identical(other.cue, cue) || other.cue == cue) &&
            (identical(other.timeOfDay, timeOfDay) ||
                other.timeOfDay == timeOfDay) &&
            (identical(other.streakFreezeUsage, streakFreezeUsage) ||
                other.streakFreezeUsage == streakFreezeUsage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      createdAt,
      updatedAt,
      sortOrder,
      status,
      schedule,
      description,
      projectId,
      goalId,
      category,
      completedAt,
      archivedAt,
      targetCount,
      targetDuration,
      cue,
      timeOfDay,
      streakFreezeUsage);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      __$$TaskImplCopyWithImpl<_$TaskImpl>(this, _$identity);
}

abstract class _Task extends Task {
  const factory _Task(
      {required final String id,
      required final String title,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final int sortOrder,
      required final TaskStatus status,
      required final TaskSchedule schedule,
      final String? description,
      final String? projectId,
      final String? goalId,
      final String? category,
      final DateTime? completedAt,
      final DateTime? archivedAt,
      final int targetCount,
      final Duration targetDuration,
      final String cue,
      final String timeOfDay,
      final StreakFreezeUsage streakFreezeUsage}) = _$TaskImpl;
  const _Task._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  int get sortOrder;
  @override
  TaskStatus get status;
  @override
  TaskSchedule get schedule;
  @override
  String? get description;
  @override
  String? get projectId;
  @override
  String? get goalId;
  @override
  String? get category;
  @override
  DateTime? get completedAt;
  @override
  DateTime? get archivedAt;
  @override

  /// How much counts as done on one due day.
  int get targetCount;
  @override

  /// The intended duration of one occurrence.
  ///
  /// Aimed-at, not measured: a *measured* duration lives on the occurrence
  /// row (`HabitCompletion.duration`), so overwriting this with what actually
  /// happened would erase the target.
  Duration get targetDuration;
  @override

  /// Free-text cue or trigger ("After brushing teeth").
  String get cue;
  @override

  /// Morning/Afternoon/Evening label. Presentation and scheduling *intent*
  /// only - it is never consulted by [Recurring], `dueAt`, snooze, reschedule
  /// or the streak readers, and L1.3 did not change that.
  String get timeOfDay;
  @override

  /// Streak freezes spent on this item.
  StreakFreezeUsage get streakFreezeUsage;
  @override
  @JsonKey(ignore: true)
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
