import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/team_analysis.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

/// The type chart, loaded once. See [pokemonProvider] for why failures are
/// values inside the `AsyncValue`. To retry: `ref.invalidate(typeChartProvider)`.
final typeChartProvider = FutureProvider<Result<TypeChart>>(
  (ref) => ref.watch(typeChartRepositoryProvider).loadTypeChart(),
);

/// What the UI can show for the team analysis.
sealed class TeamAnalysisState {
  const TeamAnalysisState();
}

/// Still waiting for the saved team or the type chart.
final class TeamAnalysisLoading extends TeamAnalysisState {
  const TeamAnalysisLoading();
}

/// The type chart could not be loaded, so nothing can be analysed.
final class TeamAnalysisUnavailable extends TeamAnalysisState {
  const TeamAnalysisUnavailable(this.failure);

  final ApiFailure failure;
}

/// The analysis of every team member that has loaded.
final class TeamAnalysisReady extends TeamAnalysisState {
  const TeamAnalysisReady(
    this.matchups, {
    required this.missingCount,
    required this.analysedCount,
  });

  /// One entry per attacking type; see [analyseTeam]. Each has one result per
  /// slot, null for a slot that was not analysed.
  final List<TypeMatchup> matchups;

  /// How many members were analysed.
  final int analysedCount;

  /// Members left out because they are still loading or failed to load. When
  /// this is not zero the analysis is incomplete, and the UI should say so: a
  /// team that looks safe may only be missing a member.
  final int missingCount;
}

/// The team analysis, worked out from the team, the type chart and each
/// member's details. It updates by itself as any of them load or change.
final teamAnalysisProvider = Provider<TeamAnalysisState>((ref) {
  // `.value` is null while an `AsyncValue` is still loading.
  final team = ref.watch(teamProvider).value;
  final chartResult = ref.watch(typeChartProvider).value;
  if (team == null || chartResult == null) return const TeamAnalysisLoading();

  switch (chartResult) {
    case Err(:final failure):
      return TeamAnalysisUnavailable(failure);
    case Ok(value: final chart):
      // One entry per slot, so each result lines up with its slot.
      final slotTypes = <List<PokemonType>?>[];
      var missingCount = 0;
      for (final id in team.slots) {
        if (id == null) {
          // An empty slot is not a member, so it is not "missing" either.
          slotTypes.add(null);
          continue;
        }
        final pokemon = ref.watch(pokemonProvider(id)).value?.valueOrNull;
        if (pokemon == null) missingCount++;
        slotTypes.add(pokemon?.types);
      }
      return TeamAnalysisReady(
        analyseTeam(slotTypes, chart),
        missingCount: missingCount,
        analysedCount: slotTypes.nonNulls.length,
      );
  }
});
