import 'package:material_ui/material_ui.dart';

/// Placeholder theme. The real colour scheme, typography and component themes
/// are designed during the UI phase.
ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    useMaterial3: true,
  );
}
