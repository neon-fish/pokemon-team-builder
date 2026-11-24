import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';
import 'package:pokemon_team_builder/features/detail/pokemon_detail_dialog.dart';
import 'package:pokemon_team_builder/features/detail/radar_chart.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_sprite.dart';
import 'package:pokemon_team_builder/features/team/team_analysis_provider.dart';

import '../../support/real_type_chart.dart';

void main() {
  late TypeChart chart;
  setUpAll(() async => chart = await loadRealTypeChart());

  const charizard = Pokemon(
    id: 6,
    name: 'charizard',
    types: [PokemonType.fire, PokemonType.flying],
    stats: BaseStats(
      hp: 78,
      attack: 84,
      defense: 78,
      specialAttack: 109,
      specialDefense: 85,
      speed: 100,
    ),
  );

  const snorlax = Pokemon(
    id: 143,
    name: 'snorlax',
    types: [PokemonType.normal],
    stats: BaseStats(
      hp: 160,
      attack: 110,
      defense: 65,
      specialAttack: 65,
      specialDefense: 110,
      speed: 30,
    ),
  );

  /// Opens the dialog for [pokemon] from a button, as a screen would. The type
  /// chart comes from [chartResult] unless a test says otherwise.
  Future<void> openDialog(
    WidgetTester tester,
    Pokemon pokemon, {
    Future<Result<TypeChart>> Function()? loadChart,
    int? slot,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          typeChartProvider.overrideWith(
            (ref) => loadChart == null ? Future.value(Ok(chart)) : loadChart(),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showPokemonDetail(context, pokemon, slot: slot),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('what it shows', () {
    testWidgets('the name, number and types', (tester) async {
      await openDialog(tester, charizard);

      expect(find.text('Charizard'), findsOneWidget);
      expect(find.text('#6'), findsOneWidget);
      expect(find.text('Flying'), findsOneWidget);
    });

    testWidgets('the base stats, as numbers and as a radar chart', (
      tester,
    ) async {
      await openDialog(tester, charizard);

      expect(find.text('Base stats'), findsOneWidget);
      expect(find.byType(RadarChart), findsOneWidget);
      for (final (name, value) in [
        ('HP', '78'),
        ('Attack', '84'),
        ('Defence', '78'),
        ('Sp. attack', '109'),
        ('Sp. defence', '85'),
        ('Speed', '100'),
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
        expect(find.text(value), findsWidgets, reason: '$name is $value');
      }
      expect(find.text('534'), findsOneWidget);
    });

    testWidgets('what it is weak to, resists and is immune to', (tester) async {
      await openDialog(tester, charizard);

      expect(find.text('Weak to'), findsOneWidget);
      expect(find.text('Resists'), findsOneWidget);
      expect(find.text('Immune to'), findsOneWidget);
      // Rock is the one 4x weakness; water and electric are 2x.
      expect(find.text('4×'), findsOneWidget);
      expect(find.text('2×'), findsNWidgets(2));
      // Bug and grass are resisted twice over, and four more once.
      expect(find.text('¼'), findsNWidgets(2));
      expect(find.text('½'), findsNWidgets(4));
      // Ground does nothing at all, so it has no multiplier to show.
      expect(find.text('Ground'), findsOneWidget);
    });

    testWidgets('leaves out a group that has nothing in it', (tester) async {
      // A normal-type resists nothing.
      await openDialog(tester, snorlax);

      expect(find.text('Weak to'), findsOneWidget);
      expect(find.text('Immune to'), findsOneWidget);
      expect(find.text('Resists'), findsNothing);
    });
  });

  group('moving', () {
    testWidgets('has no move buttons for a Pokémon that is not on the team', (
      tester,
    ) async {
      await openDialog(tester, charizard);

      expect(find.text('Move earlier'), findsNothing);
      expect(find.text('Move later'), findsNothing);
    });

    testWidgets('and no flip: it is a plain dialog', (tester) async {
      await openDialog(tester, charizard);

      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('one that is on the team takes part in the flip', (
      tester,
    ) async {
      await openDialog(tester, charizard, slot: 2);

      expect(find.byType(Hero), findsOneWidget);
    });

    testWidgets('has move buttons, and the slot, for one that is', (
      tester,
    ) async {
      await openDialog(tester, charizard, slot: 2);

      expect(find.text('Move earlier'), findsOneWidget);
      expect(find.text('Move later'), findsOneWidget);
      expect(find.text('Slot 3 of 6'), findsOneWidget);
    });

    testWidgets('come before the stats, so they are in view on opening', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openDialog(tester, charizard, slot: 2);

      final buttonTop = tester.getTopLeft(find.text('Move later')).dy;
      expect(
        buttonTop,
        lessThan(tester.getTopLeft(find.text('Base stats')).dy),
      );
      expect(tester.getBottomLeft(find.text('Move later')).dy, lessThan(500));
    });
  });

  group('the type chart', () {
    testWidgets('shows that it is waiting while it loads', (tester) async {
      final loading = Completer<Result<TypeChart>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [typeChartProvider.overrideWith((ref) => loading.future)],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const Scaffold(body: PokemonDetailDialog(charizard)),
          ),
        ),
      );
      await tester.pump();

      // The rest of the dialog does not wait for it.
      expect(find.text('Charizard'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Weak to'), findsNothing);

      loading.complete(Ok(chart));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Weak to'), findsOneWidget);
    });

    testWidgets('says when it could not be loaded, and can try again', (
      tester,
    ) async {
      var working = false;
      await openDialog(
        tester,
        charizard,
        loadChart: () async =>
            working ? Ok(chart) : const Err(OfflineFailure()),
      );

      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.text('Weak to'), findsNothing);
      // The rest of the dialog is still there.
      expect(find.text('Base stats'), findsOneWidget);

      working = true;
      // The dialog scrolls, and the button is below the fold on a short screen.
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be loaded'), findsNothing);
      expect(find.text('Weak to'), findsOneWidget);
    });
  });

  group('closing', () {
    testWidgets('the close button closes it', (tester) async {
      await openDialog(tester, charizard);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsNothing);
    });

    testWidgets('the escape key closes it', (tester) async {
      await openDialog(tester, charizard);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsNothing);
    });

    testWidgets('tapping outside it closes it', (tester) async {
      await openDialog(tester, charizard);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailDialog), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('on a wide screen the chart sits beside the bars', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openDialog(tester, charizard);

      final chartRight = tester.getRect(find.byType(RadarChart)).right;
      final barsLeft = tester.getTopLeft(find.text('HP')).dx;
      expect(chartRight, lessThanOrEqualTo(barsLeft));
      // The name is beside the picture.
      final pictureRight = tester.getRect(find.byType(PokemonSprite)).right;
      expect(
        tester.getTopLeft(find.text('Charizard')).dx,
        greaterThanOrEqualTo(pictureRight),
      );
    });

    testWidgets('on a narrow screen the chart is above the bars', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openDialog(tester, charizard);

      final chartBottom = tester.getRect(find.byType(RadarChart)).bottom;
      final barsTop = tester.getTopLeft(find.text('HP')).dy;
      expect(chartBottom, lessThanOrEqualTo(barsTop));
      // The name is below the picture.
      final pictureBottom = tester.getRect(find.byType(PokemonSprite)).bottom;
      expect(
        tester.getTopLeft(find.text('Charizard')).dy,
        greaterThanOrEqualTo(pictureBottom),
      );
    });

    testWidgets('fits a small screen at double text size, and scrolls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openDialog(tester, charizard, slot: 2);

      expect(tester.takeException(), isNull);
      // Scroll to the end: the last group is reachable.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Immune to'), findsOneWidget);
      expect(tester.getRect(find.text('Immune to')).bottom, lessThan(480));
      // The close button stayed put the whole way.
      expect(tester.getTopLeft(find.byTooltip('Close')).dy, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });

  group('for a screen reader', () {
    testWidgets('it is announced as a dialog', (tester) async {
      final semantics = tester.ensureSemantics();
      await openDialog(tester, charizard, slot: 1);

      final node = tester.getSemantics(find.byType(PokemonDetailDialog));

      expect(node.getSemanticsData().role, SemanticsRole.dialog);

      // Disposed here, not in `addTearDown`: the framework checks for leftover
      // handles before teardown callbacks run.
      semantics.dispose();
    });

    testWidgets('each weakness is one item, with its multiplier', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openDialog(tester, charizard);

      // The badge and its multiplier are joined into one label, on two lines.
      expect(find.bySemanticsLabel(RegExp(r'Rock\s+4×')), findsOneWidget);
      expect(find.bySemanticsLabel('Attack: 84'), findsOneWidget);

      semantics.dispose();
    });
  });
}
