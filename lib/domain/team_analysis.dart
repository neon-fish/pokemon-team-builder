import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';

/// How a team fares against one attacking type.
class TypeMatchup {
  const TypeMatchup(this.attacking, this.multipliers);

  final PokemonType attacking;

  /// The damage multiplier each member takes from [attacking], in slot order:
  /// 4, 2, 1, 0.5, 0.25 or 0.
  final List<double> multipliers;

  /// Members that take more than normal damage.
  int get weakCount => multipliers.where((m) => m > 1).length;

  /// Members that take less than normal damage, but some.
  int get resistantCount => multipliers.where((m) => m > 0 && m < 1).length;

  /// Members that take no damage at all.
  int get immuneCount => multipliers.where((m) => m == 0).length;

  /// Whether the team is exposed to this type: more members are weak to it than
  /// can resist or ignore it.
  ///
  /// A rule of thumb: it counts members, not how bad each weakness is (a 4x
  /// weakness counts the same as a 2x one), and it looks only at defence.
  bool get isExposed => weakCount > (resistantCount + immuneCount);
}

/// Works out how a team fares against every attacking type.
///
/// [memberTypes] holds the types of each member, in slot order (one or two
/// each). The result has one [TypeMatchup] per attacking type, in the order of
/// [PokemonType.values].
List<TypeMatchup> analyseTeam(
  List<List<PokemonType>> memberTypes,
  TypeChart chart,
) {
  return [
    for (final attacking in PokemonType.values)
      TypeMatchup(attacking, [
        for (final types in memberTypes)
          _multiplierAgainst(attacking, types, chart),
      ]),
  ];
}

/// The damage a Pokémon with [defending] types takes from [attacking].
///
/// A dual-typed Pokémon is hit by each type in turn, so the multipliers
/// combine by multiplication: 2 x 2 is 4, 2 x 0.5 cancels to 1, and anything
/// x 0 is immune. All the values are exact in floating point (powers of two).
double _multiplierAgainst(
  PokemonType attacking,
  List<PokemonType> defending,
  TypeChart chart,
) {
  var multiplier = 1.0;
  for (final type in defending) {
    multiplier *= chart.multiplier(attacking, type);
  }
  return multiplier;
}
