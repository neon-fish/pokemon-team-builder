import 'package:pokemon_team_builder/domain/pokemon_type.dart';

/// Who hits whom, and how hard: the damage multiplier for every pair of types.
class TypeChart {
  /// [attacks] has one entry per attacking type. Each entry lists only the
  /// defending types where the multiplier is not the ordinary 1.
  TypeChart(this._attacks)
    : assert(
        _attacks.length == PokemonType.values.length,
        'A chart needs an entry for every type',
      );

  final Map<PokemonType, Map<PokemonType, double>> _attacks;

  /// The damage multiplier when a move of type [attacking] hits a Pokémon of
  /// type [defending]: 2 (super effective), 0.5 (not very effective), 0 (no
  /// effect) or 1 (ordinary).
  double multiplier(PokemonType attacking, PokemonType defending) =>
      _attacks[attacking]?[defending] ?? 1;
}
