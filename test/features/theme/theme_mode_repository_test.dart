import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_repository.dart';

import '../../support/in_memory_key_value_store.dart';

void main() {
  Future<ThemeMode> loadSaved(String saved) =>
      ThemeModeRepository(InMemoryKeyValueStore({'theme_mode': saved})).load();

  test('with nothing saved, follows the browser', () async {
    final mode = await ThemeModeRepository(InMemoryKeyValueStore()).load();
    expect(mode, ThemeMode.system);
  });

  test('every mode loads back the same', () async {
    for (final mode in ThemeMode.values) {
      final store = InMemoryKeyValueStore();
      await ThemeModeRepository(store).save(mode);

      final loaded = await ThemeModeRepository(store).load();

      expect(loaded, mode);
    }
  });

  test('is saved under a readable name', () async {
    final store = InMemoryKeyValueStore();
    await ThemeModeRepository(store).save(ThemeMode.dark);

    expect(store.data['theme_mode'], 'dark');
  });

  test('an unrecognised saved value follows the browser', () async {
    expect(await loadSaved('purple'), ThemeMode.system);
    expect(await loadSaved(''), ThemeMode.system);
    // Names are matched exactly.
    expect(await loadSaved('Dark'), ThemeMode.system);
  });

  group('when storage is unavailable', () {
    test('loading follows the browser', () async {
      final mode = await ThemeModeRepository(FailingKeyValueStore()).load();
      expect(mode, ThemeMode.system);
    });

    test('saving does not throw', () async {
      await expectLater(
        ThemeModeRepository(FailingKeyValueStore()).save(ThemeMode.dark),
        completes,
      );
    });
  });
}
