import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/http/fault_injecting_transport.dart';
import 'package:pokemon_team_builder/data/http/fault_settings.dart';
import 'package:pokemon_team_builder/data/http/http_transport.dart';
import 'package:pokemon_team_builder/data/http_api_client.dart';
import 'package:pokemon_team_builder/data/retrying_api_client.dart';

import '../support/fake_transport.dart';

void main() {
  final url = Uri.parse('https://example.test/thing');
  final realBody = jsonEncode({'name': 'bulbasaur', 'id': 1});

  late FakeTransport inner;
  late FaultSettings settings;

  FaultInjectingTransport build({double random = 0}) => FaultInjectingTransport(
    inner,
    settings: () => settings,
    random: FixedRandom(random),
  );

  setUp(() {
    inner = FakeTransport(
      [],
      TransportResponse(statusCode: 200, body: realBody),
    );
    settings = FaultSettings.none;
  });

  test('with no faults, requests pass straight through', () async {
    final response = await build().get(url);
    expect(response.body, realBody);
    expect(inner.calls, [url]);
  });

  test('a failure rate of zero never fails, whatever the kinds', () async {
    settings = const FaultSettings(kinds: {FaultKind.serverError});
    expect((await build().get(url)).statusCode, 200);
  });

  group('latency', () {
    test('delays the response by the configured time', () {
      fakeAsync((async) {
        settings = const FaultSettings(latency: Duration(seconds: 2));
        var done = false;
        build().get(url).then((_) => done = true);

        async.elapse(const Duration(milliseconds: 1999));
        expect(done, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(done, isTrue);
      });
    });
  });

  group('failures', () {
    FaultSettings always(FaultKind kind) =>
        FaultSettings(failureRate: 1, kinds: {kind});

    test('offline switch throws without calling the API', () async {
      settings = const FaultSettings(offline: true);
      await expectLater(build().get(url), throwsA(isA<TransportException>()));
      expect(inner.calls, isEmpty);
    });

    test('offline fault throws', () async {
      settings = always(FaultKind.offline);
      await expectLater(build().get(url), throwsA(isA<TransportException>()));
    });

    test('serverError returns 503', () async {
      settings = always(FaultKind.serverError);
      expect((await build().get(url)).statusCode, 503);
      expect(inner.calls, isEmpty);
    });

    test('rateLimited returns 429 with the configured Retry-After', () async {
      settings = always(FaultKind.rateLimited)
          .copyWith(retryAfter: const Duration(seconds: 9));
      final response = await build().get(url);
      expect(response.statusCode, 429);
      expect(response.headers['retry-after'], '9');
    });

    test('truncatedJson cuts the real body so it no longer parses', () async {
      settings = always(FaultKind.truncatedJson);
      final response = await build().get(url);
      expect(response.statusCode, 200);
      expect(realBody.startsWith(response.body), isTrue);
      expect(response.body.length, lessThan(realBody.length));
      expect(() => jsonDecode(response.body), throwsFormatException);
    });

    test(
      'wrongShape returns valid JSON that is not the real payload',
      () async {
        settings = always(FaultKind.wrongShape);
        final response = await build().get(url);
        expect(jsonDecode(response.body), {'unexpected': 'shape'});
      },
    );

    test('timeout never completes', () {
      fakeAsync((async) {
        settings = always(FaultKind.timeout);
        var done = false;
        build().get(url).then((_) => done = true, onError: (_) => done = true);
        async.elapse(const Duration(hours: 1));
        expect(done, isFalse);
      });
    });

    test('a failure rate below 1 only fails some requests', () async {
      settings = const FaultSettings(failureRate: 0.5);
      // Random 0.2 is under the rate, so it fails; 0.9 is over it, so it passes.
      expect((await build(random: 0.2).get(url)).statusCode, 503);
      expect((await build(random: 0.9).get(url)).statusCode, 200);
    });

    test('picks among the enabled kinds', () async {
      settings = const FaultSettings(
        failureRate: 1,
        kinds: {FaultKind.serverError, FaultKind.rateLimited},
      );
      expect((await build().get(url)).statusCode, 503);
      expect((await build(random: 0.99).get(url)).statusCode, 429);
    });
  });

  test('settings are read on every request, so levers work live', () async {
    final transport = build();
    expect((await transport.get(url)).statusCode, 200);

    settings = const FaultSettings(failureRate: 1);
    expect((await transport.get(url)).statusCode, 503);

    settings = FaultSettings.none;
    expect((await transport.get(url)).statusCode, 200);
  });

  group('through the full client stack', () {
    test('each fault surfaces as the matching typed failure', () {
      final expectations = <FaultKind, Matcher>{
        FaultKind.serverError: isA<ServerFailure>(),
        FaultKind.rateLimited: isA<RateLimitedFailure>(),
        FaultKind.offline: isA<OfflineFailure>(),
        FaultKind.truncatedJson: isA<MalformedResponseFailure>(),
        FaultKind.timeout: isA<TimeoutFailure>(),
      };
      for (final MapEntry(key: kind, value: matcher) in expectations.entries) {
        fakeAsync((async) {
          settings = FaultSettings(failureRate: 1, kinds: {kind});
          final client = HttpApiClient(build());
          final result = settle(async, client.getJson(url));
          expect(result.failureOrNull, matcher, reason: '$kind');
        });
      }
    });

    test('persistent failures exhaust the retries and surface the failure', () {
      fakeAsync((async) {
        settings = const FaultSettings(failureRate: 1);
        final events = <RetryEvent>[];
        final client = RetryingApiClient(
          HttpApiClient(build()),
          random: FixedRandom(),
          onRetry: events.add,
        );
        final result = settle(async, client.getJson(url));
        expect(result.failureOrNull, isA<ServerFailure>());
        expect(events, hasLength(2));
      });
    });

    test('a brief outage is recovered from without the caller noticing', () {
      fakeAsync((async) {
        settings = const FaultSettings(failureRate: 1);
        final client = RetryingApiClient(
          HttpApiClient(build()),
          random: FixedRandom(),
        );
        final future = client.getJson(url);

        // The API recovers while the client is backing off.
        async.elapse(const Duration(milliseconds: 100));
        settings = FaultSettings.none;

        expect(settle(async, future), isA<Ok<Object?>>());
      });
    });
  });
}
