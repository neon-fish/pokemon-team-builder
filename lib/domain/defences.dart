import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/team_analysis.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';

/// How much damage an attacking [type] does to one Pokémon, as a multiplier.
class TypeEffect {
  const TypeEffect(this.type, this.multiplier);

  final PokemonType type;
  final double multiplier;
}

/// How one Pokémon fares against the attacking types, sorted into groups.
/// Types that do normal damage are in none of them.
class Defences {
  const Defences({
    required this.weakTo,
    required this.resists,
    required this.immuneTo,
  });

  /// Types that do more than normal damage, worst first (4x before 2x).
  final List<TypeEffect> weakTo;

  /// Types that do less than normal damage, but some, strongest resistance
  /// first (0.25x before 0.5x).
  final List<TypeEffect> resists;

  /// Types that do no damage at all.
  final List<PokemonType> immuneTo;
}

/// Works out the [Defences] of a Pokémon with the given [types].
///
/// This is the team analysis applied to a team of one, so a dual-typed
/// Pokémon's multipliers combine in exactly the same way.
Defences defencesOf(List<PokemonType> types, TypeChart chart) {
  final weakTo = <TypeEffect>[];
  final resists = <TypeEffect>[];
  final immuneTo = <PokemonType>[];

  for (final matchup in analyseTeam([types], chart)) {
    // There is one slot, so one multiplier, and it is never null.
    final multiplier = matchup.multipliers.single!;
    if (multiplier > 1) {
      weakTo.add(TypeEffect(matchup.attacking, multiplier));
    } else if (multiplier == 0) {
      immuneTo.add(matchup.attacking);
    } else if (multiplier < 1) {
      resists.add(TypeEffect(matchup.attacking, multiplier));
    }
  }

  // `sort` is not stable, so ties are broken explicitly, by the usual order of
  // the types.
  weakTo.sort(
    (a, b) => a.multiplier != b.multiplier
        ? b.multiplier.compareTo(a.multiplier)
        : a.type.index.compareTo(b.type.index),
  );
  resists.sort(
    (a, b) => a.multiplier != b.multiplier
        ? a.multiplier.compareTo(b.multiplier)
        : a.type.index.compareTo(b.type.index),
  );

  return Defences(weakTo: weakTo, resists: resists, immuneTo: immuneTo);
}
