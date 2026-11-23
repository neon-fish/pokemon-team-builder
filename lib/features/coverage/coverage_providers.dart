import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/domain/matchup_order.dart';
import 'package:pokemon_team_builder/features/team/team_analysis_provider.dart';

/// Which order the coverage matrix is shown in. Starts with the biggest gaps
/// first, as that answers "where is my team weak?" at a glance.
class MatchupOrderNotifier extends Notifier<MatchupOrder> {
  @override
  MatchupOrder build() => MatchupOrder.biggestGapsFirst;

  void choose(MatchupOrder order) => state = order;
}

final matchupOrderProvider =
    NotifierProvider<MatchupOrderNotifier, MatchupOrder>(
      MatchupOrderNotifier.new,
    );

/// The team analysis, with its rows in the chosen order. It follows both the
/// team and the order by itself.
final coverageProvider = Provider<TeamAnalysisState>((ref) {
  final analysis = ref.watch(teamAnalysisProvider);
  final order = ref.watch(matchupOrderProvider);

  return switch (analysis) {
    TeamAnalysisReady() => TeamAnalysisReady(
      sortMatchups(analysis.matchups, order),
      missingCount: analysis.missingCount,
      analysedCount: analysis.analysedCount,
    ),
    TeamAnalysisLoading() || TeamAnalysisUnavailable() => analysis,
  };
});
