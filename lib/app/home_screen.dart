import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/search/search_panel.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_picker.dart';

/// The main screen. For now it holds only the search; the team and the
/// analysis join it next.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokémon Team Builder'),
        actions: const [ThemeModePicker(), SizedBox(width: 16)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const SearchPanel(),
        ),
      ),
    );
  }
}
