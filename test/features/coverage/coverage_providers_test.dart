import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/matchup_order.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/features/coverage/coverage_providers.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/team/team_analysis_provider.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';
import '../../support/in_memory_key_value_store.dart';

void main() {
  final chartResponses =
      loadFixture('type_chart_responses.json')! as Map<String, Object?>;

  var chartFails = false;

  late ProviderContainer app;

  setUp(() {
    chartFails = false;
    final api = FakeApiClient((url) {
      if (url.path.contains('/type/')) {
        return chartFails
            ? const Err(ServerFailure(503))
            : Ok(chartResponses[url.pathSegments.last]);
      }
      if (url.path.endsWith('/pokemon/25')) {
        return Ok(loadFixture('pokemon_pikachu.json'));
      }
      return const Err(NotFoundFailure());
    });
    app = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        keyValueStoreProvider.overrideWithValue(
          InMemoryKeyValueStore({'team': '{"ids":[25]}'}),
        ),
      ],
    );
    addTearDown(app.dispose);
  });

  /// Waits for a team of one Pikachu to be analysed.
  Future<void> settle() async {
    await app.read(teamProvider.future);
    await app.read(typeChartProvider.future);
    app.read(coverageProvider);
    await app.read(pokemonProvider(25).future);
  }

  /// The types of the rows, top to bottom.
  List<PokemonType> rows() => [
    for (final matchup
        in (app.read(coverageProvider) as TeamAnalysisReady).matchups)
      matchup.attacking,
  ];

  test('starts with the biggest gaps first', () {
    expect(app.read(matchupOrderProvider), MatchupOrder.biggestGapsFirst);
  });

  test('puts what the team is weak to at the top', () async {
    await settle();

    // Pikachu (electric) is weak only to ground.
    expect(rows().first, PokemonType.ground);
  });

  test('changing the order changes the rows, nothing else', () async {
    await settle();
    final before = app.read(coverageProvider) as TeamAnalysisReady;

    app.read(matchupOrderProvider.notifier).choose(MatchupOrder.standard);
    final after = app.read(coverageProvider) as TeamAnalysisReady;

    expect(rows(), PokemonType.values);
    expect(after.matchups, hasLength(before.matchups.length));
    expect(after.missingCount, before.missingCount);
    expect(after.analysedCount, before.analysedCount);
  });

  test('follows the team as it changes', () async {
    await settle();

    await app.read(teamProvider.notifier).removeAt(0);

    final state = app.read(coverageProvider) as TeamAnalysisReady;
    expect(state.analysedCount, 0);
    // With nobody to analyse, every type ties, so the standard order shows.
    expect(rows(), PokemonType.values);
  });

  test('passes loading and failure through as they are', () async {
    // Reading the provider is what starts the requests, so decide first.
    chartFails = true;
    expect(app.read(coverageProvider), isA<TeamAnalysisLoading>());

    await app.read(teamProvider.future);
    await app.read(typeChartProvider.future);

    expect(app.read(coverageProvider), isA<TeamAnalysisUnavailable>());
  });
}
