// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AnalyticsData {
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  Map<DateTime, int> get habitHeatmap => throw _privateConstructorUsedError;
  Map<String, int> get categoryCompletions =>
      throw _privateConstructorUsedError;
  Map<String, int> get categoryStreaks => throw _privateConstructorUsedError;
  int get totalFocusMinutes => throw _privateConstructorUsedError;
  Map<String, int> get focusByCategory => throw _privateConstructorUsedError;
  Map<DateTime, int> get focusHeatmap => throw _privateConstructorUsedError;
  int get journalEntriesCount => throw _privateConstructorUsedError;
  Map<String, int> get moodDistribution => throw _privateConstructorUsedError;
  Map<String, int> get energyDistribution => throw _privateConstructorUsedError;
  double get avgMood => throw _privateConstructorUsedError;
  double get avgEnergy => throw _privateConstructorUsedError;
  List<CorrelationPoint> get moodHabitCorrelation =>
      throw _privateConstructorUsedError;
  List<CorrelationPoint> get energyHabitCorrelation =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $AnalyticsDataCopyWith<AnalyticsData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalyticsDataCopyWith<$Res> {
  factory $AnalyticsDataCopyWith(
          AnalyticsData value, $Res Function(AnalyticsData) then) =
      _$AnalyticsDataCopyWithImpl<$Res, AnalyticsData>;
  @useResult
  $Res call(
      {DateTime startDate,
      DateTime endDate,
      Map<DateTime, int> habitHeatmap,
      Map<String, int> categoryCompletions,
      Map<String, int> categoryStreaks,
      int totalFocusMinutes,
      Map<String, int> focusByCategory,
      Map<DateTime, int> focusHeatmap,
      int journalEntriesCount,
      Map<String, int> moodDistribution,
      Map<String, int> energyDistribution,
      double avgMood,
      double avgEnergy,
      List<CorrelationPoint> moodHabitCorrelation,
      List<CorrelationPoint> energyHabitCorrelation});
}

/// @nodoc
class _$AnalyticsDataCopyWithImpl<$Res, $Val extends AnalyticsData>
    implements $AnalyticsDataCopyWith<$Res> {
  _$AnalyticsDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startDate = null,
    Object? endDate = null,
    Object? habitHeatmap = null,
    Object? categoryCompletions = null,
    Object? categoryStreaks = null,
    Object? totalFocusMinutes = null,
    Object? focusByCategory = null,
    Object? focusHeatmap = null,
    Object? journalEntriesCount = null,
    Object? moodDistribution = null,
    Object? energyDistribution = null,
    Object? avgMood = null,
    Object? avgEnergy = null,
    Object? moodHabitCorrelation = null,
    Object? energyHabitCorrelation = null,
  }) {
    return _then(_value.copyWith(
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      habitHeatmap: null == habitHeatmap
          ? _value.habitHeatmap
          : habitHeatmap // ignore: cast_nullable_to_non_nullable
              as Map<DateTime, int>,
      categoryCompletions: null == categoryCompletions
          ? _value.categoryCompletions
          : categoryCompletions // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      categoryStreaks: null == categoryStreaks
          ? _value.categoryStreaks
          : categoryStreaks // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      totalFocusMinutes: null == totalFocusMinutes
          ? _value.totalFocusMinutes
          : totalFocusMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      focusByCategory: null == focusByCategory
          ? _value.focusByCategory
          : focusByCategory // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      focusHeatmap: null == focusHeatmap
          ? _value.focusHeatmap
          : focusHeatmap // ignore: cast_nullable_to_non_nullable
              as Map<DateTime, int>,
      journalEntriesCount: null == journalEntriesCount
          ? _value.journalEntriesCount
          : journalEntriesCount // ignore: cast_nullable_to_non_nullable
              as int,
      moodDistribution: null == moodDistribution
          ? _value.moodDistribution
          : moodDistribution // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      energyDistribution: null == energyDistribution
          ? _value.energyDistribution
          : energyDistribution // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      avgMood: null == avgMood
          ? _value.avgMood
          : avgMood // ignore: cast_nullable_to_non_nullable
              as double,
      avgEnergy: null == avgEnergy
          ? _value.avgEnergy
          : avgEnergy // ignore: cast_nullable_to_non_nullable
              as double,
      moodHabitCorrelation: null == moodHabitCorrelation
          ? _value.moodHabitCorrelation
          : moodHabitCorrelation // ignore: cast_nullable_to_non_nullable
              as List<CorrelationPoint>,
      energyHabitCorrelation: null == energyHabitCorrelation
          ? _value.energyHabitCorrelation
          : energyHabitCorrelation // ignore: cast_nullable_to_non_nullable
              as List<CorrelationPoint>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AnalyticsDataImplCopyWith<$Res>
    implements $AnalyticsDataCopyWith<$Res> {
  factory _$$AnalyticsDataImplCopyWith(
          _$AnalyticsDataImpl value, $Res Function(_$AnalyticsDataImpl) then) =
      __$$AnalyticsDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime startDate,
      DateTime endDate,
      Map<DateTime, int> habitHeatmap,
      Map<String, int> categoryCompletions,
      Map<String, int> categoryStreaks,
      int totalFocusMinutes,
      Map<String, int> focusByCategory,
      Map<DateTime, int> focusHeatmap,
      int journalEntriesCount,
      Map<String, int> moodDistribution,
      Map<String, int> energyDistribution,
      double avgMood,
      double avgEnergy,
      List<CorrelationPoint> moodHabitCorrelation,
      List<CorrelationPoint> energyHabitCorrelation});
}

/// @nodoc
class __$$AnalyticsDataImplCopyWithImpl<$Res>
    extends _$AnalyticsDataCopyWithImpl<$Res, _$AnalyticsDataImpl>
    implements _$$AnalyticsDataImplCopyWith<$Res> {
  __$$AnalyticsDataImplCopyWithImpl(
      _$AnalyticsDataImpl _value, $Res Function(_$AnalyticsDataImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startDate = null,
    Object? endDate = null,
    Object? habitHeatmap = null,
    Object? categoryCompletions = null,
    Object? categoryStreaks = null,
    Object? totalFocusMinutes = null,
    Object? focusByCategory = null,
    Object? focusHeatmap = null,
    Object? journalEntriesCount = null,
    Object? moodDistribution = null,
    Object? energyDistribution = null,
    Object? avgMood = null,
    Object? avgEnergy = null,
    Object? moodHabitCorrelation = null,
    Object? energyHabitCorrelation = null,
  }) {
    return _then(_$AnalyticsDataImpl(
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      habitHeatmap: null == habitHeatmap
          ? _value._habitHeatmap
          : habitHeatmap // ignore: cast_nullable_to_non_nullable
              as Map<DateTime, int>,
      categoryCompletions: null == categoryCompletions
          ? _value._categoryCompletions
          : categoryCompletions // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      categoryStreaks: null == categoryStreaks
          ? _value._categoryStreaks
          : categoryStreaks // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      totalFocusMinutes: null == totalFocusMinutes
          ? _value.totalFocusMinutes
          : totalFocusMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      focusByCategory: null == focusByCategory
          ? _value._focusByCategory
          : focusByCategory // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      focusHeatmap: null == focusHeatmap
          ? _value._focusHeatmap
          : focusHeatmap // ignore: cast_nullable_to_non_nullable
              as Map<DateTime, int>,
      journalEntriesCount: null == journalEntriesCount
          ? _value.journalEntriesCount
          : journalEntriesCount // ignore: cast_nullable_to_non_nullable
              as int,
      moodDistribution: null == moodDistribution
          ? _value._moodDistribution
          : moodDistribution // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      energyDistribution: null == energyDistribution
          ? _value._energyDistribution
          : energyDistribution // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      avgMood: null == avgMood
          ? _value.avgMood
          : avgMood // ignore: cast_nullable_to_non_nullable
              as double,
      avgEnergy: null == avgEnergy
          ? _value.avgEnergy
          : avgEnergy // ignore: cast_nullable_to_non_nullable
              as double,
      moodHabitCorrelation: null == moodHabitCorrelation
          ? _value._moodHabitCorrelation
          : moodHabitCorrelation // ignore: cast_nullable_to_non_nullable
              as List<CorrelationPoint>,
      energyHabitCorrelation: null == energyHabitCorrelation
          ? _value._energyHabitCorrelation
          : energyHabitCorrelation // ignore: cast_nullable_to_non_nullable
              as List<CorrelationPoint>,
    ));
  }
}

/// @nodoc

class _$AnalyticsDataImpl extends _AnalyticsData {
  const _$AnalyticsDataImpl(
      {required this.startDate,
      required this.endDate,
      final Map<DateTime, int> habitHeatmap = const {},
      final Map<String, int> categoryCompletions = const {},
      final Map<String, int> categoryStreaks = const {},
      this.totalFocusMinutes = 0,
      final Map<String, int> focusByCategory = const {},
      final Map<DateTime, int> focusHeatmap = const {},
      this.journalEntriesCount = 0,
      final Map<String, int> moodDistribution = const {},
      final Map<String, int> energyDistribution = const {},
      this.avgMood = 0.0,
      this.avgEnergy = 0.0,
      final List<CorrelationPoint> moodHabitCorrelation = const [],
      final List<CorrelationPoint> energyHabitCorrelation = const []})
      : _habitHeatmap = habitHeatmap,
        _categoryCompletions = categoryCompletions,
        _categoryStreaks = categoryStreaks,
        _focusByCategory = focusByCategory,
        _focusHeatmap = focusHeatmap,
        _moodDistribution = moodDistribution,
        _energyDistribution = energyDistribution,
        _moodHabitCorrelation = moodHabitCorrelation,
        _energyHabitCorrelation = energyHabitCorrelation,
        super._();

  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  final Map<DateTime, int> _habitHeatmap;
  @override
  @JsonKey()
  Map<DateTime, int> get habitHeatmap {
    if (_habitHeatmap is EqualUnmodifiableMapView) return _habitHeatmap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_habitHeatmap);
  }

  final Map<String, int> _categoryCompletions;
  @override
  @JsonKey()
  Map<String, int> get categoryCompletions {
    if (_categoryCompletions is EqualUnmodifiableMapView)
      return _categoryCompletions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_categoryCompletions);
  }

  final Map<String, int> _categoryStreaks;
  @override
  @JsonKey()
  Map<String, int> get categoryStreaks {
    if (_categoryStreaks is EqualUnmodifiableMapView) return _categoryStreaks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_categoryStreaks);
  }

  @override
  @JsonKey()
  final int totalFocusMinutes;
  final Map<String, int> _focusByCategory;
  @override
  @JsonKey()
  Map<String, int> get focusByCategory {
    if (_focusByCategory is EqualUnmodifiableMapView) return _focusByCategory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_focusByCategory);
  }

  final Map<DateTime, int> _focusHeatmap;
  @override
  @JsonKey()
  Map<DateTime, int> get focusHeatmap {
    if (_focusHeatmap is EqualUnmodifiableMapView) return _focusHeatmap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_focusHeatmap);
  }

  @override
  @JsonKey()
  final int journalEntriesCount;
  final Map<String, int> _moodDistribution;
  @override
  @JsonKey()
  Map<String, int> get moodDistribution {
    if (_moodDistribution is EqualUnmodifiableMapView) return _moodDistribution;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_moodDistribution);
  }

  final Map<String, int> _energyDistribution;
  @override
  @JsonKey()
  Map<String, int> get energyDistribution {
    if (_energyDistribution is EqualUnmodifiableMapView)
      return _energyDistribution;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_energyDistribution);
  }

  @override
  @JsonKey()
  final double avgMood;
  @override
  @JsonKey()
  final double avgEnergy;
  final List<CorrelationPoint> _moodHabitCorrelation;
  @override
  @JsonKey()
  List<CorrelationPoint> get moodHabitCorrelation {
    if (_moodHabitCorrelation is EqualUnmodifiableListView)
      return _moodHabitCorrelation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_moodHabitCorrelation);
  }

  final List<CorrelationPoint> _energyHabitCorrelation;
  @override
  @JsonKey()
  List<CorrelationPoint> get energyHabitCorrelation {
    if (_energyHabitCorrelation is EqualUnmodifiableListView)
      return _energyHabitCorrelation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_energyHabitCorrelation);
  }

  @override
  String toString() {
    return 'AnalyticsData(startDate: $startDate, endDate: $endDate, habitHeatmap: $habitHeatmap, categoryCompletions: $categoryCompletions, categoryStreaks: $categoryStreaks, totalFocusMinutes: $totalFocusMinutes, focusByCategory: $focusByCategory, focusHeatmap: $focusHeatmap, journalEntriesCount: $journalEntriesCount, moodDistribution: $moodDistribution, energyDistribution: $energyDistribution, avgMood: $avgMood, avgEnergy: $avgEnergy, moodHabitCorrelation: $moodHabitCorrelation, energyHabitCorrelation: $energyHabitCorrelation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalyticsDataImpl &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            const DeepCollectionEquality()
                .equals(other._habitHeatmap, _habitHeatmap) &&
            const DeepCollectionEquality()
                .equals(other._categoryCompletions, _categoryCompletions) &&
            const DeepCollectionEquality()
                .equals(other._categoryStreaks, _categoryStreaks) &&
            (identical(other.totalFocusMinutes, totalFocusMinutes) ||
                other.totalFocusMinutes == totalFocusMinutes) &&
            const DeepCollectionEquality()
                .equals(other._focusByCategory, _focusByCategory) &&
            const DeepCollectionEquality()
                .equals(other._focusHeatmap, _focusHeatmap) &&
            (identical(other.journalEntriesCount, journalEntriesCount) ||
                other.journalEntriesCount == journalEntriesCount) &&
            const DeepCollectionEquality()
                .equals(other._moodDistribution, _moodDistribution) &&
            const DeepCollectionEquality()
                .equals(other._energyDistribution, _energyDistribution) &&
            (identical(other.avgMood, avgMood) || other.avgMood == avgMood) &&
            (identical(other.avgEnergy, avgEnergy) ||
                other.avgEnergy == avgEnergy) &&
            const DeepCollectionEquality()
                .equals(other._moodHabitCorrelation, _moodHabitCorrelation) &&
            const DeepCollectionEquality().equals(
                other._energyHabitCorrelation, _energyHabitCorrelation));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      startDate,
      endDate,
      const DeepCollectionEquality().hash(_habitHeatmap),
      const DeepCollectionEquality().hash(_categoryCompletions),
      const DeepCollectionEquality().hash(_categoryStreaks),
      totalFocusMinutes,
      const DeepCollectionEquality().hash(_focusByCategory),
      const DeepCollectionEquality().hash(_focusHeatmap),
      journalEntriesCount,
      const DeepCollectionEquality().hash(_moodDistribution),
      const DeepCollectionEquality().hash(_energyDistribution),
      avgMood,
      avgEnergy,
      const DeepCollectionEquality().hash(_moodHabitCorrelation),
      const DeepCollectionEquality().hash(_energyHabitCorrelation));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalyticsDataImplCopyWith<_$AnalyticsDataImpl> get copyWith =>
      __$$AnalyticsDataImplCopyWithImpl<_$AnalyticsDataImpl>(this, _$identity);
}

abstract class _AnalyticsData extends AnalyticsData {
  const factory _AnalyticsData(
          {required final DateTime startDate,
          required final DateTime endDate,
          final Map<DateTime, int> habitHeatmap,
          final Map<String, int> categoryCompletions,
          final Map<String, int> categoryStreaks,
          final int totalFocusMinutes,
          final Map<String, int> focusByCategory,
          final Map<DateTime, int> focusHeatmap,
          final int journalEntriesCount,
          final Map<String, int> moodDistribution,
          final Map<String, int> energyDistribution,
          final double avgMood,
          final double avgEnergy,
          final List<CorrelationPoint> moodHabitCorrelation,
          final List<CorrelationPoint> energyHabitCorrelation}) =
      _$AnalyticsDataImpl;
  const _AnalyticsData._() : super._();

  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  Map<DateTime, int> get habitHeatmap;
  @override
  Map<String, int> get categoryCompletions;
  @override
  Map<String, int> get categoryStreaks;
  @override
  int get totalFocusMinutes;
  @override
  Map<String, int> get focusByCategory;
  @override
  Map<DateTime, int> get focusHeatmap;
  @override
  int get journalEntriesCount;
  @override
  Map<String, int> get moodDistribution;
  @override
  Map<String, int> get energyDistribution;
  @override
  double get avgMood;
  @override
  double get avgEnergy;
  @override
  List<CorrelationPoint> get moodHabitCorrelation;
  @override
  List<CorrelationPoint> get energyHabitCorrelation;
  @override
  @JsonKey(ignore: true)
  _$$AnalyticsDataImplCopyWith<_$AnalyticsDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CorrelationPoint {
  double get x => throw _privateConstructorUsedError;
  double get y => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $CorrelationPointCopyWith<CorrelationPoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CorrelationPointCopyWith<$Res> {
  factory $CorrelationPointCopyWith(
          CorrelationPoint value, $Res Function(CorrelationPoint) then) =
      _$CorrelationPointCopyWithImpl<$Res, CorrelationPoint>;
  @useResult
  $Res call({double x, double y, String label});
}

/// @nodoc
class _$CorrelationPointCopyWithImpl<$Res, $Val extends CorrelationPoint>
    implements $CorrelationPointCopyWith<$Res> {
  _$CorrelationPointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? x = null,
    Object? y = null,
    Object? label = null,
  }) {
    return _then(_value.copyWith(
      x: null == x
          ? _value.x
          : x // ignore: cast_nullable_to_non_nullable
              as double,
      y: null == y
          ? _value.y
          : y // ignore: cast_nullable_to_non_nullable
              as double,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CorrelationPointImplCopyWith<$Res>
    implements $CorrelationPointCopyWith<$Res> {
  factory _$$CorrelationPointImplCopyWith(_$CorrelationPointImpl value,
          $Res Function(_$CorrelationPointImpl) then) =
      __$$CorrelationPointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double x, double y, String label});
}

/// @nodoc
class __$$CorrelationPointImplCopyWithImpl<$Res>
    extends _$CorrelationPointCopyWithImpl<$Res, _$CorrelationPointImpl>
    implements _$$CorrelationPointImplCopyWith<$Res> {
  __$$CorrelationPointImplCopyWithImpl(_$CorrelationPointImpl _value,
      $Res Function(_$CorrelationPointImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? x = null,
    Object? y = null,
    Object? label = null,
  }) {
    return _then(_$CorrelationPointImpl(
      x: null == x
          ? _value.x
          : x // ignore: cast_nullable_to_non_nullable
              as double,
      y: null == y
          ? _value.y
          : y // ignore: cast_nullable_to_non_nullable
              as double,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$CorrelationPointImpl implements _CorrelationPoint {
  const _$CorrelationPointImpl(
      {required this.x, required this.y, required this.label});

  @override
  final double x;
  @override
  final double y;
  @override
  final String label;

  @override
  String toString() {
    return 'CorrelationPoint(x: $x, y: $y, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CorrelationPointImpl &&
            (identical(other.x, x) || other.x == x) &&
            (identical(other.y, y) || other.y == y) &&
            (identical(other.label, label) || other.label == label));
  }

  @override
  int get hashCode => Object.hash(runtimeType, x, y, label);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CorrelationPointImplCopyWith<_$CorrelationPointImpl> get copyWith =>
      __$$CorrelationPointImplCopyWithImpl<_$CorrelationPointImpl>(
          this, _$identity);
}

abstract class _CorrelationPoint implements CorrelationPoint {
  const factory _CorrelationPoint(
      {required final double x,
      required final double y,
      required final String label}) = _$CorrelationPointImpl;

  @override
  double get x;
  @override
  double get y;
  @override
  String get label;
  @override
  @JsonKey(ignore: true)
  _$$CorrelationPointImplCopyWith<_$CorrelationPointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
