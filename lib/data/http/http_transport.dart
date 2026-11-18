/// The lowest layer: sends a GET and returns whatever came back, with no
/// interpretation. Interpretation (status codes, JSON) happens one layer up, so
/// that anything injected here, such as a fake 429 or a truncated body, is
/// handled by exactly the same code as the real thing.
abstract interface class HttpTransport {
  /// Performs a GET.
  ///
  /// Returns a [TransportResponse] for any HTTP status, including errors.
  /// Throws [TransportException] if no response could be obtained at all.
  Future<TransportResponse> get(Uri url);
}

/// A raw HTTP response.
class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    this.headers = const {},
    this.body = '',
  });

  final int statusCode;

  /// Header names must be lower case.
  final Map<String, String> headers;

  final String body;
}

/// No response could be obtained (connectivity, DNS, blocked by the browser).
class TransportException implements Exception {
  const TransportException(this.message);

  final String message;

  @override
  String toString() => 'TransportException: $message';
}
