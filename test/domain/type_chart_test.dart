import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';

void main() {
  /// A chart where only a few matchups differ from 1.
  TypeChart chart() => TypeChart({
    for (final type in PokemonType.values) type: const {},
    PokemonType.fire: const {PokemonType.grass: 2, PokemonType.water: 0.5},
    PokemonType.normal: const {PokemonType.ghost: 0},
  });

  group('TypeChart', () {
    test('returns the listed multiplier', () {
      expect(chart().multiplier(PokemonType.fire, PokemonType.grass), 2);
      expect(chart().multiplier(PokemonType.fire, PokemonType.water), 0.5);
      expect(chart().multiplier(PokemonType.normal, PokemonType.ghost), 0);
    });

    test('an unlisted matchup is the ordinary 1', () {
      expect(chart().multiplier(PokemonType.fire, PokemonType.normal), 1);
    });

    test('is directional: attacking is not the same as defending', () {
      expect(chart().multiplier(PokemonType.grass, PokemonType.fire), 1);
    });
  });

  group('PokemonType.fromName', () {
    test('finds a modelled type', () {
      expect(PokemonType.fromName('fire'), PokemonType.fire);
    });

    test('returns null for a type we do not model', () {
      expect(PokemonType.fromName('stellar'), isNull);
      expect(PokemonType.fromName('Fire'), isNull, reason: 'case matters');
    });
  });
}
