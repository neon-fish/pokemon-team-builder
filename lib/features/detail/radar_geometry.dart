import 'dart:math';
import 'dart:ui';

/// The stat value that reaches the outer edge of the radar chart, and the end
/// of a bar. Higher values are drawn at the edge, which only a handful of
/// Pokémon reach. A fixed scale (rather than one that fits each Pokémon) means
/// two charts can be compared by eye.
const maxChartStat = 200;

/// How far out, from 0 (the centre) to 1 (the edge), a stat of [value] reaches.
double statFraction(int value) => (value / maxChartStat).clamp(0.0, 1.0);

/// The direction of axis [index] of [count], as a unit vector.
///
/// The first axis points straight up, and the rest follow clockwise, evenly
/// spaced. (On screen, y grows downwards, so "up" is a negative y.)
Offset axisDirection(int index, int count) {
  final angle = -pi / 2 + 2 * pi * index / count;
  return Offset(cos(angle), sin(angle));
}

/// The corners of the chart's shape: one per axis, each [fractions] of the way
/// from [centre] to a distance of [radius].
List<Offset> radarPoints({
  required List<double> fractions,
  required Offset centre,
  required double radius,
}) {
  return [
    for (var i = 0; i < fractions.length; i++)
      centre + axisDirection(i, fractions.length) * (radius * fractions[i]),
  ];
}
