import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';

/// One Pokémon, by id: `ref.watch(pokemonProvider(25))`.
///
/// A "family": one provider per id, created on first use and remembered, so a
/// Pokémon is loaded once however many places ask for it.
///
/// The state is an `AsyncValue<Result<Pokemon>>`: `AsyncValue` says whether it
/// is still loading, and `Result` whether it worked, with a typed `ApiFailure`
/// if not. Failures are not thrown, because Riverpod would retry a throwing
/// provider up to 10 times on top of the API client's own retries (D19). A real
/// bug still surfaces as an `AsyncError`.
///
/// To retry after a failure: `ref.invalidate(pokemonProvider(id))`.
final pokemonProvider = FutureProvider.family<Result<Pokemon>, int>(
  (ref, id) => ref.watch(pokemonRepositoryProvider).loadPokemon(id),
);
