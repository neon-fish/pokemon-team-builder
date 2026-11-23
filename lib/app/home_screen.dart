import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/search/search_panel.dart';
import 'package:pokemon_team_builder/features/search/search_sheet.dart';
import 'package:pokemon_team_builder/features/team/team_panel.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_picker.dart';

/// At this width or wider the search sits beside the team. Narrower than this,
/// the team has the whole width and the search opens in a sheet.
const _wideFrom = 900.0;

/// The most width the team ever takes, so it does not stretch across a huge
/// screen.
const _teamMaxWidth = 720.0;

/// The main screen: the team, and the search for adding to it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokémon Team Builder'),
        actions: const [ThemeModePicker(), SizedBox(width: 16)],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _wideFrom
            ? const _WideLayout()
            : const _NarrowLayout(),
      ),
    );
  }
}

/// Search on the left, always showing; the team on the right.
class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(width: 420, child: SearchPanel()),
        const VerticalDivider(width: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _teamMaxWidth),
                child: const TeamPanel(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The team on its own; the search opens in a sheet.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _teamMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Above the team, so it is on screen without scrolling.
              FilledButton.icon(
                onPressed: () => showSearchSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Pokémon'),
              ),
              const SizedBox(height: 16),
              // Tapping an empty slot has already chosen it; just show the
              // search.
              TeamPanel(onEmptySlotTapped: () => showSearchSheet(context)),
            ],
          ),
        ),
      ),
    );
  }
}
