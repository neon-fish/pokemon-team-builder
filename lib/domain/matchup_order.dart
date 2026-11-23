import 'package:pokemon_team_builder/domain/team_analysis.dart';

/// The orders the coverage results can be shown in.
enum MatchupOrder {
  /// The standard order of the types ([PokemonType.values]).
  standard,

  /// The types the team is most exposed to first.
  biggestGapsFirst,
}

/// [matchups] in the given [order]. The list passed in is left alone.
///
/// For [MatchupOrder.biggestGapsFirst], types are ranked by
/// [TypeMatchup.netExposure], highest first. Ties are broken by the number of
/// weak members (more first), then by the standard order. The last rule is
/// spelled out because `List.sort` does not promise to keep equal items in
/// their original order, and without it the rows could shuffle between
/// rebuilds.
List<TypeMatchup> sortMatchups(List<TypeMatchup> matchups, MatchupOrder order) {
  final sorted = [...matchups];
  sorted.sort((a, b) {
    if (order == MatchupOrder.biggestGapsFirst) {
      final byExposure = b.netExposure.compareTo(a.netExposure);
      if (byExposure != 0) return byExposure;
      final byWeak = b.weakCount.compareTo(a.weakCount);
      if (byWeak != 0) return byWeak;
    }
    return a.attacking.index.compareTo(b.attacking.index);
  });
  return sorted;
}
