import 'package:material_ui/material_ui.dart';

/// The background and text colours for one cell of the coverage matrix.
class CellColours {
  const CellColours({required this.background, required this.text});

  final Color background;
  final Color text;
}

/// The colours for a cell showing [multiplier]: red for weak (stronger for 4x),
/// green for resistant or immune, grey for normal damage.
///
/// The text in the cell says the same thing in words, so colour is never the
/// only signal. [scheme] supplies the reds and greys, so they follow the theme.
CellColours cellColours(ColorScheme scheme, double multiplier) {
  if (multiplier > 2) {
    return CellColours(background: scheme.error, text: scheme.onError);
  }
  if (multiplier > 1) {
    return CellColours(
      background: scheme.errorContainer,
      text: scheme.onErrorContainer,
    );
  }
  if (multiplier < 1) {
    // Material has no "good" colour, so these are chosen: a pale green with
    // dark text in the light theme, and the reverse in the dark one.
    return scheme.brightness == Brightness.light
        ? const CellColours(
            background: Color(0xFFC8E6C9),
            text: Color(0xFF1B5E20),
          )
        : const CellColours(
            background: Color(0xFF1B5E20),
            text: Color(0xFFC8E6C9),
          );
  }
  return CellColours(
    background: scheme.surfaceContainerHighest,
    text: scheme.onSurface,
  );
}
