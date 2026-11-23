import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/data/http/fault_settings.dart';
import 'package:pokemon_team_builder/features/control_panel/fault_settings_notifier.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  FaultSettings settings() => container.read(faultSettingsProvider);
  FaultSettingsNotifier notifier() =>
      container.read(faultSettingsProvider.notifier);

  test('starts with no faults', () {
    expect(settings().latency, Duration.zero);
    expect(settings().failureRate, 0);
    expect(settings().offline, isFalse);
  });

  group('each lever', () {
    test('sets the delay, leaving the others alone', () {
      notifier().setFailureRate(0.3);

      notifier().setLatency(const Duration(seconds: 2));

      expect(settings().latency, const Duration(seconds: 2));
      expect(settings().failureRate, 0.3);
    });

    test('sets the failure rate', () {
      notifier().setFailureRate(0.5);

      expect(settings().failureRate, 0.5);
    });

    test('keeps the failure rate between 0 and 1', () {
      notifier().setFailureRate(1.7);
      expect(settings().failureRate, 1);

      notifier().setFailureRate(-0.2);
      expect(settings().failureRate, 0);
    });

    test('sets how long a "too many requests" asks to wait', () {
      notifier().setRetryAfter(const Duration(seconds: 7));

      expect(settings().retryAfter, const Duration(seconds: 7));
    });

    test('switches offline on and off', () {
      notifier().setOffline(offline: true);
      expect(settings().offline, isTrue);

      notifier().setOffline(offline: false);
      expect(settings().offline, isFalse);
    });
  });

  group('choosing the kinds of failure', () {
    test('adds a kind that is not chosen', () {
      notifier().toggleKind(FaultKind.timeout);

      expect(settings().kinds, {FaultKind.serverError, FaultKind.timeout});
    });

    test('removes a kind that is chosen', () {
      notifier().toggleKind(FaultKind.timeout);

      notifier().toggleKind(FaultKind.serverError);

      expect(settings().kinds, {FaultKind.timeout});
    });

    test('never removes the last one', () {
      // Only the server error is chosen to begin with.
      notifier().toggleKind(FaultKind.serverError);

      expect(settings().kinds, {FaultKind.serverError});
    });
  });

  test('reset puts everything back to normal', () {
    notifier()
      ..setLatency(const Duration(seconds: 3))
      ..setFailureRate(0.9)
      ..setOffline(offline: true)
      ..toggleKind(FaultKind.wrongShape);

    notifier().reset();

    expect(settings().latency, Duration.zero);
    expect(settings().failureRate, 0);
    expect(settings().offline, isFalse);
    expect(settings().kinds, FaultSettings.none.kinds);
  });
}
