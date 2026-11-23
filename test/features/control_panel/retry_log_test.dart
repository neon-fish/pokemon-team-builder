import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/data/retrying_api_client.dart';
import 'package:pokemon_team_builder/features/control_panel/retry_log.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  RetryEvent event(int attempt) => RetryEvent(
    url: Uri.parse('https://example.test/thing'),
    failedAttempt: attempt,
    failure: const ServerFailure(503),
    delay: const Duration(milliseconds: 500),
  );

  List<int> attempts() => [
    for (final e in container.read(retryLogProvider)) e.failedAttempt,
  ];

  test('starts empty', () {
    expect(container.read(retryLogProvider), isEmpty);
  });

  test('lists the newest first', () {
    final log = container.read(retryLogProvider.notifier);

    log
      ..add(event(1))
      ..add(event(2))
      ..add(event(3));

    expect(attempts(), [3, 2, 1]);
  });

  test('keeps only the most recent entries', () {
    final log = container.read(retryLogProvider.notifier);

    for (var i = 1; i <= RetryLogNotifier.maxEntries + 10; i++) {
      log.add(event(i));
    }

    expect(attempts(), hasLength(RetryLogNotifier.maxEntries));
    // The newest is kept; the oldest ten are gone.
    expect(attempts().first, RetryLogNotifier.maxEntries + 10);
    expect(attempts().last, 11);
  });

  test('can be cleared', () {
    final log = container.read(retryLogProvider.notifier)..add(event(1));

    log.clear();

    expect(container.read(retryLogProvider), isEmpty);
  });
}
