import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';

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

/// Like [parseResult], for an answer fetched from [url] through [client].
///
/// If the answer arrived but could not be understood, a [client] that
/// remembers answers ([ResponseCache]) is told to forget it. Otherwise a retry
/// would be handed the same unusable answer from the cache, instead of asking
/// the API again, and could never succeed until the stored copy expired.
Result<T> parseResponse<T>(
  ApiClient client,
  Uri url,
  Result<Object?> result,
  T Function(Object?) parse,
) {
  final parsed = parseResult(result, parse);
  if (result is Ok<Object?> && parsed is Err<T>) {
    // `is` would not narrow `client` to an unrelated type; a pattern does.
    if (client case final ResponseCache cache) cache.forget(url);
  }
  return parsed;
}
