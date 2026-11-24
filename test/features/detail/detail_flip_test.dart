import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/features/detail/hero_flip.dart';
import 'package:pokemon_team_builder/features/detail/pokemon_detail_dialog.dart';
import 'package:pokemon_team_builder/features/team/team_analysis_provider.dart';
import 'package:pokemon_team_builder/features/team/team_panel.dart';
import 'package:pokemon_team_builder/features/team/team_slot.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';
import '../../support/in_memory_key_value_store.dart';
import '../../support/real_type_chart.dart';

void main() {
  const pikachu = 25;
  const koraidon = 10264;
  const koraidonName = 'Koraidon Limited Build';

  late InMemoryKeyValueStore store;

  setUp(() => store = InMemoryKeyValueStore());

  /// The team panel, with [saved] on the team, and everything settled.
  Future<void> pumpTeam(
    WidgetTester tester,
    String saved, {
    bool reduceMotion = false,
  }) async {
    store.data['team'] = saved;
    final chart = await loadRealTypeChart();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(
            FakeApiClient((url) {
              if (url.path.endsWith('/pokemon/$pikachu')) {
                return Ok(loadFixture('pokemon_pikachu.json'));
              }
              if (url.path.endsWith('/pokemon/$koraidon')) {
                return Ok(loadFixture('pokemon_koraidon_limited_build.json'));
              }
              return const Err(OfflineFailure());
            }),
          ),
          keyValueStoreProvider.overrideWithValue(store),
          typeChartProvider.overrideWith((ref) => Future.value(Ok(chart))),
        ],
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(width: 700, child: TeamPanel()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder slot(int index) => find.byType(TeamSlot).at(index);

  /// Whether the dialog's contents are on screen, somewhere: in the dialog
  /// itself, or in the flip's picture of its back.
  Finder dialogContents() => find.text('Base stats');

  /// Taps the card in slot [index], and lets the route and the flight start.
  /// After this, time moves only as the test moves it.
  Future<void> open(WidgetTester tester, int index) async {
    await tester.tap(slot(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('opening', () {
    testWidgets('shows the card first, then the dialog', (tester) async {
      await pumpTeam(tester, '{"ids":[25]}');
      await open(tester, 0);

      // Early in the flight: the card is turning, and the dialog is not yet in
      // view.
      await tester.pump(const Duration(milliseconds: 100));
      expect(dialogContents(), findsNothing);

      // Late in it: the dialog has come round. What is seen is the flight's
      // picture of it; the dialog's own place is empty until the flight lands.
      await tester.pump(const Duration(milliseconds: 350));
      expect(dialogContents(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PokemonDetailDialog),
          matching: dialogContents(),
        ),
        findsNothing,
      );
    });

    testWidgets('ends as the ordinary dialog, with the card back in place', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25]}');
      await open(tester, 0);

      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsOneWidget);
      expect(dialogContents(), findsOneWidget);
      expect(find.text('Slot 1 of 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('flies from the card that was tapped, not another', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25,25,25]}');

      await open(tester, 2);
      await tester.pumpAndSettle();

      final hero = tester.widget<Hero>(
        find.descendant(
          of: find.byType(PokemonDetailDialog),
          matching: find.byType(Hero),
        ),
      );
      expect(hero.tag, slotHeroTag(2));
    });
  });

  group('closing', () {
    testWidgets('turns the dialog back into the card', (tester) async {
      await pumpTeam(tester, '{"ids":[25]}');
      await open(tester, 0);
      await tester.pumpAndSettle();

      await close(tester);

      // Early in the flight back: the dialog is still what is showing.
      await tester.pump(const Duration(milliseconds: 100));
      expect(dialogContents(), findsOneWidget);

      // Late in it: the card has come round, and the dialog has gone.
      await tester.pump(const Duration(milliseconds: 350));
      expect(dialogContents(), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(PokemonDetailDialog), findsNothing);
      expect(
        find.descendant(of: slot(0), matching: find.text('Pikachu')),
        findsOneWidget,
      );
    });

    testWidgets('the barrier and the escape key still close it', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25]}');

      await open(tester, 0);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(PokemonDetailDialog), findsNothing);

      await open(tester, 0);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PokemonDetailDialog), findsNothing);
    });

    testWidgets('after a move, goes back to the card it is now in', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25,10264]}');
      await open(tester, 1);
      await tester.pumpAndSettle();
      Object tag() => tester
          .widget<Hero>(
            find.descendant(
              of: find.byType(PokemonDetailDialog),
              matching: find.byType(Hero),
            ),
          )
          .tag;
      expect(tag(), slotHeroTag(1));

      await tester.tap(find.text('Move earlier'));
      await tester.pumpAndSettle();

      // It was in slot 1 and is now in slot 0, so that is the card it flips
      // back into.
      expect(tag(), slotHeroTag(0));
    });
  });

  /// Whether slot [index] is drawn as a gap, because its card is in the dialog.
  bool isGap(WidgetTester tester, int index) => find
      .descendant(
        of: slot(index),
        matching: find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity == 0,
        ),
      )
      .evaluate()
      .isNotEmpty;

  List<bool> gaps(WidgetTester tester, int count) => [
    for (var i = 0; i < count; i++) isGap(tester, i),
  ];

  /// A gap is only right while something else is showing the card: its flying
  /// copy, or the open dialog. A gap with neither is a hole in the team, and
  /// the card missing from where it is about to land is the same thing from the
  /// other side.
  void expectGapIsCovered(WidgetTester tester, String when) {
    if (!gaps(tester, 3).contains(true)) return;
    final flying = find.byKey(const Key('flip-shuttle')).evaluate().isNotEmpty;
    final dialog = find.byType(PokemonDetailDialog);
    final open =
        dialog.evaluate().isNotEmpty &&
        ModalRoute.of(tester.element(dialog))?.animation?.status ==
            AnimationStatus.completed;
    expect(flying || open, isTrue, reason: 'a gap with nothing in it $when');
  }

  group('the gap left by the card in the dialog', () {
    testWidgets('is that slot only, and cannot be touched or read', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25,10264,25]}');
      expect(gaps(tester, 3), [false, false, false]);

      await open(tester, 1);
      await tester.pumpAndSettle();

      expect(gaps(tester, 3), [false, true, false]);

      // The slot's own wrappers, which are the outermost ones in it. (There are
      // others inside, such as the throw-in's, which always ignore pointers.)
      bool ignoresPointer(int index) => tester
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: slot(index),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring;
      bool hiddenFromReaders(int index) => tester
          .widget<ExcludeSemantics>(
            find
                .descendant(
                  of: slot(index),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding;
      expect(
        [for (var i = 0; i < 3; i++) ignoresPointer(i)],
        [false, true, false],
      );
      expect(
        [for (var i = 0; i < 3; i++) hiddenFromReaders(i)],
        [false, true, false],
      );
    });

    testWidgets('follows the Pokémon, and the slot it left is live again', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25,10264]}');
      await open(tester, 1); // Koraidon.
      await tester.pumpAndSettle();
      expect(gaps(tester, 2), [false, true]);

      await tester.tap(find.text('Move earlier'));
      await tester.pumpAndSettle();

      // The dialog is still open. Koraidon is in slot 0, so that is the gap,
      // and slot 1 has Pikachu, who took its place, on show.
      expect(find.byType(PokemonDetailDialog), findsOneWidget);
      expect(gaps(tester, 2), [true, false]);
      expect(
        find.descendant(of: slot(0), matching: find.text(koraidonName)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: slot(1), matching: find.text('Pikachu')),
        findsOneWidget,
      );
    });

    testWidgets('lasts through the flight back, and goes as it lands', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25,10264]}');
      await open(tester, 1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move earlier'));
      await tester.pumpAndSettle();

      await close(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(gaps(tester, 2), [true, false]);
      await tester.pump(const Duration(milliseconds: 350));
      expect(gaps(tester, 2), [true, false]);

      await tester.pumpAndSettle();
      expect(gaps(tester, 2), [false, false]);
      expect(
        find.descendant(of: slot(0), matching: find.text(koraidonName)),
        findsOneWidget,
      );
    });

    testWidgets('is never left with nothing in it, frame by frame', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25,10264]}');
      const step = Duration(milliseconds: 16);

      await open(tester, 1);
      for (var i = 0; i < 50; i++) {
        await tester.pump(step);
        expectGapIsCovered(tester, 'while opening, frame $i');
      }
      await tester.tap(find.text('Move earlier'));
      await tester.pump(step);
      expectGapIsCovered(tester, 'just after a move');

      await close(tester);
      for (var i = 0; i < 50; i++) {
        await tester.pump(step);
        expectGapIsCovered(tester, 'while closing, frame $i');
      }
      expect(gaps(tester, 2), [false, false]);
    });

    testWidgets('is cleared if the dialog is removed without closing', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25]}');
      await open(tester, 0);
      await tester.pumpAndSettle();
      expect(gaps(tester, 1), [true]);

      // Taken off the screen at once, with no closing animation to end it.
      final dialog = find.byType(PokemonDetailDialog);
      final route = ModalRoute.of(tester.element(dialog))!;
      Navigator.of(tester.element(dialog)).removeRoute(route);
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsNothing);
      expect(gaps(tester, 1), [false]);
    });

    testWidgets('is not made when the card does not fly (reduced motion)', (
      tester,
    ) async {
      await pumpTeam(tester, '{"ids":[25]}', reduceMotion: true);

      await open(tester, 0);
      await tester.pumpAndSettle();

      expect(gaps(tester, 1), [false]);
    });
  });

  group('with reduced motion', () {
    testWidgets('there is no flip: the dialog fades in', (tester) async {
      await pumpTeam(tester, '{"ids":[25]}', reduceMotion: true);
      await open(tester, 0);

      // The contents are part of the dialog itself, already. In a flip they
      // would be in the flight's picture of its back until it landed.
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(PokemonDetailDialog),
          matching: dialogContents(),
        ),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(find.byType(PokemonDetailDialog), findsOneWidget);
    });

    testWidgets('and it is quicker than the flip', (tester) async {
      await pumpTeam(tester, '{"ids":[25]}', reduceMotion: true);
      await open(tester, 0);

      await tester.pump(detailFadeDuration + const Duration(milliseconds: 50));

      // The fade is complete, long before the flip would have been.
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(
          of: find.byType(PokemonDetailDialog),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fades, isNotEmpty);
      for (final fade in fades) {
        expect(fade.opacity.value, 1);
      }
      expect(detailFadeDuration, lessThan(detailFlipDuration));
    });

    testWidgets('and closing fades out with no flip', (tester) async {
      await pumpTeam(tester, '{"ids":[25]}', reduceMotion: true);
      await open(tester, 0);
      await tester.pumpAndSettle();

      await close(tester);
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsNothing);
    });
  });
}
