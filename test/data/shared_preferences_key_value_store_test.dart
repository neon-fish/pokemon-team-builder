import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/data/storage/shared_preferences_key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    // Real `shared_preferences` code, with the browser or device storage
    // underneath swapped for a map.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('a missing key reads as null', () async {
    final store = SharedPreferencesKeyValueStore(SharedPreferencesAsync());
    expect(await store.read('nothing'), isNull);
  });

  test('a written value reads back, from a fresh store too', () async {
    await SharedPreferencesKeyValueStore(SharedPreferencesAsync())
        .write('team', '{"ids":[25]}');

    final again = SharedPreferencesKeyValueStore(SharedPreferencesAsync());

    expect(await again.read('team'), '{"ids":[25]}');
  });

  test('writing again replaces the value', () async {
    final store = SharedPreferencesKeyValueStore(SharedPreferencesAsync());
    await store.write('k', 'one');
    await store.write('k', 'two');
    expect(await store.read('k'), 'two');
  });
}
