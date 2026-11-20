import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/team/team_analysis_provider.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';
import '../../support/in_memory_key_value_store.dart';

const _pikachu = 25;

void main() {
  final chartResponses =
      loadFixture('type_chart_responses.json')! as Map<String, Object?>;

  // What the fake API does, changed by tests to simulate trouble.
  var chartFails = false;
  var pokemonFails = false;
  late FakeApiClient api;

  setUp(() {
    chartFails = false;
    pokemonFails = false;
    api = FakeApiClient((url) {
      if (url.path.contains('/type/')) {
        return chartFails
            ? const Err(ServerFailure(503))
            : Ok(chartResponses[url.pathSegments.last]);
      }
      if (url.path.endsWith('/pokemon/$_pikachu') && !pokemonFails) {
        return Ok(loadFixture('pokemon_pikachu.json'));
      }
      return const Err(NotFoundFailure());
    });
  });

  /// An app whose saved team is [ids].
  ProviderContainer appWithTeam(List<int> ids) {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        keyValueStoreProvider.overrideWithValue(
          InMemoryKeyValueStore({'team': '{"ids":$ids}'}),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Waits for everything the analysis depends on, then returns it.
  Future<TeamAnalysisState> settledAnalysis(ProviderContainer app) async {
    await app.read(teamProvider.future);
    await app.read(typeChartProvider.future);
    // Reading the analysis is what starts loading each member.
    app.read(teamAnalysisProvider);
    for (final id in app.read(teamProvider).requireValue.ids) {
      await app.read(pokemonProvider(id).future);
    }
    return app.read(teamAnalysisProvider);
  }

  TeamAnalysisReady ready(TeamAnalysisState state) {
    expect(state, isA<TeamAnalysisReady>());
    return state as TeamAnalysisReady;
  }

  List<double> multipliersFor(TeamAnalysisReady state, PokemonType attacking) {
    return state.matchups
        .singleWhere((m) => m.attacking == attacking)
        .multipliers;
  }

  test('is loading until the team and the type chart arrive', () {
    final app = appWithTeam([_pikachu]);

    expect(app.read(teamAnalysisProvider), isA<TeamAnalysisLoading>());
  });

  test('analyses a loaded team', () async {
    final app = appWithTeam([_pikachu]);

    final state = ready(await settledAnalysis(app));

    expect(state.missingCount, 0);
    // Pikachu is electric: weak to ground, resists flying.
    expect(multipliersFor(state, PokemonType.ground), [2]);
    expect(multipliersFor(state, PokemonType.flying), [0.5]);
  });

  test('an empty team is ready, with nobody in it', () async {
    final app = appWithTeam([]);

    final state = ready(await settledAnalysis(app));

    expect(state.missingCount, 0);
    expect(state.matchups.every((m) => m.multipliers.isEmpty), isTrue);
  });

  test('the same Pokémon twice counts twice but is loaded once', () async {
    final app = appWithTeam([_pikachu, _pikachu]);

    final state = ready(await settledAnalysis(app));

    expect(multipliersFor(state, PokemonType.ground), [2, 2]);
    final pikachuRequests = api.calls.where(
      (url) => url.path.endsWith('/pokemon/$_pikachu'),
    );
    expect(pikachuRequests, hasLength(1));
  });

  test(
    'a member that fails to load is counted as missing, not hidden', () async {
      pokemonFails = true;
      final app = appWithTeam([_pikachu]);

      final state = ready(await settledAnalysis(app));

      expect(state.missingCount, 1);
      expect(state.matchups.every((m) => m.multipliers.isEmpty), isTrue);
    },
  );

  test('retrying a failed member completes the analysis', () async {
    pokemonFails = true;
    final app = appWithTeam([_pikachu]);
    await settledAnalysis(app);

    pokemonFails = false;
    app.invalidate(pokemonProvider(_pikachu));
    await app.read(pokemonProvider(_pikachu).future);
    final state = ready(app.read(teamAnalysisProvider));

    expect(state.missingCount, 0);
    expect(multipliersFor(state, PokemonType.ground), [2]);
  });

  test('adding to the team updates the analysis', () async {
    final app = appWithTeam([]);
    await settledAnalysis(app);

    await app.read(teamProvider.notifier).add(_pikachu);
    // The new member is not loaded yet, so it is missing for now.
    expect(ready(app.read(teamAnalysisProvider)).missingCount, 1);

    await app.read(pokemonProvider(_pikachu).future);
    final state = ready(app.read(teamAnalysisProvider));
    expect(state.missingCount, 0);
    expect(multipliersFor(state, PokemonType.ground), [2]);
  });

  group('when the type chart cannot be loaded', () {
    test('the analysis is unavailable, with the reason', () async {
      chartFails = true;
      final app = appWithTeam([_pikachu]);

      final state = await settledAnalysis(app);

      expect(state, isA<TeamAnalysisUnavailable>());
      expect((state as TeamAnalysisUnavailable).failure, isA<ServerFailure>());
    });

    test('retrying recovers', () async {
      chartFails = true;
      final app = appWithTeam([_pikachu]);
      await settledAnalysis(app);

      chartFails = false;
      app.invalidate(typeChartProvider);
      final state = await settledAnalysis(app);

      expect(state, isA<TeamAnalysisReady>());
    });
  });
}
