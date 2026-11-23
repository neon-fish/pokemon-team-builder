import 'dart:math';

import 'package:flutter/rendering.dart';

const _red = Color(0xFFE53935);
const _white = Color(0xFFFAFAFA);
const _dark = Color(0xFF212121);

/// Draws the ball: red above, white below, a dark band across the middle and a
/// button in the centre.
///
/// [rotation] is in radians, clockwise. The colours are fixed rather than taken
/// from the theme, since it should look the same in light and dark.
void paintBall(
  Canvas canvas,
  Offset centre,
  double radius, {
  double rotation = 0,
}) {
  canvas
    ..save()
    // Moving and turning the canvas first means the ball can be drawn as if it
    // were at the origin, facing upright.
    ..translate(centre.dx, centre.dy)
    ..rotate(rotation);

  final inner = radius * 0.92;
  canvas.drawCircle(Offset.zero, radius, Paint()..color = _dark);
  canvas.drawCircle(Offset.zero, inner, Paint()..color = _white);
  // The top half: an arc from the left (pi) sweeping clockwise round the top.
  canvas.drawArc(
    Rect.fromCircle(center: Offset.zero, radius: inner),
    pi,
    pi,
    true,
    Paint()..color = _red,
  );
  // The band stops at the inner circle, where the dark outline takes over, so
  // its corners cannot poke out past the edge of the ball.
  final band = radius * 0.09;
  canvas.drawRect(
    Rect.fromLTRB(-inner, -band, inner, band),
    Paint()..color = _dark,
  );
  canvas.drawCircle(Offset.zero, radius * 0.30, Paint()..color = _dark);
  canvas.drawCircle(Offset.zero, radius * 0.19, Paint()..color = _white);

  canvas.restore();
}
