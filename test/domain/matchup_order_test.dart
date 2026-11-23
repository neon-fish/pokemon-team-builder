import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/matchup_order.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/team_analysis.dart';

void main() {
  /// What the types are, in the order a result lists them.
  List<PokemonType> typesOf(List<TypeMatchup> matchups) => [
    for (final matchup in matchups) matchup.attacking,
  ];

  /// A matchup built straight from the multipliers, so each test's numbers are
  /// visible in the test.
  TypeMatchup matchup(PokemonType type, List<double?> multipliers) =>
      TypeMatchup(type, multipliers);

  // A small team of three, against four types.
  //   fire:   all three weak            weak 3, net +3
  //   ice:    two weak, one neutral     weak 2, net +2
  //   water:  one weak, one resists     weak 1, net 0
  //   normal: all neutral               weak 0, net 0
  //   grass:  two resist                weak 0, net -2
  final fire = matchup(PokemonType.fire, [2, 2, 2]);
  final ice = matchup(PokemonType.ice, [2, 2, 1]);
  final water = matchup(PokemonType.water, [2, 0.5, 1]);
  final normal = matchup(PokemonType.normal, [1, 1, 1]);
  final grass = matchup(PokemonType.grass, [0.5, 0.5, 1]);

  group('standard order', () {
    test('is the order of the types, whatever order they come in', () {
      final shuffled = [grass, fire, normal, ice, water];

      final sorted = sortMatchups(shuffled, MatchupOrder.standard);

      expect(typesOf(sorted), [
        PokemonType.normal,
        PokemonType.fire,
        PokemonType.water,
        PokemonType.grass,
        PokemonType.ice,
      ]);
    });
  });

  group('biggest gaps first', () {
    test('puts the types the team is most exposed to first', () {
      final sorted = sortMatchups([
        grass,
        water,
        fire,
        ice,
      ], MatchupOrder.biggestGapsFirst);

      expect(typesOf(sorted), [
        PokemonType.fire,
        PokemonType.ice,
        PokemonType.water,
        PokemonType.grass,
      ]);
    });

    test('with equal exposure, more weak members comes first', () {
      // Water and normal both have net 0, but water has a weak member. Normal
      // comes first in the standard order, so this shows the rule is applied.
      final sorted = sortMatchups([
        normal,
        water,
      ], MatchupOrder.biggestGapsFirst);

      expect(typesOf(sorted), [PokemonType.water, PokemonType.normal]);
    });

    test('with everything else equal, the standard order decides', () {
      final a = matchup(PokemonType.rock, [2, 0.5]);
      final b = matchup(PokemonType.fire, [2, 0.5]);
      final c = matchup(PokemonType.bug, [2, 0.5]);

      final sorted = sortMatchups([a, b, c], MatchupOrder.biggestGapsFirst);

      // The standard order has rock, then bug, then fire.
      expect(typesOf(sorted), [
        PokemonType.rock,
        PokemonType.bug,
        PokemonType.fire,
      ]);
    });

    test('gives the same answer however the input is arranged', () {
      final all = [fire, ice, water, normal, grass];
      final expected = typesOf(
        sortMatchups(all, MatchupOrder.biggestGapsFirst),
      );

      for (var seed = 0; seed < 20; seed++) {
        final shuffled = [...all]..shuffle(Random(seed));
        final sorted = sortMatchups(shuffled, MatchupOrder.biggestGapsFirst);
        expect(typesOf(sorted), expected, reason: 'seed $seed');
      }
    });

    test('ignores slots with nothing in them', () {
      // The same exposure as `ice`, with gaps in the team.
      final withGaps = matchup(PokemonType.ice, [null, 2, null, 2, 1]);

      expect(withGaps.netExposure, ice.netExposure);
    });

    test('an empty team gives the standard order', () {
      final nobody = [
        for (final type in PokemonType.values.reversed)
          matchup(type, [null, null, null]),
      ];

      final sorted = sortMatchups(nobody, MatchupOrder.biggestGapsFirst);

      expect(typesOf(sorted), PokemonType.values);
    });
  });

  test('the list that was passed in is left as it was', () {
    final original = [grass, fire, water];

    sortMatchups(original, MatchupOrder.biggestGapsFirst);

    expect(typesOf(original), [
      PokemonType.grass,
      PokemonType.fire,
      PokemonType.water,
    ]);
  });
}
