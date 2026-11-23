import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/caching_api_client.dart';
import 'package:pokemon_team_builder/data/pokemon_repository.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';

import '../support/fake_api_client.dart';
import '../support/fixtures.dart';

const _pikachuArtwork =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/25.png';
const _pikachuSmall =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png';

/// A fresh, editable copy of the Pikachu response.
Map<String, Object?> pikachu() {
  return loadFixture('pokemon_pikachu.json')! as Map<String, Object?>;
}

void main() {
  group('parsePokemon', () {
    test('reads a real response', () {
      final pokemon = parsePokemon(pikachu());

      expect(pokemon.id, 25);
      expect(pokemon.name, 'pikachu');
      expect(pokemon.types, [PokemonType.electric]);
      expect(pokemon.stats.hp, 35);
      expect(pokemon.stats.attack, 55);
      expect(pokemon.stats.defense, 40);
      expect(pokemon.stats.specialAttack, 50);
      expect(pokemon.stats.specialDefense, 50);
      expect(pokemon.stats.speed, 90);
      expect(pokemon.spriteUrl, _pikachuArtwork);
    });

    test('keeps both types in order, primary first', () {
      final pokemon = parsePokemon(
        loadFixture('pokemon_koraidon_limited_build.json'),
      );

      expect(pokemon.types, [PokemonType.fighting, PokemonType.dragon]);
    });

    test('ignores types it does not model, but keeps the rest', () {
      final json = pikachu();
      (json['types']! as List<Object?>).add({
        'slot': 2,
        'type': {'name': 'stellar'},
      });

      expect(parsePokemon(json).types, [PokemonType.electric]);
    });

    group('picture', () {
      test('falls back to the small sprite when there is no artwork', () {
        final json = pikachu();
        json['sprites'] = {'front_default': _pikachuSmall};

        expect(parsePokemon(json).spriteUrl, _pikachuSmall);
      });

      test('falls back when the artwork is null', () {
        final json = pikachu();
        json['sprites'] = {
          'front_default': _pikachuSmall,
          'other': {
            'official-artwork': {'front_default': null},
          },
        };

        expect(parsePokemon(json).spriteUrl, _pikachuSmall);
      });

      test('uses artwork when the small sprite is null (real form)', () {
        final pokemon = parsePokemon(
          loadFixture('pokemon_koraidon_sprinting_build.json'),
        );

        expect(pokemon.spriteUrl, endsWith('official-artwork/10265.png'));
      });

      test('is null when the API has no picture (real form)', () {
        final pokemon = parsePokemon(
          loadFixture('pokemon_koraidon_limited_build.json'),
        );

        expect(pokemon.spriteUrl, isNull);
      });

      test('a missing or odd sprites field does not fail the Pokémon', () {
        final missing = pikachu()..remove('sprites');
        final odd = pikachu()..['sprites'] = 'not an object';

        expect(parsePokemon(missing).spriteUrl, isNull);
        expect(parsePokemon(odd).spriteUrl, isNull);
      });
    });

    group('throws FormatException when', () {
      void expectRejected(Map<String, Object?> json) =>
          expect(() => parsePokemon(json), throwsFormatException);

      test('the response is not an object', () {
        expect(() => parsePokemon([1]), throwsFormatException);
      });

      test('the id is missing', () => expectRejected(pikachu()..remove('id')));

      test('the id is not a number', () {
        expectRejected(pikachu()..['id'] = '25');
      });

      test('the name is missing', () {
        expectRejected(pikachu()..remove('name'));
      });

      test('the types are missing', () {
        expectRejected(pikachu()..remove('types'));
      });

      test('no type is recognised', () {
        expectRejected(
          pikachu()
            ..['types'] = [
              {
                'slot': 1,
                'type': {'name': 'stellar'},
              },
            ],
        );
      });

      test('a stat is missing', () {
        final json = pikachu();
        (json['stats']! as List<Object?>).removeLast(); // speed
        expectRejected(json);
      });

      test('a stat value is not a number', () {
        final json = pikachu();
        final first =
            (json['stats']! as List<Object?>).first! as Map<String, Object?>;
        first['base_stat'] = 'lots';
        expectRejected(json);
      });
    });
  });

  group('PokemonRepository', () {
    test('requests the Pokémon by id and parses it', () async {
      final api = FakeApiClient((_) => Ok(pikachu()));

      final result = await PokemonRepository(api).loadPokemon(25);

      expect(
        api.calls.single.toString(),
        'https://pokeapi.co/api/v2/pokemon/25',
      );
      expect(result.valueOrNull?.name, 'pikachu');
    });

    test('a missing Pokémon is a NotFoundFailure', () async {
      final api = FakeApiClient((_) => const Err(NotFoundFailure()));

      final result = await PokemonRepository(api).loadPokemon(99999);

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('a malformed response is a MalformedResponseFailure', () async {
      final api = FakeApiClient((_) => const Ok({'id': 25}));

      final result = await PokemonRepository(api).loadPokemon(25);

      expect(result.failureOrNull, isA<MalformedResponseFailure>());
    });

    test('a retry after a malformed response asks the API again', () async {
      // The first answer is valid JSON of the wrong shape; the second is right.
      var asked = 0;
      final api = FakeApiClient(
        (_) => ++asked == 1 ? const Ok({'id': 25}) : Ok(pikachu()),
      );
      // Through a real cache, which would otherwise keep the bad answer.
      final repository = PokemonRepository(CachingApiClient(api));

      final first = await repository.loadPokemon(25);
      final second = await repository.loadPokemon(25);

      expect(first.failureOrNull, isA<MalformedResponseFailure>());
      expect(second.valueOrNull?.name, 'pikachu');
      expect(api.calls, hasLength(2));
    });

    test('a good answer is still kept', () async {
      final api = FakeApiClient((_) => Ok(pikachu()));
      final repository = PokemonRepository(CachingApiClient(api));

      await repository.loadPokemon(25);
      await repository.loadPokemon(25);

      expect(api.calls, hasLength(1));
    });
  });
}
