import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/team.dart';

void main() {
  test('starts empty', () {
    expect(const Team().ids, isEmpty);
    expect(const Team().isFull, isFalse);
  });

  group('add', () {
    test('appends, keeping the order', () {
      final team = const Team().add(25).add(6).add(1);
      expect(team.ids, [25, 6, 1]);
    });

    test('leaves the original team alone', () {
      const original = Team([1]);
      original.add(2);
      expect(original.ids, [1]);
    });

    test('the same Pokémon can fill several slots', () {
      final team = const Team().add(4).add(4).add(4);
      expect(team.ids, [4, 4, 4]);
    });

    test('ignores a seventh Pokémon', () {
      const full = Team([1, 2, 3, 4, 5, 6]);
      expect(full.isFull, isTrue);
      expect(full.add(7), same(full));
    });

    test('six of the same Pokémon fill the team', () {
      var team = const Team();
      for (var i = 0; i < 6; i++) {
        team = team.add(4);
      }
      expect(team.ids, [4, 4, 4, 4, 4, 4]);
      expect(team.isFull, isTrue);
    });
  });

  group('removeAt', () {
    test('removes that slot and the later ones move up', () {
      const team = Team([1, 2, 3]);
      expect(team.removeAt(1).ids, [1, 3]);
    });

    test('removes only the chosen slot when the Pokémon appears twice', () {
      const team = Team([4, 7, 4]);
      expect(team.removeAt(2).ids, [4, 7]);
    });

    test('can remove the first and the last slot', () {
      const team = Team([1, 2, 3]);
      expect(team.removeAt(0).ids, [2, 3]);
      expect(team.removeAt(2).ids, [1, 2]);
    });

    test('a full team has room again', () {
      const full = Team([1, 2, 3, 4, 5, 6]);
      expect(full.removeAt(2).isFull, isFalse);
    });

    test('ignores a slot that does not exist', () {
      const team = Team([1]);
      expect(team.removeAt(1), same(team));
      expect(team.removeAt(-1), same(team));
    });
  });
}
