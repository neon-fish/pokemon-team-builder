import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/coverage/coverage_matrix.dart';
import 'package:pokemon_team_builder/features/insights/insights_tab.dart';
import 'package:pokemon_team_builder/features/insights/team_stats_view.dart';

/// What the team adds up to, in one panel with a tab for each view: where it is
/// weak (coverage), and what it is made of (stats).
///
/// Tabs, rather than the two views stacked, because the coverage matrix is
/// already tall. This is a segmented control that swaps the content in place,
/// not a `TabBar` with a `TabBarView`: that needs a fixed height and swipes
/// sideways, which fights the page's own scrolling.
class TeamInsights extends ConsumerWidget {
  const TeamInsights({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(insightsTabProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Team analysis', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SegmentedButton<InsightsTab>(
          showSelectedIcon: false,
          // Fills the width, so the two halves are easy targets on a phone.
          expandedInsets: EdgeInsets.zero,
          segments: const [
            ButtonSegment(value: InsightsTab.coverage, label: Text('Coverage')),
            ButtonSegment(value: InsightsTab.stats, label: Text('Stats')),
          ],
          selected: {tab},
          onSelectionChanged: (selection) =>
              ref.read(insightsTabProvider.notifier).choose(selection.single),
        ),
        const SizedBox(height: 16),
        switch (tab) {
          InsightsTab.coverage => const CoverageMatrix(),
          InsightsTab.stats => const TeamStatsView(),
        },
      ],
    );
  }
}
