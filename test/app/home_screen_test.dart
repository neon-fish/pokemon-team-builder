import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/app.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/features/search/search_panel.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_panel.dart';
import 'package:pokemon_team_builder/features/team/team_slot.dart';

import '../support/fake_api_client.dart';
import '../support/fixtures.dart';
import '../support/in_memory_key_value_store.dart';
import '../support/screen_size.dart';

void main() {
  late InMemoryKeyValueStore store;

  setUp(() => store = InMemoryKeyValueStore());

  /// Shows the whole app, with a fake API that knows the index and Pikachu.
  Future<void> pumpApp(WidgetTester tester) async {
    final client = FakeApiClient((url) {
      if (url.path.endsWith('/pokemon')) {
        return Ok(loadFixture('pokemon_index.json'));
      }
      if (url.path.endsWith('/pokemon/25')) {
        return Ok(loadFixture('pokemon_pikachu.json'));
      }
      return const Err(NotFoundFailure());
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          keyValueStoreProvider.overrideWithValue(store),
        ],
        child: const PokemonTeamBuilderApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<int?> teamSlots(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(teamProvider)
          .requireValue
          .slots;

  /// What is typed in the search box that is on top. (With the sheet open over
  /// the wide layout there are two; the last is the one in front.)
  String searchFieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).last).controller!.text;

  /// The row for Pikachu in the search results.
  Finder pikachuRow() => find.widgetWithText(ListTile, 'Pikachu');

  group('on a wide screen', () {
    testWidgets('the search and the team are both there', (tester) async {
      useScreenSize(tester, desktopScreen);
      await pumpApp(tester);

      expect(find.byType(SearchPanel), findsOneWidget);
      expect(find.byType(TeamPanel), findsOneWidget);
      expect(find.text('Add Pokémon'), findsNothing);
    });

    testWidgets('the search is to the left of the team', (tester) async {
      useScreenSize(tester, desktopScreen);
      await pumpApp(tester);

      final search = tester.getRect(find.byType(SearchPanel));
      final team = tester.getRect(find.byType(TeamPanel));
      expect(search.right, lessThanOrEqualTo(team.left));
    });

    testWidgets('picking a Pokémon puts it in the team, and the search stays', (
      tester,
    ) async {
      useScreenSize(tester, desktopScreen);
      await pumpApp(tester);

      await tester.tap(pikachuRow());
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(TeamPanel),
          matching: find.text('Pikachu'),
        ),
        findsOneWidget,
      );
      expect(find.text('Your team (1 of 6)'), findsOneWidget);
      expect(find.byType(SearchPanel), findsOneWidget);
    });

    testWidgets('an empty slot can be chosen for the next pick', (
      tester,
    ) async {
      useScreenSize(tester, desktopScreen);
      await pumpApp(tester);

      await tester.tap(find.byType(TeamSlot).at(4));
      await tester.pump();
      await tester.tap(pikachuRow());
      await tester.pumpAndSettle();

      expect(teamSlots(tester), [null, null, null, null, 25, null]);
      // The choice is used up: the next pick takes the first empty slot.
      await tester.tap(pikachuRow());
      await tester.pumpAndSettle();
      expect(teamSlots(tester), [25, null, null, null, 25, null]);
    });
  });

  group('on a phone-sized screen', () {
    testWidgets('shows the team and a button, but not the search', (
      tester,
    ) async {
      useScreenSize(tester, phoneScreen);
      await pumpApp(tester);

      expect(find.byType(TeamPanel), findsOneWidget);
      expect(find.byType(SearchPanel), findsNothing);
      expect(find.text('Add Pokémon'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the button opens the search, ready for typing', (
      tester,
    ) async {
      useScreenSize(tester, phoneScreen);
      await pumpApp(tester);

      await tester.tap(find.text('Add Pokémon'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchPanel), findsOneWidget);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);
    });

    testWidgets('picking closes the search and the Pokémon is in the team', (
      tester,
    ) async {
      useScreenSize(tester, phoneScreen);
      await pumpApp(tester);
      await tester.tap(find.text('Add Pokémon'));
      await tester.pumpAndSettle();

      await tester.tap(pikachuRow());
      await tester.pumpAndSettle();

      expect(find.byType(SearchPanel), findsNothing);
      expect(find.text('Your team (1 of 6)'), findsOneWidget);
      expect(find.text('Pikachu'), findsOneWidget);
      expect(teamSlots(tester), [25, null, null, null, null, null]);
    });

    testWidgets('tapping an empty slot opens the search for that slot', (
      tester,
    ) async {
      useScreenSize(tester, phoneScreen);
      await pumpApp(tester);

      await tester.tap(find.byType(TeamSlot).at(3));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPanel), findsOneWidget);
      await tester.tap(pikachuRow());
      await tester.pumpAndSettle();

      expect(teamSlots(tester), [null, null, null, 25, null, null]);
    });

    testWidgets('closing the search without picking forgets the slot', (
      tester,
    ) async {
      useScreenSize(tester, phoneScreen);
      await pumpApp(tester);
      await tester.tap(find.byType(TeamSlot).at(3));
      await tester.pumpAndSettle();

      // Tap the dimmed area above the sheet to dismiss it.
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPanel), findsNothing);

      // The next add, from the button, goes to the first empty slot.
      await tester.tap(find.text('Add Pokémon'));
      await tester.pumpAndSettle();
      await tester.tap(pikachuRow());
      await tester.pumpAndSettle();

      expect(teamSlots(tester), [25, null, null, null, null, null]);
    });

    testWidgets('the button is on screen without scrolling', (tester) async {
      useScreenSize(tester, phoneScreen);
      await pumpApp(tester);

      final button = tester.getRect(find.text('Add Pokémon'));
      expect(button.bottom, lessThan(phoneScreen.height));
    });

    testWidgets('a full team fits without overflow', (tester) async {
      useScreenSize(tester, phoneScreen);
      store.data['team'] = '{"ids":[25,25,25,25,25,25]}';
      await pumpApp(tester);

      expect(find.text('Your team (6 of 6)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the switch between layouts', () {
    /// Makes the window [size], as if the browser had been resized.
    Future<void> resizeTo(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
    }

    testWidgets('is exactly at 900 px wide', (tester) async {
      useScreenSize(tester, const Size(899, 800));
      await pumpApp(tester);
      expect(find.byType(SearchPanel), findsNothing, reason: '899 px');

      await resizeTo(tester, const Size(900, 800));

      expect(find.byType(SearchPanel), findsOneWidget, reason: '900 px');
    });

    testWidgets('going from phone to desktop moves the search into view', (
      tester,
    ) async {
      useScreenSize(tester, phoneScreen);
      await pumpApp(tester);
      expect(find.byType(SearchPanel), findsNothing);

      await resizeTo(tester, desktopScreen);

      expect(find.byType(SearchPanel), findsOneWidget);
      expect(find.byType(TeamPanel), findsOneWidget);
    });

    testWidgets('the team and the search text survive both ways', (
      tester,
    ) async {
      useScreenSize(tester, desktopScreen);
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField), 'pika');
      await tester.pumpAndSettle();
      await tester.tap(pikachuRow());
      await tester.pumpAndSettle();

      await resizeTo(tester, phoneScreen);

      expect(find.text('Your team (1 of 6)'), findsOneWidget);
      expect(find.text('Pikachu'), findsOneWidget);
      await tester.tap(find.text('Add Pokémon'));
      await tester.pumpAndSettle();
      expect(searchFieldText(tester), 'pika');

      // Back to wide: the sheet is still open over it, so close it first.
      await tester.tapAt(const Offset(200, 20));
      await resizeTo(tester, desktopScreen);

      expect(find.text('Your team (1 of 6)'), findsOneWidget);
      expect(searchFieldText(tester), 'pika');
    });

    testWidgets('with the sheet open, the search box and results agree', (
      tester,
    ) async {
      useScreenSize(tester, phoneScreen);
      await pumpApp(tester);
      await tester.tap(find.text('Add Pokémon'));
      await tester.pumpAndSettle();

      // The window grows while the sheet is open, so there are two searches.
      await resizeTo(tester, desktopScreen);
      expect(find.byType(SearchPanel), findsNWidgets(2));
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'bulba',
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(1100, 20));
      await tester.pumpAndSettle();

      // One search is left, and what it says matches what it shows.
      expect(find.byType(SearchPanel), findsOneWidget);
      expect(searchFieldText(tester), 'bulba');
      expect(find.text('Bulbasaur'), findsOneWidget);
      expect(find.text('Pikachu'), findsNothing);
    });
  });

  group('other conditions', () {
    testWidgets('the dark theme shows everything without errors', (
      tester,
    ) async {
      useScreenSize(tester, desktopScreen);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      store.data['team'] = '{"ids":[25,7,null,25]}';
      await pumpApp(tester);

      final shown = Theme.of(tester.element(find.byType(Scaffold).first));
      expect(shown.brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a full team fits at double text size on a phone', (
      tester,
    ) async {
      useScreenSize(tester, phoneScreen);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      store.data['team'] = '{"ids":[25,25,25,25,25,25]}';
      await pumpApp(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('failed slots fit at double text size on a phone', (
      tester,
    ) async {
      useScreenSize(tester, phoneScreen);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      store.data['team'] = '{"ids":[1,2]}';
      await pumpApp(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
