import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/pokemon_search.dart';
import 'package:pokemon_team_builder/domain/pokemon_summary.dart';

void main() {
  const index = [
    PokemonSummary(id: 4, name: 'charmander'),
    PokemonSummary(id: 25, name: 'pikachu'),
    PokemonSummary(id: 26, name: 'raichu'),
    PokemonSummary(id: 59, name: 'arcanine'),
    PokemonSummary(id: 122, name: 'mr-mime'),
    PokemonSummary(id: 10080, name: 'pikachu-rock-star'),
    PokemonSummary(id: 10100, name: 'raichu-alola'),
  ];

  List<String> namesFor(String query) => [
    for (final match in searchPokemon(index, query)) match.name,
  ];

  group('with nothing typed', () {
    test('gives the whole list, in order', () {
      expect(searchPokemon(index, ''), same(index));
    });

    test('spaces alone count as nothing', () {
      expect(searchPokemon(index, '   '), same(index));
    });
  });

  group('matching by name', () {
    test('finds names containing the text', () {
      expect(namesFor('mime'), ['mr-mime']);
    });

    test('ignores capital letters', () {
      expect(namesFor('PIKA'), ['pikachu', 'pikachu-rock-star']);
    });

    test('ignores spaces around the text', () {
      expect(namesFor('  mime  '), ['mr-mime']);
    });

    test('treats a space as a hyphen, so a tidied name still matches', () {
      expect(namesFor('mr mime'), ['mr-mime']);
      expect(namesFor('Pikachu Rock Star'), ['pikachu-rock-star']);
    });

    test('finds nothing when nothing matches', () {
      expect(namesFor('zzz'), isEmpty);
    });
  });

  group('ordering', () {
    test(
      'names that start with the text come before names that contain it',
      () {
        // `charmander` has "ar" inside and comes first in the list, but
        // `arcanine` starts with it. `pikachu-rock-star` has it in "star".
        expect(namesFor('ar'), ['arcanine', 'charmander', 'pikachu-rock-star']);
      },
    );

    test('keeps the order of the list within each group', () {
      expect(namesFor('chu'), [
        'pikachu',
        'raichu',
        'pikachu-rock-star',
        'raichu-alola',
      ]);
      expect(namesFor('rai'), ['raichu', 'raichu-alola']);
    });
  });

  group('matching by number', () {
    test('finds the Pokémon with exactly that number', () {
      expect(namesFor('25'), ['pikachu']);
      expect(namesFor('10080'), ['pikachu-rock-star']);
    });

    test('does not match part of a number', () {
      expect(namesFor('2'), isEmpty);
    });

    test('a number that nobody has finds nothing', () {
      expect(namesFor('9999'), isEmpty);
    });
  });
}
