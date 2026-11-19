import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/scratch_home.dart';
import 'package:pokemon_team_builder/app/theme.dart';

/// Root widget. Routing will live here; providers are assembled in
/// `providers.dart`.
class PokemonTeamBuilderApp extends StatelessWidget {
  const PokemonTeamBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokémon Team Builder',
      theme: buildAppTheme(),
      home: const ScratchHome(),
    );
  }
}
