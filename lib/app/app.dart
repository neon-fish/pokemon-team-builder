import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/theme.dart';

/// Root widget. The composition root (provider overrides, routing) lives here.
class PokemonTeamBuilderApp extends StatelessWidget {
  const PokemonTeamBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokémon Team Builder',
      theme: buildAppTheme(),
      home: const Scaffold(
        body: Center(child: Text('Pokémon Team Builder')),
      ),
    );
  }
}
