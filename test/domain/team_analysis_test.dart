import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/team_analysis.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';

import '../support/real_type_chart.dart';

void main() {
  // The real chart, with the Gen 6+ rules.
  late TypeChart chart;
  setUpAll(() async => chart = await loadRealTypeChart());

  // A few well-known Pokémon, by their types.
  const charizard = [PokemonType.fire, PokemonType.flying];
  const blastoise = [PokemonType.water];
  const venusaur = [PokemonType.grass, PokemonType.poison];

  TypeMatchup against(List<TypeMatchup> analysis, PokemonType attacking) =>
      analysis.singleWhere((m) => m.attacking == attacking);

  group('one dual-typed Pokémon (Charizard, fire / flying)', () {
    List<double?> multipliersFrom(PokemonType attacking) {
      final analysis = analyseTeam([charizard], chart);
      return against(analysis, attacking).multipliers;
    }

    test('two weaknesses on top of each other make a 4x weakness', () {
      expect(multipliersFrom(PokemonType.rock), [4]);
    });

    test('a single weakness is 2x', () {
      expect(multipliersFrom(PokemonType.water), [2]);
      expect(multipliersFrom(PokemonType.electric), [2]);
    });

    test('two resistances make a 0.25x resistance', () {
      expect(multipliersFrom(PokemonType.grass), [0.25]);
      expect(multipliersFrom(PokemonType.bug), [0.25]);
    });

    test('an immunity beats everything else', () {
      expect(multipliersFrom(PokemonType.ground), [0]);
    });

    test('a weakness and a resistance cancel out', () {
      // Fire resists ice, but flying is weak to it.
      expect(multipliersFrom(PokemonType.ice), [1]);
    });

    test('a single resistance is 0.5x', () {
      expect(multipliersFrom(PokemonType.fire), [0.5]);
    });
  });

  group('a team of the three original starters', () {
    late List<TypeMatchup> analysis;
    setUp(() {
      analysis = analyseTeam([charizard, blastoise, venusaur], chart);
    });

    test('has one result per attacking type, in the standard order', () {
      expect(analysis.map((m) => m.attacking), PokemonType.values);
    });

    test('lists each member\'s multiplier, in slot order', () {
      // Charizard 2x, Blastoise 0.5x (water resists water), Venusaur 0.5x.
      expect(against(analysis, PokemonType.water).multipliers, [2, 0.5, 0.5]);
    });

    test('counts weak, resistant and immune members', () {
      final ground = against(analysis, PokemonType.ground);
      // Charizard is immune; Blastoise neutral; Venusaur 1x (grass resists,
      // poison is weak).
      expect(ground.immuneCount, 1);
      expect(ground.weakCount, 0);
      expect(ground.resistantCount, 0);
    });

    test('exposed when more members are weak than can resist', () {
      // Charizard and Blastoise are weak to electric; only Venusaur resists.
      final electric = against(analysis, PokemonType.electric);
      expect(electric.weakCount, 2);
      expect(electric.resistantCount, 1);
      expect(electric.isExposed, isTrue);
    });

    test('a lone weakness with no answer is still exposed', () {
      // Only Venusaur is weak to psychic, and nobody resists it.
      final psychic = against(analysis, PokemonType.psychic);
      expect(psychic.weakCount, 1);
      expect(psychic.isExposed, isTrue);
    });

    test('not exposed when resistances cover the weaknesses', () {
      // Only Venusaur is weak to fire; Charizard and Blastoise resist it.
      final fire = against(analysis, PokemonType.fire);
      expect(fire.weakCount, 1);
      expect(fire.resistantCount, 2);
      expect(fire.isExposed, isFalse);
    });

    test('not exposed when weaknesses and resistances are level', () {
      // Venusaur is weak to ice; Blastoise resists it; Charizard is neutral.
      final ice = against(analysis, PokemonType.ice);
      expect(ice.weakCount, 1);
      expect(ice.resistantCount, 1);
      expect(ice.isExposed, isFalse);
    });
  });

  test('six of the same Pokémon stack the same weakness', () {
    const charmander = [PokemonType.fire];
    final analysis = analyseTeam(List.filled(6, charmander), chart);

    final water = against(analysis, PokemonType.water);

    expect(water.multipliers, [2, 2, 2, 2, 2, 2]);
    expect(water.weakCount, 6);
    expect(water.isExposed, isTrue);
  });

  test('an empty team is exposed to nothing', () {
    final analysis = analyseTeam([], chart);

    expect(analysis, hasLength(PokemonType.values.length));
    expect(analysis.every((m) => m.multipliers.isEmpty), isTrue);
    expect(analysis.any((m) => m.isExposed), isFalse);
  });

  group('slots with nothing to analyse', () {
    // Slot 0 empty, slot 1 Charizard, slot 2 not loaded, slot 3 Blastoise.
    late List<TypeMatchup> analysis;
    setUp(() {
      analysis = analyseTeam([null, charizard, null, blastoise], chart);
    });

    test('keep their place, as null', () {
      // Charizard 2x and Blastoise 0.5x against water.
      expect(against(analysis, PokemonType.water).multipliers, [
        null,
        2,
        null,
        0.5,
      ]);
    });

    test('are left out of every count', () {
      final water = against(analysis, PokemonType.water);

      expect(water.knownCount, 2);
      expect(water.weakCount, 1);
      expect(water.resistantCount, 1);
      expect(water.immuneCount, 0);
    });

    test('a team of only nulls is exposed to nothing', () {
      final nobody = analyseTeam([null, null, null], chart);

      expect(nobody.every((m) => m.knownCount == 0), isTrue);
      expect(nobody.any((m) => m.isExposed), isFalse);
    });
  });

  group('net exposure', () {
    test('is weak members minus those that resist or ignore the type', () {
      // Against electric: Charizard weak, Blastoise weak, Venusaur resists.
      final analysis = analyseTeam([charizard, blastoise, venusaur], chart);

      expect(against(analysis, PokemonType.electric).netExposure, 1);
      // Against ground: Charizard immune, the others neutral.
      expect(against(analysis, PokemonType.ground).netExposure, -1);
    });

    test('is positive exactly when the team is exposed', () {
      final analysis = analyseTeam([charizard, blastoise, venusaur], chart);

      for (final matchup in analysis) {
        expect(matchup.netExposure > 0, matchup.isExposed);
      }
    });
  });
}
