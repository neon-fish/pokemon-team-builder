import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';

/// How a team fares against one attacking type.
class TypeMatchup {
  const TypeMatchup(this.attacking, this.multipliers);

  final PokemonType attacking;

  /// The damage multiplier each slot takes from [attacking], in slot order:
  /// 4, 2, 1, 0.5, 0.25 or 0. A slot with nothing to analyse (empty, or its
  /// Pokémon has not loaded) is null.
  final List<double?> multipliers;

  /// How many slots were analysed: those that are not null.
  int get knownCount => multipliers.nonNulls.length;

  /// Members that take more than normal damage.
  int get weakCount => multipliers.nonNulls.where((m) => m > 1).length;

  /// Members that take less than normal damage, but some.
  int get resistantCount =>
      multipliers.nonNulls.where((m) => m > 0 && m < 1).length;

  /// Members that take no damage at all.
  int get immuneCount => multipliers.nonNulls.where((m) => m == 0).length;

  /// Weak members minus those that resist or ignore the type. Positive means
  /// the team is more likely to be hurt than helped by this type; the larger,
  /// the worse.
  int get netExposure => weakCount - resistantCount - immuneCount;

  /// Whether the team is exposed to this type: more members are weak to it than
  /// can resist or ignore it.
  ///
  /// A rule of thumb: it counts members, not how bad each weakness is (a 4x
  /// weakness counts the same as a 2x one), and it looks only at defence.
  bool get isExposed => netExposure > 0;
}

/// Works out how a team fares against every attacking type.
///
/// [slotTypes] has an entry for each slot, in slot order: the types of the
/// Pokémon there (one or two), or null if there is nothing to analyse. Keeping
/// the empty and unloaded slots, as nulls, means each result lines up with its
/// slot. The result has one [TypeMatchup] per attacking type, in the order of
/// [PokemonType.values].
List<TypeMatchup> analyseTeam(
  List<List<PokemonType>?> slotTypes,
  TypeChart chart,
) {
  return [
    for (final attacking in PokemonType.values)
      TypeMatchup(attacking, [
        for (final types in slotTypes)
          types == null ? null : _multiplierAgainst(attacking, types, chart),
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
