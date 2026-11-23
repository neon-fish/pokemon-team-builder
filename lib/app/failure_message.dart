import 'package:pokemon_team_builder/core/api_failure.dart';

/// What to tell the user about [failure], in plain words.
///
/// The `switch` has no default, so a new kind of failure will not compile until
/// it has a message here.
String describeFailure(ApiFailure failure) => switch (failure) {
  OfflineFailure() =>
    'You seem to be offline. Check your connection and try again.',
  TimeoutFailure() => 'PokéAPI took too long to answer.',
  RateLimitedFailure() =>
    'PokéAPI asked us to slow down. Try again in a moment.',
  ServerFailure() => 'PokéAPI is having problems at the moment.',
  NotFoundFailure() => 'PokéAPI does not have that.',
  ClientErrorFailure() => 'PokéAPI rejected the request.',
  MalformedResponseFailure() => 'PokéAPI sent something we did not expect.',
};
