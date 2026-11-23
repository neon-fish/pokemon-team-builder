import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// The WCAG contrast ratio between two colours: 1 (identical) to 21 (black on
/// white). Written out here, rather than reusing the app's rule, so tests that
/// use it are an independent check.
double contrastBetween(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (max(first, second) + 0.05) / (min(first, second) + 0.05);
}
