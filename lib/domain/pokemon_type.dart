/// The 18 Pokémon types that take part in damage calculations.
///
/// PokeAPI also lists a few special types (`stellar`, `unknown`, `shadow`) that
/// never appear in the type chart, so they are deliberately not modelled.
enum PokemonType {
  normal,
  fighting,
  flying,
  poison,
  ground,
  rock,
  bug,
  ghost,
  steel,
  fire,
  water,
  grass,
  electric,
  psychic,
  ice,
  dragon,
  dark,
  fairy;

  /// Maps each `name` ("fire") to its value, built once.
  static final Map<String, PokemonType> _byName = values.asNameMap();

  /// The type called [name] in the API, or null if it is not one we model.
  static PokemonType? fromName(String name) => _byName[name];
}
