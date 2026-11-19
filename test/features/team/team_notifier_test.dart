import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/data/storage/key_value_store.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

import '../../support/in_memory_key_value_store.dart';

void main() {
  /// A fresh app (container) whose storage is [store].
  ProviderContainer appWith(KeyValueStore store) {
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts loading, then gives an empty team', () async {
    final container = appWith(InMemoryKeyValueStore());

    expect(container.read(teamProvider).isLoading, isTrue);
    final team = await container.read(teamProvider.future);

    expect(team.ids, isEmpty);
  });

  test('loads the team saved earlier', () async {
    final container = appWith(
      InMemoryKeyValueStore({'team': '{"ids":[25,6]}'}),
    );

    final team = await container.read(teamProvider.future);

    expect(team.ids, [25, 6]);
  });

  test('adding updates the state', () async {
    final container = appWith(InMemoryKeyValueStore());
    await container.read(teamProvider.future);

    await container.read(teamProvider.notifier).add(25);

    expect(container.read(teamProvider).requireValue.ids, [25]);
  });

  test('a change survives a restart', () async {
    final store = InMemoryKeyValueStore();
    final first = appWith(store);
    await first.read(teamProvider.future);
    await first.read(teamProvider.notifier).add(25);
    await first.read(teamProvider.notifier).add(6);
    await first.read(teamProvider.notifier).remove(25);

    // A brand-new app over the same storage.
    final second = appWith(store);
    final team = await second.read(teamProvider.future);

    expect(team.ids, [6]);
  });

  test('changes made before loading finishes are not lost', () async {
    final container = appWith(InMemoryKeyValueStore({'team': '{"ids":[1]}'}));

    // No waiting for the load: both calls start straight away.
    final notifier = container.read(teamProvider.notifier);
    await Future.wait([notifier.add(2), notifier.add(3)]);

    expect(container.read(teamProvider).requireValue.ids, [1, 2, 3]);
  });

  test('a seventh Pokémon is ignored', () async {
    final store = InMemoryKeyValueStore({'team': '{"ids":[1,2,3,4,5,6]}'});
    final container = appWith(store);
    await container.read(teamProvider.future);

    await container.read(teamProvider.notifier).add(7);

    expect(container.read(teamProvider).requireValue.ids, [1, 2, 3, 4, 5, 6]);
  });

  test('a change that changes nothing is not saved', () async {
    final store = InMemoryKeyValueStore();
    final container = appWith(store);
    await container.read(teamProvider.future);

    await container.read(teamProvider.notifier).remove(99);

    expect(store.data, isEmpty);
  });

  test('the team still works for the session if storage fails', () async {
    final container = appWith(FailingKeyValueStore());

    final loaded = await container.read(teamProvider.future);
    await container.read(teamProvider.notifier).add(25);

    expect(loaded.ids, isEmpty);
    expect(container.read(teamProvider).requireValue.ids, [25]);
  });
}
