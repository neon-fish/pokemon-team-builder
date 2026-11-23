import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/features/team/add_target_notifier.dart';
import 'package:pokemon_team_builder/features/team/arrivals_notifier.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

import '../../support/in_memory_key_value_store.dart';

void main() {
  late InMemoryKeyValueStore store;

  setUp(() => store = InMemoryKeyValueStore());

  /// A container whose team has loaded from [saved], with the arrivals that
  /// loading caused already used up, so a test sees only what it causes itself.
  Future<ProviderContainer> teamLoaded({
    String? saved,
    bool keepStartupArrivals = false,
  }) async {
    if (saved != null) store.data['team'] = saved;
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container.read(teamProvider.future);
    if (!keepStartupArrivals) {
      for (var slot = 0; slot < 6; slot++) {
        container.read(arrivalsProvider.notifier).consume(slot);
      }
    }
    return container;
  }

  Map<int, Duration> arrivals(ProviderContainer container) =>
      container.read(arrivalsProvider);

  group('loading the saved team', () {
    test('every filled slot arrives, in order, a little apart', () async {
      final container = await teamLoaded(
        saved: '{"ids":[25,null,6,null,null,9]}',
        keepStartupArrivals: true,
      );

      // Spaced by position among the filled slots, not by slot number, so an
      // empty slot in between does not make the next one wait for nothing.
      expect(arrivals(container), {
        0: Duration.zero,
        2: startupThrowStagger,
        5: startupThrowStagger * 2,
      });
    });

    test('an empty team has none', () async {
      final container = await teamLoaded(keepStartupArrivals: true);

      expect(arrivals(container), isEmpty);
    });

    test('unreadable saved data, an empty team, has none', () async {
      final container = await teamLoaded(
        saved: 'not json',
        keepStartupArrivals: true,
      );

      expect(arrivals(container), isEmpty);
    });
  });

  group('adding', () {
    test('a Pokémon arrives in the slot it fills, at once', () async {
      final container = await teamLoaded(saved: '{"ids":[25]}');

      await container.read(teamProvider.notifier).add(6);

      expect(arrivals(container), {1: Duration.zero});
    });

    test('into a chosen slot arrives in that slot', () async {
      final container = await teamLoaded();

      await container.read(teamProvider.notifier).addAt(4, 6);

      expect(arrivals(container), {4: Duration.zero});
    });

    test('from the search arrives where it was put', () async {
      final container = await teamLoaded(saved: '{"ids":[25]}');
      final team = container.read(teamProvider.notifier);

      // With no slot chosen, the first empty one.
      await team.addPicked(6);
      expect(arrivals(container), {1: Duration.zero});

      // With a slot chosen, that one.
      container.read(addTargetProvider.notifier).choose(5);
      await team.addPicked(9);
      expect(arrivals(container), {1: Duration.zero, 5: Duration.zero});
    });

    test('that changes nothing leaves no arrival', () async {
      final container = await teamLoaded(saved: '{"ids":[1,2,3,4,5,6]}');
      final team = container.read(teamProvider.notifier);

      await team.add(7); // Full.
      await team.addAt(2, 7); // Taken.
      await team.addAt(9, 7); // No such slot.

      expect(arrivals(container), isEmpty);
    });
  });

  group('rearranging', () {
    test('moving into an empty slot is not an arrival', () async {
      final container = await teamLoaded(saved: '{"ids":[25]}');

      await container.read(teamProvider.notifier).move(0, 3);

      expect(arrivals(container), isEmpty);
    });

    test('swapping two Pokémon is not an arrival', () async {
      final container = await teamLoaded(saved: '{"ids":[25,6]}');

      await container.read(teamProvider.notifier).move(0, 1);

      expect(arrivals(container), isEmpty);
    });

    test('removing is not an arrival', () async {
      final container = await teamLoaded(saved: '{"ids":[25,6]}');

      await container.read(teamProvider.notifier).removeAt(0);

      expect(arrivals(container), isEmpty);
    });
  });

  group('using one up', () {
    test('takes out only that slot', () async {
      final container = await teamLoaded(
        saved: '{"ids":[25,6,9]}',
        keepStartupArrivals: true,
      );

      container.read(arrivalsProvider.notifier).consume(1);

      expect(arrivals(container).keys, [0, 2]);
    });

    test('a slot with none is no trouble', () async {
      final container = await teamLoaded();

      container.read(arrivalsProvider.notifier).consume(3);

      expect(arrivals(container), isEmpty);
    });
  });
}
