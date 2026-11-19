import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/type_chart_repository.dart';
import 'package:pokemon_team_builder/domain/type_chart.dart';

import 'fake_api_client.dart';
import 'fixtures.dart';

/// The real type chart, built from trimmed copies of all 18 API responses by
/// the real repository.
Future<TypeChart> loadRealTypeChart() async {
  final responses =
      loadFixture('type_chart_responses.json')! as Map<String, Object?>;
  // The last part of `.../type/fire` is the type's name.
  final api = FakeApiClient((url) => Ok(responses[url.pathSegments.last]));

  final result = await TypeChartRepository(api).loadTypeChart();
  return result.valueOrNull!;
}
