import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The slot whose card is "in the details dialog" right now, or null if none is.
///
/// While the dialog is open its card has been lifted out of the team, so that
/// slot is drawn as a gap. It is state of its own because the gap has to follow
/// the Pokémon: if the buttons in the dialog move it to another slot, the gap
/// moves with it, and the slot it left shows the card that took its place.
class LiftedSlotNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  /// [slot] is where the dialog's Pokémon is now.
  void lift(int slot) {
    // The dialog can outlive the providers (when the whole app is torn down).
    if (!ref.mounted) return;
    state = slot;
  }

  /// The dialog has finished closing, so [slot] is an ordinary slot again.
  ///
  /// It only does anything if [slot] is still the lifted one. A dialog that
  /// closes late must not put down the slot a newer dialog has since lifted.
  void putDown(int slot) {
    if (!ref.mounted) return; // As above.
    if (state == slot) state = null;
  }
}

final liftedSlotProvider = NotifierProvider<LiftedSlotNotifier, int?>(
  LiftedSlotNotifier.new,
);
