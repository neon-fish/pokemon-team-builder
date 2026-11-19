/// Just enough about a Pokémon to list and search for it: the id to load it
/// with, and the name to match against.
///
/// Form variants (mega evolutions, regional forms) are separate entries with
/// ids from 10001 upwards.
class PokemonSummary {
  const PokemonSummary({required this.id, required this.name});

  final int id;

  /// The API's name, such as `pikachu-rock-star`.
  final String name;
}
