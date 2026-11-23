import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/json_reader.dart';
import 'package:pokemon_team_builder/data/parse_result.dart';
import 'package:pokemon_team_builder/data/poke_api.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';

/// Loads single Pokémon from the API.
class PokemonRepository {
  PokemonRepository(this._client);

  final ApiClient _client;

  Future<Result<Pokemon>> loadPokemon(int id) async {
    final url = Uri.parse('$pokeApiBaseUrl/pokemon/$id');
    final result = await _client.getJson(url);
    return parseResponse(_client, url, result, parsePokemon);
  }
}

/// Reads one `/pokemon/{id}` response.
///
/// Throws a [FormatException] if the id, name, types or stats are missing or
/// the wrong kind of value. The picture is different: it is cosmetic, so if it
/// is missing or odd the Pokémon still loads, just without one.
Pokemon parsePokemon(Object? json) {
  final response = asJsonObject(json, 'the Pokémon response');
  return Pokemon(
    id: asJsonInt(response['id'], 'id'),
    name: asJsonString(response['name'], 'name'),
    types: _parseTypes(response['types']),
    stats: _parseStats(response['stats']),
    spriteUrl: _parseSpriteUrl(response['sprites']),
  );
}

/// Reads the current types. (The response also has `past_types`, how the types
/// looked in older games, which we ignore.)
///
/// Names we do not model are skipped; a Pokémon left with no known type at all
/// is rejected, since the analysis could not say anything about it.
List<PokemonType> _parseTypes(Object? json) {
  final types = <PokemonType>[];
  for (final entry in asJsonList(json, 'types')) {
    final slot = asJsonObject(entry, 'a type entry');
    final typeObject = asJsonObject(slot['type'], 'type');
    final type = PokemonType.fromName(
      asJsonString(typeObject['name'], 'type name'),
    );
    if (type != null) types.add(type);
  }
  if (types.isEmpty) throw const FormatException('No recognised types');
  return types;
}

BaseStats _parseStats(Object? json) {
  final values = <String, int>{};
  for (final entry in asJsonList(json, 'stats')) {
    final item = asJsonObject(entry, 'a stat entry');
    final statObject = asJsonObject(item['stat'], 'stat');
    final name = asJsonString(statObject['name'], 'stat name');
    values[name] = asJsonInt(item['base_stat'], 'base_stat of $name');
  }
  return BaseStats(
    hp: _stat(values, 'hp'),
    attack: _stat(values, 'attack'),
    defense: _stat(values, 'defense'),
    specialAttack: _stat(values, 'special-attack'),
    specialDefense: _stat(values, 'special-defense'),
    speed: _stat(values, 'speed'),
  );
}

int _stat(Map<String, int> values, String name) {
  final value = values[name];
  if (value == null) throw FormatException('Missing stat: $name');
  return value;
}

/// Prefers the official artwork, then the small sprite, else null.
///
/// Many form variants have no small sprite, and a few have no picture at all,
/// so every level may be missing or null. The map patterns below match only
/// when each level is there and the final value is a string.
String? _parseSpriteUrl(Object? sprites) {
  if (sprites case {
    'other': {'official-artwork': {'front_default': final String artwork}},
  }) {
    return artwork;
  }
  if (sprites case {'front_default': final String small}) {
    return small;
  }
  return null;
}
