import 'package:pokemon_team_builder/data/http/http_transport.dart';

import 'fake_transport.dart';
import 'fixtures.dart';

/// A transport that answers each address like the real API would (the index,
/// Pikachu, and the 18 types), and counts how often each was asked for. For
/// tests that run the app's real networking stack over a fake network.
class CountingTransport implements HttpTransport {
  final _chartResponses =
      loadFixture('type_chart_responses.json')! as Map<String, Object?>;

  /// How many times each path was requested.
  final counts = <String, int>{};

  @override
  Future<TransportResponse> get(Uri url) async {
    counts[url.path] = (counts[url.path] ?? 0) + 1;
    if (url.path.contains('/type/')) {
      return okJson(_chartResponses[url.pathSegments.last]);
    }
    if (url.path.endsWith('/pokemon/25')) {
      return okJson(loadFixture('pokemon_pikachu.json'));
    }
    return okJson(loadFixture('pokemon_index.json'));
  }
}
