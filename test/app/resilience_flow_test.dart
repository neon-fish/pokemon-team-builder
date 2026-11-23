import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/app.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/data/http/fault_settings.dart';
import 'package:pokemon_team_builder/features/control_panel/control_panel.dart';
import 'package:pokemon_team_builder/features/control_panel/fault_settings_notifier.dart';
import 'package:pokemon_team_builder/features/control_panel/retry_log.dart';
import 'package:pokemon_team_builder/features/team/team_slot.dart';

import '../support/counting_transport.dart';
import '../support/in_memory_key_value_store.dart';
import '../support/screen_size.dart';

/// The demonstration the control panel exists for, run end to end: the whole
/// app, over its real networking stack (faults, retries, limits, cache) and a
/// fake network.
void main() {
  late CountingTransport transport;
  late ProviderContainer container;

  setUp(() => transport = CountingTransport());

  Future<void> pumpApp(WidgetTester tester) async {
    useScreenSize(tester, desktopScreen);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpTransportProvider.overrideWithValue(transport),
          keyValueStoreProvider.overrideWithValue(
            InMemoryKeyValueStore({'team': '{"ids":[25]}'}),
          ),
        ],
        child: const PokemonTeamBuilderApp(),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(PokemonTeamBuilderApp)),
    );
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Simulate problems'));
    await tester.pumpAndSettle();
  }

  Future<void> closePanel(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  }

  /// Scrolls the panel until [finder] is properly in view.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.descendant(
        of: find.byType(ControlPanel),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Finder inTeam(Finder finder) =>
      find.descendant(of: find.byType(TeamSlot), matching: finder);

  testWidgets('the app starts normally, with an empty retry log', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Pikachu'), findsWidgets);
    expect(container.read(retryLogProvider), isEmpty);
  });

  testWidgets('turning failures up and reloading shows the app coping', (
    tester,
  ) async {
    await pumpApp(tester);
    await openPanel(tester);

    // Every request now fails with a server error.
    container.read(faultSettingsProvider.notifier).setFailureRate(1);
    await reveal(tester, find.text('Clear cache and reload'));
    await tester.tap(find.text('Clear cache and reload'));
    // Long enough for every retry's wait to pass (they total under 2 seconds).
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    // The app did not crash, and did not give up at the first failure: each
    // request was tried three times, and each of the two waits is in the log.
    expect(tester.takeException(), isNull);
    final log = container.read(retryLogProvider);
    expect(log, isNotEmpty);
    final forPikachu = [
      for (final event in log)
        if (event.url.path.endsWith('/pokemon/25')) event.failedAttempt,
    ];
    expect(forPikachu, [2, 1]);

    // Where it matters, it says so, and offers a way out.
    await closePanel(tester);
    expect(inTeam(find.text('Could not load #25')), findsOneWidget);
    expect(inTeam(find.text('Try again')), findsOneWidget);
    expect(
      find.textContaining('The type chart could not be loaded'),
      findsOneWidget,
    );
  });

  testWidgets('going back to normal lets the app recover', (tester) async {
    await pumpApp(tester);
    await openPanel(tester);
    container.read(faultSettingsProvider.notifier).setFailureRate(1);
    await reveal(tester, find.text('Clear cache and reload'));
    await tester.tap(find.text('Clear cache and reload'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    // Back to normal, then ask again from the slot's own button.
    await reveal(tester, find.text('Back to normal'));
    await tester.tap(find.text('Back to normal'));
    await tester.pumpAndSettle();
    await closePanel(tester);
    await tester.tap(inTeam(find.text('Try again')));
    await tester.pumpAndSettle();

    expect(inTeam(find.text('Pikachu')), findsOneWidget);
    expect(inTeam(find.text('Could not load #25')), findsNothing);
  });

  testWidgets('an unexpected response can be retried once things are normal', (
    tester,
  ) async {
    await pumpApp(tester);
    await openPanel(tester);
    // Every request now answers with valid JSON that is not what was asked for.
    container.read(faultSettingsProvider.notifier)
      ..toggleKind(FaultKind.wrongShape)
      ..toggleKind(FaultKind.serverError)
      ..setFailureRate(1);
    await reveal(tester, find.text('Clear cache and reload'));
    await tester.tap(find.text('Clear cache and reload'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    await closePanel(tester);
    expect(inTeam(find.text('Could not load #25')), findsOneWidget);
    expect(
      inTeam(find.textContaining('did not expect')),
      findsOneWidget,
      reason: 'the reason is the unexpected response, not a server error',
    );

    await openPanel(tester);
    await reveal(tester, find.text('Back to normal'));
    await tester.tap(find.text('Back to normal'));
    await tester.pumpAndSettle();
    await closePanel(tester);
    await tester.tap(inTeam(find.text('Try again')));
    await tester.pumpAndSettle();

    // The retry reached the API instead of being handed the bad answer again.
    expect(inTeam(find.text('Pikachu')), findsOneWidget);
    expect(inTeam(find.text('Could not load #25')), findsNothing);
  });

  testWidgets('the retry log in the panel names the request and the wait', (
    tester,
  ) async {
    await pumpApp(tester);
    await openPanel(tester);
    container.read(faultSettingsProvider.notifier).setFailureRate(1);
    await reveal(tester, find.text('Clear cache and reload'));
    await tester.tap(find.text('Clear cache and reload'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Retry log'));

    expect(find.text('/api/v2/pokemon/25'), findsWidgets);
    expect(find.textContaining('Attempt 1 failed.'), findsWidgets);
    expect(find.textContaining('Trying again in'), findsWidgets);
  });

  testWidgets('a slow network is waited for, not mistaken for a failure', (
    tester,
  ) async {
    await pumpApp(tester);
    await openPanel(tester);
    container
        .read(faultSettingsProvider.notifier)
        .setLatency(const Duration(seconds: 2));
    await reveal(tester, find.text('Clear cache and reload'));
    await tester.tap(find.text('Clear cache and reload'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    // Two seconds is well inside the five-second timeout: no retries at all.
    expect(container.read(retryLogProvider), isEmpty);
    await closePanel(tester);
    expect(inTeam(find.text('Pikachu')), findsOneWidget);
  });
}
