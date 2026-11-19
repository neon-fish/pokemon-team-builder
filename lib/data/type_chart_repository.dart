import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/json_reader.dart';
import 'package:pokemon_team_builder/data/parse_result.dart';
import 'package:pokemon_team_builder/data/poke_api.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';

/// Builds the [TypeChart] from the API: one request per type, 18 in all.
///
/// The requests go out together; the concurrency limiter keeps the number in
/// flight sensible, and the cache means a second load costs nothing.
class TypeChartRepository {
  TypeChartRepository(this._client);

  final ApiClient _client;

  /// The whole chart, or the first failure if any one type could not be loaded
  /// (a chart with a missing row would give wrong answers, so there is no
  /// partial result).
  Future<Result<TypeChart>> loadTypeChart() async {
    const types = PokemonType.values;
    final results = await Future.wait([
      for (final type in types) _loadAttacks(type),
    ]);

    final attacks = <PokemonType, Map<PokemonType, double>>{};
    for (var i = 0; i < types.length; i++) {
      switch (results[i]) {
        case Ok(value: final value):
          attacks[types[i]] = value;
        case Err(failure: final failure):
          return Err(failure);
      }
    }
    return Ok(TypeChart(attacks));
  }

  Future<Result<Map<PokemonType, double>>> _loadAttacks(
    PokemonType type,
  ) async {
    final result = await _client.getJson(
      Uri.parse('$pokeApiBaseUrl/type/${type.name}'),
    );
    return parseResult(result, parseAttackMultipliers);
  }
}

/// Reads one `/type/{name}` response and returns what that type's attacks do:
/// each defending type that is not simply 1, with its multiplier.
///
/// Throws a [FormatException] if the response is not shaped as expected. Type
/// names we do not model (such as `stellar`) are skipped rather than treated as
/// an error, so a new type added to the API does not break the chart.
Map<PokemonType, double> parseAttackMultipliers(Object? json) {
  final response = asJsonObject(json, 'the type response');
  final relations = asJsonObject(
    response['damage_relations'],
    'damage_relations',
  );

  final multipliers = <PokemonType, double>{};
  _addMultipliers(multipliers, relations, 'double_damage_to', 2);
  _addMultipliers(multipliers, relations, 'half_damage_to', 0.5);
  _addMultipliers(multipliers, relations, 'no_damage_to', 0);
  return multipliers;
}

void _addMultipliers(
  Map<PokemonType, double> multipliers,
  Map<String, Object?> relations,
  String key,
  double multiplier,
) {
  for (final entry in asJsonList(relations[key], key)) {
    final name = asJsonString(asJsonObject(entry, key)['name'], '$key name');
    final type = PokemonType.fromName(name);
    if (type != null) multipliers[type] = multiplier;
  }
}
