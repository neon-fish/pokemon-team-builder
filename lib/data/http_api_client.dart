import 'dart:async';
import 'dart:convert';

import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/http/http_transport.dart';

/// Turns raw HTTP responses into [Result]s: applies the timeout, maps status
/// codes to [ApiFailure]s and decodes JSON.
class HttpApiClient implements ApiClient {

  HttpApiClient(this._transport, {this.timeout = const Duration(seconds: 10)});

  final HttpTransport _transport;

  /// How long to wait for a response before giving up with [TimeoutFailure].
  final Duration timeout;

  @override
  Future<Result<Object?>> getJson(Uri url) async {
    final TransportResponse response;
    try {
      // Known limitation: a Dart future cannot be cancelled, so after a timeout the underlying request carries on and its result is discarded.
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
      // Also catches 1xx and 3xx, which is a slightly misleading label, but the browser follows redirects so they should not occur in practice.
      _ => Err(ClientErrorFailure(status)),
    };
  }

  Result<Object?> _decode(String body) {
    // An empty body, including a 204, counts as malformed: every endpoint we use is expected to return JSON.
    if (body.trim().isEmpty) {
      return const Err(MalformedResponseFailure('Empty response body'));
    }
    try {
      // Decodes on the main thread. Fine for now; measure before optimising, since web has no true background isolates to move it to.
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
