import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/data/http/fault_settings.dart';
import 'package:pokemon_team_builder/data/retrying_api_client.dart';
import 'package:pokemon_team_builder/features/control_panel/control_panel.dart';
import 'package:pokemon_team_builder/features/control_panel/fault_settings_notifier.dart';
import 'package:pokemon_team_builder/features/control_panel/retry_log.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';

import '../../support/counting_transport.dart';
import '../../support/in_memory_key_value_store.dart';

void main() {
  late CountingTransport transport;

  setUp(() => transport = CountingTransport());

  /// Shows the panel, over the app's real networking stack with a fake network.
  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpTransportProvider.overrideWithValue(transport),
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const Scaffold(body: ControlPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ControlPanel)));

  FaultSettings settings(WidgetTester tester) =>
      containerOf(tester).read(faultSettingsProvider);

  /// The panel is a long, scrolling list, and a list builds only what is on
  /// screen (plus a little beyond). So to use something further down, scroll
  /// until it is built, then until it is properly in view.
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

  // The sliders are found by key, not by position, so reordering the levers
  // cannot silently point a test at the wrong one.
  final delaySlider = find.byKey(const Key('delay-slider'));
  final failureSlider = find.byKey(const Key('failure-rate-slider'));
  final retryAfterSlider = find.byKey(const Key('retry-after-slider'));

  RetryEvent retry(int attempt) => RetryEvent(
    url: Uri.parse('https://pokeapi.co/api/v2/pokemon/25'),
    failedAttempt: attempt,
    failure: const ServerFailure(503),
    delay: const Duration(milliseconds: 700),
  );

  testWidgets('starts with everything normal', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Simulate problems'), findsOneWidget);
    expect(find.text('No extra delay'), findsOneWidget);
    expect(find.text('No requests fail'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
  });

  group('the delay slider', () {
    testWidgets('sets the delay', (tester) async {
      await pumpPanel(tester);

      // Tapping the middle of the track sets the middle of the range.
      await tester.tap(delaySlider);
      await tester.pumpAndSettle();

      expect(settings(tester).latency, const Duration(milliseconds: 2500));
      expect(find.text('Every request waits 2.5 s first'), findsOneWidget);
    });
  });

  group('the failure controls', () {
    testWidgets('the slider sets the failure rate', (tester) async {
      await pumpPanel(tester);

      await tester.tap(failureSlider);
      await tester.pumpAndSettle();

      expect(settings(tester).failureRate, 0.5);
      expect(
        find.text('50% of requests fail, in one of the ways chosen below'),
        findsOneWidget,
      );
    });

    testWidgets('shows a rate as a whole percentage, rounded not cut', (
      tester,
    ) async {
      await pumpPanel(tester);

      // 0.57 * 100 is 56.99999999999999 in floating point, so cutting off the
      // decimals would say 56%.
      containerOf(tester)
          .read(faultSettingsProvider.notifier)
          .setFailureRate(0.57);
      await tester.pump();

      expect(
        find.text('57% of requests fail, in one of the ways chosen below'),
        findsOneWidget,
      );
    });

    testWidgets('a kind of failure can be chosen and unchosen', (tester) async {
      await pumpPanel(tester);

      await tester.tap(find.text('No answer'));
      await tester.pump();
      expect(settings(tester).kinds, contains(FaultKind.timeout));

      await tester.tap(find.text('No answer'));
      await tester.pump();
      expect(settings(tester).kinds, isNot(contains(FaultKind.timeout)));
    });

    testWidgets('the last kind cannot be unchosen', (tester) async {
      await pumpPanel(tester);

      // Only "Server error" is chosen to begin with.
      await tester.tap(find.text('Server error'));
      await tester.pump();

      expect(settings(tester).kinds, {FaultKind.serverError});
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Server error'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('has a chip for every kind of failure', (tester) async {
      await pumpPanel(tester);

      expect(find.byType(FilterChip), findsNWidgets(FaultKind.values.length));
    });
  });

  group('the "too many requests" wait', () {
    testWidgets('is switched off until that failure is chosen', (tester) async {
      await pumpPanel(tester);
      final before = settings(tester).retryAfter;

      expect(find.textContaining('Choose "Too many requests"'), findsOneWidget);
      // Try to use it: nothing should change.
      await tester.tap(retryAfterSlider, warnIfMissed: false);
      await tester.drag(retryAfterSlider, const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(settings(tester).retryAfter, before);
    });

    testWidgets('can be set once it is chosen', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.text('Too many requests'));
      await tester.pump();

      await tester.tap(retryAfterSlider);
      await tester.pumpAndSettle();

      expect(settings(tester).retryAfter, const Duration(seconds: 5));
    });
  });

  group('the offline switch', () {
    testWidgets('turns the offline lever on and off', (tester) async {
      await pumpPanel(tester);
      await reveal(tester, find.byType(SwitchListTile));

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(settings(tester).offline, isTrue);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(settings(tester).offline, isFalse);
    });
  });

  testWidgets('"Back to normal" resets every lever', (tester) async {
    await pumpPanel(tester);
    containerOf(tester).read(faultSettingsProvider.notifier)
      ..setLatency(const Duration(seconds: 3))
      ..setFailureRate(0.8)
      ..setOffline(offline: true);
    await tester.pump();
    await reveal(tester, find.text('Back to normal'));

    await tester.tap(find.text('Back to normal'));
    await tester.pumpAndSettle();

    expect(settings(tester).latency, Duration.zero);
    expect(settings(tester).failureRate, 0);
    expect(settings(tester).offline, isFalse);
    // Back at the top, the sliders' labels are back to normal too.
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('No extra delay'), findsOneWidget);
    expect(find.text('No requests fail'), findsOneWidget);
  });

  group('the cache', () {
    testWidgets('"Clear cache and reload" asks the API for everything again', (
      tester,
    ) async {
      await pumpPanel(tester);
      final container = containerOf(tester);
      await container.read(pokemonProvider(25).future);
      expect(transport.counts['/api/v2/pokemon/25'], 1);

      await reveal(tester, find.text('Clear cache and reload'));
      await tester.tap(find.text('Clear cache and reload'));
      await container.read(pokemonProvider(25).future);

      expect(transport.counts['/api/v2/pokemon/25'], 2);
    });
  });

  group('the retry log', () {
    testWidgets('explains itself when empty, and Clear is off', (tester) async {
      await pumpPanel(tester);
      await reveal(tester, find.text('Retry log'));

      expect(find.textContaining('Nothing yet'), findsOneWidget);
      final clear = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Clear'),
      );
      expect(clear.onPressed, isNull);
    });

    testWidgets('lists each retry, newest first', (tester) async {
      await pumpPanel(tester);
      containerOf(tester).read(retryLogProvider.notifier)
        ..add(retry(1))
        ..add(retry(2));
      await tester.pump();
      await reveal(tester, find.text('Retry log'));

      expect(find.text('/api/v2/pokemon/25'), findsNWidgets(2));
      expect(find.textContaining('Attempt 1 failed.'), findsOneWidget);
      expect(find.textContaining('Attempt 2 failed.'), findsOneWidget);
      // Newest first: attempt 2 is above attempt 1.
      final second = tester.getTopLeft(find.textContaining('Attempt 2'));
      final first = tester.getTopLeft(find.textContaining('Attempt 1'));
      expect(second.dy, lessThan(first.dy));
    });

    testWidgets('says why it failed and how long it will wait', (tester) async {
      await pumpPanel(tester);
      containerOf(tester).read(retryLogProvider.notifier).add(retry(1));
      await tester.pump();
      await reveal(tester, find.text('Retry log'));

      expect(
        find.text(
          'Attempt 1 failed. PokéAPI is having problems at the moment. '
          'Trying again in 0.7 s.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Clear empties it', (tester) async {
      await pumpPanel(tester);
      containerOf(tester).read(retryLogProvider.notifier).add(retry(1));
      await tester.pump();
      await reveal(tester, find.text('Clear'));

      await tester.tap(find.text('Clear'));
      await tester.pump();

      expect(find.textContaining('Attempt 1'), findsNothing);
      expect(find.textContaining('Nothing yet'), findsOneWidget);
    });
  });

  testWidgets('the close button stays in view however far it is scrolled', (
    tester,
  ) async {
    await pumpPanel(tester);

    await reveal(tester, find.text('Retry log'));

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.text('Simulate problems'), findsOneWidget);
  });

  group('layout', () {
    testWidgets('fits a narrow drawer with a long log at double text size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(344, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPanel(tester);
      final log = containerOf(tester).read(retryLogProvider.notifier);
      for (var i = 1; i <= 5; i++) {
        log.add(retry(i));
      }
      await tester.pump();

      // Scroll through the whole panel in small steps. A list only builds what
      // is on screen, so one big jump would skip the middle and never check it.
      // Any overflow is reported as an exception, so check after each step.
      for (var step = 0; step < 20; step++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'after step $step');
      }
    });
  });
}
