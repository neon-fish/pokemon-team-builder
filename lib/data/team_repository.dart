import 'dart:convert';

import 'package:pokemon_team_builder/data/json_reader.dart';
import 'package:pokemon_team_builder/data/storage/key_value_store.dart';
import 'package:pokemon_team_builder/domain/team.dart';

/// Saves the team and loads it back.
///
/// Persistence is best effort. If storage is unavailable (for example a browser
/// with site data blocked) or holds something unreadable, loading gives an
/// empty team and saving does nothing, so the app still works for the session.
class TeamRepository {
  TeamRepository(this._store);

  final KeyValueStore _store;

  static const _key = 'team';

  Future<Team> load() async {
    final String? saved;
    try {
      saved = await _store.read(_key);
    } on Object {
      // Any storage problem. See the class comment.
      return const Team();
    }
    if (saved == null) return const Team();

    try {
      return _decode(saved);
    } on FormatException {
      return const Team();
    }
  }

  Future<void> save(Team team) async {
    try {
      await _store.write(_key, jsonEncode({'ids': team.ids}));
    } on Object {
      // Best effort. See the class comment.
    }
  }

  /// Reads the saved text. Throws a [FormatException] if it is not what
  /// [save] writes.
  Team _decode(String saved) {
    final object = asJsonObject(jsonDecode(saved), 'the saved team');
    final ids = asJsonList(object['ids'], 'ids').whereType<int>();

    // Rebuild through `add`, so the rules (no duplicates, at most six) apply
    // to saved data too.
    var team = const Team();
    for (final id in ids) {
      team = team.add(id);
    }
    return team;
  }
}
