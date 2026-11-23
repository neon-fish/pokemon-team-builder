import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/defences.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';

import '../support/real_type_chart.dart';

void main() {
  // The real chart, with the Gen 6+ rules.
  late TypeChart chart;
  setUpAll(() async => chart = await loadRealTypeChart());

  /// A group as `type: multiplier` pairs, to compare in one go.
  Map<PokemonType, double> asMap(List<TypeEffect> effects) => {
    for (final effect in effects) effect.type: effect.multiplier,
  };

  group('Charizard (fire / flying)', () {
    late Defences defences;
    setUp(() {
      defences = defencesOf([PokemonType.fire, PokemonType.flying], chart);
    });

    test('is weak to rock (4x), then water and electric (2x)', () {
      expect(asMap(defences.weakTo), {
        PokemonType.rock: 4,
        PokemonType.water: 2,
        PokemonType.electric: 2,
      });
    });

    test('lists the worst weakness first, then the usual type order', () {
      expect(defences.weakTo.map((e) => e.type), [
        PokemonType.rock,
        PokemonType.water,
        PokemonType.electric,
      ]);
    });

    test('resists six types, the strongest resistances first', () {
      expect(defences.resists.map((e) => e.type), [
        // 0.25x
        PokemonType.bug,
        PokemonType.grass,
        // 0.5x
        PokemonType.fighting,
        PokemonType.steel,
        PokemonType.fire,
        PokemonType.fairy,
      ]);
      expect(defences.resists.first.multiplier, 0.25);
      expect(defences.resists.last.multiplier, 0.5);
    });

    test('is immune to ground', () {
      expect(defences.immuneTo, [PokemonType.ground]);
    });

    test('leaves types that do normal damage out of every group', () {
      // Ice does 2x to flying and 0.5x to fire, which cancel out.
      final mentioned = {
        ...defences.weakTo.map((e) => e.type),
        ...defences.resists.map((e) => e.type),
        ...defences.immuneTo,
      };
      expect(mentioned, isNot(contains(PokemonType.ice)));
      expect(mentioned, hasLength(10));
    });
  });

  group('a single-typed Pokémon (normal)', () {
    test('is weak to fighting, immune to ghost, and resists nothing', () {
      final defences = defencesOf([PokemonType.normal], chart);

      expect(asMap(defences.weakTo), {PokemonType.fighting: 2});
      expect(defences.immuneTo, [PokemonType.ghost]);
      expect(defences.resists, isEmpty);
    });
  });
}
