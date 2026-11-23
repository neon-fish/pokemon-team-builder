import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/failure_message.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/domain/team.dart';
import 'package:pokemon_team_builder/features/detail/pokemon_detail_dialog.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_sprite.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/team/add_target_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

/// How long a Pokémon has to be held before it can be dragged.
///
/// A plain drag would start after a pixel or so of movement with a mouse, so a
/// slightly shaky click would drag instead of opening the details, and on a
/// touch screen it would compete with scrolling the page. Holding first avoids
/// both: if the pointer moves before the time is up, the press is left to
/// whatever else wants it (a click, or a scroll). (The default is half a
/// second; that felt slow with a mouse.)
const dragHoldDelay = Duration(milliseconds: 300);

/// How faded the Pokémon's own slot looks while it is being dragged away.
const _draggedSlotOpacity = 0.35;

/// How wide the picture that follows the pointer is.
const _dragPreviewWidth = 140.0;

/// One of the six team slots: empty, or holding a Pokémon.
///
/// [index] is the slot's place in the team (0 to 5). [onEmptyTapped] is called
/// after an empty slot is tapped, for a screen that wants to react by showing
/// the search.
///
/// Every slot is also a place to drop a dragged Pokémon. Dropping on an empty
/// slot moves the Pokémon there; dropping on a full one swaps the two.
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

    // What is dragged is the number of the slot it came from. `candidates` is
    // whatever is being dragged over this slot right now, so the slot can
    // light up as a place to drop.
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) =>
          ref.read(teamProvider.notifier).move(details.data, index),
      builder: (context, candidates, rejected) {
        final isDropTarget = candidates.isNotEmpty;
        return id == null
            ? _EmptySlot(
                index,
                onTapped: onEmptyTapped,
                isDropTarget: isDropTarget,
              )
            : _FilledSlot(index, id, isDropTarget: isDropTarget);
      },
    );
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
  const _EmptySlot(this.index, {this.onTapped, required this.isDropTarget});

  final int index;
  final VoidCallback? onTapped;

  /// Whether a Pokémon is being dragged over this slot.
  final bool isDropTarget;

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
        shape: isChosen || isDropTarget
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
  const _FilledSlot(this.index, this.id, {required this.isDropTarget});

  final int index;
  final int id;

  /// Whether a Pokémon is being dragged over this slot.
  final bool isDropTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(pokemonProvider(id));
    // Null while loading, including a retry (see `SearchResultTile`).
    final details = request.isLoading ? null : request.value;
    final name = switch (details) {
      Ok(:final value) => displayName(value.name),
      _ => 'Pokémon #$id',
    };

    // Only a Pokémon that has loaded has details to show.
    final pokemon = switch (details) {
      Ok(:final value) => value,
      _ => null,
    };

    final colours = Theme.of(context).colorScheme;
    final team = ref.read(teamProvider.notifier);

    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: isDropTarget
          ? _slotShape(colours.primary, width: 2)
          : _slotShape(colours.outlineVariant),
      child: InkWell(
        onTap: pokemon == null
            ? null
            : () => showPokemonDetail(context, pokemon, slot: index),
        // Dragging is not available to a screen reader or the keyboard, so the
        // same two moves are offered as actions. They swap with the
        // neighbouring slot, which is what a drop on it would do. The first
        // slot has nothing earlier, and the last nothing later, so those
        // actions are left out.
        //
        // They are placed here, inside the `InkWell`, so that they join the
        // item the screen reader lands on ("Pikachu, Electric"). Around the
        // whole card they ended up on a separate, unlabelled item that nothing
        // could focus, which would have made them unreachable.
        child: Semantics(
          // Joined to the name and types, so a reader says which slot this is,
          // which is what "move earlier" and "move later" are relative to.
          label: 'Slot ${index + 1}',
          customSemanticsActions: {
            if (index > 0)
              const CustomSemanticsAction(label: 'Move earlier'): () =>
                  team.move(index, index - 1),
            if (index < Team.slotCount - 1)
              const CustomSemanticsAction(label: 'Move later'): () =>
                  team.move(index, index + 1),
          },
          child: Stack(
            children: [
              // The content sets the slot's size (so that larger text makes
              // the slot taller). The top padding keeps it clear of the remove
              // button.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
                child: switch (details) {
                  null => const Center(child: CircularProgressIndicator()),
                  Ok(:final value) => _Member(value),
                  Err(:final failure) => _Unavailable(id, failure),
                },
              ),
              // A button inside the tappable card takes its own taps, so
              // removing never opens the details.
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove $name from the team',
                  onPressed: () => team.removeAt(index),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return LongPressDraggable<int>(
      // What is carried: where it came from. The slot it is dropped on does the
      // rest (see `TeamSlot`).
      data: index,
      delay: dragHoldDelay,
      feedback: _DragPreview(name: name, pokemon: pokemon),
      // The slot stays in its place, faded, so the layout does not jump and it
      // is clear where the Pokémon came from.
      childWhenDragging: Opacity(opacity: _draggedSlotOpacity, child: card),
      child: card,
    );
  }
}

/// The small card that follows the pointer while a Pokémon is dragged.
///
/// It is drawn above the whole page, outside the slot, so it cannot rely on the
/// slot for a width or a background.
class _DragPreview extends StatelessWidget {
  const _DragPreview({required this.name, required this.pokemon});

  final String name;

  /// Null if the Pokémon has not loaded; the preview then shows only the name.
  final Pokemon? pokemon;

  @override
  Widget build(BuildContext context) {
    final pokemon = this.pokemon;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _dragPreviewWidth,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: pokemon == null
              ? Text(name, textAlign: TextAlign.center)
              : _Member(pokemon),
        ),
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
