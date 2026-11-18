import 'package:pokemon_team_builder/core/api_failure.dart';

/// The outcome of an operation that can fail in expected ways.
///
/// Expected failures are values, not exceptions, so callers are forced to
/// handle them and the compiler can check a `switch` is exhaustive.
sealed class Result<T> {
  const Result();

  /// The value if this is [Ok], otherwise null.
  T? get valueOrNull => switch (this) {
    Ok<T>(value: final value) => value,
    Err<T>() => null,
  };

  /// The failure if this is [Err], otherwise null.
  ApiFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(failure: final failure) => failure,
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final ApiFailure failure;

  @override
  String toString() => 'Err($failure)';
}
