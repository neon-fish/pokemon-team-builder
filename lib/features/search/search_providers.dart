import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/pokemon_search.dart';
import 'package:pokemon_team_builder/domain/pokemon_summary.dart';

/// Every Pokémon's name and id, loaded once. See `pokemonProvider` for why
/// failures are values inside the `AsyncValue`. To retry:
/// `ref.invalidate(pokemonIndexProvider)`.
final pokemonIndexProvider = FutureProvider<Result<List<PokemonSummary>>>(
  (ref) => ref.watch(pokemonIndexRepositoryProvider).loadIndex(),
);

/// What the user has typed in the search field.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// What the UI can show for the search.
sealed class SearchState {
  const SearchState();
}

/// Still waiting for the list of Pokémon.
final class SearchLoading extends SearchState {
  const SearchLoading();
}

/// The list of Pokémon could not be loaded, so there is nothing to search.
final class SearchUnavailable extends SearchState {
  const SearchUnavailable(this.failure);

  final ApiFailure failure;
}

/// The Pokémon that match the query, best first. Empty if none do.
final class SearchReady extends SearchState {
  const SearchReady(this.matches, {required this.query});

  final List<PokemonSummary> matches;

  /// What was typed, without surrounding spaces. For messages such as "No
  /// Pokémon match ...".
  final String query;
}

/// The search results, updated as the query changes or the list arrives.
///
/// The whole list is searched on each keystroke. That is about 1,350 short
/// strings, which is far too little work to need waiting for the user to stop
/// typing.
final searchProvider = Provider<SearchState>((ref) {
  // `.value` is null while an `AsyncValue` is still loading.
  final indexResult = ref.watch(pokemonIndexProvider).value;
  if (indexResult == null) return const SearchLoading();

  switch (indexResult) {
    case Err(:final failure):
      return SearchUnavailable(failure);
    case Ok(value: final index):
      final query = ref.watch(searchQueryProvider);
      return SearchReady(searchPokemon(index, query), query: query.trim());
  }
});
