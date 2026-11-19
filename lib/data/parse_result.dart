import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';

/// Turns a raw API [result] into a typed one by running [parse] on the JSON.
///
/// - A failure passes through untouched.
/// - If [parse] throws a [FormatException] (the JSON was not the shape we
///   expected), the outcome is a [MalformedResponseFailure].
///
/// This is the one place where parsing exceptions are turned into failures, so
/// nothing above the repositories ever has to catch one.
Result<T> parseResult<T>(Result<Object?> result, T Function(Object?) parse) {
  switch (result) {
    case Err(:final failure):
      return Err(failure);
    case Ok(:final value):
      try {
        return Ok(parse(value));
      } on FormatException catch (e) {
        return Err(MalformedResponseFailure(e.message));
      }
  }
}
