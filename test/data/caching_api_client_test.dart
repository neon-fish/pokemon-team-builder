import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/caching_api_client.dart';

import '../support/fake_api_client.dart';

void main() {
  final url = Uri.parse('https://example.test/pokemon/1');
  final other = Uri.parse('https://example.test/pokemon/2');

  const ttl = Duration(minutes: 10);
  const staleFor = Duration(hours: 1);

  // The test owns the clock: move `time` forward to make entries age.
  late DateTime time;
  late FakeApiClient inner;
  late CachingApiClient cache;

  /// Answers 'v1' on the first call for a URL, 'v2' on the second, and so on.
  Result<Object?> Function(Uri) numbered() {
    final counts = <Uri, int>{};
    return (url) {
      final n = (counts[url] ?? 0) + 1;
      counts[url] = n;
      return Ok('v$n');
    };
  }

  void build({Result<Object?> Function(Uri)? respond, int maxEntries = 200}) {
    inner = FakeApiClient(respond ?? numbered());
    cache = CachingApiClient(
      inner,
      ttl: ttl,
      staleFor: staleFor,
      maxEntries: maxEntries,
      now: () => time,
    );
  }

  setUp(() {
    time = DateTime(2026);
    build();
  });

  group('fresh entries', () {
    test('the second request is served without calling the network', () async {
      await cache.getJson(url);
      final second = await cache.getJson(url);

      expect(second.valueOrNull, 'v1');
      expect(inner.calls, [url]);
    });

    test('different URLs are cached separately', () async {
      await cache.getJson(url);
      await cache.getJson(other);

      expect(inner.calls, [url, other]);
    });

    test('still fresh just before the time-to-live runs out', () async {
      await cache.getJson(url);
      time = time.add(ttl - const Duration(seconds: 1));
      await cache.getJson(url);

      expect(inner.calls, hasLength(1));
    });
  });

  group('stale entries', () {
    test('are returned at once, and refreshed for next time', () async {
      await cache.getJson(url);
      time = time.add(ttl);

      final stale = await cache.getJson(url);
      expect(stale.valueOrNull, 'v1', reason: 'the caller gets the old data');

      // Let the background refresh finish.
      await Future<void>.delayed(Duration.zero);
      expect(inner.calls, hasLength(2));

      final refreshed = await cache.getJson(url);
      expect(refreshed.valueOrNull, 'v2');
      expect(inner.calls, hasLength(2), reason: 'the new entry is fresh');
    });

    test('a failed refresh keeps the old answer', () async {
      var failing = false;
      build(
        respond: (_) =>
            failing ? const Err(ServerFailure(503)) : const Ok('original'),
      );
      await cache.getJson(url);
      time = time.add(ttl);
      failing = true;

      final stale = await cache.getJson(url);
      await Future<void>.delayed(Duration.zero);
      final again = await cache.getJson(url);

      expect(stale.valueOrNull, 'original');
      expect(again.valueOrNull, 'original');
    });

    test(
      'are fetched properly once the stale window has also passed',
      () async {
        await cache.getJson(url);
        time = time.add(ttl + staleFor);

        final result = await cache.getJson(url);

        expect(
          result.valueOrNull,
          'v2',
          reason: 'the caller waits for new data',
        );
      },
    );
  });

  group('failures', () {
    test('are not cached', () async {
      build(respond: (_) => const Err(OfflineFailure()));

      final first = await cache.getJson(url);
      final second = await cache.getJson(url);

      expect(first.failureOrNull, isA<OfflineFailure>());
      expect(second.failureOrNull, isA<OfflineFailure>());
      expect(inner.calls, hasLength(2));
    });
  });

  group('de-duplication', () {
    test('simultaneous requests for one URL share a single call', () async {
      final slow = _ManualClient();
      final dedupe = CachingApiClient(slow, now: () => time);

      final first = dedupe.getJson(url);
      final second = dedupe.getJson(url);
      slow.completeAll(const Ok('shared'));

      expect((await first).valueOrNull, 'shared');
      expect((await second).valueOrNull, 'shared');
      expect(slow.calls, hasLength(1));
    });

    test('a failed shared call is shared too, then forgotten', () async {
      final slow = _ManualClient();
      final dedupe = CachingApiClient(slow, now: () => time);

      final first = dedupe.getJson(url);
      final second = dedupe.getJson(url);
      slow.completeAll(const Err(TimeoutFailure()));

      expect((await first).failureOrNull, isA<TimeoutFailure>());
      expect((await second).failureOrNull, isA<TimeoutFailure>());

      // The failure was not remembered: a new request tries again.
      final third = dedupe.getJson(url);
      slow.completeAll(const Ok('ok'));
      expect((await third).valueOrNull, 'ok');
      expect(slow.calls, hasLength(2));
    });
  });

  group('size limit', () {
    test('the oldest entry is dropped when the limit is passed', () async {
      build(maxEntries: 2);
      final third = Uri.parse('https://example.test/pokemon/3');

      await cache.getJson(url);
      await cache.getJson(other);
      await cache.getJson(third); // pushes `url` out
      expect(inner.calls, hasLength(3));

      await cache.getJson(other); // still cached
      await cache.getJson(third); // still cached
      expect(inner.calls, hasLength(3));

      await cache.getJson(url); // was dropped, so it is fetched again
      expect(inner.calls, hasLength(4));
    });
  });
}

/// An [ApiClient] whose calls stay pending until the test completes them.
class _ManualClient implements ApiClient {
  final List<Uri> calls = [];
  final List<Completer<Result<Object?>>> _pending = [];

  @override
  Future<Result<Object?>> getJson(Uri url) {
    calls.add(url);
    final completer = Completer<Result<Object?>>();
    _pending.add(completer);
    return completer.future;
  }

  void completeAll(Result<Object?> result) {
    for (final completer in _pending) {
      completer.complete(result);
    }
    _pending.clear();
  }
}
