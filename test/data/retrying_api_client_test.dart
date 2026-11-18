import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/http/http_transport.dart';
import 'package:pokemon_team_builder/data/http_api_client.dart';
import 'package:pokemon_team_builder/data/retrying_api_client.dart';

import '../support/fake_transport.dart';

void main() {
  final url = Uri.parse('https://example.test/thing');

  // Random of 1.0 makes the jittered delay equal to the full capped backoff,
  // which keeps the arithmetic in these tests readable.
  RetryingApiClient build(
    FakeTransport transport, {
    RetryPolicy policy = const RetryPolicy(),
    double random = 1.0,
    List<RetryEvent>? events,
  }) {
    return RetryingApiClient(
      HttpApiClient(transport),
      policy: policy,
      random: FixedRandom(random),
      onRetry: events?.add,
    );
  }

  test('a success is returned without retrying', () {
    fakeAsync((async) {
      final transport = FakeTransport([okJson('hello')]);
      final result = settle(async, build(transport).getJson(url));
      expect(result.valueOrNull, 'hello');
      expect(transport.calls, hasLength(1));
    });
  });

  test('retries a transient failure and then succeeds', () {
    fakeAsync((async) {
      final events = <RetryEvent>[];
      final transport = FakeTransport([status(503), okJson('recovered')]);
      final result = settle(
        async,
        build(transport, events: events).getJson(url),
      );

      expect(result.valueOrNull, 'recovered');
      expect(transport.calls, hasLength(2));
      expect(events, hasLength(1));
      expect(events.single.failedAttempt, 1);
      expect(events.single.failure, isA<ServerFailure>());
      expect(events.single.delay, const Duration(milliseconds: 500));
    });
  });

  test('waits for the backoff before trying again', () {
    fakeAsync((async) {
      final transport = FakeTransport([status(503), okJson('ok')]);
      final future = build(transport).getJson(url);

      async.elapse(const Duration(milliseconds: 499));
      expect(transport.calls, hasLength(1));

      async.elapse(const Duration(milliseconds: 1));
      expect(transport.calls, hasLength(2));
      expect(settle(async, future).valueOrNull, 'ok');
    });
  });

  test('gives up after maxAttempts and returns the last failure', () {
    fakeAsync((async) {
      final events = <RetryEvent>[];
      final transport = FakeTransport([], status(500));
      final result = settle(
        async,
        build(transport, events: events).getJson(url),
      );

      expect(result.failureOrNull, isA<ServerFailure>());
      expect(transport.calls, hasLength(3));
      // Backoff doubles: 500ms, then 1s.
      expect(events.map((e) => e.delay), const [
        Duration(milliseconds: 500),
        Duration(seconds: 1),
      ]);
    });
  });

  test('backoff is capped at maxDelay', () {
    fakeAsync((async) {
      final events = <RetryEvent>[];
      final transport = FakeTransport([], status(500));
      settle(
        async,
        build(
          transport,
          events: events,
          policy: const RetryPolicy(
            maxAttempts: 6,
            maxDelay: Duration(seconds: 2),
          ),
        ).getJson(url),
      );

      expect(events.map((e) => e.delay.inMilliseconds), [
        500,
        1000,
        2000,
        2000,
        2000,
      ]);
    });
  });

  test('jitter spreads the delay between half and the full backoff', () {
    fakeAsync((async) {
      final events = <RetryEvent>[];
      settle(
        async,
        build(
          FakeTransport([status(500), okJson(1)]),
          random: 0,
          events: events,
        ).getJson(url),
      );
      expect(events.single.delay, const Duration(milliseconds: 250));
    });
  });

  test('retries offline and timeout failures', () {
    fakeAsync((async) {
      final transport = FakeTransport([
        const TransportException('down'),
        okJson('back'),
      ]);
      final result = settle(async, build(transport).getJson(url));
      expect(result.valueOrNull, 'back');
      expect(transport.calls, hasLength(2));
    });
  });

  group('permanent failures are not retried', () {
    final cases = <String, Object>{
      'not found': status(404),
      'client error': status(403),
      'malformed body': const TransportResponse(statusCode: 200, body: '{"a":'),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        fakeAsync((async) {
          final transport = FakeTransport([entry.value]);
          final result = settle(async, build(transport).getJson(url));
          expect(result, isA<Err<Object?>>());
          expect(transport.calls, hasLength(1));
        });
      });
    }
  });

  group('Retry-After', () {
    test('is honoured instead of the backoff', () {
      fakeAsync((async) {
        final events = <RetryEvent>[];
        final transport = FakeTransport([
          status(429, headers: {'retry-after': '5'}),
          okJson('ok'),
        ]);
        final future = build(transport, events: events).getJson(url);

        async.elapse(const Duration(seconds: 4));
        expect(transport.calls, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(transport.calls, hasLength(2));
        expect(events.single.delay, const Duration(seconds: 5));
        expect(settle(async, future).valueOrNull, 'ok');
      });
    });

    test('gives up straight away if the wait is longer than maxRetryAfter', () {
      fakeAsync((async) {
        final transport = FakeTransport([
          status(429, headers: {'retry-after': '120'}),
        ]);
        final result = settle(async, build(transport).getJson(url));
        expect(result.failureOrNull, isA<RateLimitedFailure>());
        expect(transport.calls, hasLength(1));
      });
    });

    test('a 429 without Retry-After falls back to backoff', () {
      fakeAsync((async) {
        final events = <RetryEvent>[];
        settle(
          async,
          build(
            FakeTransport([status(429), okJson(1)]),
            events: events,
          ).getJson(url),
        );
        expect(events.single.delay, const Duration(milliseconds: 500));
      });
    });
  });
}
