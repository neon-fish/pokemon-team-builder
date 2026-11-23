import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';

void main() {
  // Every stat has a different value, so a mix-up between two would show.
  const stats = BaseStats(
    hp: 35,
    attack: 55,
    defense: 40,
    specialAttack: 50,
    specialDefense: 60,
    speed: 90,
  );

  group('BaseStats', () {
    test('valueOf gives the matching stat', () {
      expect(stats.valueOf(Stat.hp), 35);
      expect(stats.valueOf(Stat.attack), 55);
      expect(stats.valueOf(Stat.defense), 40);
      expect(stats.valueOf(Stat.specialAttack), 50);
      expect(stats.valueOf(Stat.specialDefense), 60);
      expect(stats.valueOf(Stat.speed), 90);
    });

    test('the total adds all six', () {
      expect(stats.total, 330);
    });

    test('the stats are in the usual order', () {
      expect(Stat.values, [
        Stat.hp,
        Stat.attack,
        Stat.defense,
        Stat.specialAttack,
        Stat.specialDefense,
        Stat.speed,
      ]);
    });
  });
}
