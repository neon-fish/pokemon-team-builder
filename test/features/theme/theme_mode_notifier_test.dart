import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/data/storage/key_value_store.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_notifier.dart';

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

  test('starts loading, then follows the browser', () async {
    final container = appWith(InMemoryKeyValueStore());

    expect(container.read(themeModeProvider).isLoading, isTrue);
    final mode = await container.read(themeModeProvider.future);

    expect(mode, ThemeMode.system);
  });

  test('loads the choice saved earlier', () async {
    final container = appWith(InMemoryKeyValueStore({'theme_mode': 'dark'}));

    final mode = await container.read(themeModeProvider.future);

    expect(mode, ThemeMode.dark);
  });

  test('choosing updates the state and saves it', () async {
    final store = InMemoryKeyValueStore();
    final container = appWith(store);
    await container.read(themeModeProvider.future);

    await container.read(themeModeProvider.notifier).choose(ThemeMode.light);

    expect(container.read(themeModeProvider).requireValue, ThemeMode.light);
    expect(store.data['theme_mode'], 'light');
  });

  test('a choice survives a restart', () async {
    final store = InMemoryKeyValueStore();
    final first = appWith(store);
    await first.read(themeModeProvider.future);
    await first.read(themeModeProvider.notifier).choose(ThemeMode.dark);

    // A brand-new app over the same storage.
    final second = appWith(store);
    final mode = await second.read(themeModeProvider.future);

    expect(mode, ThemeMode.dark);
  });

  test('a choice made before loading finishes is not overwritten', () async {
    final container = appWith(InMemoryKeyValueStore({'theme_mode': 'dark'}));

    // No waiting for the load: the saved 'dark' arrives after this call starts.
    await container.read(themeModeProvider.notifier).choose(ThemeMode.light);

    expect(container.read(themeModeProvider).requireValue, ThemeMode.light);
  });

  test('choosing the current mode does not save again', () async {
    final store = InMemoryKeyValueStore();
    final container = appWith(store);
    await container.read(themeModeProvider.future);

    await container.read(themeModeProvider.notifier).choose(ThemeMode.system);

    expect(store.data, isEmpty);
  });

  test('the choice still works for the session if storage fails', () async {
    final container = appWith(FailingKeyValueStore());

    final loaded = await container.read(themeModeProvider.future);
    await container.read(themeModeProvider.notifier).choose(ThemeMode.dark);

    expect(loaded, ThemeMode.system);
    expect(container.read(themeModeProvider).requireValue, ThemeMode.dark);
  });
}
