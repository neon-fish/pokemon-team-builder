import 'dart:async';
import 'dart:convert';

import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/http/http_transport.dart';

/// Turns raw HTTP responses into [Result]s: applies the timeout, maps status
/// codes to [ApiFailure]s and decodes JSON.
class HttpApiClient implements ApiClient {
  HttpApiClient(this._transport, {this.timeout = defaultTimeout});

  /// PokéAPI normally answers in well under a second. Five seconds leaves room
  /// for a slow connection, and keeps the worst case short: with the retry
  /// policy's three attempts, a request that never answers is given up on after
  /// about 16 seconds, not about 31 with a ten-second timeout.
  static const defaultTimeout = Duration(seconds: 5);

  final HttpTransport _transport;

  /// How long to wait for a response before giving up with [TimeoutFailure].
  final Duration timeout;

  @override
  Future<Result<Object?>> getJson(Uri url) async {
    final TransportResponse response;
    try {
      // A Dart future cannot be cancelled, so after a timeout the request
      // carries on and its result is discarded.
      response = await _transport.get(url).timeout(timeout);
    } on TimeoutException {
      return const Err(TimeoutFailure());
    } on TransportException catch (e) {
      return Err(OfflineFailure(e.message));
    }
    return _interpret(response);
  }

  Result<Object?> _interpret(TransportResponse response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return _decode(response.body);
    }
    return switch (status) {
      404 => const Err(NotFoundFailure()),
      429 => Err(
        RateLimitedFailure(
          retryAfter: _parseRetryAfter(response.headers['retry-after']),
        ),
      ),
      >= 500 => Err(ServerFailure(status)),
      // Also 1xx and 3xx, which should not occur: the browser follows redirects.
      _ => Err(ClientErrorFailure(status)),
    };
  }

  Result<Object?> _decode(String body) {
    // An empty body, including a 204, counts as malformed: every endpoint we
    // use returns JSON.
    if (body.trim().isEmpty) {
      return const Err(MalformedResponseFailure('Empty response body'));
    }
    try {
      // Decoded on the main thread. Web has no true background isolate to move
      // it to, so measure before optimising.
      return Ok(jsonDecode(body));
    } on FormatException catch (e) {
      return Err(MalformedResponseFailure('Invalid JSON: ${e.message}'));
    }
  }

  /// Parses the delay-in-seconds form of `Retry-After`. The HTTP-date form is
  /// not supported (treated as absent), which is a known limitation.
  Duration? _parseRetryAfter(String? value) {
    final seconds = int.tryParse(value?.trim() ?? '');
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }
}
