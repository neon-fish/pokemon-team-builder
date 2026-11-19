import 'package:pokemon_team_builder/data/storage/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [KeyValueStore] backed by `shared_preferences`, which on the web is the
/// browser's `localStorage`.
class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferencesKeyValueStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}
