import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/data/team_repository.dart';
import 'package:pokemon_team_builder/domain/team.dart';

import '../support/in_memory_key_value_store.dart';

void main() {
  const noOne = [null, null, null, null, null, null];

  Future<Team> loadSaved(String saved) =>
      TeamRepository(InMemoryKeyValueStore({'team': saved})).load();

  test('an empty store gives an empty team', () async {
    final team = await TeamRepository(InMemoryKeyValueStore()).load();
    expect(team.slots, noOne);
  });

  test('a saved team loads back the same, gaps included', () async {
    final store = InMemoryKeyValueStore();
    await TeamRepository(store)
        .save(Team.fromSlots([25, null, 6, null, null, 150]));

    final loaded = await TeamRepository(store).load();

    expect(loaded.slots, [25, null, 6, null, null, 150]);
  });

  test('is saved as one entry per slot', () async {
    final store = InMemoryKeyValueStore();
    await TeamRepository(store).save(Team.fromSlots([25, null, 6]));

    expect(store.data['team'], '{"ids":[25,null,6,null,null,null]}');
  });

  group('unreadable saved data gives an empty team', () {
    test('not JSON', () async {
      expect((await loadSaved('{oops')).slots, noOne);
    });

    test('JSON of the wrong shape', () async {
      expect((await loadSaved('[1, 2, 3]')).slots, noOne);
      expect((await loadSaved('{"ids": "many"}')).slots, noOne);
      expect((await loadSaved('{}')).slots, noOne);
    });
  });

  test('a value that is not an id leaves its slot empty', () async {
    final team = await loadSaved('{"ids": [1, "x", null, 2.5, 3]}');
    expect(team.slots, [1, null, null, null, 3, null]);
  });

  test('a save with fewer than six entries fills the first slots', () async {
    // The format used before empty slots were allowed.
    final team = await loadSaved('{"ids": [25, 6]}');
    expect(team.slots, [25, 6, null, null, null, null]);
  });

  test('repeated Pokémon are kept', () async {
    final team = await loadSaved('{"ids": [4, 4, 4]}');
    expect(team.slots, [4, 4, 4, null, null, null]);
  });

  test('saved data still obeys the six-slot limit', () async {
    final team = await loadSaved('{"ids": [1, 1, 2, 3, 4, 5, 6, 7, 8]}');
    expect(team.slots, [1, 1, 2, 3, 4, 5]);
  });

  group('when storage is unavailable', () {
    test('loading gives an empty team', () async {
      final team = await TeamRepository(FailingKeyValueStore()).load();
      expect(team.slots, noOne);
    });

    test('saving does not throw', () async {
      await expectLater(
        TeamRepository(FailingKeyValueStore()).save(Team.fromSlots([1])),
        completes,
      );
    });
  });
}
