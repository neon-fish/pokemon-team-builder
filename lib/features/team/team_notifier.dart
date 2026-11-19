import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/domain/team.dart';

/// The user's team. Loaded from storage when first read, saved after every
/// change.
///
/// The state is an `AsyncValue<Team>`: loading for a moment at start-up, then
/// data. Loading cannot fail (a problem with storage gives an empty team), so
/// there is no error state to handle.
class TeamNotifier extends AsyncNotifier<Team> {
  @override
  Future<Team> build() => ref.watch(teamRepositoryProvider).load();

  /// Adds a Pokémon to the team and saves it. If the team is full, does nothing.
  Future<void> add(int id) => _change((team) => team.add(id));

  /// Removes a Pokémon from the team and saves it. If the Pokémon is not on the
  /// team, does nothing.
  Future<void> removeAt(int index) => _change((team) => team.removeAt(index));

  Future<void> _change(Team Function(Team team) change) async {
    // Make sure the saved team has loaded before changing anything.
    await future;

    // From here to the assignment there is no `await`, so nothing else can
    // run in between: two quick changes cannot overwrite each other.
    final updated = change(state.requireValue);
    if (identical(updated, state.requireValue)) return; // nothing changed
    state = AsyncData(updated);

    await ref.read(teamRepositoryProvider).save(updated);
  }
}

final teamProvider = AsyncNotifierProvider<TeamNotifier, Team>(
  TeamNotifier.new,
);
