import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';

/// The user's choice of light, dark or "follow the browser". Loaded from
/// storage when first read, saved after every change.
///
/// The state is an `AsyncValue<ThemeMode>`: loading for a moment, then data.
/// Loading cannot fail (a problem with storage means "follow the browser"), so
/// there is no error state to handle. `main` waits for the first value before
/// showing anything, so the app never flashes the wrong theme.
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() => ref.watch(themeModeRepositoryProvider).load();

  /// Switches to [mode] and saves the choice. Choosing the current mode does
  /// nothing.
  Future<void> choose(ThemeMode mode) async {
    // Make sure the saved choice has loaded first, so it cannot arrive later
    // and overwrite this one.
    await future;

    if (state.requireValue == mode) return;
    state = AsyncData(mode);

    await ref.read(themeModeRepositoryProvider).save(mode);
  }
}

final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
