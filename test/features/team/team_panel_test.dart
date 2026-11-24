import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/features/detail/pokemon_detail_dialog.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/team/add_target_notifier.dart';
import 'package:pokemon_team_builder/features/team/arrivals_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_panel.dart';
import 'package:pokemon_team_builder/features/team/team_slot.dart';
import 'package:pokemon_team_builder/features/team/throw_in.dart';

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
  final screenKey = GlobalKey();
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
          // The boundary lets a test take a picture of the whole screen.
          home: RepaintBoundary(
            key: screenKey,
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: TeamPanel(onEmptySlotTapped: () => emptyTaps++),
                ),
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

  group('tapping a Pokémon', () {
    testWidgets('opens its details', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[25]}');
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(of: slot(0), matching: find.byType(Card)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsOneWidget);
      expect(find.text('Base stats'), findsOneWidget);
    });

    testWidgets('on its name works as well as on the card', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[25]}');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pikachu'));
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsOneWidget);
    });

    testWidgets('on its remove button removes it, and opens nothing', (
      tester,
    ) async {
      await pumpTeam(tester, saved: '{"ids":[25]}');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove Pikachu from the team'));
      await tester.pumpAndSettle();

      expect(savedSlots(tester), everyElement(isNull));
      expect(find.byType(PokemonDetailDialog), findsNothing);
    });

    testWidgets('does nothing while it is still loading', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[25]}', client: _HeldApiClient());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      expect(find.byType(PokemonDetailDialog), findsNothing);
    });

    testWidgets('does nothing if it could not be loaded', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[7]}');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Could not load #7'));
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsNothing);
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

  group('arriving', () {
    const frame = Duration(milliseconds: 16);

    RenderObject picture(WidgetTester tester, int index) => tester.renderObject(
      find.descendant(
        of: slot(index),
        matching: find.byKey(const Key('throw-in-picture')),
      ),
    );

    void expectBall(WidgetTester tester, int index, {required bool shown}) {
      final matcher = paints..circle();
      expect(
        picture(tester, index),
        shown ? matcher : isNot(matcher),
        reason: 'ball in slot $index',
      );
    }

    testWidgets('a saved team is thrown in one after another', (tester) async {
      await pumpTeam(tester, saved: '{"ids":[25,25,25]}');
      await tester.pump();
      await tester.pump();
      await tester.pump(frame);

      // Slot 0 is under way. Slot 1 waits one stagger, and slot 2 two. (After
      // a slot's wait is up, its ball shows from the frame after, hence the
      // small extra pumps.)
      const settle = Duration(milliseconds: 30);
      await tester.pump(startupThrowStagger ~/ 2);
      expectBall(tester, 0, shown: true);
      expectBall(tester, 1, shown: false);
      expectBall(tester, 2, shown: false);

      await tester.pump(startupThrowStagger);
      await tester.pump(settle);
      expectBall(tester, 1, shown: true);
      expectBall(tester, 2, shown: false);

      await tester.pump(startupThrowStagger);
      await tester.pump(settle);
      expectBall(tester, 2, shown: true);

      // And all of them end up showing their Pokémon, with nothing over it.
      await tester.pumpAndSettle();
      expect(find.text('Pikachu'), findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(picture(tester, i), paintsNothing, reason: 'slot $i');
      }
    });

    testWidgets('a Pokémon added to the team is thrown in', (tester) async {
      await pumpTeam(tester);
      await tester.pumpAndSettle();

      await containerOf(tester).read(teamProvider.notifier).add(25);
      await tester.pump();
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 300));

      expectBall(tester, 0, shown: true);

      await tester.pumpAndSettle();
      expect(find.text('Pikachu'), findsOneWidget);
      expect(picture(tester, 0), paintsNothing);
    });

    testWidgets('the cover is the colour of the card, so it is not seen', (
      tester,
    ) async {
      await pumpTeam(tester, saved: '{"ids":[25]}');
      await tester.pumpAndSettle();

      final cover = tester.widget<ThrowIn>(find.byType(ThrowIn)).coverColour;
      final card = tester.widget<Card>(
        find.descendant(of: slot(0), matching: find.byType(Card)),
      );

      expect(card.color, cover);
    });

    testWidgets('hovering over a card whose ball is on its way changes nothing', (
      tester,
    ) async {
      await pumpTeam(tester, saved: '{"ids":[25,25,25]}');
      await tester.pump();
      await tester.pump();
      await tester.pump(frame);

      // Slot 2 is the last to throw, so it is still covered and has not yet
      // thrown. Move the mouse onto it, and wait for the card's hover colour,
      // which fades in over a short time, to appear.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pump();
      final area = tester.getRect(slot(2));
      await mouse.moveTo(area.center);
      // One frame for the card to notice the mouse, then a little time for the
      // colour to fade in. (Both are well inside the wait slot 2 has before it
      // throws.)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // A point in the card's padding, and one in the middle, under the cover.
      final ring = area.centerLeft + const Offset(6, 0);
      final middle = area.center + const Offset(0, 40);
      final colours = await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(screenKey),
        );
        final image = await boundary.toImage();
        final bytes = (await image.toByteData())!;
        List<int> at(Offset p) => [
          for (var channel = 0; channel < 4; channel++)
            bytes.getUint8(
              (p.dy.toInt() * image.width + p.dx.toInt()) * 4 + channel,
            ),
        ];
        return [at(ring), at(middle)];
      });

      expect(colours![0], colours[1]);
    });

    testWidgets('one that cannot be loaded ends with the error, not a ball', (
      tester,
    ) async {
      await pumpTeam(tester);
      await tester.pumpAndSettle();

      await containerOf(tester).read(teamProvider.notifier).add(7);
      await tester.pumpAndSettle();

      expect(find.text('Could not load #7'), findsOneWidget);
      expect(picture(tester, 0), paintsNothing);
    });

    testWidgets('a slow one keeps the ball waiting, and can still be removed', (
      tester,
    ) async {
      await pumpTeam(tester, saved: '{"ids":[25]}', client: _HeldApiClient());
      await tester.pump();
      await tester.pump(frame);
      // Far longer than the flight. The Pokémon has still not loaded.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));

      expectBall(tester, 0, shown: true);

      await tester.tap(find.byTooltip('Remove Pokémon #25 from the team'));
      await tester.pump();

      expect(savedSlots(tester), everyElement(isNull));
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

    testWidgets('every slot is the same width, and the gaps are even', (
      tester,
    ) async {
      for (final width in [380.0, 700.0]) {
        await pumpTeam(tester, width: width);
        await tester.pumpAndSettle();

        final first = tester.getSize(slot(0)).width;
        for (var i = 1; i < 6; i++) {
          expect(
            tester.getSize(slot(i)).width,
            closeTo(first, 0.01),
            reason: 'slot $i at $width px',
          );
        }
        // The gap between neighbours in the top row is the same everywhere.
        final across = columns(tester);
        for (var i = 1; i < across; i++) {
          expect(
            tester.getTopLeft(slot(i)).dx - tester.getTopRight(slot(i - 1)).dx,
            closeTo(12, 0.01),
            reason: 'gap before slot $i at $width px',
          );
        }
        // And the row fills the space exactly, with no gap at the edge.
        expect(tester.getTopRight(slot(across - 1)).dx, closeTo(width, 0.01));
      }
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
