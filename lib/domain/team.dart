/// The Pokémon the user has picked: up to six slots, in the order they were
/// added.
///
/// The same Pokémon may fill more than one slot, as in the games. Holds ids
/// only; details are loaded separately. Immutable: [add] and [removeAt] return
/// a new team and leave this one alone.
class Team {
  const Team([this.ids = const []]);

  /// How many Pokémon a team can hold.
  static const maxSize = 6;

  final List<int> ids;

  bool get isFull => ids.length >= maxSize;

  /// This team with [id] added in the next free slot.
  ///
  /// Returns this team unchanged if it is already full. The UI should not offer
  /// the action then, but a stray call is harmless.
  Team add(int id) {
    if (isFull) return this;
    return Team([...ids, id]);
  }

  /// This team without the Pokémon in slot [index] (counting from 0); the
  /// later ones move up. Unchanged if there is no such slot.
  ///
  /// Removal is by position, not by id, because the same id can appear in
  /// several slots.
  Team removeAt(int index) {
    if (index < 0 || index >= ids.length) return this;
    return Team([
      for (var i = 0; i < ids.length; i++)
        if (i != index) ids[i],
    ]);
  }
}
