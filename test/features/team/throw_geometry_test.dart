import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/features/team/throw_geometry.dart';

void main() {
  const slot = Size(200, 240);

  group('the ball', () {
    test('starts outside the slot, at the bottom left, and large', () {
      final start = ballCentre(0, slot);
      final radius = ballRadius(0, slot);

      // Its whole width is beyond the left edge and below the bottom edge, so
      // none of it is on screen when the flight begins.
      expect(start.dx + radius, lessThanOrEqualTo(0));
      expect(start.dy - radius, greaterThanOrEqualTo(slot.height));
      // Large: a third or so of the slot's shorter side.
      expect(radius, closeTo(200 * 0.32, 0.001));
    });

    test('lands in the middle of the slot, small', () {
      expect(ballCentre(1, slot), const Offset(100, 120));
      expect(ballRadius(1, slot), closeTo(200 * 0.12, 0.001));
    });

    test('rises above where it lands on the way, as a throw does', () {
      final landing = ballCentre(1, slot);

      expect(ballCentre(0.5, slot).dy, lessThan(landing.dy));
    });

    test('moves steadily towards the landing point sideways', () {
      final xs = [for (var t = 0.0; t <= 1.0; t += 0.1) ballCentre(t, slot).dx];

      expect(xs, orderedEquals([...xs]..sort()));
    });

    test('shrinks all the way', () {
      final radii = [for (var t = 0.0; t <= 1.0; t += 0.1) ballRadius(t, slot)];

      for (var i = 1; i < radii.length; i++) {
        expect(radii[i], lessThan(radii[i - 1]), reason: 'step $i');
      }
    });

    test('is sized by the shorter side, and the path scales with the slot', () {
      const small = Size(100, 120);

      expect(ballRadius(0, small), closeTo(ballRadius(0, slot) / 2, 0.001));
      expect(ballCentre(1, small), const Offset(50, 60));
    });
  });
}
