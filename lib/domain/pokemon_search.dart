import 'package:pokemon_team_builder/domain/pokemon_summary.dart';

/// The Pokémon in [index] that match what the user typed, best matches first.
///
/// - The text is tidied first: trimmed, lower-cased, and spaces become hyphens
///   (so `Mr Mime` finds `mr-mime`).
/// - Nothing typed gives the whole index.
/// - A name that starts with the text, or a Pokémon whose number is exactly the
///   text, is a best match. A name that merely contains the text comes after.
/// - Within each group the order of [index] is kept.
List<PokemonSummary> searchPokemon(List<PokemonSummary> index, String query) {
  final wanted = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  if (wanted.isEmpty) return index;

  // Null if the text is not a whole number.
  final wantedId = int.tryParse(wanted);

  final best = <PokemonSummary>[];
  final others = <PokemonSummary>[];
  for (final pokemon in index) {
    if (pokemon.id == wantedId || pokemon.name.startsWith(wanted)) {
      best.add(pokemon);
    } else if (pokemon.name.contains(wanted)) {
      others.add(pokemon);
    }
  }
  return [...best, ...others];
}
