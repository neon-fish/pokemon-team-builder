import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/data/http/http_transport.dart';

/// A [HttpTransport] that plays back a script of responses and exceptions, then
/// repeats [fallback] once the script runs out. Records every request.
class FakeTransport implements HttpTransport {
  FakeTransport([
    Iterable<Object> script = const [],
    this.fallback = const TransportResponse(statusCode: 200, body: '{}'),
  ]) : _script = Queue.of(script);

  final Queue<Object> _script;
  final TransportResponse fallback;
  final List<Uri> calls = [];

  @override
  Future<TransportResponse> get(Uri url) async {
    calls.add(url);
    if (_script.isEmpty) return fallback;
    final next = _script.removeFirst();
    return switch (next) {
      TransportResponse() => next,
      Exception() => throw next,
      _ => throw ArgumentError('Bad script entry: $next'),
    };
  }
}

/// A 200 response carrying [json].
TransportResponse okJson(Object? json) =>
    TransportResponse(statusCode: 200, body: jsonEncode(json));

/// A response with the given status and no body.
TransportResponse status(int code, {Map<String, String> headers = const {}}) =>
    TransportResponse(statusCode: code, headers: headers);

/// A [Random] that always returns [value] from [nextDouble].
class FixedRandom implements Random {
  FixedRandom([this.value = 1.0]);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => value >= 0.5;

  @override
  int nextInt(int max) => min(max - 1, (value * max).floor());
}

/// Starts [future], advances fake time by [elapse], and returns its result.
/// Fails the test if the future has not completed by then.
T settle<T>(
  FakeAsync async,
  Future<T> future, {
  Duration elapse = const Duration(minutes: 10),
}) {
  T? value;
  var done = false;
  unawaited(
    future.then((v) {
      value = v;
      done = true;
    }),
  );
  async.elapse(elapse);
  expect(done, isTrue, reason: 'future did not complete in $elapse');
  return value as T;
}
