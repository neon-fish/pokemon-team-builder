import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/failure_message.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';

void main() {
  const failures = <ApiFailure>[
    OfflineFailure('no wifi'),
    TimeoutFailure(),
    RateLimitedFailure(retryAfter: Duration(seconds: 5)),
    ServerFailure(503),
    NotFoundFailure(),
    ClientErrorFailure(400),
    MalformedResponseFailure('not JSON'),
  ];

  test('every kind of failure has a message', () {
    for (final failure in failures) {
      expect(describeFailure(failure), isNotEmpty, reason: '$failure');
    }
  });

  test('each kind of failure has its own message', () {
    final messages = {for (final failure in failures) describeFailure(failure)};

    expect(messages, hasLength(failures.length));
  });

  test('the message is plain words, not technical detail', () {
    final message = describeFailure(const ServerFailure(503));

    expect(message, isNot(contains('503')));
    expect(message, isNot(contains('ServerFailure')));
  });
}
