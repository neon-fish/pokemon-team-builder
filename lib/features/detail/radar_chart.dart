import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/detail/radar_geometry.dart';

/// A radar (spider) chart: one axis per label, with a filled shape whose
/// corners are the [values].
///
/// It is a picture only, drawn with `CustomPaint`. The numbers it shows are
/// also given as text beside it (see `StatBars`), so it is hidden from screen
/// readers rather than read out twice.
class RadarChart extends StatelessWidget {
  const RadarChart({required this.labels, required this.values, super.key})
    : assert(labels.length == values.length);

  /// The name at the end of each axis, starting at the top and going clockwise.
  final List<String> labels;

  /// One value per axis; see [maxChartStat] for the scale.
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _RadarPainter(
            labels: labels,
            fractions: [for (final value in values) statFraction(value)],
            gridColour: theme.colorScheme.outlineVariant,
            shapeColour: theme.colorScheme.primary,
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

/// The space between the end of an axis and its label.
const _labelGap = 6.0;

/// How far out the grid rings are, as a share of the way to the edge.
const _ringFractions = [1 / 3, 2 / 3, 1.0];

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.labels,
    required this.fractions,
    required this.gridColour,
    required this.shapeColour,
    required this.labelStyle,
    required this.textScaler,
  });

  final List<String> labels;
  final List<double> fractions;
  final Color gridColour;
  final Color shapeColour;
  final TextStyle? labelStyle;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final count = fractions.length;
    final centre = size.center(Offset.zero);

    // The labels are measured first, because they decide how much of the space
    // is left for the chart itself. (With larger text, the chart shrinks.)
    final labelPainters = <TextPainter>[];
    var roomForLabels = 0.0;
    for (var i = 0; i < count; i++) {
      final painter = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      labelPainters.add(painter);
      final direction = axisDirection(i, count);
      final room =
          _labelGap +
          direction.dx.abs() * painter.width +
          direction.dy.abs() * painter.height;
      roomForLabels = max(roomForLabels, room);
    }
    final radius = max(0.0, size.shortestSide / 2 - roomForLabels);

    // The grid: rings (each the same shape as the data, at a fixed distance
    // out) and a spoke for each axis.
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gridColour;
    for (final ring in _ringFractions) {
      final corners = radarPoints(
        fractions: List.filled(count, ring),
        centre: centre,
        radius: radius,
      );
      canvas.drawPath(Path()..addPolygon(corners, true), gridPaint);
    }
    for (var i = 0; i < count; i++) {
      canvas.drawLine(
        centre,
        centre + axisDirection(i, count) * radius,
        gridPaint,
      );
    }

    // The data: a translucent fill with a solid outline.
    final shape = Path()
      ..addPolygon(
        radarPoints(fractions: fractions, centre: centre, radius: radius),
        true,
      );
    canvas.drawPath(
      shape,
      Paint()..color = shapeColour.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = shapeColour,
    );

    // The labels, each just beyond the end of its axis.
    for (var i = 0; i < count; i++) {
      final painter = labelPainters[i];
      final direction = axisDirection(i, count);
      final halfExtent =
          (direction.dx.abs() * painter.width +
              direction.dy.abs() * painter.height) /
          2;
      final labelCentre =
          centre + direction * (radius + _labelGap + halfExtent);
      painter.paint(
        canvas,
        labelCentre - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      !listEquals(old.labels, labels) ||
      !listEquals(old.fractions, fractions) ||
      old.gridColour != gridColour ||
      old.shapeColour != shapeColour ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}
