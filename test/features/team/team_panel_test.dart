import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/team/add_target_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_panel.dart';
import 'package:pokemon_team_builder/features/team/team_slot.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';
import '../../support/in_memory_key_value_store.dart';

/// An [ApiClient] that holds back every request until the test answers it.
class _HeldApiClient implements ApiClient {
  final pending = <Completer<Result<Object?>>>[];

  @override
  Future<Result<Object?>> getJson(Uri url) {
    final answer = Completer<Result<Object?>>();
    pending.add(answer);
    return answer.future;
  }
}

void main() {
  late InMemoryKeyValueStore store;
  late FakeApiClient api;
  var emptyTaps = 0;

  setUp(() {
    store = InMemoryKeyValueStore();
    emptyTaps = 0;
    // Only Pikachu (25) can be loaded; every other Pokémon fails.
    api = FakeApiClient(
      (url) => url.path.endsWith('/pokemon/25')
          ? Ok(loadFixture('pokemon_pikachu.json'))
          : const Err(OfflineFailure()),
    );
  });

  /// Shows the team panel in a space [width] wide, with [saved] already saved.
  Future<void> pumpTeam(
    WidgetTester tester, {
    String? saved,
    ApiClient? client,
    double width = 700,
  }) async {
    if (saved != null) store.data['team'] = saved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client ?? api),
          keyValueStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: width,
                child: TeamPanel(onEmptySlotTapped: () => emptyTaps++),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TeamPanel)));

  List<int?> savedSlots(WidgetTester tester) =>
      containerOf(tester).read(teamProvider).requireValue.slots;

  Finder slot(int index) => find.byType(TeamSlot).at(index);

  testWidgets('an empty team is six empty slots', (tester) async {
    await pumpTeam(tester);
    await tester.pumpAndSettle();

    expect(find.text('Your team (0 of 6)'), findsOneWidget);
    expect(find.byType(TeamSlot), findsNWidgets(6));
    expect(find.text('Add a Pokémon'), findsNWidgets(6));
  });

  testWidgets('a saved team fills its slots, gaps included', (tester) async {
    await pumpTeam(tester, saved: '{"ids":[null,25,null,25]}');
    await tester.pumpAndSettle();

    expect(find.text('Your team (2 of 6)'), findsOneWidget);
    expect(find.text('Add a Pokémon'), findsNWidgets(4));
    // The same Pokémon may fill two slots.
    expect(find.text('Pikachu'), findsNWidgets(2));
    expect(find.text('Electric'), findsNWidgets(2));
    // The first slot is one of the empty ones, and the second is Pikachu.
    expect(
      find.descendant(of: slot(0), matching: find.text('Add a Pokémon')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: slot(1), matching: find.text('Pikachu')),
      findsOneWidget,
    );
  });

  testWidgets('shows a spinner while a Pokémon loads, and it can be removed', (
    tester,
  ) async {
    final held = _HeldApiClient();
    await pumpTeam(tester, saved: '{"ids":[25]}', client: held);
    // The spinner never settles, so `pumpAndSettle` would time out. Pump single
    // frames instead: one to build, one for the saved team to finish loading.
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Its name is not known yet, so the button uses its number.
    await tester.tap(find.byTooltip('Remove Pokémon #25 from the team'));
    await tester.pumpAndSettle();

    expect(savedSlots(tester), everyElement(isNull));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('a Pokémon that cannot be loaded', () {
    testWidgets('says so, with the reason', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[7]}');
      await tester.pumpAndSettle();

      expect(find.text('Could not load #7'), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('can be asked for again', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[7]}');
      await tester.pumpAndSettle();
      final before = api.calls.where((u) => u.path.endsWith('/pokemon/7'));
      expect(before, hasLength(1));

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      final after = api.calls.where((u) => u.path.endsWith('/pokemon/7'));
      expect(after, hasLength(2));
    });

    testWidgets('can still be removed', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[7]}');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove Pokémon #7 from the team'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load #7'), findsNothing);
      expect(find.text('Add a Pokémon'), findsNWidgets(6));
    });
  });

  group('removing', () {
    testWidgets('empties just that slot, and saves', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[25,25]}');
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: slot(0),
          matching: find.byTooltip('Remove Pikachu from the team'),
        ),
      );
      await tester.pumpAndSettle();

      expect(savedSlots(tester), [null, 25, null, null, null, null]);
      expect(store.data['team'], '{"ids":[null,25,null,null,null,null]}');
      expect(find.text('Your team (1 of 6)'), findsOneWidget);
    });
  });

  group('tapping an empty slot', () {
    testWidgets('chooses it for the next Pokémon, and tells the screen', (
      tester,
    ) async {
      await pumpTeam(tester);
      await tester.pumpAndSettle();

      await tester.tap(slot(3));
      await tester.pump();

      expect(containerOf(tester).read(addTargetProvider), 3);
      expect(emptyTaps, 1);
      // That slot, and only that one, is marked as chosen.
      expect(find.text('Choose a Pokémon'), findsOneWidget);
      expect(
        find.descendant(of: slot(3), matching: find.text('Choose a Pokémon')),
        findsOneWidget,
      );
    });

    testWidgets('tapping a different empty slot moves the choice', (
      tester,
    ) async {
      await pumpTeam(tester);
      await tester.pumpAndSettle();

      await tester.tap(slot(3));
      await tester.tap(slot(1));
      await tester.pump();

      expect(containerOf(tester).read(addTargetProvider), 1);
      expect(find.text('Choose a Pokémon'), findsOneWidget);
    });

    testWidgets('does nothing to a filled slot', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[25]}');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pikachu'));
      await tester.pump();

      expect(containerOf(tester).read(addTargetProvider), isNull);
      expect(emptyTaps, 0);
    });
  });

  group('layout', () {
    /// How many slots share the top row.
    int columns(WidgetTester tester) {
      final top = tester.getTopLeft(slot(0)).dy;
      return [
        for (var i = 0; i < 6; i++)
          if (tester.getTopLeft(slot(i)).dy == top) i,
      ].length;
    }

    testWidgets('two across on a narrow space', (tester) async {
      await pumpTeam(tester, width: 380);
      await tester.pumpAndSettle();

      expect(columns(tester), 2);
    });

    testWidgets('three across on a wider space', (tester) async {
      await pumpTeam(tester, width: 700);
      await tester.pumpAndSettle();

      expect(columns(tester), 3);
    });

    testWidgets('six slots that failed to load fit without overflow', (
      tester,
    ) async {
      // A failed slot has more text than any other.
      await pumpTeam(tester, saved: '{"ids":[1,2,3,4,5,6]}', width: 380);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Try again'), findsNWidgets(6));
    });

    testWidgets('a long name with two types fits without overflow', (
      tester,
    ) async {
      final client = FakeApiClient(
        (_) => Ok(loadFixture('pokemon_koraidon_limited_build.json')),
      );
      await pumpTeam(
        tester,
        saved: '{"ids":[10264]}',
        client: client,
        width: 380,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TypeBadge), findsNWidgets(2));
    });
  });
}
