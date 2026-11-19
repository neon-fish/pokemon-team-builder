import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/type_chart_repository.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';

import '../support/fake_api_client.dart';
import '../support/fixtures.dart';

/// A `/type/{name}` response listing the given matchups.
Map<String, Object?> typeResponse({
  List<String> doubleTo = const [],
  List<String> halfTo = const [],
  List<String> noneTo = const [],
}) {
  List<Object?> named(List<String> names) => [
    for (final name in names)
      {'name': name, 'url': 'https://pokeapi.co/api/v2/type/$name/'},
  ];
  return {
    'name': 'some-type',
    'damage_relations': {
      'double_damage_to': named(doubleTo),
      'half_damage_to': named(halfTo),
      'no_damage_to': named(noneTo),
    },
  };
}

void main() {
  group('parseAttackMultipliers', () {
    test('reads a real response', () {
      final multipliers = parseAttackMultipliers(loadFixture('type_fire.json'));

      expect(multipliers, {
        PokemonType.grass: 2,
        PokemonType.ice: 2,
        PokemonType.bug: 2,
        PokemonType.steel: 2,
        PokemonType.fire: 0.5,
        PokemonType.water: 0.5,
        PokemonType.rock: 0.5,
        PokemonType.dragon: 0.5,
      });
    });

    test('reads immunities as zero', () {
      final multipliers = parseAttackMultipliers(
        typeResponse(noneTo: ['ghost']),
      );
      expect(multipliers, {PokemonType.ghost: 0});
    });

    test('skips type names it does not model', () {
      final multipliers = parseAttackMultipliers(
        typeResponse(doubleTo: ['stellar', 'grass']),
      );
      expect(multipliers, {PokemonType.grass: 2});
    });

    group('throws FormatException when', () {
      void expectRejected(Object? json) =>
          expect(() => parseAttackMultipliers(json), throwsFormatException);

      test('the response is not an object', () => expectRejected([1, 2]));

      test('damage_relations is missing', () => expectRejected({'id': 1}));

      test('a relation list is missing', () {
        expectRejected({
          'damage_relations': {'double_damage_to': <Object?>[]},
        });
      });

      test('a relation list is not a list', () {
        expectRejected({
          'damage_relations': {
            'double_damage_to': 'grass',
            'half_damage_to': <Object?>[],
            'no_damage_to': <Object?>[],
          },
        });
      });

      test('an entry has no name', () {
        final broken = typeResponse();
        final relations = broken['damage_relations']! as Map<String, Object?>;
        relations['double_damage_to'] = [
          {'url': 'https://pokeapi.co/api/v2/type/12/'},
        ];
        expectRejected(broken);
      });
    });
  });

  group('TypeChartRepository', () {
    /// A fake API where fire is the real fixture, ghost is immune to normal,
    /// and every other type has no special matchups.
    FakeApiClient fakeApi({Result<Object?>? Function(Uri url)? override}) {
      return FakeApiClient((url) {
        final overridden = override?.call(url);
        if (overridden != null) return overridden;
        if (url.path.endsWith('/type/fire')) {
          return Ok(loadFixture('type_fire.json'));
        }
        if (url.path.endsWith('/type/normal')) {
          return Ok(typeResponse(noneTo: ['ghost']));
        }
        return Ok(typeResponse());
      });
    }

    test('assembles the chart from one request per type', () async {
      final api = fakeApi();

      final result = await TypeChartRepository(api).loadTypeChart();

      final chart = result.valueOrNull;
      expect(chart, isNotNull);
      expect(api.calls, hasLength(PokemonType.values.length));
      expect(chart!.multiplier(PokemonType.fire, PokemonType.grass), 2);
      expect(chart.multiplier(PokemonType.fire, PokemonType.water), 0.5);
      expect(chart.multiplier(PokemonType.normal, PokemonType.ghost), 0);
      expect(chart.multiplier(PokemonType.water, PokemonType.fire), 1);
    });

    test('requests the documented URL for each type', () async {
      final api = fakeApi();

      await TypeChartRepository(api).loadTypeChart();

      expect(
        api.calls.map((url) => url.toString()),
        contains('https://pokeapi.co/api/v2/type/fire'),
      );
    });

    test('one failed type fails the whole load, with that failure', () async {
      final api = fakeApi(
        override: (url) => url.path.endsWith('/type/water')
            ? const Err(ServerFailure(503))
            : null,
      );

      final result = await TypeChartRepository(api).loadTypeChart();

      expect(result.failureOrNull, isA<ServerFailure>());
    });

    test(
      'a response of the wrong shape is a MalformedResponseFailure',
      () async {
        final api = fakeApi(
          override: (url) => url.path.endsWith('/type/water')
              ? const Ok({'unexpected': 'shape'})
              : null,
        );

        final result = await TypeChartRepository(api).loadTypeChart();

        expect(result.failureOrNull, isA<MalformedResponseFailure>());
      },
    );
  });
}
