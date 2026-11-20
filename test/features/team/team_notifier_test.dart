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

  /// What is in each of the six slots right now.
  List<int?> slotsIn(ProviderContainer container) =>
      container.read(teamProvider).requireValue.slots;

  test('starts loading, then gives an empty team', () async {
    final container = appWith(InMemoryKeyValueStore());

    expect(container.read(teamProvider).isLoading, isTrue);
    final team = await container.read(teamProvider.future);

    expect(team.memberIds, isEmpty);
  });

  test('loads the team saved earlier, gaps included', () async {
    final container = appWith(
      InMemoryKeyValueStore({'team': '{"ids":[25,null,6]}'}),
    );

    final team = await container.read(teamProvider.future);

    expect(team.slots, [25, null, 6, null, null, null]);
  });

  test('adding updates the state', () async {
    final container = appWith(InMemoryKeyValueStore());
    await container.read(teamProvider.future);

    await container.read(teamProvider.notifier).add(25);

    expect(slotsIn(container), [25, null, null, null, null, null]);
  });

  test('adding fills a gap left by an earlier removal', () async {
    final container = appWith(
      InMemoryKeyValueStore({'team': '{"ids":[1,2,3]}'}),
    );
    await container.read(teamProvider.future);
    final notifier = container.read(teamProvider.notifier);

    await notifier.removeAt(1);
    await notifier.add(9);

    expect(slotsIn(container), [1, 9, 3, null, null, null]);
  });

  test('moving swaps two slots and saves the team', () async {
    final store = InMemoryKeyValueStore({'team': '{"ids":[1,2,3]}'});
    final container = appWith(store);
    await container.read(teamProvider.future);

    await container.read(teamProvider.notifier).move(0, 2);

    expect(slotsIn(container), [3, 2, 1, null, null, null]);
    expect(store.data['team'], '{"ids":[3,2,1,null,null,null]}');
  });

  test('a change survives a restart', () async {
    final store = InMemoryKeyValueStore();
    final first = appWith(store);
    await first.read(teamProvider.future);
    await first.read(teamProvider.notifier).add(25);
    await first.read(teamProvider.notifier).add(6);
    await first.read(teamProvider.notifier).removeAt(0);
    await first.read(teamProvider.notifier).move(1, 4);

    // A brand-new app over the same storage.
    final second = appWith(store);
    final team = await second.read(teamProvider.future);

    expect(team.slots, [null, null, null, null, 6, null]);
  });

  test('changes made before loading finishes are not lost', () async {
    final container = appWith(InMemoryKeyValueStore({'team': '{"ids":[1]}'}));

    // No waiting for the load: both calls start straight away.
    final notifier = container.read(teamProvider.notifier);
    await Future.wait([notifier.add(2), notifier.add(3)]);

    expect(slotsIn(container), [1, 2, 3, null, null, null]);
  });

  test('different kinds of change are applied in the order made', () async {
    final container = appWith(InMemoryKeyValueStore({'team': '{"ids":[1,2]}'}));
    final notifier = container.read(teamProvider.notifier);

    // Swap the two (giving 2, 1), then empty the first slot (leaving 1).
    await Future.wait([notifier.move(0, 1), notifier.removeAt(0)]);

    expect(slotsIn(container), [null, 1, null, null, null, null]);
  });

  test('a seventh Pokémon is ignored', () async {
    final store = InMemoryKeyValueStore({'team': '{"ids":[1,2,3,4,5,6]}'});
    final container = appWith(store);
    await container.read(teamProvider.future);

    await container.read(teamProvider.notifier).add(7);

    expect(slotsIn(container), [1, 2, 3, 4, 5, 6]);
  });

  group('a change that changes nothing is not saved', () {
    Future<void> expectNothingSaved(
      Future<void> Function(TeamNotifier notifier) change,
    ) async {
      final store = InMemoryKeyValueStore();
      final container = appWith(store);
      await container.read(teamProvider.future);

      await change(container.read(teamProvider.notifier));

      expect(store.data, isEmpty);
    }

    test('removing a slot that does not exist', () {
      return expectNothingSaved((notifier) => notifier.removeAt(99));
    });

    test('removing a slot that is already empty', () {
      return expectNothingSaved((notifier) => notifier.removeAt(2));
    });

    test('moving between two empty slots', () {
      return expectNothingSaved((notifier) => notifier.move(0, 1));
    });
  });

  test('six of the same Pokémon make a team, and it is saved', () async {
    final store = InMemoryKeyValueStore();
    final container = appWith(store);
    final notifier = container.read(teamProvider.notifier);

    // Six Charmanders, added one straight after another.
    await Future.wait([for (var i = 0; i < 6; i++) notifier.add(4)]);

    expect(slotsIn(container), [4, 4, 4, 4, 4, 4]);
    expect(store.data['team'], '{"ids":[4,4,4,4,4,4]}');
  });

  test('removing one of two identical slots keeps the other', () async {
    final store = InMemoryKeyValueStore({'team': '{"ids":[4,7,4]}'});
    final container = appWith(store);
    await container.read(teamProvider.future);

    await container.read(teamProvider.notifier).removeAt(0);

    expect(slotsIn(container), [null, 7, 4, null, null, null]);
  });

  test('the team still works for the session if storage fails', () async {
    final container = appWith(FailingKeyValueStore());

    final loaded = await container.read(teamProvider.future);
    await container.read(teamProvider.notifier).add(25);

    expect(loaded.memberIds, isEmpty);
    expect(slotsIn(container), [25, null, null, null, null, null]);
  });
}
