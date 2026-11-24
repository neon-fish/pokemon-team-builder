import 'package:flutter_test/flutter_test.dart';

import 'json_shape.dart';

void main() {
  test('the same shape has no differences, whatever the values', () {
    expect(
      shapeDifferences(
        {'id': 25, 'name': 'pikachu', 'ok': true},
        {'id': 26, 'name': 'raichu', 'ok': false},
      ),
      isEmpty,
    );
  });

  test('extra keys in the live response are fine (fixtures are trimmed)', () {
    expect(shapeDifferences({'id': 1}, {'id': 1, 'height': 4}), isEmpty);
  });

  test('a key that has gone is reported with its path', () {
    expect(
      shapeDifferences(
        {
          'stats': [
            {
              'stat': {'name': 'hp'},
            },
          ],
        },
        {
          'stats': [
            {'stat': <String, Object?>{}},
          ],
        },
      ),
      ['.stats[0].stat.name: missing'],
    );
  });

  test('a value of a different kind is reported', () {
    expect(shapeDifferences({'id': 25}, {'id': '25'}), [
      '.id: was a number, is now a string',
    ]);
  });

  test('an object that became a list, and the reverse, are reported', () {
    expect(shapeDifferences({'a': <String, Object?>{}}, {'a': <Object?>[]}), [
      '.a: was an object, is now a list',
    ]);
    expect(shapeDifferences({'a': <Object?>[]}, {'a': <String, Object?>{}}), [
      '.a: was a list, is now an object',
    ]);
  });

  test('only the first item of a list is compared', () {
    expect(
      shapeDifferences(
        {
          'items': [
            {'name': 'a'},
          ],
        },
        {
          'items': [
            {'name': 'b'},
            {'other': 1},
          ],
        },
      ),
      isEmpty,
    );
  });

  test('an empty list, or a null, says nothing, so it is fine', () {
    expect(
      shapeDifferences(
        {'a': <Object?>[]},
        {
          'a': [1],
        },
      ),
      isEmpty,
    );
    expect(
      shapeDifferences(
        {
          'a': <Object?>[1],
        },
        {'a': <Object?>[]},
      ),
      isEmpty,
    );
    expect(shapeDifferences({'a': 'x'}, {'a': null}), isEmpty);
    expect(shapeDifferences({'a': null}, {'a': 'x'}), isEmpty);
  });

  test('reports every difference, not just the first', () {
    expect(
      shapeDifferences({'a': 1, 'b': 'x', 'c': true}, {'a': 'no', 'b': 'x'}),
      hasLength(2),
    );
  });
}
