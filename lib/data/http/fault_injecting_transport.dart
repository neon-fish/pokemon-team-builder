import 'dart:async';
import 'dart:math';

import 'package:pokemon_team_builder/data/http/fault_settings.dart';
import 'package:pokemon_team_builder/data/http/http_transport.dart';

/// Wraps a real [HttpTransport] and misbehaves on demand.
///
/// Injected at the transport level so that a simulated 429 or truncated body
/// travels through exactly the same decoding, retry and caching code as a real
/// one. [settings] is read on every request, so the control panel can change
/// behaviour live.
class FaultInjectingTransport implements HttpTransport {
  FaultInjectingTransport(
    this._inner, {
    required this._settings,
    Random? random,
  }) : _random = random ?? Random();

  final HttpTransport _inner;
  final FaultSettings Function() _settings;
  final Random _random;

  @override
  Future<TransportResponse> get(Uri url) async {
    final settings = _settings();

    if (settings.latency > Duration.zero) {
      await Future<void>.delayed(settings.latency);
    }
    if (settings.offline) {
      throw const TransportException('Simulated: offline');
    }

    final fault = _chooseFault(settings);
    switch (fault) {
      case null:
        return _inner.get(url);
      case FaultKind.offline:
        throw const TransportException('Simulated: connection lost');
      case FaultKind.timeout:
        // Never completes; the client's own timeout is what ends the request.
        return Completer<TransportResponse>().future;
      case FaultKind.serverError:
        return const TransportResponse(statusCode: 503);
      case FaultKind.rateLimited:
        return TransportResponse(
          statusCode: 429,
          headers: {'retry-after': '${settings.retryAfter.inSeconds}'},
        );
      case FaultKind.truncatedJson:
        final real = await _inner.get(url);
        return TransportResponse(
          statusCode: real.statusCode,
          headers: real.headers,
          body: real.body.substring(0, real.body.length ~/ 2),
        );
      case FaultKind.wrongShape:
        return const TransportResponse(
          statusCode: 200,
          body: '{"unexpected":"shape"}',
        );
    }
  }

  FaultKind? _chooseFault(FaultSettings settings) {
    if (settings.failureRate <= 0 || settings.kinds.isEmpty) return null;
    if (_random.nextDouble() >= settings.failureRate) return null;
    return settings.kinds.elementAt(_random.nextInt(settings.kinds.length));
  }
}
