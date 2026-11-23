import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/failure_message.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_sprite.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/team/add_target_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

/// One of the six team slots: empty, or holding a Pokémon.
///
/// [index] is the slot's place in the team (0 to 5). [onEmptyTapped] is called
/// after an empty slot is tapped, for a screen that wants to react by showing
/// the search.
class TeamSlot extends ConsumerWidget {
  const TeamSlot(this.index, {this.onEmptyTapped, super.key});

  final int index;
  final VoidCallback? onEmptyTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` picks out just this slot, so the widget is rebuilt only when
    // its own slot changes, not whenever any slot does. While the saved team is
    // still loading there is no team yet, and the slot shows as empty.
    final id = ref.watch(
      teamProvider.select((team) => team.value?.slots[index]),
    );

    return id == null
        ? _EmptySlot(index, onTapped: onEmptyTapped)
        : _FilledSlot(index, id);
  }
}

/// The outline shared by every kind of slot.
RoundedRectangleBorder _slotShape(Color colour, {double width = 1}) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: colour, width: width),
  );
}

class _EmptySlot extends ConsumerWidget {
  const _EmptySlot(this.index, {this.onTapped});

  final int index;
  final VoidCallback? onTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colours = Theme.of(context).colorScheme;
    // Whether the user has already chosen this slot for the next Pokémon.
    final isChosen = ref.watch(addTargetProvider) == index;

    return Tooltip(
      message: 'Add a Pokémon to slot ${index + 1}',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: isChosen
            ? _slotShape(colours.primary, width: 2)
            : _slotShape(colours.outlineVariant),
        child: InkWell(
          onTap: () {
            ref.read(addTargetProvider.notifier).choose(index);
            onTapped?.call();
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 36,
                  color: isChosen ? colours.primary : colours.outline,
                ),
                const SizedBox(height: 8),
                Text(isChosen ? 'Choose a Pokémon' : 'Add a Pokémon'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilledSlot extends ConsumerWidget {
  const _FilledSlot(this.index, this.id);

  final int index;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(pokemonProvider(id));
    // Null while loading, including a retry (see `SearchResultTile`).
    final details = request.isLoading ? null : request.value;
    final name = switch (details) {
      Ok(:final value) => displayName(value.name),
      _ => 'Pokémon #$id',
    };

    return Card(
      margin: EdgeInsets.zero,
      shape: _slotShape(Theme.of(context).colorScheme.outlineVariant),
      child: Stack(
        children: [
          // The content sets the slot's size (so that larger text makes the
          // slot taller). The top padding keeps it clear of the remove button.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
            child: switch (details) {
              null => const Center(child: CircularProgressIndicator()),
              Ok(:final value) => _Member(value),
              Err(:final failure) => _Unavailable(id, failure),
            },
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove $name from the team',
              onPressed: () => ref.read(teamProvider.notifier).removeAt(index),
            ),
          ),
        ],
      ),
    );
  }
}

/// A Pokémon in its slot: picture, name and types.
class _Member extends StatelessWidget {
  const _Member(this.pokemon);

  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PokemonSprite(url: pokemon.spriteUrl, size: 96),
          const SizedBox(height: 4),
          Text(
            displayName(pokemon.name),
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [for (final type in pokemon.types) TypeBadge(type)],
          ),
        ],
      ),
    );
  }
}

/// A slot whose Pokémon could not be loaded, with a way to try again. (The
/// remove button is still there, so a bad slot can always be emptied.)
class _Unavailable extends ConsumerWidget {
  const _Unavailable(this.id, this.failure);

  final int id;
  final ApiFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off),
          const SizedBox(height: 4),
          Text('Could not load #$id', style: textTheme.titleSmall),
          Text(
            describeFailure(failure),
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          TextButton(
            onPressed: () => ref.invalidate(pokemonProvider(id)),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
