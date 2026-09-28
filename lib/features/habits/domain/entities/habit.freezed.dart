// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'habit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Habit {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  String get frequency => throw _privateConstructorUsedError;
  List<int> get customWeekdays => throw _privateConstructorUsedError;
  String get timeOfDay => throw _privateConstructorUsedError;
  int get targetCount => throw _privateConstructorUsedError;
  Duration get targetDuration => throw _privateConstructorUsedError;
  String get cue => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;
  bool get isArchived => throw _privateConstructorUsedError;
  int get streakFreezesUsed => throw _privateConstructorUsedError;
  DateTime? get lastCompletedAt => throw _privateConstructorUsedError;
  int get currentStreak => throw _privateConstructorUsedError;
  int get longestStreak => throw _privateConstructorUsedError;
  int get totalCompletions => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $HabitCopyWith<Habit> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HabitCopyWith<$Res> {
  factory $HabitCopyWith(Habit value, $Res Function(Habit) then) =
      _$HabitCopyWithImpl<$Res, Habit>;
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      String category,
      String frequency,
      List<int> customWeekdays,
      String timeOfDay,
      int targetCount,
      Duration targetDuration,
      String cue,
      DateTime createdAt,
      DateTime updatedAt,
      int sortOrder,
      bool isArchived,
      int streakFreezesUsed,
      DateTime? lastCompletedAt,
      int currentStreak,
      int longestStreak,
      int totalCompletions});
}

/// @nodoc
class _$HabitCopyWithImpl<$Res, $Val extends Habit>
    implements $HabitCopyWith<$Res> {
  _$HabitCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? category = null,
    Object? frequency = null,
    Object? customWeekdays = null,
    Object? timeOfDay = null,
    Object? targetCount = null,
    Object? targetDuration = null,
    Object? cue = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? sortOrder = null,
    Object? isArchived = null,
    Object? streakFreezesUsed = null,
    Object? lastCompletedAt = freezed,
    Object? currentStreak = null,
    Object? longestStreak = null,
    Object? totalCompletions = null,
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
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      frequency: null == frequency
          ? _value.frequency
          : frequency // ignore: cast_nullable_to_non_nullable
              as String,
      customWeekdays: null == customWeekdays
          ? _value.customWeekdays
          : customWeekdays // ignore: cast_nullable_to_non_nullable
              as List<int>,
      timeOfDay: null == timeOfDay
          ? _value.timeOfDay
          : timeOfDay // ignore: cast_nullable_to_non_nullable
              as String,
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
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
      streakFreezesUsed: null == streakFreezesUsed
          ? _value.streakFreezesUsed
          : streakFreezesUsed // ignore: cast_nullable_to_non_nullable
              as int,
      lastCompletedAt: freezed == lastCompletedAt
          ? _value.lastCompletedAt
          : lastCompletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      currentStreak: null == currentStreak
          ? _value.currentStreak
          : currentStreak // ignore: cast_nullable_to_non_nullable
              as int,
      longestStreak: null == longestStreak
          ? _value.longestStreak
          : longestStreak // ignore: cast_nullable_to_non_nullable
              as int,
      totalCompletions: null == totalCompletions
          ? _value.totalCompletions
          : totalCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HabitImplCopyWith<$Res> implements $HabitCopyWith<$Res> {
  factory _$$HabitImplCopyWith(
          _$HabitImpl value, $Res Function(_$HabitImpl) then) =
      __$$HabitImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      String category,
      String frequency,
      List<int> customWeekdays,
      String timeOfDay,
      int targetCount,
      Duration targetDuration,
      String cue,
      DateTime createdAt,
      DateTime updatedAt,
      int sortOrder,
      bool isArchived,
      int streakFreezesUsed,
      DateTime? lastCompletedAt,
      int currentStreak,
      int longestStreak,
      int totalCompletions});
}

/// @nodoc
class __$$HabitImplCopyWithImpl<$Res>
    extends _$HabitCopyWithImpl<$Res, _$HabitImpl>
    implements _$$HabitImplCopyWith<$Res> {
  __$$HabitImplCopyWithImpl(
      _$HabitImpl _value, $Res Function(_$HabitImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? category = null,
    Object? frequency = null,
    Object? customWeekdays = null,
    Object? timeOfDay = null,
    Object? targetCount = null,
    Object? targetDuration = null,
    Object? cue = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? sortOrder = null,
    Object? isArchived = null,
    Object? streakFreezesUsed = null,
    Object? lastCompletedAt = freezed,
    Object? currentStreak = null,
    Object? longestStreak = null,
    Object? totalCompletions = null,
  }) {
    return _then(_$HabitImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      frequency: null == frequency
          ? _value.frequency
          : frequency // ignore: cast_nullable_to_non_nullable
              as String,
      customWeekdays: null == customWeekdays
          ? _value._customWeekdays
          : customWeekdays // ignore: cast_nullable_to_non_nullable
              as List<int>,
      timeOfDay: null == timeOfDay
          ? _value.timeOfDay
          : timeOfDay // ignore: cast_nullable_to_non_nullable
              as String,
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
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
      streakFreezesUsed: null == streakFreezesUsed
          ? _value.streakFreezesUsed
          : streakFreezesUsed // ignore: cast_nullable_to_non_nullable
              as int,
      lastCompletedAt: freezed == lastCompletedAt
          ? _value.lastCompletedAt
          : lastCompletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      currentStreak: null == currentStreak
          ? _value.currentStreak
          : currentStreak // ignore: cast_nullable_to_non_nullable
              as int,
      longestStreak: null == longestStreak
          ? _value.longestStreak
          : longestStreak // ignore: cast_nullable_to_non_nullable
              as int,
      totalCompletions: null == totalCompletions
          ? _value.totalCompletions
          : totalCompletions // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$HabitImpl extends _Habit {
  const _$HabitImpl(
      {required this.id,
      required this.title,
      required this.description,
      required this.category,
      required this.frequency,
      required final List<int> customWeekdays,
      required this.timeOfDay,
      required this.targetCount,
      required this.targetDuration,
      required this.cue,
      required this.createdAt,
      required this.updatedAt,
      required this.sortOrder,
      required this.isArchived,
      required this.streakFreezesUsed,
      this.lastCompletedAt,
      required this.currentStreak,
      required this.longestStreak,
      required this.totalCompletions})
      : _customWeekdays = customWeekdays,
        super._();

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final String category;
  @override
  final String frequency;
  final List<int> _customWeekdays;
  @override
  List<int> get customWeekdays {
    if (_customWeekdays is EqualUnmodifiableListView) return _customWeekdays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customWeekdays);
  }

  @override
  final String timeOfDay;
  @override
  final int targetCount;
  @override
  final Duration targetDuration;
  @override
  final String cue;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final int sortOrder;
  @override
  final bool isArchived;
  @override
  final int streakFreezesUsed;
  @override
  final DateTime? lastCompletedAt;
  @override
  final int currentStreak;
  @override
  final int longestStreak;
  @override
  final int totalCompletions;

  @override
  String toString() {
    return 'Habit(id: $id, title: $title, description: $description, category: $category, frequency: $frequency, customWeekdays: $customWeekdays, timeOfDay: $timeOfDay, targetCount: $targetCount, targetDuration: $targetDuration, cue: $cue, createdAt: $createdAt, updatedAt: $updatedAt, sortOrder: $sortOrder, isArchived: $isArchived, streakFreezesUsed: $streakFreezesUsed, lastCompletedAt: $lastCompletedAt, currentStreak: $currentStreak, longestStreak: $longestStreak, totalCompletions: $totalCompletions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HabitImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.frequency, frequency) ||
                other.frequency == frequency) &&
            const DeepCollectionEquality()
                .equals(other._customWeekdays, _customWeekdays) &&
            (identical(other.timeOfDay, timeOfDay) ||
                other.timeOfDay == timeOfDay) &&
            (identical(other.targetCount, targetCount) ||
                other.targetCount == targetCount) &&
            (identical(other.targetDuration, targetDuration) ||
                other.targetDuration == targetDuration) &&
            (identical(other.cue, cue) || other.cue == cue) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.isArchived, isArchived) ||
                other.isArchived == isArchived) &&
            (identical(other.streakFreezesUsed, streakFreezesUsed) ||
                other.streakFreezesUsed == streakFreezesUsed) &&
            (identical(other.lastCompletedAt, lastCompletedAt) ||
                other.lastCompletedAt == lastCompletedAt) &&
            (identical(other.currentStreak, currentStreak) ||
                other.currentStreak == currentStreak) &&
            (identical(other.longestStreak, longestStreak) ||
                other.longestStreak == longestStreak) &&
            (identical(other.totalCompletions, totalCompletions) ||
                other.totalCompletions == totalCompletions));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        title,
        description,
        category,
        frequency,
        const DeepCollectionEquality().hash(_customWeekdays),
        timeOfDay,
        targetCount,
        targetDuration,
        cue,
        createdAt,
        updatedAt,
        sortOrder,
        isArchived,
        streakFreezesUsed,
        lastCompletedAt,
        currentStreak,
        longestStreak,
        totalCompletions
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$HabitImplCopyWith<_$HabitImpl> get copyWith =>
      __$$HabitImplCopyWithImpl<_$HabitImpl>(this, _$identity);
}

abstract class _Habit extends Habit {
  const factory _Habit(
      {required final String id,
      required final String title,
      required final String description,
      required final String category,
      required final String frequency,
      required final List<int> customWeekdays,
      required final String timeOfDay,
      required final int targetCount,
      required final Duration targetDuration,
      required final String cue,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final int sortOrder,
      required final bool isArchived,
      required final int streakFreezesUsed,
      final DateTime? lastCompletedAt,
      required final int currentStreak,
      required final int longestStreak,
      required final int totalCompletions}) = _$HabitImpl;
  const _Habit._() : super._();

  @override
  String get id;
  @override
  String get title;
  @override
  String get description;
  @override
  String get category;
  @override
  String get frequency;
  @override
  List<int> get customWeekdays;
  @override
  String get timeOfDay;
  @override
  int get targetCount;
  @override
  Duration get targetDuration;
  @override
  String get cue;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  int get sortOrder;
  @override
  bool get isArchived;
  @override
  int get streakFreezesUsed;
  @override
  DateTime? get lastCompletedAt;
  @override
  int get currentStreak;
  @override
  int get longestStreak;
  @override
  int get totalCompletions;
  @override
  @JsonKey(ignore: true)
  _$$HabitImplCopyWith<_$HabitImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
