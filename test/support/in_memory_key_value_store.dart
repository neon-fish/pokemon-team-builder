import 'package:pokemon_team_builder/data/storage/key_value_store.dart';

/// A [KeyValueStore] that keeps everything in a map. [data] can be set up
/// before a test and inspected afterwards.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

/// A [KeyValueStore] that always fails, like a browser with site data blocked.
class FailingKeyValueStore implements KeyValueStore {
  @override
  Future<String?> read(String key) async =>
      throw Exception('storage unavailable');

  @override
  Future<void> write(String key, String value) async =>
      throw Exception('storage unavailable');
}
