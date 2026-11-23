import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/features/detail/radar_geometry.dart';

void main() {
  /// Offsets are made of doubles that are rarely exactly equal after
  /// trigonometry, so compare them to within a tiny margin.
  Matcher isOffset(double x, double y) => predicate<Offset>(
    (offset) => (offset.dx - x).abs() < 1e-9 && (offset.dy - y).abs() < 1e-9,
    'is ($x, $y)',
  );

  group('statFraction', () {
    test('0 is the centre and the maximum is the edge', () {
      expect(statFraction(0), 0);
      expect(statFraction(maxChartStat), 1);
    });

    test('values in between are proportional', () {
      expect(statFraction(maxChartStat ~/ 2), 0.5);
    });

    test('values beyond the edge stay at the edge', () {
      // Blissey has 255 HP.
      expect(statFraction(255), 1);
    });

    test('a negative value (not expected) stays at the centre', () {
      expect(statFraction(-5), 0);
    });
  });

  group('axisDirection', () {
    test('the first axis points straight up', () {
      expect(axisDirection(0, 6), isOffset(0, -1));
    });

    test('the axes go clockwise, so the second is up and to the right', () {
      final direction = axisDirection(1, 6);
      expect(direction.dx, greaterThan(0));
      expect(direction.dy, lessThan(0));
    });

    test('the middle axis of six points straight down', () {
      expect(axisDirection(3, 6), isOffset(0, 1));
    });

    test('every direction is a unit vector, evenly spaced', () {
      for (var i = 0; i < 6; i++) {
        expect(axisDirection(i, 6).distance, closeTo(1, 1e-9));
      }
      // Each axis is 60 degrees on from the last.
      final angle0 = axisDirection(0, 6).direction;
      final angle1 = axisDirection(1, 6).direction;
      expect(angle1 - angle0, closeTo(pi / 3, 1e-9));
    });

    test('the number of axes sets the spacing', () {
      // With four axes, the second is to the right.
      expect(axisDirection(1, 4), isOffset(1, 0));
    });
  });

  group('radarPoints', () {
    const centre = Offset(50, 50);

    test('a full-length axis reaches the radius', () {
      final points = radarPoints(
        fractions: List.filled(6, 1),
        centre: centre,
        radius: 40,
      );

      expect(points, hasLength(6));
      expect(points[0], isOffset(50, 10)); // straight up
      expect(points[3], isOffset(50, 90)); // straight down
    });

    test('a fraction scales the distance from the centre', () {
      final points = radarPoints(
        fractions: [0.5, 0, 0, 0, 0, 0],
        centre: centre,
        radius: 40,
      );

      expect(points[0], isOffset(50, 30));
    });

    test('a zero fraction is at the centre', () {
      final points = radarPoints(
        fractions: [0, 0, 0],
        centre: centre,
        radius: 40,
      );

      expect(points, everyElement(isOffset(50, 50)));
    });
  });
}
