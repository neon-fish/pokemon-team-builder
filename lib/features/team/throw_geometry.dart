import 'dart:ui';

/// How big the ball is at the start of its flight, as a fraction of the shorter
/// side of the slot. It is thrown over the viewer's shoulder, so it starts
/// large and close.
const _startRadiusFraction = 0.32;

/// How big it is when it lands.
const _endRadiusFraction = 0.12;

/// Where the ball is, [t] of the way through its flight (0 at the start, 1 on
/// landing), in a slot of [size].
///
/// It starts just outside the bottom-left corner, so it is not on screen yet,
/// rises in an arc, and comes down in the middle of the slot. The arc comes from
/// a curve that is pulled towards a point above and to the left of the slot, so
/// the path bulges upwards instead of running in a straight line.
Offset ballCentre(double t, Size size) {
  final start = Offset(-ballRadius(0, size), size.height + ballRadius(0, size));
  final pull = Offset(size.width * 0.15, -size.height * 0.25);
  final end = Offset(size.width / 2, size.height / 2);

  // A quadratic Bézier curve: a weighted mix of the three points, where the
  // weights change smoothly from all-start to all-end as `t` goes from 0 to 1.
  final fromStart = (1 - t) * (1 - t);
  final towardsPull = 2 * (1 - t) * t;
  final towardsEnd = t * t;
  return start * fromStart + pull * towardsPull + end * towardsEnd;
}

/// The ball's radius [t] of the way through its flight, in a slot of [size].
/// It shrinks steadily as it moves away from the viewer.
double ballRadius(double t, Size size) {
  final side = size.shortestSide;
  return side *
      (_startRadiusFraction + (_endRadiusFraction - _startRadiusFraction) * t);
}
