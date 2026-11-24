import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/domain/team.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_slot.dart';

/// Below this width the slots go two across (three rows); at or above it, three
/// across (two rows).
const _threeAcrossFrom = 520.0;

/// The space between slots.
const _gap = 12.0;

/// No slot is shorter than this, so an empty slot is the same size as a full
/// one. A slot can be taller: see [TeamPanel].
const _slotMinHeight = 208.0;

/// The heading and the six team slots.
///
/// Each row of slots is as tall as its tallest slot, so larger text sizes make
/// the slots grow instead of overflowing.
///
/// [onEmptySlotTapped] is passed on to every slot; see [TeamSlot].
class TeamPanel extends ConsumerWidget {
  const TeamPanel({this.onEmptySlotTapped, super.key});

  final VoidCallback? onEmptySlotTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      teamProvider.select((team) => team.value?.memberIds.length ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your team ($count of ${Team.slotCount})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        // Dragging cannot be seen, so it is said. Always shown, even with
        // nobody to drag, so that adding the first Pokémon does not move
        // everything below it.
        Text(
          'Hold and drag a Pokémon to move it. Dropping it on another swaps '
          'the two.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < _threeAcrossFrom ? 2 : 3;
            final rows = Team.slotCount ~/ columns;
            // Each row is as tall as its tallest slot: `IntrinsicHeight` asks
            // the slots how tall they want to be, and `stretch` makes them all
            // that height. (A `Table` can do this too, but it does not notice
            // when a slot's content changes size, such as a Pokémon loading.)
            return Column(
              children: [
                for (var row = 0; row < rows; row++)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var column = 0; column < columns; column++) ...[
                          // The gap is a box between slots, not padding inside
                          // them: padding on all but the last slot made the
                          // last column wider than the rest.
                          if (column > 0) const SizedBox(width: _gap),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: row < rows - 1 ? _gap : 0,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: _slotMinHeight,
                                ),
                                child: TeamSlot(
                                  row * columns + column,
                                  onEmptyTapped: onEmptySlotTapped,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
