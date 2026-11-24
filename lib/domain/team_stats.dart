import 'package:pokemon_team_builder/domain/pokemon.dart';

/// How a team's members compare on one base stat.
class StatSummary {
  const StatSummary({
    required this.stat,
    required this.average,
    required this.highest,
    required this.lowest,
  });

  final Stat stat;

  /// The mean of the members' values.
  final double average;

  /// The member with the most of this stat. If several tie, the first in slot
  /// order.
  final Pokemon highest;

  /// The member with the least of this stat. If several tie, the first in slot
  /// order.
  final Pokemon lowest;
}

/// The team's six base stats, summed up across its members.
class TeamStats {
  const TeamStats({
    required this.memberCount,
    required this.summaries,
    required this.averageTotal,
  });

  /// How many members the figures are drawn from.
  final int memberCount;

  /// One entry per stat, in the order of [Stat.values].
  final List<StatSummary> summaries;

  /// The mean of the members' totals (all six stats added together).
  final double averageTotal;
}

/// Sums up the base stats of [members], or returns null if there are none (an
/// average of nobody means nothing).
///
/// [members] are the Pokémon that could be analysed, in slot order. Empty
/// slots and Pokémon that have not loaded are left out by the caller, as they
/// are in `analyseTeam`.
TeamStats? summariseStats(List<Pokemon> members) {
  if (members.isEmpty) return null;

  return TeamStats(
    memberCount: members.length,
    summaries: [for (final stat in Stat.values) _summarise(stat, members)],
    averageTotal: _mean([for (final member in members) member.stats.total]),
  );
}

StatSummary _summarise(Stat stat, List<Pokemon> members) {
  var highest = members.first;
  var lowest = members.first;
  for (final member in members) {
    // Strict comparisons, so on a tie the earlier member stays.
    if (member.stats.valueOf(stat) > highest.stats.valueOf(stat)) {
      highest = member;
    }
    if (member.stats.valueOf(stat) < lowest.stats.valueOf(stat)) {
      lowest = member;
    }
  }
  return StatSummary(
    stat: stat,
    average: _mean([for (final member in members) member.stats.valueOf(stat)]),
    highest: highest,
    lowest: lowest,
  );
}

double _mean(List<int> values) =>
    values.fold(0, (sum, value) => sum + value) / values.length;
