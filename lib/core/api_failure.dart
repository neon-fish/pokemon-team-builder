/// Everything that can go wrong when talking to the API, as a closed set.
///
/// The UI and state layers switch exhaustively over this type, so a new kind of
/// failure cannot be added without every consumer deciding how to handle it.
sealed class ApiFailure {
  const ApiFailure();

  /// Whether trying again later might succeed.
  ///
  /// Used by the retry layer. Permanent failures (not found, malformed data,
  /// rejected requests) are never retried.
  bool get isTransient;
}

/// The network could not be reached (no connection, DNS failure, blocked
/// request).
final class OfflineFailure extends ApiFailure {
  const OfflineFailure([this.detail]);

  final String? detail;

  @override
  bool get isTransient => true;

  @override
  String toString() => 'OfflineFailure(${detail ?? ''})';
}

/// The request took longer than the allowed time.
final class TimeoutFailure extends ApiFailure {
  const TimeoutFailure();

  @override
  bool get isTransient => true;

  @override
  String toString() => 'TimeoutFailure()';
}

/// The server asked us to slow down (HTTP 429).
final class RateLimitedFailure extends ApiFailure {
  const RateLimitedFailure({this.retryAfter});

  /// How long the server asked us to wait, if it said.
  ///
  /// Note: browsers only expose `Retry-After` to scripts when the server lists
  /// it in `Access-Control-Expose-Headers`, so this is often null on web.
  final Duration? retryAfter;

  @override
  bool get isTransient => true;

  @override
  String toString() => 'RateLimitedFailure(retryAfter: $retryAfter)';
}

/// The server failed (HTTP 5xx).
final class ServerFailure extends ApiFailure {
  const ServerFailure(this.statusCode);

  final int statusCode;

  @override
  bool get isTransient => true;

  @override
  String toString() => 'ServerFailure($statusCode)';
}

/// The thing asked for does not exist (HTTP 404).
final class NotFoundFailure extends ApiFailure {
  const NotFoundFailure();

  @override
  bool get isTransient => false;

  @override
  String toString() => 'NotFoundFailure()';
}

/// The server rejected the request (HTTP 4xx other than 404 and 429).
final class ClientErrorFailure extends ApiFailure {
  const ClientErrorFailure(this.statusCode);

  final int statusCode;

  @override
  bool get isTransient => false;

  @override
  String toString() => 'ClientErrorFailure($statusCode)';
}

/// The server answered, but the body was not usable (not JSON, empty, or not
/// the shape we expected).
final class MalformedResponseFailure extends ApiFailure {
  const MalformedResponseFailure(this.detail);

  final String detail;

  @override
  bool get isTransient => false;

  @override
  String toString() => 'MalformedResponseFailure($detail)';
}
