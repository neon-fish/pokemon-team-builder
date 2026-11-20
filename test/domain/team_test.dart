import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/team.dart';

void main() {
  test('starts with six empty slots', () {
    const team = Team();

    expect(team.slots, [null, null, null, null, null, null]);
    expect(team.memberIds, isEmpty);
    expect(team.isFull, isFalse);
  });

  group('fromSlots', () {
    test('keeps each Pokémon in its slot, gaps included', () {
      final team = Team.fromSlots([25, null, 6, null, null, 1]);

      expect(team.slots, [25, null, 6, null, null, 1]);
    });

    test('fills up a short list with empty slots', () {
      final team = Team.fromSlots([25, 6]);

      expect(team.slots, [25, 6, null, null, null, null]);
    });

    test('drops anything past six', () {
      final team = Team.fromSlots([1, 2, 3, 4, 5, 6, 7, 8]);

      expect(team.slots, [1, 2, 3, 4, 5, 6]);
    });

    test('keeps the same Pokémon in several slots', () {
      final team = Team.fromSlots([4, 4, 4]);

      expect(team.slots, [4, 4, 4, null, null, null]);
    });
  });

  test('memberIds lists the Pokémon in slot order, without gaps', () {
    final team = Team.fromSlots([null, 25, null, 6, 25, null]);

    expect(team.memberIds, [25, 6, 25]);
  });

  group('add', () {
    test('fills the first empty slot, in order', () {
      final team = const Team().add(25).add(6).add(1);

      expect(team.slots, [25, 6, 1, null, null, null]);
    });

    test('fills a gap left earlier before using later slots', () {
      final team = Team.fromSlots([25, null, 6]).add(1);

      expect(team.slots, [25, 1, 6, null, null, null]);
    });

    test('leaves the original team alone', () {
      final original = Team.fromSlots([1]);
      original.add(2);

      expect(original.slots, [1, null, null, null, null, null]);
    });

    test('the same Pokémon can fill several slots', () {
      final team = const Team().add(4).add(4).add(4);

      expect(team.memberIds, [4, 4, 4]);
    });

    test('ignores a seventh Pokémon', () {
      final full = Team.fromSlots([1, 2, 3, 4, 5, 6]);

      expect(full.isFull, isTrue);
      expect(full.add(7), same(full));
    });

    test('six of the same Pokémon fill the team', () {
      var team = const Team();
      for (var i = 0; i < 6; i++) {
        team = team.add(4);
      }

      expect(team.slots, [4, 4, 4, 4, 4, 4]);
      expect(team.isFull, isTrue);
    });
  });

  group('addAt', () {
    test('fills the chosen slot, not the first empty one', () {
      final team = const Team().addAt(3, 9);

      expect(team.slots, [null, null, null, 9, null, null]);
    });

    test('leaves every other slot where it is', () {
      final team = Team.fromSlots([1, 2, 3]).addAt(4, 9);

      expect(team.slots, [1, 2, 3, null, 9, null]);
    });

    test('a later add still uses the first empty slot', () {
      final team = const Team().addAt(3, 9).add(1);

      expect(team.slots, [1, null, null, 9, null, null]);
    });

    test('the same Pokémon can be put in a second slot', () {
      final team = Team.fromSlots([4]).addAt(1, 4);

      expect(team.slots, [4, 4, null, null, null, null]);
    });

    test('leaves the original team alone', () {
      final original = Team.fromSlots([1]);
      original.addAt(2, 9);

      expect(original.slots, [1, null, null, null, null, null]);
    });

    test('does not overwrite a slot that is taken', () {
      final team = Team.fromSlots([1, 2]);

      expect(team.addAt(1, 9), same(team));
    });

    test('ignores a slot that does not exist', () {
      final team = Team.fromSlots([1]);

      expect(team.addAt(6, 9), same(team));
      expect(team.addAt(-1, 9), same(team));
    });

    test('ignores a full team', () {
      final full = Team.fromSlots([1, 2, 3, 4, 5, 6]);

      expect(full.addAt(0, 9), same(full));
    });
  });

  group('removeAt', () {
    test('empties that slot and nothing else moves', () {
      final team = Team.fromSlots([1, 2, 3]);

      expect(team.removeAt(1).slots, [1, null, 3, null, null, null]);
    });

    test('removes only the chosen slot when the Pokémon appears twice', () {
      final team = Team.fromSlots([4, 7, 4]);

      expect(team.removeAt(2).slots, [4, 7, null, null, null, null]);
    });

    test('can remove the first and the last slot', () {
      final team = Team.fromSlots([1, 2, 3, 4, 5, 6]);

      expect(team.removeAt(0).slots, [null, 2, 3, 4, 5, 6]);
      expect(team.removeAt(5).slots, [1, 2, 3, 4, 5, null]);
    });

    test('a full team has room again, in the slot that was freed', () {
      final full = Team.fromSlots([1, 2, 3, 4, 5, 6]);
      final room = full.removeAt(2);

      expect(room.isFull, isFalse);
      expect(room.add(9).slots, [1, 2, 9, 4, 5, 6]);
    });

    test('ignores a slot that does not exist', () {
      final team = Team.fromSlots([1]);

      expect(team.removeAt(6), same(team));
      expect(team.removeAt(-1), same(team));
    });

    test('ignores a slot that is already empty', () {
      final team = Team.fromSlots([1]);

      expect(team.removeAt(3), same(team));
    });
  });

  group('move', () {
    test('swaps two Pokémon', () {
      final team = Team.fromSlots([1, 2, 3]);

      expect(team.move(0, 2).slots, [3, 2, 1, null, null, null]);
    });

    test('works the same in either direction', () {
      final team = Team.fromSlots([1, 2, 3]);

      expect(team.move(2, 0).slots, team.move(0, 2).slots);
    });

    test('moves a Pokémon into an empty slot, leaving its own empty', () {
      final team = Team.fromSlots([1, 2]);

      expect(team.move(0, 4).slots, [null, 2, null, null, 1, null]);
    });

    test('leaves every other Pokémon where it is', () {
      final team = Team.fromSlots([1, 2, 3]);

      expect(team.move(1, 5).slots, [1, null, 3, null, null, 2]);
    });

    test('leaves the original team alone', () {
      final original = Team.fromSlots([1, 2]);
      original.move(0, 1);

      expect(original.slots, [1, 2, null, null, null, null]);
    });

    group('does nothing, returning the same team, when', () {
      final team = Team.fromSlots([1, 2, 1]);

      test('moving a slot onto itself', () {
        expect(team.move(1, 1), same(team));
      });

      test('both slots are empty', () {
        expect(team.move(3, 4), same(team));
      });

      test('both slots hold the same Pokémon', () {
        expect(team.move(0, 2), same(team));
      });

      test('a slot does not exist', () {
        expect(team.move(0, 6), same(team));
        expect(team.move(-1, 0), same(team));
        expect(team.move(9, 9), same(team));
      });
    });
  });
}
