import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';

/// An [ApiClient] that answers from a function and records the requests.
class FakeApiClient implements ApiClient {
  FakeApiClient(this._respond);

  final Result<Object?> Function(Uri url) _respond;
  final List<Uri> calls = [];

  @override
  Future<Result<Object?>> getJson(Uri url) async {
    calls.add(url);
    return _respond(url);
  }
}
