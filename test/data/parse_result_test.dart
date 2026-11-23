import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/parse_result.dart';

import '../support/fake_api_client.dart';

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

  group('parseResponse', () {
    final url = Uri.parse('https://example.test/thing');

    // A client that remembers answers, and notes which it was told to forget.
    final forgotten = <Uri>[];
    late _RememberingClient client;
    setUp(() {
      forgotten.clear();
      client = _RememberingClient(forgotten);
    });

    test('parses like parseResult', () {
      final result = parseResponse(client, url, const Ok(42), parseInt);

      expect(result.valueOrNull, 42);
    });

    test('forgets an answer that arrived but could not be understood', () {
      final result = parseResponse(client, url, const Ok('nope'), parseInt);

      expect(result.failureOrNull, isA<MalformedResponseFailure>());
      expect(forgotten, [url]);
    });

    test('keeps an answer that was understood', () {
      parseResponse(client, url, const Ok(42), parseInt);

      expect(forgotten, isEmpty);
    });

    test('has nothing to forget when there was no answer', () {
      parseResponse<int>(client, url, const Err(ServerFailure(503)), parseInt);

      expect(forgotten, isEmpty);
    });

    test('copes with a client that remembers nothing', () {
      final plain = FakeApiClient((_) => const Ok(null));

      final result = parseResponse(plain, url, const Ok('nope'), parseInt);

      expect(result.failureOrNull, isA<MalformedResponseFailure>());
    });
  });
}

/// A client that records the addresses it was told to forget.
class _RememberingClient implements ApiClient, ResponseCache {
  _RememberingClient(this.forgotten);

  final List<Uri> forgotten;

  @override
  Future<Result<Object?>> getJson(Uri url) async => const Ok(null);

  @override
  void forget(Uri url) => forgotten.add(url);
}
