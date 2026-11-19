import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/data/team_repository.dart';
import 'package:pokemon_team_builder/domain/team.dart';

import '../support/in_memory_key_value_store.dart';

void main() {
  Future<Team> loadSaved(String saved) =>
      TeamRepository(InMemoryKeyValueStore({'team': saved})).load();

  test('an empty store gives an empty team', () async {
    final team = await TeamRepository(InMemoryKeyValueStore()).load();
    expect(team.ids, isEmpty);
  });

  test('a saved team loads back the same', () async {
    final store = InMemoryKeyValueStore();
    await TeamRepository(store).save(const Team([25, 6, 150]));

    final loaded = await TeamRepository(store).load();

    expect(loaded.ids, [25, 6, 150]);
  });

  group('unreadable saved data gives an empty team', () {
    test('not JSON', () async {
      expect((await loadSaved('{oops')).ids, isEmpty);
    });

    test('JSON of the wrong shape', () async {
      expect((await loadSaved('[1, 2, 3]')).ids, isEmpty);
      expect((await loadSaved('{"ids": "many"}')).ids, isEmpty);
      expect((await loadSaved('{}')).ids, isEmpty);
    });
  });

  test('values that are not ids are skipped', () async {
    final team = await loadSaved('{"ids": [1, "x", null, 2.5, 3]}');
    expect(team.ids, [1, 3]);
  });

  test('repeated Pokémon are kept', () async {
    final team = await loadSaved('{"ids": [4, 4, 4]}');
    expect(team.ids, [4, 4, 4]);
  });

  test('saved data still obeys the six-slot limit', () async {
    final team = await loadSaved('{"ids": [1, 1, 2, 3, 4, 5, 6, 7, 8]}');
    expect(team.ids, [1, 1, 2, 3, 4, 5]);
  });

  group('when storage is unavailable', () {
    test('loading gives an empty team', () async {
      final team = await TeamRepository(FailingKeyValueStore()).load();
      expect(team.ids, isEmpty);
    });

    test('saving does not throw', () async {
      await expectLater(
        TeamRepository(FailingKeyValueStore()).save(const Team([1])),
        completes,
      );
    });
  });
}
