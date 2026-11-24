import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/features/insights/team_stats_provider.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';
import '../../support/in_memory_key_value_store.dart';

void main() {
  // Only Pikachu (25) loads; every other Pokémon fails.
  const pikachu = 25;

  ProviderContainer appWithTeam(List<int?> ids) {
    final api = FakeApiClient(
      (url) => url.path.endsWith('/pokemon/$pikachu')
          ? Ok(loadFixture('pokemon_pikachu.json'))
          : const Err(NotFoundFailure()),
    );
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

  Future<void> settle(ProviderContainer app) async {
    await app.read(teamProvider.future);
    app.read(teamStatsProvider); // Starts loading each member.
    for (final id in app.read(teamProvider).requireValue.memberIds) {
      await app.read(pokemonProvider(id).future);
    }
  }

  test('is null for an empty team', () async {
    final app = appWithTeam([]);
    await settle(app);

    expect(app.read(teamStatsProvider), isNull);
  });

  test(
    'sums up the members that loaded and leaves out those that did not',
    () async {
      final app = appWithTeam([pikachu, 7]);
      await settle(app);

      final stats = app.read(teamStatsProvider)!;

      expect(stats.memberCount, 1);
      expect(stats.averageTotal, 320);
    },
  );

  test('is null when nobody could be loaded', () async {
    final app = appWithTeam([7]);
    await settle(app);

    expect(app.read(teamStatsProvider), isNull);
  });
}
