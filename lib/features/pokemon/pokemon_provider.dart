import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';

/// One Pokémon, by id: `ref.watch(pokemonProvider(25))`.
///
/// This is a "family": a separate provider for each id, created on first use
/// and remembered, so the same Pokémon is only loaded once however many places
/// ask for it.
///
/// The state is an `AsyncValue<Result<Pokemon>>`. The two layers mean
/// different things:
///
/// - `AsyncValue`: is it still loading?
/// - `Result`: it finished, so did it work? A failure is a typed `ApiFailure`.
///
/// Failures are deliberately not thrown. Riverpod retries a provider that
/// throws, up to 10 times, on top of the retries the API client already does;
/// a plain 404 would be requested over and over. A real bug would still surface
/// as an `AsyncError`.
///
/// To retry after a failure: `ref.invalidate(pokemonProvider(id))`.
final pokemonProvider = FutureProvider.family<Result<Pokemon>, int>(
  (ref, id) => ref.watch(pokemonRepositoryProvider).loadPokemon(id),
);
