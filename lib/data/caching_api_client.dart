import 'dart:async';

import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';

/// Remembers successful responses in memory, so repeat requests are instant and
/// never reach the network.
///
/// Three behaviours:
///
/// - **Fresh:** an answer younger than [ttl] is returned as it is.
/// - **Stale while revalidating:** an answer older than [ttl] but younger than
///   [ttl] + [staleFor] is still returned straight away, and a refresh runs in
///   the background so the next request gets newer data. The user never waits
///   for a refresh, and a failed refresh just leaves the old answer in place.
/// - **De-duplication:** if the same URL is requested while it is already being
///   fetched, the second caller shares the first caller's request.
///
/// Only successes are stored. A failure is never cached, so the next request
/// tries again.
///
/// Placed outside the concurrency limiter, so cache hits never take a slot.
class CachingApiClient implements ApiClient {
  CachingApiClient(
    this._inner, {
    this.ttl = const Duration(minutes: 10),
    this.staleFor = const Duration(hours: 1),
    this.maxEntries = 200,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ApiClient _inner;
  final Duration ttl;
  final Duration staleFor;

  /// Upper bound on stored responses. When exceeded, the oldest is dropped.
  final int maxEntries;

  /// "What time is it?", injectable so tests can move time themselves.
  final DateTime Function() _now;

  final Map<Uri, _Entry> _entries = {};
  final Map<Uri, Future<Result<Object?>>> _inFlight = {};

  @override
  Future<Result<Object?>> getJson(Uri url) {
    final entry = _entries[url];
    if (entry == null) return _fetch(url);

    final age = _now().difference(entry.storedAt);
    if (age < ttl) {
      return Future.value(Ok(entry.value));
    }
    if (age < ttl + staleFor) {
      // Answer now with the old data, and refresh quietly for next time.
      unawaited(_fetch(url));
      return Future.value(Ok(entry.value));
    }
    return _fetch(url);
  }

  /// Fetches [url], unless the same fetch is already under way.
  Future<Result<Object?>> _fetch(Uri url) {
    final running = _inFlight[url];
    if (running != null) return running;

    final future = _fetchAndStore(url);
    _inFlight[url] = future;
    return future;
  }

  Future<Result<Object?>> _fetchAndStore(Uri url) async {
    try {
      final result = await _inner.getJson(url);
      if (result case Ok<Object?>(:final value)) {
        _store(url, value);
      }
      return result;
    } finally {
      // `remove` hands back the future it removed; we do not need it.
      unawaited(_inFlight.remove(url));
    }
  }

  void _store(Uri url, Object? value) {
    // Remove first so a re-stored URL moves to the back of the line.
    _entries.remove(url);
    _entries[url] = _Entry(value, _now());
    if (_entries.length > maxEntries) {
      // A Dart map remembers insertion order, so the first key is the oldest.
      _entries.remove(_entries.keys.first);
    }
  }
}

class _Entry {
  const _Entry(this.value, this.storedAt);

  final Object? value;
  final DateTime storedAt;
}
