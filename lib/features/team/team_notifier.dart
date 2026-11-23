import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/domain/team.dart';
import 'package:pokemon_team_builder/features/team/add_target_notifier.dart';

/// The user's team. Loaded from storage when first read, saved after every
/// change.
///
/// The state is an `AsyncValue<Team>`: loading for a moment at start-up, then
/// data. Loading cannot fail (a problem with storage gives an empty team), so
/// there is no error state to handle.
class TeamNotifier extends AsyncNotifier<Team> {
  @override
  Future<Team> build() => ref.watch(teamRepositoryProvider).load();

  /// Puts a Pokémon in the first empty slot and saves the team. If the team is
  /// full, does nothing.
  Future<void> add(int id) => _change((team) => team.add(id));

  /// Puts a Pokémon in a specific slot and saves the team. If that slot is
  /// already occupied, or if the index is out of range, does
  /// nothing.
  Future<void> addAt(int index, int id) =>
      _change((team) => team.addAt(index, id));

  /// Adds a Pokémon the user picked from the search, and saves the team.
  ///
  /// It goes into the slot the user chose ([addTargetProvider]) if that is
  /// still empty, otherwise into the first empty slot. The choice is used up
  /// either way. If the team is full, does nothing.
  Future<void> addPicked(int id) {
    final target = ref.read(addTargetProvider);
    ref.read(addTargetProvider.notifier).choose(null);

    // Deciding inside `_change` looks at the team as it is at that moment, so
    // a slot filled in the meantime is not overwritten.
    return _change((team) {
      if (target != null &&
          target < Team.slotCount &&
          team.slots[target] == null) {
        return team.addAt(target, id);
      }
      return team.add(id);
    });
  }

  /// Empties a slot and saves the team. If there is no such slot, or it is
  /// already empty, does nothing.
  Future<void> removeAt(int index) => _change((team) => team.removeAt(index));

  /// Swaps two slots (or moves a Pokémon into an empty one) and saves the team.
  /// If that would change nothing, does nothing.
  Future<void> move(int from, int to) => _change((team) => team.move(from, to));

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
