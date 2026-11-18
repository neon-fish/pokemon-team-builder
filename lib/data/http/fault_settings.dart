/// The kinds of failure the fault injector can simulate.
enum FaultKind {
  /// HTTP 503.
  serverError,

  /// HTTP 429 with a `Retry-After` header.
  rateLimited,

  /// The request never completes, so the client's own timeout fires.
  timeout,

  /// No connection at all.
  offline,

  /// A 200 whose JSON body is cut off halfway.
  truncatedJson,

  /// A 200 with valid JSON that is not the shape we expect.
  wrongShape,
}

/// The levers for simulating a misbehaving API. Immutable; the control panel
/// replaces the whole value when a lever moves.
class FaultSettings {
  const FaultSettings({
    this.latency = Duration.zero,
    this.failureRate = 0,
    this.kinds = const {FaultKind.serverError},
    this.offline = false,
    this.retryAfter = const Duration(seconds: 2),
  }) : assert(failureRate >= 0 && failureRate <= 1);

  /// No faults: requests pass straight through.
  static const none = FaultSettings();

  /// Delay added to every request.
  final Duration latency;

  /// Probability (0 to 1) that a request fails with one of [kinds].
  final double failureRate;

  /// Which failures may be chosen when a request is selected to fail.
  final Set<FaultKind> kinds;

  /// Fail every request as if there were no connection.
  final bool offline;

  /// The `Retry-After` value sent with a simulated 429.
  final Duration retryAfter;

  FaultSettings copyWith({
    Duration? latency,
    double? failureRate,
    Set<FaultKind>? kinds,
    bool? offline,
    Duration? retryAfter,
  }) {
    return FaultSettings(
      latency: latency ?? this.latency,
      failureRate: failureRate ?? this.failureRate,
      kinds: kinds ?? this.kinds,
      offline: offline ?? this.offline,
      retryAfter: retryAfter ?? this.retryAfter,
    );
  }
}
