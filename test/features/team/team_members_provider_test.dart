import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/team/team_members_provider.dart';
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

  /// Waits for the team and for each member's details, then returns the result.
  Future<TeamMembers> settledMembers(ProviderContainer app) async {
    await app.read(teamProvider.future);
    // Listening is what starts loading each member, and keeps the result.
    final subscription = app.listen(teamMembersProvider, (previous, next) {});
    for (final id in app.read(teamProvider).requireValue.memberIds) {
      await app.read(pokemonProvider(id).future);
    }
    return subscription.read()!;
  }

  test('is null until the saved team has loaded', () {
    final app = appWithTeam([pikachu]);

    expect(app.read(teamMembersProvider), isNull);
  });

  test('has one entry per slot, null for the empty ones', () async {
    final app = appWithTeam([null, pikachu, null]);

    final members = await settledMembers(app);

    expect(members.slots.length, 6);
    expect(members.slots[0], isNull);
    expect(members.slots[1]?.name, 'pikachu');
    expect(members.slots[2], isNull);
    expect(members.missingCount, 0);
    expect(members.loaded.map((p) => p.name), ['pikachu']);
  });

  test(
    'a member that failed to load is missing, and a blank slot is not',
    () async {
      final app = appWithTeam([pikachu, 7, null]);

      final members = await settledMembers(app);

      expect(members.slots[1], isNull);
      expect(members.missingCount, 1);
      expect(members.loaded.length, 1);
    },
  );

  test('counts a member that is still loading as missing', () async {
    final app = appWithTeam([pikachu]);
    await app.read(teamProvider.future);

    // Their details have been asked for but not answered.
    final members = app.read(teamMembersProvider)!;

    expect(members.missingCount, 1);
    expect(members.loaded, isEmpty);
  });

  test('an empty team has nobody and nobody missing', () async {
    final app = appWithTeam([]);

    final members = await settledMembers(app);

    expect(members.loaded, isEmpty);
    expect(members.missingCount, 0);
  });
}
