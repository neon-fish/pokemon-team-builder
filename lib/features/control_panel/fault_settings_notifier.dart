import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/data/http/fault_settings.dart';

/// Holds the current fault-injection levers. The control panel changes them;
/// the fault injector reads the latest value on every request.
///
/// Not saved: after a reload everything is back to normal, so a lever left on
/// cannot make the next visit look broken.
class FaultSettingsNotifier extends Notifier<FaultSettings> {
  @override
  FaultSettings build() => FaultSettings.none;

  /// Replaces all the levers at once.
  void update(FaultSettings settings) => state = settings;

  /// Delay added to every request.
  void setLatency(Duration latency) => state = state.copyWith(latency: latency);

  /// Share of requests (0 to 1) that fail, with one of the chosen kinds.
  void setFailureRate(double rate) =>
      state = state.copyWith(failureRate: rate.clamp(0, 1));

  /// How long a simulated "too many requests" tells the app to wait.
  void setRetryAfter(Duration retryAfter) =>
      state = state.copyWith(retryAfter: retryAfter);

  /// Fails every request as if there were no connection.
  void setOffline({required bool offline}) =>
      state = state.copyWith(offline: offline);

  /// Adds [kind] to the failures that may happen, or removes it if it is
  /// already there. At least one kind always stays: with none chosen, a failure
  /// rate would silently do nothing.
  void toggleKind(FaultKind kind) {
    final kinds = {...state.kinds};
    if (kinds.contains(kind)) {
      if (kinds.length == 1) return;
      kinds.remove(kind);
    } else {
      kinds.add(kind);
    }
    state = state.copyWith(kinds: kinds);
  }

  /// Back to normal: no delay, no failures, online.
  void reset() => state = FaultSettings.none;
}

final faultSettingsProvider =
    NotifierProvider<FaultSettingsNotifier, FaultSettings>(
      FaultSettingsNotifier.new,
    );
