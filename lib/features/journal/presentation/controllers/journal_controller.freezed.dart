// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$JournalState {
  JournalEntry? get morningEntry => throw _privateConstructorUsedError;
  JournalEntry? get eveningEntry => throw _privateConstructorUsedError;
  List<JournalEntry> get recentEntries => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isSaving => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  DateTime? get selectedDate => throw _privateConstructorUsedError;
  String get selectedType => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $JournalStateCopyWith<JournalState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JournalStateCopyWith<$Res> {
  factory $JournalStateCopyWith(
          JournalState value, $Res Function(JournalState) then) =
      _$JournalStateCopyWithImpl<$Res, JournalState>;
  @useResult
  $Res call(
      {JournalEntry? morningEntry,
      JournalEntry? eveningEntry,
      List<JournalEntry> recentEntries,
      bool isLoading,
      bool isSaving,
      String? error,
      DateTime? selectedDate,
      String selectedType});

  $JournalEntryCopyWith<$Res>? get morningEntry;
  $JournalEntryCopyWith<$Res>? get eveningEntry;
}

/// @nodoc
class _$JournalStateCopyWithImpl<$Res, $Val extends JournalState>
    implements $JournalStateCopyWith<$Res> {
  _$JournalStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? morningEntry = freezed,
    Object? eveningEntry = freezed,
    Object? recentEntries = null,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? error = freezed,
    Object? selectedDate = freezed,
    Object? selectedType = null,
  }) {
    return _then(_value.copyWith(
      morningEntry: freezed == morningEntry
          ? _value.morningEntry
          : morningEntry // ignore: cast_nullable_to_non_nullable
              as JournalEntry?,
      eveningEntry: freezed == eveningEntry
          ? _value.eveningEntry
          : eveningEntry // ignore: cast_nullable_to_non_nullable
              as JournalEntry?,
      recentEntries: null == recentEntries
          ? _value.recentEntries
          : recentEntries // ignore: cast_nullable_to_non_nullable
              as List<JournalEntry>,
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
      selectedDate: freezed == selectedDate
          ? _value.selectedDate
          : selectedDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      selectedType: null == selectedType
          ? _value.selectedType
          : selectedType // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $JournalEntryCopyWith<$Res>? get morningEntry {
    if (_value.morningEntry == null) {
      return null;
    }

    return $JournalEntryCopyWith<$Res>(_value.morningEntry!, (value) {
      return _then(_value.copyWith(morningEntry: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $JournalEntryCopyWith<$Res>? get eveningEntry {
    if (_value.eveningEntry == null) {
      return null;
    }

    return $JournalEntryCopyWith<$Res>(_value.eveningEntry!, (value) {
      return _then(_value.copyWith(eveningEntry: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$JournalStateImplCopyWith<$Res>
    implements $JournalStateCopyWith<$Res> {
  factory _$$JournalStateImplCopyWith(
          _$JournalStateImpl value, $Res Function(_$JournalStateImpl) then) =
      __$$JournalStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {JournalEntry? morningEntry,
      JournalEntry? eveningEntry,
      List<JournalEntry> recentEntries,
      bool isLoading,
      bool isSaving,
      String? error,
      DateTime? selectedDate,
      String selectedType});

  @override
  $JournalEntryCopyWith<$Res>? get morningEntry;
  @override
  $JournalEntryCopyWith<$Res>? get eveningEntry;
}

/// @nodoc
class __$$JournalStateImplCopyWithImpl<$Res>
    extends _$JournalStateCopyWithImpl<$Res, _$JournalStateImpl>
    implements _$$JournalStateImplCopyWith<$Res> {
  __$$JournalStateImplCopyWithImpl(
      _$JournalStateImpl _value, $Res Function(_$JournalStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? morningEntry = freezed,
    Object? eveningEntry = freezed,
    Object? recentEntries = null,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? error = freezed,
    Object? selectedDate = freezed,
    Object? selectedType = null,
  }) {
    return _then(_$JournalStateImpl(
      morningEntry: freezed == morningEntry
          ? _value.morningEntry
          : morningEntry // ignore: cast_nullable_to_non_nullable
              as JournalEntry?,
      eveningEntry: freezed == eveningEntry
          ? _value.eveningEntry
          : eveningEntry // ignore: cast_nullable_to_non_nullable
              as JournalEntry?,
      recentEntries: null == recentEntries
          ? _value._recentEntries
          : recentEntries // ignore: cast_nullable_to_non_nullable
              as List<JournalEntry>,
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
      selectedDate: freezed == selectedDate
          ? _value.selectedDate
          : selectedDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      selectedType: null == selectedType
          ? _value.selectedType
          : selectedType // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$JournalStateImpl implements _JournalState {
  const _$JournalStateImpl(
      {this.morningEntry,
      this.eveningEntry,
      final List<JournalEntry> recentEntries = const [],
      this.isLoading = false,
      this.isSaving = false,
      this.error,
      this.selectedDate,
      this.selectedType = 'Morning'})
      : _recentEntries = recentEntries;

  @override
  final JournalEntry? morningEntry;
  @override
  final JournalEntry? eveningEntry;
  final List<JournalEntry> _recentEntries;
  @override
  @JsonKey()
  List<JournalEntry> get recentEntries {
    if (_recentEntries is EqualUnmodifiableListView) return _recentEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentEntries);
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
  final DateTime? selectedDate;
  @override
  @JsonKey()
  final String selectedType;

  @override
  String toString() {
    return 'JournalState(morningEntry: $morningEntry, eveningEntry: $eveningEntry, recentEntries: $recentEntries, isLoading: $isLoading, isSaving: $isSaving, error: $error, selectedDate: $selectedDate, selectedType: $selectedType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JournalStateImpl &&
            (identical(other.morningEntry, morningEntry) ||
                other.morningEntry == morningEntry) &&
            (identical(other.eveningEntry, eveningEntry) ||
                other.eveningEntry == eveningEntry) &&
            const DeepCollectionEquality()
                .equals(other._recentEntries, _recentEntries) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isSaving, isSaving) ||
                other.isSaving == isSaving) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.selectedDate, selectedDate) ||
                other.selectedDate == selectedDate) &&
            (identical(other.selectedType, selectedType) ||
                other.selectedType == selectedType));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      morningEntry,
      eveningEntry,
      const DeepCollectionEquality().hash(_recentEntries),
      isLoading,
      isSaving,
      error,
      selectedDate,
      selectedType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$JournalStateImplCopyWith<_$JournalStateImpl> get copyWith =>
      __$$JournalStateImplCopyWithImpl<_$JournalStateImpl>(this, _$identity);
}

abstract class _JournalState implements JournalState {
  const factory _JournalState(
      {final JournalEntry? morningEntry,
      final JournalEntry? eveningEntry,
      final List<JournalEntry> recentEntries,
      final bool isLoading,
      final bool isSaving,
      final String? error,
      final DateTime? selectedDate,
      final String selectedType}) = _$JournalStateImpl;

  @override
  JournalEntry? get morningEntry;
  @override
  JournalEntry? get eveningEntry;
  @override
  List<JournalEntry> get recentEntries;
  @override
  bool get isLoading;
  @override
  bool get isSaving;
  @override
  String? get error;
  @override
  DateTime? get selectedDate;
  @override
  String get selectedType;
  @override
  @JsonKey(ignore: true)
  _$$JournalStateImplCopyWith<_$JournalStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
