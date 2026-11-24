import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How much later each saved Pokémon is thrown than the one before it, when the
/// saved team appears at start-up.
const startupThrowStagger = Duration(milliseconds: 150);

/// Which slots have just had a Pokémon arrive, and so should play the throw-in.
///
/// Each entry is a slot number and how long that slot waits before throwing.
/// A slot's widget looks itself up when it first appears and takes its entry out
/// ([consume]) as it starts, so a rebuild or a layout change cannot replay it.
///
/// Kept apart from the team, which is saved data: "just arrived" is a fact about
/// the screen. It is recorded by the code that adds a Pokémon, because widgets
/// cannot tell an add from a drag: both leave a slot newly filled.
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
