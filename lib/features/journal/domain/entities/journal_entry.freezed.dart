// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$JournalEntry {
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  Map<String, String> get responses => throw _privateConstructorUsedError;
  int? get moodRating => throw _privateConstructorUsedError;
  int? get energyRating => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  String? get gratitudeNote => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $JournalEntryCopyWith<JournalEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JournalEntryCopyWith<$Res> {
  factory $JournalEntryCopyWith(
          JournalEntry value, $Res Function(JournalEntry) then) =
      _$JournalEntryCopyWithImpl<$Res, JournalEntry>;
  @useResult
  $Res call(
      {String id,
      String type,
      DateTime date,
      Map<String, String> responses,
      int? moodRating,
      int? energyRating,
      List<String>? tags,
      String? gratitudeNote,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$JournalEntryCopyWithImpl<$Res, $Val extends JournalEntry>
    implements $JournalEntryCopyWith<$Res> {
  _$JournalEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? date = null,
    Object? responses = null,
    Object? moodRating = freezed,
    Object? energyRating = freezed,
    Object? tags = freezed,
    Object? gratitudeNote = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      responses: null == responses
          ? _value.responses
          : responses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      moodRating: freezed == moodRating
          ? _value.moodRating
          : moodRating // ignore: cast_nullable_to_non_nullable
              as int?,
      energyRating: freezed == energyRating
          ? _value.energyRating
          : energyRating // ignore: cast_nullable_to_non_nullable
              as int?,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      gratitudeNote: freezed == gratitudeNote
          ? _value.gratitudeNote
          : gratitudeNote // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$JournalEntryImplCopyWith<$Res>
    implements $JournalEntryCopyWith<$Res> {
  factory _$$JournalEntryImplCopyWith(
          _$JournalEntryImpl value, $Res Function(_$JournalEntryImpl) then) =
      __$$JournalEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String type,
      DateTime date,
      Map<String, String> responses,
      int? moodRating,
      int? energyRating,
      List<String>? tags,
      String? gratitudeNote,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$JournalEntryImplCopyWithImpl<$Res>
    extends _$JournalEntryCopyWithImpl<$Res, _$JournalEntryImpl>
    implements _$$JournalEntryImplCopyWith<$Res> {
  __$$JournalEntryImplCopyWithImpl(
      _$JournalEntryImpl _value, $Res Function(_$JournalEntryImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? date = null,
    Object? responses = null,
    Object? moodRating = freezed,
    Object? energyRating = freezed,
    Object? tags = freezed,
    Object? gratitudeNote = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$JournalEntryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      responses: null == responses
          ? _value._responses
          : responses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      moodRating: freezed == moodRating
          ? _value.moodRating
          : moodRating // ignore: cast_nullable_to_non_nullable
              as int?,
      energyRating: freezed == energyRating
          ? _value.energyRating
          : energyRating // ignore: cast_nullable_to_non_nullable
              as int?,
      tags: freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      gratitudeNote: freezed == gratitudeNote
          ? _value.gratitudeNote
          : gratitudeNote // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$JournalEntryImpl extends _JournalEntry {
  const _$JournalEntryImpl(
      {required this.id,
      required this.type,
      required this.date,
      required final Map<String, String> responses,
      this.moodRating,
      this.energyRating,
      final List<String>? tags,
      this.gratitudeNote,
      this.createdAt,
      this.updatedAt})
      : _responses = responses,
        _tags = tags,
        super._();

  @override
  final String id;
  @override
  final String type;
  @override
  final DateTime date;
  final Map<String, String> _responses;
  @override
  Map<String, String> get responses {
    if (_responses is EqualUnmodifiableMapView) return _responses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_responses);
  }

  @override
  final int? moodRating;
  @override
  final int? energyRating;
  final List<String>? _tags;
  @override
  List<String>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? gratitudeNote;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'JournalEntry(id: $id, type: $type, date: $date, responses: $responses, moodRating: $moodRating, energyRating: $energyRating, tags: $tags, gratitudeNote: $gratitudeNote, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JournalEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.date, date) || other.date == date) &&
            const DeepCollectionEquality()
                .equals(other._responses, _responses) &&
            (identical(other.moodRating, moodRating) ||
                other.moodRating == moodRating) &&
            (identical(other.energyRating, energyRating) ||
                other.energyRating == energyRating) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.gratitudeNote, gratitudeNote) ||
                other.gratitudeNote == gratitudeNote) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      date,
      const DeepCollectionEquality().hash(_responses),
      moodRating,
      energyRating,
      const DeepCollectionEquality().hash(_tags),
      gratitudeNote,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$JournalEntryImplCopyWith<_$JournalEntryImpl> get copyWith =>
      __$$JournalEntryImplCopyWithImpl<_$JournalEntryImpl>(this, _$identity);
}

abstract class _JournalEntry extends JournalEntry {
  const factory _JournalEntry(
      {required final String id,
      required final String type,
      required final DateTime date,
      required final Map<String, String> responses,
      final int? moodRating,
      final int? energyRating,
      final List<String>? tags,
      final String? gratitudeNote,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$JournalEntryImpl;
  const _JournalEntry._() : super._();

  @override
  String get id;
  @override
  String get type;
  @override
  DateTime get date;
  @override
  Map<String, String> get responses;
  @override
  int? get moodRating;
  @override
  int? get energyRating;
  @override
  List<String>? get tags;
  @override
  String? get gratitudeNote;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$JournalEntryImplCopyWith<_$JournalEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
