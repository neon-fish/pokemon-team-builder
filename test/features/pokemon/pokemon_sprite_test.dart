import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_sprite.dart';

void main() {
  Future<void> pumpSprite(WidgetTester tester, {String? url, double? size}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: size == null
                ? PokemonSprite(url: url)
                : PokemonSprite(url: url, size: size),
          ),
        ),
      ),
    );
  }

  final placeholder = find.byIcon(Icons.catching_pokemon);

  testWidgets('with no picture, shows only the placeholder', (tester) async {
    await pumpSprite(tester);

    expect(placeholder, findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a picture that cannot load leaves the placeholder, quietly', (
    tester,
  ) async {
    // In tests every network image fails to load, which is what we want here.
    await pumpSprite(tester, url: 'https://example.test/missing.png');
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(placeholder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('takes the size it is given', (tester) async {
    await pumpSprite(tester, size: 80);

    expect(tester.getSize(find.byType(PokemonSprite)), const Size(80, 80));
  });
}
