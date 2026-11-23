import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/features/detail/radar_chart.dart';

void main() {
  const labels = ['HP', 'Atk', 'Def', 'SpA', 'SpD', 'Spe'];

  Future<void> pumpChart(
    WidgetTester tester, {
    List<int> values = const [35, 55, 40, 50, 50, 90],
    double size = 240,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: size,
              child: RadarChart(labels: labels, values: values),
            ),
          ),
        ),
      ),
    );
  }

  /// The render object that does the drawing.
  RenderObject painted(WidgetTester tester) => tester.renderObject(
    find.descendant(
      of: find.byType(RadarChart),
      matching: find.byType(CustomPaint),
    ),
  );

  /// What the chart draws first: three rings, then a spoke for each of the six
  /// axes. A pattern must name every drawing call of a kind, in order, so the
  /// tests of the shape start from this.
  PaintPattern grid() => paints
    ..path(style: PaintingStyle.stroke)
    ..path(style: PaintingStyle.stroke)
    ..path(style: PaintingStyle.stroke)
    ..line()
    ..line()
    ..line()
    ..line()
    ..line()
    ..line();

  testWidgets('draws the grid, then the shape: a fill and an outline', (
    tester,
  ) async {
    await pumpChart(tester);

    expect(
      painted(tester),
      grid()
        ..path(style: PaintingStyle.fill)
        ..path(style: PaintingStyle.stroke, strokeWidth: 2),
    );
  });

  testWidgets('the shape covers the centre, and stays inside the chart', (
    tester,
  ) async {
    await pumpChart(tester, size: 240);

    expect(
      painted(tester),
      grid()..path(
        style: PaintingStyle.fill,
        includes: [const Offset(120, 120)],
        excludes: [const Offset(2, 2), const Offset(238, 238)],
      ),
    );
  });

  testWidgets('is a picture only: nothing for a screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpChart(tester);

    expect(find.bySemanticsLabel('HP'), findsNothing);
    expect(find.bySemanticsLabel('Atk'), findsNothing);

    semantics.dispose();
  });

  testWidgets('copes with the smallest and the largest values', (tester) async {
    await pumpChart(tester, values: const [0, 0, 0, 0, 0, 0]);
    expect(tester.takeException(), isNull);

    await pumpChart(tester, values: const [255, 255, 255, 255, 255, 255]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copes with a tiny space and with double text size', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // Too small for the labels to leave any room for the chart itself.
    await pumpChart(tester, size: 40);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the shape grows with the values', (tester) async {
    // A point 30 pixels straight above the centre of the 240 pixel chart. The
    // top corner of the shape is at about 15 pixels for a stat of 35, and
    // about 45 for a stat of 100.
    const point = Offset(120, 90);

    await pumpChart(tester, values: const [35, 35, 35, 35, 35, 35]);
    expect(
      painted(tester),
      grid()..path(style: PaintingStyle.fill, excludes: [point]),
    );

    await pumpChart(tester, values: const [100, 100, 100, 100, 100, 100]);
    expect(
      painted(tester),
      grid()..path(style: PaintingStyle.fill, includes: [point]),
    );
  });
}
