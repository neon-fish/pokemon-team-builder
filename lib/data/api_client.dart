import 'package:pokemon_team_builder/core/result.dart';

/// Fetches JSON and reports every expected failure as a typed value.
///
/// Implementations never throw for network or HTTP problems. Behaviour such as
/// retrying, limiting concurrency and caching is added by wrapping one
/// [ApiClient] in another.
abstract interface class ApiClient {
  Future<Result<Object?>> getJson(Uri url);
}

/// An [ApiClient] that remembers answers, and can be told that one was no good.
///
/// Whoever reads an answer is the only one who knows if it is usable. An answer
/// can be perfectly good JSON and still not be what was asked for. Without a
/// way to say so, asking again would just be handed the same bad answer.
abstract interface class ResponseCache {
  /// Drops the answer stored for [url], so the next request for it goes to the
  /// network. Does nothing if there is none.
  void forget(Uri url);
}
