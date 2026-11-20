import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/data/storage/key_value_store.dart';

/// Saves the user's choice of light, dark or "follow the browser", and loads it
/// back.
///
/// This lives in `features/theme` rather than `data` because it deals in
/// Flutter's [ThemeMode], and `data` is plain Dart.
///
/// Like the team (see `TeamRepository`), persistence is best effort: if storage
/// is unavailable or holds something unrecognised, the choice is
/// [ThemeMode.system] and saving does nothing.
class ThemeModeRepository {
  ThemeModeRepository(this._store);

  final KeyValueStore _store;

  static const _key = 'theme_mode';

  Future<ThemeMode> load() async {
    try {
      final saved = await _store.read(_key);
      // Saved as the enum's name: 'system', 'light' or 'dark'. Anything else,
      // including nothing at all, falls back to following the browser.
      return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
    } on Object {
      // Any storage problem. See the class comment.
      return ThemeMode.system;
    }
  }

  Future<void> save(ThemeMode mode) async {
    try {
      await _store.write(_key, mode.name);
    } on Object {
      // Best effort. See the class comment.
    }
  }
}
