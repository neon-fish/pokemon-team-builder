import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/json_reader.dart';
import 'package:pokemon_team_builder/data/parse_result.dart';
import 'package:pokemon_team_builder/data/poke_api.dart';
import 'package:pokemon_team_builder/domain/pokemon_summary.dart';

/// Loads the list of every Pokémon (name and id only), for searching.
///
/// The list endpoint returns names and URLs, not details, so this is one cheap
/// request (about 90 KB today). Details are loaded one by one, on demand, by
/// the Pokémon repository.
class PokemonIndexRepository {
  PokemonIndexRepository(this._client);

  final ApiClient _client;

  Future<Result<List<PokemonSummary>>> loadIndex() async {
    // The limit is far above the roughly 1,350 entries that exist, so the whole
    // list arrives in a single page, with room to grow.
    final result = await _client.getJson(
      Uri.parse('$pokeApiBaseUrl/pokemon?limit=5000'),
    );
    return parseResult(result, parsePokemonIndex);
  }
}

/// Reads a `/pokemon?limit=...` response.
///
/// Throws a [FormatException] if the response is not an object with a `results`
/// list, or if no usable entry is found in it. A single bad entry is skipped
/// instead: the other 1,350 are independent, and one oddity should not take
/// search away from everyone.
List<PokemonSummary> parsePokemonIndex(Object? json) {
  final response = asJsonObject(json, 'the Pokémon list');
  final entries = asJsonList(response['results'], 'results');

  final index = <PokemonSummary>[];
  for (final entry in entries) {
    final summary = _parseEntry(entry);
    if (summary != null) index.add(summary);
  }
  if (index.isEmpty) throw const FormatException('No usable entries in list');
  return index;
}

/// Reads one `{"name": ..., "url": ".../pokemon/25/"}` entry, or null if it is
/// not that shape.
PokemonSummary? _parseEntry(Object? entry) {
  if (entry case {'name': final String name, 'url': final String url}) {
    final id = _idFromUrl(url);
    if (id != null) return PokemonSummary(id: id, name: name);
  }
  return null;
}

/// The id at the end of a URL such as `https://pokeapi.co/api/v2/pokemon/25/`.
int? _idFromUrl(String url) {
  final match = RegExp(r'/pokemon/(\d+)/?$').firstMatch(url);
  if (match == null) return null;
  // `tryParse` gives null for a number too large to hold, where `parse` would
  // throw and take the whole list down with one bad entry.
  return int.tryParse(match.group(1)!);
}
