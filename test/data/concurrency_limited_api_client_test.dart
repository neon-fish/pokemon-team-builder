import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/concurrency_limited_api_client.dart';

/// An [ApiClient] whose requests stay in flight until the test completes them.
class _GatedClient implements ApiClient {
  final started = <Uri>[];
  final _gates = <Completer<Result<Object?>>>[];
  int active = 0;
  int maxActive = 0;

  @override
  Future<Result<Object?>> getJson(Uri url) async {
    started.add(url);
    active++;
    maxActive = max(maxActive, active);
    final gate = Completer<Result<Object?>>();
    _gates.add(gate);
    try {
      return await gate.future;
    } finally {
      active--;
    }
  }

  /// Finishes the oldest unfinished request.
  void finishNext() => _gates.removeAt(0).complete(const Ok(null));

  void failNext() => _gates.removeAt(0).completeError(StateError('boom'));
}

void main() {
  Uri uri(int i) => Uri.parse('https://example.test/$i');

  test('never runs more than the limit at once', () async {
    final inner = _GatedClient();
    final client = ConcurrencyLimitedApiClient(inner, limit: 2);

    final futures = [for (var i = 0; i < 5; i++) client.getJson(uri(i))];
    await pumpEventQueue();
    expect(inner.started, [uri(0), uri(1)]);

    while (inner.started.length < 5 || inner.active > 0) {
      inner.finishNext();
      await pumpEventQueue();
    }

    expect(inner.maxActive, 2);
    expect(inner.started, [for (var i = 0; i < 5; i++) uri(i)], reason: 'FIFO');
    expect(await Future.wait(futures), everyElement(isA<Ok<Object?>>()));
  });

  test('starts the next request as soon as one finishes', () async {
    final inner = _GatedClient();
    final client = ConcurrencyLimitedApiClient(inner, limit: 1);

    unawaited(client.getJson(uri(0)));
    unawaited(client.getJson(uri(1)));
    await pumpEventQueue();
    expect(inner.started, [uri(0)]);

    inner.finishNext();
    await pumpEventQueue();
    expect(inner.started, [uri(0), uri(1)]);
  });

  test('an exception releases the slot so later requests still run', () async {
    final inner = _GatedClient();
    final client = ConcurrencyLimitedApiClient(inner, limit: 1);

    final first = client.getJson(uri(0));
    final second = client.getJson(uri(1));
    await pumpEventQueue();

    inner.failNext();
    await expectLater(first, throwsStateError);
    await pumpEventQueue();

    expect(inner.started, [uri(0), uri(1)]);
    inner.finishNext();
    expect(await second, isA<Ok<Object?>>());
  });

  test('limit must be at least 1', () {
    expect(
      () => ConcurrencyLimitedApiClient(_GatedClient(), limit: 0),
      throwsAssertionError,
    );
  });
}
