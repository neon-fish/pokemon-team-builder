import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/home_screen.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_notifier.dart';

/// Root widget: the theme and the home screen. Providers are assembled in
/// `providers.dart`.
class PokemonTeamBuilderApp extends ConsumerWidget {
  const PokemonTeamBuilderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` is null while the saved choice is still loading. `main` waits
    // for it, so in practice the first frame already has the real choice.
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;

    return MaterialApp(
      title: 'Pokémon Team Builder',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      // `ThemeMode.system` follows the browser's light/dark preference.
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
