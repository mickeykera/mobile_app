class Failure {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const Failure(this.message, {this.originalError, this.stackTrace});

  String get userMessage => message;
  bool get isRetryable => false;
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message,
      {this.statusCode, super.originalError, super.stackTrace});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.originalError, super.stackTrace});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.originalError, super.stackTrace});
}

class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;
  const ValidationFailure(super.message,
      {this.fieldErrors, super.originalError, super.stackTrace});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.originalError, super.stackTrace});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message,
      {super.originalError, super.stackTrace});
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure(super.message,
      {super.originalError, super.stackTrace});
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.originalError, super.stackTrace});
}

typedef Result<T> = Either<Failure, T>;

class Either<L, R> {
  final L? _left;
  final R? _right;
  final bool _isLeft;

  const Either._(this._left, this._right, this._isLeft);

  factory Either.left(L value) => Either._(value, null, true);
  factory Either.right(R value) => Either._(null, value, false);

  R getOrElse(R Function(L) onLeft) => _isLeft ? onLeft(_left as L) : _right!;

  R fold(R Function(L) onLeft, R Function(R) onRight) =>
      _isLeft ? onLeft(_left as L) : onRight(_right as R);

  bool get isLeft => _isLeft;
  bool get isRight => !_isLeft;
  L? get left => _left;
  R? get right => _right;
}
