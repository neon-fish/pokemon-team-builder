import 'package:pokemon_team_builder/core/result.dart';

/// Fetches JSON and reports every expected failure as a typed value.
///
/// Implementations never throw for network or HTTP problems. Behaviour such as
/// retrying, limiting concurrency and caching is added by wrapping one
/// [ApiClient] in another.
abstract interface class ApiClient {
  Future<Result<Object?>> getJson(Uri url);
}
