import 'package:material_ui/material_ui.dart';

/// The app's theme, in light or dark.
///
/// Both come from one seed colour, so they match. The accent is indigo rather
/// than red: red already means "error" in Material, and would also be mistaken
/// for the fire type.
ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}
