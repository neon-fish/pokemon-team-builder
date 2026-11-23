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
/// [slot] is where the Pokémon is when this appears (counting from 0). The
/// dialog stays open while the Pokémon is moved, so this keeps track of where
/// it has got to.
class MoveControls extends ConsumerStatefulWidget {
  const MoveControls(this.slot, {super.key});

  final int slot;

  @override
  ConsumerState<MoveControls> createState() => _MoveControlsState();
}

class _MoveControlsState extends ConsumerState<MoveControls> {
  late int _slot;

  @override
  void initState() {
    super.initState();
    _slot = widget.slot;
  }

  void _moveTo(int target) {
    ref.read(teamProvider.notifier).move(_slot, target);
    setState(() => _slot = target);
  }

  @override
  Widget build(BuildContext context) {
    // A `Wrap` rather than a `Row`, so the pieces drop onto a second line when
    // the dialog is narrow or the text is large.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton.icon(
          onPressed: _slot > 0 ? () => _moveTo(_slot - 1) : null,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Move earlier'),
        ),
        Text('Slot ${_slot + 1} of ${Team.slotCount}'),
        TextButton.icon(
          onPressed: _slot < Team.slotCount - 1
              ? () => _moveTo(_slot + 1)
              : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Move later'),
        ),
      ],
    );
  }
}
