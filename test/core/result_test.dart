import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';

void main() {
  group('Result', () {
    test('Ok exposes its value and no failure', () {
      const Result<int> result = Ok(3);
      expect(result.valueOrNull, 3);
      expect(result.failureOrNull, isNull);
    });

    test('Err exposes its failure and no value', () {
      const Result<int> result = Err(NotFoundFailure());
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('ApiFailure.isTransient', () {
    test('network, timeout, rate limit and server failures can be retried', () {
      const transient = <ApiFailure>[
        OfflineFailure(),
        TimeoutFailure(),
        RateLimitedFailure(),
        ServerFailure(500),
      ];
      expect(transient.map((f) => f.isTransient), everyElement(isTrue));
    });

    test('not found, rejected and malformed responses are permanent', () {
      const permanent = <ApiFailure>[
        NotFoundFailure(),
        ClientErrorFailure(400),
        MalformedResponseFailure('x'),
      ];
      expect(permanent.map((f) => f.isTransient), everyElement(isFalse));
    });
  });
}
