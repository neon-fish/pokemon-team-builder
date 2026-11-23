import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/team.dart';
import 'package:pokemon_team_builder/features/detail/pokemon_detail_dialog.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_panel.dart';
import 'package:pokemon_team_builder/features/team/team_slot.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';
import '../../support/in_memory_key_value_store.dart';

void main() {
  // Two Pokémon that load, so a swap can be seen: 25 is Pikachu and 10264 is
  // Koraidon (limited build). Every other number fails to load.
  const pikachu = 25;
  const koraidon = 10264;
  const koraidonName = 'Koraidon Limited Build';

  late InMemoryKeyValueStore store;

  setUp(() => store = InMemoryKeyValueStore());

  Future<void> pumpTeam(WidgetTester tester, String saved) async {
    store.data['team'] = saved;
    final api = FakeApiClient((url) {
      if (url.path.endsWith('/pokemon/$pikachu')) {
        return Ok(loadFixture('pokemon_pikachu.json'));
      }
      if (url.path.endsWith('/pokemon/$koraidon')) {
        return Ok(loadFixture('pokemon_koraidon_limited_build.json'));
      }
      return const Err(OfflineFailure());
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          keyValueStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 700, child: TeamPanel()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<int?> savedSlots(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TeamPanel)))
          .read(teamProvider)
          .requireValue
          .slots;

  Finder slot(int index) => find.byType(TeamSlot).at(index);

  /// Presses on [from] and holds it long enough to pick it up. The finger or
  /// pointer is still down, so the test can look at the drag in progress.
  Future<TestGesture> pickUp(WidgetTester tester, Finder from) async {
    final gesture = await tester.startGesture(tester.getCenter(from));
    await tester.pump(dragHoldDelay + const Duration(milliseconds: 50));
    return gesture;
  }

  /// A whole drag: pick up [from], carry it to [to] and let go.
  Future<void> drag(WidgetTester tester, Finder from, Finder to) async {
    final gesture = await pickUp(tester, from);
    await gesture.moveTo(tester.getCenter(to));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('dragging', () {
    testWidgets('onto an empty slot moves the Pokémon there, and saves', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25]}');

      await drag(tester, slot(0), slot(4));

      expect(savedSlots(tester), [null, null, null, null, pikachu, null]);
      expect(store.data['team'], '{"ids":[null,null,null,null,25,null]}');
      expect(
        find.descendant(of: slot(4), matching: find.text('Pikachu')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: slot(0), matching: find.text('Add a Pokémon')),
        findsOneWidget,
      );
    });

    testWidgets('onto another Pokémon swaps the two', (tester) async {
      await pumpTeam(tester, '{"ids":[25,10264]}');

      await drag(tester, slot(0), slot(1));

      expect(savedSlots(tester), [koraidon, pikachu, null, null, null, null]);
      expect(
        find.descendant(of: slot(0), matching: find.text(koraidonName)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: slot(1), matching: find.text('Pikachu')),
        findsOneWidget,
      );
    });

    testWidgets('onto its own slot changes nothing', (tester) async {
      await pumpTeam(tester, '{"ids":[25,10264]}');
      final before = store.data['team'];

      await drag(tester, slot(0), slot(0));

      expect(savedSlots(tester), [pikachu, koraidon, null, null, null, null]);
      expect(store.data['team'], before);
    });

    testWidgets('and dropping it outside the slots changes nothing', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25]}');

      final gesture = await pickUp(tester, slot(0));
      await gesture.moveTo(const Offset(790, 590)); // Below the team.
      await gesture.up();
      await tester.pumpAndSettle();

      expect(savedSlots(tester), [pikachu, null, null, null, null, null]);
      expect(find.text('Pikachu'), findsOneWidget);
    });

    testWidgets('does not start until the Pokémon has been held', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25]}');

      // Straight away, with no pause: this is a swipe or a shaky click, not a
      // drag.
      final gesture = await tester.startGesture(tester.getCenter(slot(0)));
      await gesture.moveTo(tester.getCenter(slot(4)));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(savedSlots(tester), [pikachu, null, null, null, null, null]);
    });

    testWidgets('a Pokémon that could not be loaded can be moved too', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[7]}');

      await drag(tester, slot(0), slot(2));

      expect(savedSlots(tester), [null, null, 7, null, null, null]);
    });

    testWidgets('an empty slot cannot be picked up', (tester) async {
      await pumpTeam(tester, '{"ids":[null,25]}');

      await drag(tester, slot(0), slot(1));

      expect(savedSlots(tester), [null, pikachu, null, null, null, null]);
    });

    testWidgets('a short press still opens the details', (tester) async {
      await pumpTeam(tester, '{"ids":[25]}');

      await tester.tap(slot(0));
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsOneWidget);
    });
  });

  group('while dragging', () {
    testWidgets('a preview follows the pointer, and nothing moves yet', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25]}');
      expect(find.text('Pikachu'), findsOneWidget);

      final gesture = await pickUp(tester, slot(0));
      await gesture.moveTo(tester.getCenter(slot(4)));
      await tester.pump();

      // The slot's own copy, left behind, and the preview.
      expect(find.text('Pikachu'), findsNWidgets(2));
      expect(savedSlots(tester), [pikachu, null, null, null, null, null]);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Pikachu'), findsOneWidget);
    });

    testWidgets('the slot it came from is faded', (tester) async {
      await pumpTeam(tester, '{"ids":[25]}');
      Finder faded() => find.descendant(
        of: slot(0),
        matching: find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity < 1,
        ),
      );
      expect(faded(), findsNothing);

      final gesture = await pickUp(tester, slot(0));
      await gesture.moveBy(const Offset(20, 20));
      await tester.pump();
      expect(faded(), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(faded(), findsNothing);
    });

    testWidgets('the slot under the pointer is highlighted, and only it', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25,10264]}');
      final primary = buildAppTheme(Brightness.light).colorScheme.primary;

      /// The border colour of each slot's card, by slot number.
      List<Color> borders() => [
        for (var i = 0; i < Team.slotCount; i++)
          ((tester
                      .widget<Card>(
                        find.descendant(
                          of: slot(i),
                          matching: find.byType(Card),
                        ),
                      )
                      .shape!)
                  as RoundedRectangleBorder)
              .side
              .color,
      ];

      final gesture = await pickUp(tester, slot(0));
      expect(borders().where((colour) => colour == primary), isEmpty);

      // Over a full slot, then over an empty one: either can be dropped on.
      await gesture.moveTo(tester.getCenter(slot(1)));
      await tester.pump();
      expect(
        [for (final c in borders()) c == primary],
        [false, true, false, false, false, false],
      );

      await gesture.moveTo(tester.getCenter(slot(3)));
      await tester.pump();
      expect(
        [for (final c in borders()) c == primary],
        [false, false, false, true, false, false],
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(borders().where((colour) => colour == primary), isEmpty);
    });
  });

  group('moving without dragging', () {
    /// The names of the extra actions a screen reader is offered on slot [i].
    List<String> actionsOn(WidgetTester tester, int i) {
      final node = tester.getSemantics(
        find.descendant(of: slot(i), matching: find.byType(Card)),
      );
      return [
        for (final id
            in node.getSemanticsData().customSemanticsActionIds ?? <int>[])
          CustomSemanticsAction.getAction(id)?.label ?? '',
      ];
    }

    /// Does what a screen reader does when the user picks [label] on slot [i].
    void perform(WidgetTester tester, int i, String label) {
      final node = tester.getSemantics(
        find.descendant(of: slot(i), matching: find.byType(Card)),
      );
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(
          CustomSemanticsAction(label: label),
        ),
      );
    }

    testWidgets('a Pokémon is offered the moves that are possible', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTeam(tester, '{"ids":[25,25,25,25,25,25]}');

      expect(actionsOn(tester, 0), ['Move later']);
      expect(
        actionsOn(tester, 2),
        unorderedEquals(['Move earlier', 'Move later']),
      );
      expect(actionsOn(tester, 5), ['Move earlier']);

      // Disposed here, not in `addTearDown`: the framework checks for leftover
      // handles before teardown callbacks run.
      semantics.dispose();
    });

    testWidgets('are on the item a reader lands on, which names its slot', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTeam(tester, '{"ids":[25,25,25]}');

      // Actions on a node that has no label and cannot take focus would never
      // be offered, so check this node is the one that does the other things.
      final data = tester
          .getSemantics(
            find.descendant(of: slot(2), matching: find.byType(Card)),
          )
          .getSemanticsData();
      expect(data.label, contains('Slot 3'));
      expect(data.label, contains('Pikachu'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.hasAction(SemanticsAction.focus), isTrue);
      expect(data.hasAction(SemanticsAction.customAction), isTrue);

      semantics.dispose();
    });

    testWidgets('"Move later" swaps with the next slot', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTeam(tester, '{"ids":[25,10264]}');

      perform(tester, 0, 'Move later');
      await tester.pumpAndSettle();

      expect(savedSlots(tester), [koraidon, pikachu, null, null, null, null]);
      semantics.dispose();
    });

    testWidgets('"Move earlier" swaps with the one before', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTeam(tester, '{"ids":[25,10264]}');

      perform(tester, 1, 'Move earlier');
      await tester.pumpAndSettle();

      expect(savedSlots(tester), [koraidon, pikachu, null, null, null, null]);
      semantics.dispose();
    });

    testWidgets('can move into an empty slot', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTeam(tester, '{"ids":[25]}');

      perform(tester, 0, 'Move later');
      await tester.pumpAndSettle();

      expect(savedSlots(tester), [null, pikachu, null, null, null, null]);
      semantics.dispose();
    });
  });

  group('the details dialog', () {
    testWidgets('moves the Pokémon it was opened from, and keeps up', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25,10264]}');

      await tester.tap(slot(1));
      await tester.pumpAndSettle();
      expect(find.text('Slot 2 of 6'), findsOneWidget);

      await tester.tap(find.text('Move earlier'));
      await tester.pumpAndSettle();

      expect(savedSlots(tester), [koraidon, pikachu, null, null, null, null]);
      expect(find.text('Slot 1 of 6'), findsOneWidget);
    });
  });
}
