import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

/// The Pokémon in the team, as far as they have loaded.
class TeamMembers {
  const TeamMembers(this.slots, {required this.missingCount});

  /// One entry per slot, in slot order. Null for a slot with nothing to use:
  /// empty, or its Pokémon has not loaded (yet) or failed to.
  final List<Pokemon?> slots;

  /// Members left out because they are still loading or failed to load. An
  /// empty slot is not a member, so it does not count. When this is not zero,
  /// anything worked out from the team is incomplete, and the UI should say so:
  /// a team that looks safe may only be missing a member.
  final int missingCount;

  /// The Pokémon that have loaded, in slot order.
  List<Pokemon> get loaded => slots.nonNulls.toList();
}

/// The team's Pokémon, or null until the saved team has loaded. It updates by
/// itself as each member loads, and as the team changes.
final teamMembersProvider = Provider<TeamMembers?>((ref) {
  // `.value` is null while an `AsyncValue` is still loading.
  final team = ref.watch(teamProvider).value;
  if (team == null) return null;

  final slots = <Pokemon?>[];
  var missingCount = 0;
  for (final id in team.slots) {
    if (id == null) {
      slots.add(null);
      continue;
    }
    final pokemon = ref.watch(pokemonProvider(id)).value?.valueOrNull;
    if (pokemon == null) missingCount++;
    slots.add(pokemon);
  }
  return TeamMembers(slots, missingCount: missingCount);
});
