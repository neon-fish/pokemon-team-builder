import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/features/detail/stat_bars.dart';

void main() {
  const stats = BaseStats(
    hp: 35,
    attack: 55,
    defense: 40,
    specialAttack: 50,
    specialDefense: 51,
    speed: 90,
  );

  Future<void> pumpBars(
    WidgetTester tester,
    BaseStats stats, {
    double width = 300,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          // Scrolls, as it does in the dialog, so tall content is not an
          // overflow.
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(width: width, child: StatBars(stats)),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows each stat by name, with its number', (tester) async {
    await pumpBars(tester, stats);

    for (final (name, value) in [
      ('HP', '35'),
      ('Attack', '55'),
      ('Defence', '40'),
      ('Sp. attack', '50'),
      ('Sp. defence', '51'),
      ('Speed', '90'),
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
      expect(find.text(value), findsOneWidget, reason: '$name is $value');
    }
  });

  testWidgets('shows the total', (tester) async {
    await pumpBars(tester, stats);

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('321'), findsOneWidget);
  });

  testWidgets('each bar is as long as its stat, in stat order', (tester) async {
    await pumpBars(tester, stats);

    final lengths = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((box) => box.widthFactor);

    expect(lengths, [
      35 / 200,
      55 / 200,
      40 / 200,
      50 / 200,
      51 / 200,
      90 / 200,
    ]);
  });

  testWidgets('each bar is drawn: it has a size, in proportion to its stat', (
    tester,
  ) async {
    await pumpBars(tester, stats, width: 300);

    // The first bar is HP, 35 out of 200. Reading the property is not enough:
    // a childless box can be told a width and still be zero pixels tall.
    final track = find.byType(FractionallySizedBox).first;
    final fill = find.descendant(
      of: track,
      matching: find.byType(DecoratedBox),
    );
    final trackSize = tester.getSize(
      find.ancestor(of: track, matching: find.byType(DecoratedBox)).first,
    );
    final fillSize = tester.getSize(fill);

    expect(fillSize.height, 8);
    expect(fillSize.width, closeTo(trackSize.width * 35 / 200, 0.01));
  });

  testWidgets('a stat beyond the scale fills its bar, no more', (tester) async {
    await pumpBars(
      tester,
      const BaseStats(
        hp: 255,
        attack: 10,
        defense: 10,
        specialAttack: 10,
        specialDefense: 10,
        speed: 10,
      ),
    );

    final first = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .first;
    expect(first.widthFactor, 1);
  });

  testWidgets('a screen reader hears one sentence per stat', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBars(tester, stats);

    expect(find.bySemanticsLabel('Attack: 55'), findsOneWidget);
    expect(find.bySemanticsLabel('Sp. defence: 51'), findsOneWidget);
    expect(find.bySemanticsLabel('Total: 321'), findsOneWidget);
    // The numbers are not also read out a second time on their own.
    expect(find.bySemanticsLabel('55'), findsNothing);

    // Disposed here, not in `addTearDown`: the framework checks for leftover
    // handles before teardown callbacks run.
    semantics.dispose();
  });

  testWidgets('fits a narrow space at double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpBars(tester, stats, width: 200);

    expect(tester.takeException(), isNull);
  });
}
