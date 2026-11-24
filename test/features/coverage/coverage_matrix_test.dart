import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/features/coverage/coverage_matrix.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

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

/// An [ApiClient] that can be told to leave type chart requests unanswered,
/// like a slow network, and otherwise passes everything to [inner].
class _HoldableApiClient implements ApiClient {
  _HoldableApiClient(this.inner);

  final ApiClient inner;
  var holdTypeRequests = false;

  @override
  Future<Result<Object?>> getJson(Uri url) {
    if (holdTypeRequests && url.path.contains('/type/')) {
      return Completer<Result<Object?>>().future;
    }
    return inner.getJson(url);
  }
}

void main() {
  final chartResponses =
      loadFixture('type_chart_responses.json')! as Map<String, Object?>;

  // What the fake API does, changed by tests to simulate trouble.
  var chartFails = false;
  late FakeApiClient api;
  late InMemoryKeyValueStore store;

  setUp(() {
    chartFails = false;
    store = InMemoryKeyValueStore();
    api = FakeApiClient((url) {
      if (url.path.contains('/type/')) {
        return chartFails
            ? const Err(ServerFailure(503))
            : Ok(chartResponses[url.pathSegments.last]);
      }
      // Only Pikachu (25) can be loaded; every other Pokémon fails.
      if (url.path.endsWith('/pokemon/25')) {
        return Ok(loadFixture('pokemon_pikachu.json'));
      }
      return const Err(NotFoundFailure());
    });
  });

  /// Shows the matrix, with [saved] team text already in storage.
  Future<void> pumpMatrix(
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
              child: SizedBox(width: width, child: const CoverageMatrix()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The attacking types of the rows, top to bottom.
  List<String> rowTypes(WidgetTester tester) => [
    for (final row in tester.widgetList<MatchupRow>(find.byType(MatchupRow)))
      row.matchup.attacking.name,
  ];

  /// The row for one attacking type, such as 'ground'.
  Finder rowFor(String type) => find.byWidgetPredicate(
    (widget) => widget is MatchupRow && widget.matchup.attacking.name == type,
  );

  /// What each cell of a row shows, slot by slot: null for a blank cell.
  List<double?> cellsIn(WidgetTester tester, String type) => [
    for (final cell in tester.widgetList<MatchupCell>(
      find.descendant(of: rowFor(type), matching: find.byType(MatchupCell)),
    ))
      cell.multiplier,
  ];

  group('with nobody in the team', () {
    testWidgets('invites you to add someone, instead of 18 blank rows', (
      tester,
    ) async {
      await pumpMatrix(tester);

      expect(
        find.text('Add a Pokémon to see where your team is weak.'),
        findsOneWidget,
      );
      expect(find.byType(MatchupRow), findsNothing);
    });

    testWidgets('fills in when someone is added', (tester) async {
      await pumpMatrix(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CoverageMatrix)),
      );
      await container.read(teamProvider.notifier).add(25);
      await tester.pumpAndSettle();

      expect(find.byType(MatchupRow), findsNWidgets(18));
    });
  });

  testWidgets('shows a spinner while the type chart loads', (tester) async {
    final held = _HeldApiClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(held),
          keyValueStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: CoverageMatrix())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(MatchupRow), findsNothing);
  });

  group('when the type chart cannot be loaded', () {
    testWidgets('says so, with the reason', (tester) async {
      chartFails = true;
      await pumpMatrix(tester, saved: '{"ids":[25]}');

      expect(
        find.textContaining('The type chart could not be loaded'),
        findsOneWidget,
      );
      expect(find.textContaining('having problems'), findsOneWidget);
      expect(find.byType(MatchupRow), findsNothing);
    });

    testWidgets('trying again shows the matrix once it works', (tester) async {
      chartFails = true;
      await pumpMatrix(tester, saved: '{"ids":[25]}');

      chartFails = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchupRow), findsNWidgets(18));
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('while trying the type chart again after a failure', () {
    testWidgets('shows a spinner, not the old failure', (tester) async {
      chartFails = true;
      final client = _HoldableApiClient(api);
      await pumpMatrix(tester, saved: '{"ids":[25]}', client: client);
      expect(find.text('Try again'), findsOneWidget);

      // The retry is under way but has not been answered.
      client.holdTypeRequests = true;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.textContaining('could not be loaded'), findsNothing);
    });
  });

  group('with a team', () {
    // Pikachu in the second slot. Pikachu is electric: weak only to ground, and
    // it resists flying, steel and electric.
    const saved = '{"ids":[null,25]}';

    testWidgets('has a row for every type', (tester) async {
      await pumpMatrix(tester, saved: saved);

      expect(find.byType(MatchupRow), findsNWidgets(18));
    });

    testWidgets('puts each result in its Pokémon\'s own column', (
      tester,
    ) async {
      await pumpMatrix(tester, saved: saved);

      // Six cells: the empty first slot is blank, Pikachu takes double damage.
      expect(cellsIn(tester, 'ground'), [null, 2, null, null, null, null]);
      expect(cellsIn(tester, 'flying'), [null, 0.5, null, null, null, null]);
      expect(cellsIn(tester, 'fire'), [null, 1, null, null, null, null]);
    });

    testWidgets('writes the multiplier in each cell, not just colours it', (
      tester,
    ) async {
      await pumpMatrix(tester, saved: saved);

      expect(
        find.descendant(of: rowFor('ground'), matching: find.text('2×')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rowFor('flying'), matching: find.text('½')),
        findsOneWidget,
      );
    });

    testWidgets('starts with the biggest gap at the top', (tester) async {
      await pumpMatrix(tester, saved: saved);

      expect(rowTypes(tester).first, 'ground');
      // Pikachu resists flying, steel and electric equally, so they come last,
      // in the standard order among themselves.
      expect(rowTypes(tester).sublist(15), ['flying', 'steel', 'electric']);
    });

    testWidgets('explains the types the team is exposed to, and only those', (
      tester,
    ) async {
      await pumpMatrix(tester, saved: saved);

      expect(
        find.text('1 of 1 is weak to Ground and nobody resists it.'),
        findsOneWidget,
      );
      expect(find.textContaining('weak to'), findsOneWidget);
    });

    testWidgets('counts the weak members in the last column', (tester) async {
      await pumpMatrix(tester, saved: '{"ids":[25,25,null,25]}');

      expect(
        find.descendant(of: rowFor('ground'), matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('shows the Pokémon at the head of its column', (tester) async {
      await pumpMatrix(tester, saved: saved);

      expect(find.byTooltip('Pikachu'), findsOneWidget);
    });

    testWidgets('gives a screen reader a sentence for each row', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpMatrix(tester, saved: saved);

      expect(
        find.bySemanticsLabel(
          'Ground: 1 weak, 0 resist, 0 immune. '
          '1 of 1 is weak to Ground and nobody resists it.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Flying: 0 weak, 1 resist, 0 immune.'),
        findsOneWidget,
      );
      // Disposed here, not with `addTearDown`: the framework checks for open
      // handles before teardown callbacks run.
      semantics.dispose();
    });
  });

  group('choosing the order', () {
    Future<void> chooseOrder(WidgetTester tester, String label) async {
      await tester.tap(find.byTooltip('Change the order of the types'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('standard order lists the types as the game does', (
      tester,
    ) async {
      await pumpMatrix(tester, saved: '{"ids":[25]}');

      await chooseOrder(tester, 'Standard order');

      expect(rowTypes(tester).first, 'normal');
      expect(rowTypes(tester).last, 'fairy');
    });

    testWidgets('can go back to the biggest gaps first', (tester) async {
      await pumpMatrix(tester, saved: '{"ids":[25]}');
      await chooseOrder(tester, 'Standard order');

      await chooseOrder(tester, 'Biggest gaps first');

      expect(rowTypes(tester).first, 'ground');
    });

    testWidgets('the menu shows which order is in use', (tester) async {
      await pumpMatrix(tester, saved: '{"ids":[25]}');

      await tester.tap(find.byTooltip('Change the order of the types'));
      await tester.pumpAndSettle();

      final items = tester.widgetList<CheckedPopupMenuItem<Object?>>(
        find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
      );
      final checked = [for (final item in items) item.checked];
      // Biggest gaps first is listed second.
      expect(checked, [false, true]);
    });
  });

  group('when a member could not be included', () {
    testWidgets('says the picture may be incomplete, but still shows it', (
      tester,
    ) async {
      // Pokémon 7 fails to load.
      await pumpMatrix(tester, saved: '{"ids":[25,7]}');

      expect(
        find.text(
          '1 team member is still loading or could not be loaded, so this may '
          'be incomplete.',
        ),
        findsOneWidget,
      );
      expect(find.byType(MatchupRow), findsNWidgets(18));
    });

    testWidgets('says how many, when it is more than one', (tester) async {
      await pumpMatrix(tester, saved: '{"ids":[25,7,8]}');

      expect(find.textContaining('2 team members are still'), findsOneWidget);
    });

    testWidgets('with nobody analysed, shows the warning and no rows', (
      tester,
    ) async {
      await pumpMatrix(tester, saved: '{"ids":[7]}');

      expect(find.textContaining('may be incomplete'), findsOneWidget);
      expect(find.byType(MatchupRow), findsNothing);
      // It is not the "add a Pokémon" message: the team is not empty.
      expect(find.textContaining('Add a Pokémon'), findsNothing);
    });

    testWidgets('no warning when everyone is included', (tester) async {
      await pumpMatrix(tester, saved: '{"ids":[25]}');

      expect(find.textContaining('may be incomplete'), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('fits a phone-sized width with a full team', (tester) async {
      await pumpMatrix(
        tester,
        saved: '{"ids":[25,25,25,25,25,25]}',
        width: 368,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MatchupRow), findsNWidgets(18));
    });

    testWidgets('fits at double text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpMatrix(
        tester,
        saved: '{"ids":[25,25,25,25,25,25]}',
        width: 368,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('every type still has its badge at phone width', (
      tester,
    ) async {
      await pumpMatrix(tester, saved: '{"ids":[25]}', width: 368);

      expect(find.byType(TypeBadge), findsNWidgets(18));
      expect(tester.takeException(), isNull);
    });
  });
}
