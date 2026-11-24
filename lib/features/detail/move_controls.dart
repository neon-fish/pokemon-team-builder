import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/domain/team.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

/// "Move earlier" and "Move later" buttons for a Pokémon on the team, with its
/// place in the team between them.
///
/// This is the way to reorder without a mouse or a touch screen: a drag cannot
/// be done with a keyboard. Each button swaps the Pokémon with the slot beside
/// it, which is what dropping it there would do.
///
/// [slot] is where the Pokémon is now (counting from 0). The dialog stays open
/// while the Pokémon is moved, so whoever shows this keeps track of where it
/// has got to: [onMoved] is called with the new slot, and should show this
/// again with it.
class MoveControls extends ConsumerWidget {
  const MoveControls(this.slot, {required this.onMoved, super.key});

  final int slot;
  final ValueChanged<int> onMoved;

  void _moveTo(WidgetRef ref, int target) {
    ref.read(teamProvider.notifier).move(slot, target);
    onMoved(target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A `Wrap` rather than a `Row`, so the pieces drop onto a second line when
    // the dialog is narrow or the text is large.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton.icon(
          onPressed: slot > 0 ? () => _moveTo(ref, slot - 1) : null,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Move earlier'),
        ),
        Text('Slot ${slot + 1} of ${Team.slotCount}'),
        TextButton.icon(
          onPressed: slot < Team.slotCount - 1
              ? () => _moveTo(ref, slot + 1)
              : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Move later'),
        ),
      ],
    );
  }
}
