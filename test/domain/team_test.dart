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

    test('ignores a Pokémon already in the team', () {
      const team = Team([25]);
      expect(team.add(25), same(team));
    });

    test('ignores a seventh Pokémon', () {
      const full = Team([1, 2, 3, 4, 5, 6]);
      expect(full.isFull, isTrue);
      expect(full.add(7), same(full));
    });
  });

  group('remove', () {
    test('removes the Pokémon and keeps the order of the rest', () {
      const team = Team([1, 2, 3]);
      expect(team.remove(2).ids, [1, 3]);
    });

    test('a full team has room again', () {
      const full = Team([1, 2, 3, 4, 5, 6]);
      expect(full.remove(3).isFull, isFalse);
    });

    test('ignores a Pokémon that is not in the team', () {
      const team = Team([1]);
      expect(team.remove(9), same(team));
    });
  });
}
