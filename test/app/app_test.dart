import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/app.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_notifier.dart';

import '../support/fake_api_client.dart';
import '../support/fixtures.dart';
import '../support/in_memory_key_value_store.dart';
import '../support/screen_size.dart';

void main() {
  /// The pretend outside world: a fake API (answering `null` unless a [client]
  /// is given) and in-memory storage (empty unless a [store] is given).
  List<Override> fakeWorld({
    FakeApiClient? client,
    InMemoryKeyValueStore? store,
  }) {
    return [
      apiClientProvider.overrideWithValue(
        client ?? FakeApiClient((_) => const Ok(null)),
      ),
      keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
    ];
  }

  /// Shows the whole app over [fakeWorld].
  Future<void> pumpAppWith(
    WidgetTester tester, {
    FakeApiClient? client,
    InMemoryKeyValueStore? store,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: fakeWorld(client: client, store: store),
        child: const PokemonTeamBuilderApp(),
      ),
    );
  }

  testWidgets('starts with the search, ready to use', (tester) async {
    useScreenSize(tester, desktopScreen);
    final client = FakeApiClient(
      (url) => url.path.endsWith('/pokemon')
          ? Ok(loadFixture('pokemon_index.json'))
          : const Err(NotFoundFailure()),
    );
    await pumpAppWith(tester, client: client);
    await tester.pumpAndSettle();

    expect(find.text('Pokémon Team Builder'), findsOneWidget);
    expect(find.text('Search by name or number'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
  });

  testWidgets('shows a message instead of crashing when nothing loads', (
    tester,
  ) async {
    useScreenSize(tester, desktopScreen);
    final client = FakeApiClient((_) => const Err(OfflineFailure('no wifi')));
    await pumpAppWith(tester, client: client);
    await tester.pumpAndSettle();

    expect(
      find.text('The list of Pokémon could not be loaded.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    // The rest of the app is still there.
    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
  });

  group('theme', () {
    /// Whether the screen is currently drawn in light or dark.
    Brightness shownBrightness(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold))).brightness;

    /// Which of the picker's three buttons is shown as selected.
    ThemeMode pickerSelection(WidgetTester tester) => tester
        .widget<SegmentedButton<ThemeMode>>(
          find.byType(SegmentedButton<ThemeMode>),
        )
        .selected
        .single;

    /// Makes the pretend browser prefer [brightness].
    void browserPrefers(WidgetTester tester, Brightness brightness) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }

    testWidgets('follows the browser by default', (tester) async {
      browserPrefers(tester, Brightness.dark);

      await pumpAppWith(tester);

      expect(shownBrightness(tester), Brightness.dark);
    });

    testWidgets('a saved choice beats the browser, from the first frame', (
      tester,
    ) async {
      browserPrefers(tester, Brightness.dark);
      final container = ProviderContainer(
        overrides: fakeWorld(
          store: InMemoryKeyValueStore({'theme_mode': 'light'}),
        ),
      );
      addTearDown(container.dispose);
      // What `main` does before showing anything.
      await container.read(themeModeProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PokemonTeamBuilderApp(),
        ),
      );

      // One frame, no further pumping: the right theme is already there.
      expect(shownBrightness(tester), Brightness.light);
    });

    testWidgets('the picker changes the theme and saves the choice', (
      tester,
    ) async {
      browserPrefers(tester, Brightness.light);
      final store = InMemoryKeyValueStore();
      await pumpAppWith(tester, store: store);
      expect(shownBrightness(tester), Brightness.light);

      await tester.tap(find.byTooltip('Dark'));
      await tester.pumpAndSettle();

      expect(shownBrightness(tester), Brightness.dark);
      expect(pickerSelection(tester), ThemeMode.dark);
      expect(store.data['theme_mode'], 'dark');
    });

    testWidgets('choosing "match the browser" goes back to following it', (
      tester,
    ) async {
      browserPrefers(tester, Brightness.light);
      await pumpAppWith(
        tester,
        store: InMemoryKeyValueStore({'theme_mode': 'dark'}),
      );
      await tester.pumpAndSettle();
      expect(shownBrightness(tester), Brightness.dark);

      await tester.tap(find.byTooltip('Match the browser'));
      await tester.pumpAndSettle();

      expect(shownBrightness(tester), Brightness.light);
      expect(pickerSelection(tester), ThemeMode.system);
    });

    testWidgets('the picker starts on the saved choice', (tester) async {
      await pumpAppWith(
        tester,
        store: InMemoryKeyValueStore({'theme_mode': 'dark'}),
      );
      await tester.pumpAndSettle();

      expect(pickerSelection(tester), ThemeMode.dark);
    });

    testWidgets(
      'the picker starts on "match the browser" if nothing is saved',
      (tester) async {
        await pumpAppWith(tester);
        await tester.pumpAndSettle();

        expect(pickerSelection(tester), ThemeMode.system);
      },
    );
  });
}
