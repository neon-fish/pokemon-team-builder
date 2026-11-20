import 'package:material_ui/material_ui.dart';

/// The app's theme, in light or dark.
///
/// Both come from one seed colour, so they match. The accent is indigo rather
/// than red on purpose: red already means "error" in Material, and it would
/// also be mistaken for the fire type. Component themes are added here as the
/// widgets that need them are built.
ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}
