import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/app.dart';

void main() {
  testWidgets('app boots and shows the title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PokemonTeamBuilderApp()),
    );

    expect(find.text('Pokémon Team Builder'), findsOneWidget);
  });
}
