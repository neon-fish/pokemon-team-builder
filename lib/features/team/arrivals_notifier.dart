import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How much later each saved Pokémon is thrown than the one before it, when the
/// saved team appears at start-up.
const startupThrowStagger = Duration(milliseconds: 150);

/// Which slots have just had a Pokémon arrive, and so should play the throw-in.
///
/// Each entry is a slot number and how long that slot waits before throwing.
/// A slot's widget looks itself up here when it first appears, and takes its
/// entry out ([consume]) once it starts, so rebuilding it or moving it to a
/// different layout cannot play the throw a second time.
///
/// This is kept apart from the team itself, which is saved data: "this has just
/// arrived" is a fact about the screen, not something to store. It is also
/// recorded here, by the code that adds a Pokémon, because the widgets cannot
/// work it out by comparing before and after. A slot that became filled because
/// a Pokémon was dragged into it looks exactly like one that was added.
class ArrivalsNotifier extends Notifier<Map<int, Duration>> {
  @override
  Map<int, Duration> build() => const {};

  /// A Pokémon was just added to each of [slots]. They throw straight away.
  void markAdded(Iterable<int> slots) {
    state = {...state, for (final slot in slots) slot: Duration.zero};
  }

  /// The saved team has just loaded: every filled slot throws, one after
  /// another, in slot order.
  void markLoaded(List<int?> slots) {
    var position = 0;
    final arrivals = <int, Duration>{};
    for (var slot = 0; slot < slots.length; slot++) {
      if (slots[slot] == null) continue;
      arrivals[slot] = startupThrowStagger * position;
      position++;
    }
    state = {...state, ...arrivals};
  }

  /// Takes [slot]'s entry out, if it has one.
  void consume(int slot) {
    if (!state.containsKey(slot)) return;
    state = {
      for (final entry in state.entries)
        if (entry.key != slot) entry.key: entry.value,
    };
  }
}

final arrivalsProvider = NotifierProvider<ArrivalsNotifier, Map<int, Duration>>(
  ArrivalsNotifier.new,
);
