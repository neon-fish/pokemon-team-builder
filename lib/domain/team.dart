/// The Pokémon the user has picked: always six slots, any of which may be
/// empty.
///
/// A slot keeps its position. Removing a Pokémon empties its slot and nothing
/// else moves; adding fills the first empty slot. The same Pokémon may fill
/// more than one slot, as in the games. Holds ids only; details are loaded
/// separately.
///
/// Immutable: [add], [removeAt] and [move] return a new team and leave this one
/// alone. When a change would do nothing they return this same object, which
/// lets callers skip a pointless save.
class Team {
  /// A team with every slot empty.
  const Team() : slots = const [null, null, null, null, null, null];

  const Team._(this.slots);

  /// A team with [slots] in order. If there are fewer than six the rest are
  /// empty, and any beyond six are dropped, so saved data can never make a team
  /// the wrong size.
  factory Team.fromSlots(List<int?> slots) {
    return Team._([
      for (var i = 0; i < slotCount; i++)
        if (i < slots.length) slots[i] else null,
    ]);
  }

  /// How many slots a team has.
  static const slotCount = 6;

  /// What is in each slot: a Pokémon id, or null for an empty slot. Always
  /// [slotCount] long.
  final List<int?> slots;

  /// The ids of the Pokémon on the team, in slot order, without the gaps.
  List<int> get memberIds => [
    // `?id` includes the id only if it is not null.
    for (final id in slots) ?id,
  ];

  /// Whether every slot is taken.
  bool get isFull => !slots.contains(null);

  /// This team with [id] in the first empty slot.
  ///
  /// Returns this team unchanged if it is already full. The UI should not offer
  /// the action then, but a stray call is harmless.
  Team add(int id) {
    final index = slots.indexOf(null);
    if (index == -1) return this;
    return _withSlot(index, id);
  }

  /// This team with [id] in slot [index] (counting from 0). Nothing else
  /// moves. Unchanged if there is no such slot, or it is already taken.
  Team addAt(int index, int id) {
    if (!_isSlot(index) || slots[index] != null) return this;
    return _withSlot(index, id);
  }

  /// This team with slot [index] (counting from 0) emptied. Nothing else
  /// moves. Unchanged if there is no such slot, or it is already empty.
  ///
  /// Removal is by position, not by id, because the same id can appear in
  /// several slots.
  Team removeAt(int index) {
    if (!_isSlot(index) || slots[index] == null) return this;
    return _withSlot(index, null);
  }

  /// This team with slots [from] and [to] exchanged. If [to] is empty, the
  /// Pokémon simply moves there. Unchanged if either slot does not exist, or
  /// swapping would make no difference (the same slot, two empty slots, or the
  /// same Pokémon in both).
  Team move(int from, int to) {
    if (!_isSlot(from) || !_isSlot(to)) return this;
    if (slots[from] == slots[to]) return this;

    final swapped = [...slots];
    swapped[from] = slots[to];
    swapped[to] = slots[from];
    return Team._(swapped);
  }

  bool _isSlot(int index) => index >= 0 && index < slotCount;

  /// This team with slot [index] set to [id] (or emptied, if null).
  Team _withSlot(int index, int? id) {
    return Team._([
      for (var i = 0; i < slotCount; i++)
        if (i == index) id else slots[i],
    ]);
  }
}
