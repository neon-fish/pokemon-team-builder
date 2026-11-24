@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/concurrency_limited_api_client.dart';
import 'package:pokemon_team_builder/data/http/package_http_transport.dart';
import 'package:pokemon_team_builder/data/http_api_client.dart';
import 'package:pokemon_team_builder/data/poke_api.dart';
import 'package:pokemon_team_builder/data/pokemon_index_repository.dart';
import 'package:pokemon_team_builder/data/pokemon_repository.dart';
import 'package:pokemon_team_builder/data/retrying_api_client.dart';
import 'package:pokemon_team_builder/data/type_chart_repository.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';

import '../support/fixtures.dart';
import 'json_shape.dart';

/// Checks the real PokeAPI still answers the way the app, and its saved test
/// fixtures, expect. It is skipped in the normal run (see `dart_test.yaml`):
///
///     flutter test --run-skipped --tags live
///
/// A failure here means the API may have changed, or that it is having a bad
/// moment. Each message says which request, so check it by hand before
/// blaming the code.
void main() {
  // The same layers as the app, less the cache and the simulated faults. The
  // retrying layer is kept so a passing wobble at the API does not fail a run.
  final ApiClient client = ConcurrencyLimitedApiClient(
    RetryingApiClient(
      HttpApiClient(
        PackageHttpTransport(),
        timeout: const Duration(seconds: 20),
      ),
    ),
  );

  /// The live response for [path], failing the test with a clear message if it
  /// could not be fetched.
  Future<Object?> fetch(String path) async {
    final result = await client.getJson(Uri.parse('$pokeApiBaseUrl$path'));
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('GET $path failed: $failure'),
    };
  }

  group('the app reads the live API', () {
    test('the list of every Pokémon', () async {
      final result = await PokemonIndexRepository(client).loadIndex();

      final index = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail('The index failed: $failure'),
      };
      // About 1,350 today. Well under that would mean a page was cut short.
      expect(index.length, greaterThan(1000));
      expect(index.where((p) => p.id == 25).single.name, 'pikachu');
    });

    test('a Pokémon, and an alternative form', () async {
      final repository = PokemonRepository(client);

      final pikachu = switch (await repository.loadPokemon(25)) {
        Ok(:final value) => value,
        Err(:final failure) => fail('Pikachu failed: $failure'),
      };
      expect(pikachu.name, 'pikachu');
      expect(pikachu.types, [PokemonType.electric]);
      expect(pikachu.stats.total, greaterThan(0));
      expect(pikachu.spriteUrl, isNotNull);

      final koraidon = switch (await repository.loadPokemon(10264)) {
        Ok(:final value) => value,
        Err(:final failure) => fail('Koraidon failed: $failure'),
      };
      expect(koraidon.types, [PokemonType.fighting, PokemonType.dragon]);
    });

    test('the whole type chart', () async {
      final result = await TypeChartRepository(client).loadTypeChart();

      final chart = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail('The type chart failed: $failure'),
      };
      // Spot checks that have not changed since the first games.
      expect(chart.multiplier(PokemonType.electric, PokemonType.ground), 0);
      expect(chart.multiplier(PokemonType.fire, PokemonType.grass), 2);
      expect(chart.multiplier(PokemonType.fire, PokemonType.water), 0.5);
      expect(chart.multiplier(PokemonType.normal, PokemonType.normal), 1);
    });
  });

  group('the saved fixtures still match the live shape', () {
    void expectMatches(String name, Object? saved, Object? live) {
      final differences = shapeDifferences(saved, live);
      expect(
        differences,
        isEmpty,
        reason: '$name no longer matches the API:\n${differences.join('\n')}',
      );
    }

    test('pokemon_index.json', () async {
      expectMatches(
        'pokemon_index.json',
        loadFixture('pokemon_index.json'),
        await fetch('/pokemon?limit=5000'),
      );
    });

    test('pokemon_pikachu.json', () async {
      expectMatches(
        'pokemon_pikachu.json',
        loadFixture('pokemon_pikachu.json'),
        await fetch('/pokemon/25'),
      );
    });

    test('the Koraidon fixtures', () async {
      expectMatches(
        'pokemon_koraidon_limited_build.json',
        loadFixture('pokemon_koraidon_limited_build.json'),
        await fetch('/pokemon/10264'),
      );
      expectMatches(
        'pokemon_koraidon_sprinting_build.json',
        loadFixture('pokemon_koraidon_sprinting_build.json'),
        await fetch('/pokemon/10265'),
      );
    });

    test('type_fire.json', () async {
      expectMatches(
        'type_fire.json',
        loadFixture('type_fire.json'),
        await fetch('/type/fire'),
      );
    });

    test('all 18 types in type_chart_responses.json', () async {
      final saved =
          loadFixture('type_chart_responses.json')! as Map<String, Object?>;
      for (final type in saved.keys) {
        expectMatches(
          'The $type fixture',
          saved[type],
          await fetch('/type/$type'),
        );
      }
    });
  });
}
