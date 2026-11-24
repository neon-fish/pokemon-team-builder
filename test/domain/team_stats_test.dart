import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/team_stats.dart';

void main() {
  /// A Pokémon whose six stats are, in order, [values].
  Pokemon pokemon(int id, List<int> values) => Pokemon(
    id: id,
    name: 'pokemon-$id',
    types: const [PokemonType.normal],
    stats: BaseStats(
      hp: values[0],
      attack: values[1],
      defense: values[2],
      specialAttack: values[3],
      specialDefense: values[4],
      speed: values[5],
    ),
  );

  StatSummary summaryOf(TeamStats stats, Stat stat) =>
      stats.summaries.singleWhere((summary) => summary.stat == stat);

  test('nobody to summarise gives nothing', () {
    expect(summariseStats([]), isNull);
  });

  test('has one summary per stat, in the usual order', () {
    final stats = summariseStats([
      pokemon(1, [1, 2, 3, 4, 5, 6]),
    ])!;

    expect([for (final summary in stats.summaries) summary.stat], Stat.values);
  });

  test('a team of one is that Pokémon, and is its own highest and lowest', () {
    final solo = pokemon(1, [10, 20, 30, 40, 50, 60]);

    final stats = summariseStats([solo])!;

    expect(stats.memberCount, 1);
    expect(summaryOf(stats, Stat.attack).average, 20);
    expect(summaryOf(stats, Stat.attack).highest, solo);
    expect(summaryOf(stats, Stat.attack).lowest, solo);
    expect(stats.averageTotal, 210);
  });

  group('with several members', () {
    // Each stat has a different winner and loser, so mixing two stats up, or
    // two members, would show.
    final a = pokemon(1, [100, 10, 50, 50, 50, 50]);
    final b = pokemon(2, [50, 90, 50, 50, 50, 10]);
    final c = pokemon(3, [30, 20, 80, 50, 50, 30]);
    late TeamStats stats;

    setUp(() => stats = summariseStats([a, b, c])!);

    test('counts the members', () {
      expect(stats.memberCount, 3);
    });

    test('averages each stat across them', () {
      expect(summaryOf(stats, Stat.hp).average, 60); // (100 + 50 + 30) / 3
      expect(summaryOf(stats, Stat.attack).average, 40); // (10 + 90 + 20) / 3
      expect(summaryOf(stats, Stat.defense).average, 60); // (50 + 50 + 80) / 3
      expect(summaryOf(stats, Stat.speed).average, 30); // (50 + 10 + 30) / 3
    });

    test('keeps the fraction rather than rounding it', () {
      final uneven = summariseStats([
        pokemon(1, [1, 1, 1, 1, 1, 1]),
        pokemon(2, [2, 2, 2, 2, 2, 2]),
      ])!;

      expect(summaryOf(uneven, Stat.hp).average, 1.5);
    });

    test('finds the member with the most and the least of each stat', () {
      expect(summaryOf(stats, Stat.hp).highest, a);
      expect(summaryOf(stats, Stat.hp).lowest, c);
      expect(summaryOf(stats, Stat.attack).highest, b);
      expect(summaryOf(stats, Stat.attack).lowest, a);
      expect(summaryOf(stats, Stat.defense).highest, c);
      expect(summaryOf(stats, Stat.speed).lowest, b);
    });

    test('averages the totals', () {
      // 310, 300 and 260 are the three totals.
      expect(stats.averageTotal, 290);
    });
  });

  test('on a tie, the earlier member is both the highest and the lowest', () {
    final first = pokemon(1, [50, 50, 50, 50, 50, 50]);
    final second = pokemon(2, [50, 50, 50, 50, 50, 50]);

    final stats = summariseStats([first, second])!;

    expect(summaryOf(stats, Stat.speed).highest, first);
    expect(summaryOf(stats, Stat.speed).lowest, first);
  });

  test('each stat can have a different highest and lowest from the last', () {
    // Guards against reusing one member across all the stats.
    final strong = pokemon(1, [90, 10, 10, 10, 10, 10]);
    final fast = pokemon(2, [10, 10, 10, 10, 10, 90]);

    final stats = summariseStats([strong, fast])!;

    expect(summaryOf(stats, Stat.hp).highest, strong);
    expect(summaryOf(stats, Stat.speed).highest, fast);
  });
}
