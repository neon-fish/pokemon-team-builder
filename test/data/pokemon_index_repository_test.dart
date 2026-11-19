import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/pokemon_index_repository.dart';

import '../support/fake_api_client.dart';
import '../support/fixtures.dart';

/// A list response containing the given entries.
Map<String, Object?> listOf(List<Object?> entries) => {
  'count': entries.length,
  'results': entries,
};

Map<String, String> entry(String name, String url) => {
  'name': name,
  'url': url,
};

void main() {
  group('parsePokemonIndex', () {
    test('reads a real response, in order', () {
      final index = parsePokemonIndex(loadFixture('pokemon_index.json'));

      expect(index.map((p) => p.name), [
        'bulbasaur',
        'ivysaur',
        'pikachu',
        'pikachu-rock-star',
        'baxcalibur-mega',
      ]);
    });

    test('takes the id from the end of the URL, including form variants', () {
      final index = parsePokemonIndex(loadFixture('pokemon_index.json'));

      expect(index.map((p) => p.id), [1, 2, 25, 10080, 10325]);
    });

    test('accepts a URL without the trailing slash', () {
      final index = parsePokemonIndex(
        listOf([entry('eevee', 'https://pokeapi.co/api/v2/pokemon/133')]),
      );

      expect(index.single.id, 133);
    });

    test('skips bad entries and keeps the good ones', () {
      final index = parsePokemonIndex(
        listOf([
          entry('mew', 'https://pokeapi.co/api/v2/pokemon/151/'),
          'not an object',
          {'url': 'https://pokeapi.co/api/v2/pokemon/1/'},
          {'name': 'no-url'},
          entry('wrong-path', 'https://pokeapi.co/api/v2/type/10/'),
          entry('no-number', 'https://pokeapi.co/api/v2/pokemon/abc/'),
          entry('too-big', 'https://pokeapi.co/api/v2/pokemon/${'9' * 30}/'),
          {'name': 7, 'url': 'https://pokeapi.co/api/v2/pokemon/2/'},
          entry('mewtwo', 'https://pokeapi.co/api/v2/pokemon/150/'),
        ]),
      );

      expect(index.map((p) => p.name), ['mew', 'mewtwo']);
    });

    group('throws FormatException when', () {
      void expectRejected(Object? json) =>
          expect(() => parsePokemonIndex(json), throwsFormatException);

      test('the response is not an object', () => expectRejected([1]));

      test('results is missing', () => expectRejected({'count': 0}));

      test('results is not a list', () {
        expectRejected({'results': 'many'});
      });

      test('results is empty', () => expectRejected(listOf([])));

      test('no entry is usable', () {
        expectRejected(listOf(['junk', 42, <String, Object?>{}]));
      });
    });
  });

  group('PokemonIndexRepository', () {
    test('asks for the whole list in one request and parses it', () async {
      final api = FakeApiClient((_) => Ok(loadFixture('pokemon_index.json')));

      final result = await PokemonIndexRepository(api).loadIndex();

      expect(
        api.calls.single.toString(),
        'https://pokeapi.co/api/v2/pokemon?limit=5000',
      );
      expect(result.valueOrNull, hasLength(5));
    });

    test('a failure passes through', () async {
      final api = FakeApiClient((_) => const Err(OfflineFailure()));

      final result = await PokemonIndexRepository(api).loadIndex();

      expect(result.failureOrNull, isA<OfflineFailure>());
    });

    test('an unusable response is a MalformedResponseFailure', () async {
      final api = FakeApiClient((_) => const Ok({'results': <Object?>[]}));

      final result = await PokemonIndexRepository(api).loadIndex();

      expect(result.failureOrNull, isA<MalformedResponseFailure>());
    });
  });
}
