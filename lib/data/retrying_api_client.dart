import 'dart:math';

import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';

/// How [RetryingApiClient] decides whether and when to try again.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 8),
    this.maxRetryAfter = const Duration(seconds: 30),
  }) : assert(maxAttempts >= 1);

  /// Total tries, including the first.
  final int maxAttempts;

  /// Backoff before the second try; doubles each time.
  final Duration baseDelay;

  /// Ceiling for the backoff.
  final Duration maxDelay;

  /// If the server asks us to wait longer than this, give up instead of making
  /// the user stare at a spinner.
  final Duration maxRetryAfter;
}

/// Reported just before a retry waits, for logging and the control panel.
class RetryEvent {
  const RetryEvent({
    required this.url,
    required this.failedAttempt,
    required this.failure,
    required this.delay,
  });

  final Uri url;

  /// The attempt that just failed, starting at 1.
  final int failedAttempt;

  final ApiFailure failure;

  /// How long we will wait before the next attempt.
  final Duration delay;
}

/// Retries transient failures with exponential backoff and jitter, and honours
/// the server's `Retry-After`. Permanent failures are returned immediately.
class RetryingApiClient implements ApiClient {
  RetryingApiClient(
    this._inner, {
    this.policy = const RetryPolicy(),
    Random? random,
    this._onRetry,
  }) : _random = random ?? Random();

  final ApiClient _inner;
  final RetryPolicy policy;
  final Random _random;
  final void Function(RetryEvent event)? _onRetry;

  @override
  Future<Result<Object?>> getJson(Uri url) async {
    var attempt = 1;
    while (true) {
      final result = await _inner.getJson(url);
      if (result case Err<Object?>(failure: final failure)) {
        if (attempt >= policy.maxAttempts || !failure.isTransient) {
          return result;
        }
        final delay = _delayAfter(attempt, failure);
        if (delay == null) return result;
        _onRetry?.call(
          RetryEvent(
            url: url,
            failedAttempt: attempt,
            failure: failure,
            delay: delay,
          ),
        );
        await Future<void>.delayed(delay);
        attempt++;
      } else {
        return result;
      }
    }
  }

  /// How long to wait after [failedAttempt] (counting from 1) before trying
  /// again, or null if we should give up instead.
  Duration? _delayAfter(int failedAttempt, ApiFailure failure) {
    if (failure case RateLimitedFailure(retryAfter: final retryAfter?)) {
      return retryAfter > policy.maxRetryAfter ? null : retryAfter;
    }

    // Exponential backoff, capped: the base delay after the first failure,
    // twice that after the second, and so on. "Equal jitter" (half fixed, half
    // random) spreads out clients retrying together without ever waiting ~0.
    // The exponent is capped so the power cannot grow without bound.
    final exponent = min(failedAttempt - 1, 20);
    final uncapped = policy.baseDelay.inMicroseconds * pow(2, exponent);
    final capped = min(uncapped, policy.maxDelay.inMicroseconds);
    final jittered = capped * (0.5 + 0.5 * _random.nextDouble());
    return Duration(microseconds: jittered.round());
  }
}
