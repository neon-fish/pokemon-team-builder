import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/domain/team_stats.dart';
import 'package:pokemon_team_builder/features/detail/radar_chart.dart';
import 'package:pokemon_team_builder/features/insights/incomplete_warning.dart';
import 'package:pokemon_team_builder/features/insights/team_stats_provider.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';
import 'package:pokemon_team_builder/features/pokemon/stat_labels.dart';
import 'package:pokemon_team_builder/features/team/team_members_provider.dart';

/// The most width the radar chart takes, so it does not swell on a wide panel.
const _radarMaxWidth = 300.0;

/// What the team is made of: its average base stats, and who stands out in
/// each.
class TeamStatsView extends ConsumerWidget {
  const TeamStatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamMembersProvider);
    final stats = ref.watch(teamStatsProvider);

    // Still waiting for the saved team.
    if (members == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // Nobody to summarise and nobody missing: an empty team.
    if (stats == null && members.missingCount == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Add a Pokémon to see what your team is made of.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (members.missingCount > 0) IncompleteWarning(members.missingCount),
        if (stats != null) _Summary(stats),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.stats);

  final TeamStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'The average of each base stat across the team, and who is highest '
          'and lowest in it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _radarMaxWidth),
            child: RadarChart(
              labels: [for (final stat in Stat.values) statAbbreviation(stat)],
              values: [
                for (final summary in stats.summaries) summary.average.round(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final summary in stats.summaries)
          _StatRow(summary, showRange: stats.memberCount > 1),
        const SizedBox(height: 4),
        _TotalRow(stats.averageTotal.round()),
      ],
    );
  }
}

/// How the team's best and worst compare, in words. Nothing to say for a team
/// of one, and "all the same" is better than naming a member twice.
String? _rangeText(StatSummary summary) {
  final high = summary.highest.stats.valueOf(summary.stat);
  final low = summary.lowest.stats.valueOf(summary.stat);
  if (high == low) return 'All the same';
  return 'Highest: ${displayName(summary.highest.name)} $high · '
      'Lowest: ${displayName(summary.lowest.name)} $low';
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.summary, {required this.showRange});

  final StatSummary summary;
  final bool showRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = statName(summary.stat);
    final average = summary.average.round();
    final range = showRange ? _rangeText(summary) : null;

    // One sentence for the row, as the stat bars do, instead of the pieces.
    return Semantics(
      label: range == null
          ? '$name: average $average'
          : '$name: average $average. $range',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(name)),
                Text(
                  '$average',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (range != null)
              Text(
                range,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.total);

  final int total;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    return Semantics(
      label: 'Total: average $total',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(child: Text('Total', style: style)),
          Text('$total', style: style),
        ],
      ),
    );
  }
}
