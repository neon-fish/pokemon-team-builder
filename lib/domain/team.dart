/// The Pokémon the user has picked: up to six, in the order they were added.
///
/// Holds ids only; details are loaded separately. Immutable: [add] and
/// [remove] return a new team and leave this one alone.
class Team {
  const Team([this.ids = const []]);

  /// How many Pokémon a team can hold.
  static const maxSize = 6;

  final List<int> ids;

  bool get isFull => ids.length >= maxSize;

  bool contains(int id) => ids.contains(id);

  /// This team with [id] added at the end.
  ///
  /// Returns this team unchanged if it is already full or already has [id]:
  /// the same Pokémon twice would add nothing to the analysis. The UI should
  /// not offer the action in those cases, but a stray call is harmless.
  Team add(int id) {
    if (isFull || contains(id)) return this;
    return Team([...ids, id]);
  }

  /// This team without [id]. Unchanged if it was not in the team.
  Team remove(int id) {
    if (!contains(id)) return this;
    return Team([
      for (final other in ids)
        if (other != id) other,
    ]);
  }
}
