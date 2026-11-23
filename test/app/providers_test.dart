import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/http/fault_settings.dart';
import 'package:pokemon_team_builder/features/control_panel/fault_settings_notifier.dart';
import 'package:pokemon_team_builder/features/control_panel/retry_log.dart';

import '../support/fake_transport.dart';

/// Tests the networking stack exactly as the app assembles it, with only the
/// real network swapped for a fake transport.
void main() {
  final url = Uri.parse('https://example.test/thing');

  ProviderContainer containerWith(FakeTransport transport) {
    final container = ProviderContainer(
      overrides: [httpTransportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a request flows through the whole stack to the transport', () {
    fakeAsync((async) {
      final transport = FakeTransport([
        okJson({'name': 'eevee'}),
      ]);
      final client = containerWith(transport).read(apiClientProvider);

      final result = settle(async, client.getJson(url));

      expect(result.valueOrNull, {'name': 'eevee'});
      expect(transport.calls, [url]);
    });
  });

  test('a repeated request is answered from the cache', () {
    fakeAsync((async) {
      final transport = FakeTransport([
        okJson({'name': 'eevee'}),
      ]);
      final client = containerWith(transport).read(apiClientProvider);

      settle(async, client.getJson(url));
      final again = settle(async, client.getJson(url));

      expect(again.valueOrNull, {'name': 'eevee'});
      expect(transport.calls, hasLength(1));
    });
  });

  test('a brief outage is retried and the caller gets the answer', () {
    fakeAsync((async) {
      final transport = FakeTransport([status(503), okJson('back')]);
      final client = containerWith(transport).read(apiClientProvider);

      final result = settle(async, client.getJson(url));

      expect(result.valueOrNull, 'back');
      expect(transport.calls, hasLength(2));
    });
  });

  test('a missing resource is reported once, without retries', () {
    fakeAsync((async) {
      final transport = FakeTransport([status(404)]);
      final client = containerWith(transport).read(apiClientProvider);

      final result = settle(async, client.getJson(url));

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(transport.calls, hasLength(1));
    });
  });

  group('the retry log', () {
    test('starts empty', () {
      final container = containerWith(FakeTransport());

      expect(container.read(retryLogProvider), isEmpty);
    });

    test('notes each retry as the stack makes it', () {
      fakeAsync((async) {
        final transport = FakeTransport([status(503), status(503), okJson(1)]);
        final container = containerWith(transport);

        settle(async, container.read(apiClientProvider).getJson(url));

        final log = container.read(retryLogProvider);
        expect(log, hasLength(2));
        // Newest first: the second failed attempt, then the first.
        expect([for (final event in log) event.failedAttempt], [2, 1]);
        expect(log.first.url, url);
        expect(log.first.failure, isA<ServerFailure>());
      });
    });

    test('has nothing to say about a request that works first time', () {
      fakeAsync((async) {
        final container = containerWith(FakeTransport([okJson(1)]));

        settle(async, container.read(apiClientProvider).getJson(url));

        expect(container.read(retryLogProvider), isEmpty);
      });
    });

    test('does not log a failure that is not retried', () {
      fakeAsync((async) {
        final container = containerWith(FakeTransport([status(404)]));

        settle(async, container.read(apiClientProvider).getJson(url));

        expect(container.read(retryLogProvider), isEmpty);
      });
    });
  });

  group('the cache', () {
    test('is the one the app uses, so clearing it forces a new request', () {
      fakeAsync((async) {
        final transport = FakeTransport([okJson('first'), okJson('second')]);
        final container = containerWith(transport);
        final client = container.read(apiClientProvider);

        settle(async, client.getJson(url));
        expect(settle(async, client.getJson(url)).valueOrNull, 'first');
        expect(transport.calls, hasLength(1));

        container.read(apiCacheProvider).clear();

        expect(settle(async, client.getJson(url)).valueOrNull, 'second');
        expect(transport.calls, hasLength(2));
      });
    });

    test('is the same object as the client the app asks for', () {
      final container = containerWith(FakeTransport());

      expect(
        container.read(apiClientProvider),
        same(container.read(apiCacheProvider)),
      );
    });
  });

  group('fault levers', () {
    test('reach the stack and take effect live', () {
      fakeAsync((async) {
        final transport = FakeTransport();
        final container = containerWith(transport);
        final client = container.read(apiClientProvider);

        container
            .read(faultSettingsProvider.notifier)
            .update(const FaultSettings(failureRate: 1));
        final failed = settle(async, client.getJson(url));
        expect(failed.failureOrNull, isA<ServerFailure>());
        expect(transport.calls, isEmpty, reason: 'faults replace the call');

        container
            .read(faultSettingsProvider.notifier)
            .update(FaultSettings.none);
        final recovered = settle(async, client.getJson(url));
        expect(recovered, isA<Ok<Object?>>());
        expect(transport.calls, hasLength(1));
      });
    });

    test('the offline switch surfaces as an offline failure', () {
      fakeAsync((async) {
        final container = containerWith(FakeTransport());
        container
            .read(faultSettingsProvider.notifier)
            .update(const FaultSettings(offline: true));

        final result = settle(
          async,
          container.read(apiClientProvider).getJson(url),
        );

        expect(result.failureOrNull, isA<OfflineFailure>());
      });
    });

    test('changing a lever does not rebuild the stack', () {
      final container = containerWith(FakeTransport());
      final before = container.read(apiClientProvider);

      container
          .read(faultSettingsProvider.notifier)
          .update(const FaultSettings(latency: Duration(seconds: 1)));

      expect(container.read(apiClientProvider), same(before));
    });
  });
}
