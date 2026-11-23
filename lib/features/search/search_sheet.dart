import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/search/search_panel.dart';
import 'package:pokemon_team_builder/features/team/add_target_notifier.dart';

/// Shows the search in a sheet that slides up over the screen, for screens too
/// narrow to have it beside the team. Picking a Pokémon closes it.
///
/// When the sheet goes away, however it goes (picked, swiped down, tapped
/// outside), the slot the user had chosen is forgotten, so it does not linger
/// into the next search.
Future<void> showSearchSheet(BuildContext context) {
  // The cleanup below runs after the sheet has closed, by which time the widget
  // that opened it may be gone (the window can be resized in between), and a
  // widget's `ref` must not be used after that. The container lives as long as
  // the app, so take it now.
  final container = ProviderScope.containerOf(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        // Keeps the list clear of the on-screen keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: SearchPanel(
            autofocus: true,
            onPicked: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      );
    },
  ).whenComplete(() => container.read(addTargetProvider.notifier).choose(null));
}
