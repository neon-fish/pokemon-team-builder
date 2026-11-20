import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_notifier.dart';

/// Three buttons: follow the browser, light, dark. Shows the current choice and
/// changes it.
class ThemeModePicker extends ConsumerWidget {
  const ThemeModePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` is null while the saved choice is still loading.
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;

    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto, semanticLabel: 'Match the browser'),
          tooltip: 'Match the browser',
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode, semanticLabel: 'Light'),
          tooltip: 'Light',
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode, semanticLabel: 'Dark'),
          tooltip: 'Dark',
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) =>
          ref.read(themeModeProvider.notifier).choose(selection.single),
    );
  }
}
