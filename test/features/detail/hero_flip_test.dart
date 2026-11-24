import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/features/detail/hero_flip.dart';

void main() {
  const quarterTurn = pi / 2;

  group('which face shows', () {
    test('the card at the start, and the dialog at the end', () {
      expect(showsCardFace(0), isTrue);
      expect(showsCardFace(1), isFalse);
    });

    test('the swap is halfway', () {
      expect(showsCardFace(0.4999), isTrue);
      expect(showsCardFace(0.5), isFalse);
    });
  });

  group('how far the face is turned', () {
    test('the card faces us at the start, and the dialog at the end', () {
      expect(flipAngle(0), 0);
      expect(flipAngle(1), closeTo(0, 1e-12));
    });

    test('the card turns edge-on, a quarter turn, as the faces swap', () {
      expect(flipAngle(0.4999), closeTo(quarterTurn, 0.001));
    });

    test('the dialog starts edge-on, from the other side', () {
      // A negative quarter turn: edge-on again, so the swap cannot be seen, but
      // turning the other way, so it comes round to face us the right way up.
      expect(flipAngle(0.5), closeTo(-quarterTurn, 1e-12));
    });

    test('never turns past edge-on, so no face is ever seen from behind', () {
      for (var t = 0.0; t <= 1.0; t += 0.01) {
        expect(flipAngle(t).abs(), lessThanOrEqualTo(quarterTurn + 1e-9));
      }
    });

    test('the card turns steadily towards edge-on', () {
      final angles = [for (var t = 0.0; t < 0.5; t += 0.05) flipAngle(t)];

      for (var i = 1; i < angles.length; i++) {
        expect(angles[i], greaterThan(angles[i - 1]));
      }
    });

    test('and the dialog turns steadily towards facing us', () {
      final angles = [for (var t = 0.5; t <= 1.0; t += 0.05) flipAngle(t)];

      for (var i = 1; i < angles.length; i++) {
        expect(angles[i], greaterThan(angles[i - 1]));
      }
    });
  });

  test('each slot has its own tag, and the same one every time', () {
    expect(slotHeroTag(2), slotHeroTag(2));
    expect(slotHeroTag(2), isNot(slotHeroTag(3)));
  });
}
