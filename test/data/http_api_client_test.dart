import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/http/http_transport.dart';
import 'package:pokemon_team_builder/data/http_api_client.dart';

import '../support/fake_transport.dart';

void main() {
  final url = Uri.parse('https://example.test/thing');

  Future<Result<Object?>> fetch(Object script) =>
      HttpApiClient(FakeTransport([script])).getJson(url);

  group('success', () {
    test('decodes a JSON object', () async {
      final result = await fetch(okJson({'name': 'pikachu'}));
      expect(result.valueOrNull, {'name': 'pikachu'});
    });

    test('accepts a JSON null as a valid value', () async {
      final result = await fetch(
        const TransportResponse(statusCode: 200, body: 'null'),
      );
      expect(result, isA<Ok<Object?>>());
      expect(result.valueOrNull, isNull);
    });
  });

  group('status mapping', () {
    test('404 is NotFound', () async {
      expect((await fetch(status(404))).failureOrNull, isA<NotFoundFailure>());
    });

    test('429 is RateLimited and reads Retry-After seconds', () async {
      final result = await fetch(status(429, headers: {'retry-after': '7'}));
      expect(
        result.failureOrNull,
        isA<RateLimitedFailure>().having(
          (f) => f.retryAfter,
          'retryAfter',
          const Duration(seconds: 7),
        ),
      );
    });

    for (final header in [
      null,
      '',
      'soon',
      '-3',
      'Wed, 21 Oct 2026 07:28:00 GMT',
    ]) {
      test(
        '429 with unusable Retry-After ($header) has no retryAfter',
        () async {
          final result = await fetch(
            status(429, headers: {'retry-after': ?header}),
          );
          expect(
            result.failureOrNull,
            isA<RateLimitedFailure>().having(
              (f) => f.retryAfter,
              'retryAfter',
              isNull,
            ),
          );
        },
      );
    }

    test('5xx is Server with the status code', () async {
      expect(
        (await fetch(status(502))).failureOrNull,
        isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 502),
      );
    });

    test('other 4xx is ClientError', () async {
      expect(
        (await fetch(status(403))).failureOrNull,
        isA<ClientErrorFailure>().having(
          (f) => f.statusCode,
          'statusCode',
          403,
        ),
      );
    });
  });

  group('bad bodies', () {
    test('invalid JSON is Malformed', () async {
      final result = await fetch(
        const TransportResponse(statusCode: 200, body: '{"a":'),
      );
      expect(result.failureOrNull, isA<MalformedResponseFailure>());
    });

    test('an empty 200 is Malformed', () async {
      final result = await fetch(const TransportResponse(statusCode: 200));
      expect(result.failureOrNull, isA<MalformedResponseFailure>());
    });

    test('an HTML error page served as 200 is Malformed', () async {
      final result = await fetch(
        const TransportResponse(
          statusCode: 200,
          body: '<html>Bad gateway</html>',
        ),
      );
      expect(result.failureOrNull, isA<MalformedResponseFailure>());
    });
  });

  group('connectivity', () {
    test('a transport exception is Offline', () async {
      final result = await fetch(const TransportException('no route'));
      expect(
        result.failureOrNull,
        isA<OfflineFailure>().having((f) => f.detail, 'detail', 'no route'),
      );
    });

    test('a request that never completes is a Timeout', () {
      fakeAsync((async) {
        final client = HttpApiClient(_HangingTransport());
        final result = settle(
          async,
          client.getJson(url),
          elapse: const Duration(seconds: 11),
        );
        expect(result.failureOrNull, isA<TimeoutFailure>());
      });
    });

    test('the timeout is configurable', () {
      fakeAsync((async) {
        final client = HttpApiClient(
          _HangingTransport(),
          timeout: const Duration(seconds: 2),
        );
        final result = settle(
          async,
          client.getJson(url),
          elapse: const Duration(seconds: 3),
        );
        expect(result.failureOrNull, isA<TimeoutFailure>());
      });
    });
  });
}

class _HangingTransport implements HttpTransport {
  @override
  Future<TransportResponse> get(Uri url) =>
      Completer<TransportResponse>().future;
}
