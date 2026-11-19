import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/parse_result.dart';

void main() {
  int parseInt(Object? json) {
    if (json is int) return json;
    throw const FormatException('not an int');
  }

  test('a successful response is parsed', () {
    final result = parseResult(const Ok(42), parseInt);
    expect(result.valueOrNull, 42);
  });

  test('a failure passes through untouched', () {
    const failure = ServerFailure(503);
    final result = parseResult<int>(const Err(failure), parseInt);
    expect(result.failureOrNull, same(failure));
  });

  test('a FormatException becomes a MalformedResponseFailure', () {
    final result = parseResult(const Ok('nope'), parseInt);

    final failure = result.failureOrNull;
    expect(failure, isA<MalformedResponseFailure>());
    expect((failure! as MalformedResponseFailure).detail, 'not an int');
  });

  test('any other exception is a bug and is not swallowed', () {
    expect(
      () => parseResult(const Ok(1), (_) => throw StateError('bug')),
      throwsStateError,
    );
  });
}
