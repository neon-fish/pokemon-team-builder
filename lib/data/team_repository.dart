import 'dart:convert';

import 'package:pokemon_team_builder/data/json_reader.dart';
import 'package:pokemon_team_builder/data/storage/key_value_store.dart';
import 'package:pokemon_team_builder/domain/team.dart';

/// Saves the team and loads it back.
///
/// Persistence is best effort. If storage is unavailable (for example a browser
/// with site data blocked) or holds something unreadable, loading gives an
/// empty team and saving does nothing, so the app still works for the session.
///
/// Saved as JSON with one entry per slot, `null` for an empty one:
/// `{"ids":[25,null,6,null,null,null]}`.
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
      await _store.write(_key, jsonEncode({'ids': team.slots}));
    } on Object {
      // Best effort. See the class comment.
    }
  }

  /// Reads the saved text. Throws a [FormatException] if it is not what
  /// [save] writes.
  Team _decode(String saved) {
    final object = asJsonObject(jsonDecode(saved), 'the saved team');
    final entries = asJsonList(object['ids'], 'ids');

    // Each saved slot is an id or empty; anything else (text, a decimal) is
    // treated as empty. `fromSlots` pads or cuts the list to exactly six, so
    // neither an old save with fewer entries nor a hand-edited one with more
    // can make the wrong size of team.
    return Team.fromSlots([
      for (final entry in entries)
        if (entry is int) entry else null,
    ]);
  }
}
