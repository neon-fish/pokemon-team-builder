import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/coverage/cell_colours.dart';

import '../../support/contrast.dart';

void main() {
  ColorScheme scheme(Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: brightness);

  const multipliers = [4.0, 2.0, 1.0, 0.5, 0.25, 0.0];

  for (final brightness in Brightness.values) {
    group('in the ${brightness.name} theme', () {
      for (final multiplier in multipliers) {
        test('the text is readable on a ${multiplier}x cell', () {
          final colours = cellColours(scheme(brightness), multiplier);

          expect(
            contrastBetween(colours.background, colours.text),
            greaterThanOrEqualTo(4.5),
          );
        });
      }

      test('weak, resistant and normal cells look different', () {
        final theme = scheme(brightness);

        final backgrounds = {
          cellColours(theme, 4).background,
          cellColours(theme, 2).background,
          cellColours(theme, 0.5).background,
          cellColours(theme, 1).background,
        };

        expect(backgrounds, hasLength(4));
      });
    });
  }

  test('resistant and immune cells share a colour', () {
    final theme = scheme(Brightness.light);

    expect(
      cellColours(theme, 0.5).background,
      cellColours(theme, 0).background,
    );
    expect(
      cellColours(theme, 0.25).background,
      cellColours(theme, 0).background,
    );
  });
}
