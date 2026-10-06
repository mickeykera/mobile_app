// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TaskState {
  List<Task> get tasks => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isSaving => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TaskStateCopyWith<TaskState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskStateCopyWith<$Res> {
  factory $TaskStateCopyWith(TaskState value, $Res Function(TaskState) then) =
      _$TaskStateCopyWithImpl<$Res, TaskState>;
  @useResult
  $Res call({List<Task> tasks, bool isLoading, bool isSaving, String? error});
}

/// @nodoc
class _$TaskStateCopyWithImpl<$Res, $Val extends TaskState>
    implements $TaskStateCopyWith<$Res> {
  _$TaskStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tasks = null,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      tasks: null == tasks
          ? _value.tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<Task>,
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
abstract class _$$TaskStateImplCopyWith<$Res>
    implements $TaskStateCopyWith<$Res> {
  factory _$$TaskStateImplCopyWith(
          _$TaskStateImpl value, $Res Function(_$TaskStateImpl) then) =
      __$$TaskStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Task> tasks, bool isLoading, bool isSaving, String? error});
}

/// @nodoc
class __$$TaskStateImplCopyWithImpl<$Res>
    extends _$TaskStateCopyWithImpl<$Res, _$TaskStateImpl>
    implements _$$TaskStateImplCopyWith<$Res> {
  __$$TaskStateImplCopyWithImpl(
      _$TaskStateImpl _value, $Res Function(_$TaskStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tasks = null,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? error = freezed,
  }) {
    return _then(_$TaskStateImpl(
      tasks: null == tasks
          ? _value._tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<Task>,
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

class _$TaskStateImpl implements _TaskState {
  const _$TaskStateImpl(
      {final List<Task> tasks = const [],
      this.isLoading = false,
      this.isSaving = false,
      this.error})
      : _tasks = tasks;

  final List<Task> _tasks;
  @override
  @JsonKey()
  List<Task> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
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
    return 'TaskState(tasks: $tasks, isLoading: $isLoading, isSaving: $isSaving, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskStateImpl &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isSaving, isSaving) ||
                other.isSaving == isSaving) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_tasks), isLoading, isSaving, error);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskStateImplCopyWith<_$TaskStateImpl> get copyWith =>
      __$$TaskStateImplCopyWithImpl<_$TaskStateImpl>(this, _$identity);
}

abstract class _TaskState implements TaskState {
  const factory _TaskState(
      {final List<Task> tasks,
      final bool isLoading,
      final bool isSaving,
      final String? error}) = _$TaskStateImpl;

  @override
  List<Task> get tasks;
  @override
  bool get isLoading;
  @override
  bool get isSaving;
  @override
  String? get error;
  @override
  @JsonKey(ignore: true)
  _$$TaskStateImplCopyWith<_$TaskStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
