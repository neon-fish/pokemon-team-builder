import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/type_colours.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';

/// The WCAG contrast ratio between two colours: 1 (identical) to 21 (black on
/// white). Written out here, rather than reusing the app's rule, so the test is
/// an independent check.
double contrastBetween(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (max(first, second) + 0.05) / (min(first, second) + 0.05);
}

void main() {
  test('every type has its own colour', () {
    final colours = {for (final type in PokemonType.values) typeColour(type)};

    expect(colours, hasLength(PokemonType.values.length));
  });

  group('the text on a type badge', () {
    for (final type in PokemonType.values) {
      test('is readable on ${type.name}', () {
        final background = typeColour(type);
        final text = readableTextOn(background);

        expect(contrastBetween(background, text), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('readableTextOn', () {
    test('is white on a dark colour', () {
      expect(readableTextOn(const Color(0xFF000000)), Colors.white);
      expect(readableTextOn(const Color(0xFF1A237E)), Colors.white);
    });

    test('is black on a light colour', () {
      expect(readableTextOn(const Color(0xFFFFFFFF)), Colors.black);
      expect(readableTextOn(const Color(0xFFF7D02C)), Colors.black);
    });
  });
}
