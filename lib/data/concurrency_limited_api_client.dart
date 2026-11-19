import 'dart:async';
import 'dart:collection';

import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';

/// Caps the number of requests in flight. Extra requests wait their turn in
/// first-in, first-out order.
///
/// This keeps a fan-out (one detail request per Pokémon) from flooding the
/// browser or the API. Placed outside the retry layer, a request keeps its slot
/// while it backs off, which also eases pressure on a struggling server.
class ConcurrencyLimitedApiClient implements ApiClient {
  ConcurrencyLimitedApiClient(this._inner, {this.limit = 6})
    : assert(limit >= 1);

  final ApiClient _inner;
  final int limit;

  int _running = 0;
  final Queue<Completer<void>> _waiting = Queue();

  @override
  Future<Result<Object?>> getJson(Uri url) async {
    await _acquire();
    try {
      return await _inner.getJson(url);
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_running < limit) {
      _running++;
      return Future.value();
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    return turn.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      // Hand the slot straight to the next in line; the count is unchanged.
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
  }
}
