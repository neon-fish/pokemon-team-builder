import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/app.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The container is created here, rather than by `ProviderScope`, so the saved
  // theme can be loaded before the first frame. Otherwise someone who chose
  // light in a dark browser would see dark for a moment first. It lives as long
  // as the app, so it is never disposed.
  final container = ProviderContainer();
  await container.read(themeModeProvider.future);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PokemonTeamBuilderApp(),
    ),
  );
}
