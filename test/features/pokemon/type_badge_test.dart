import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/type_colours.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';

void main() {
  Future<void> pumpBadge(WidgetTester tester, PokemonType type) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TypeBadge(type))),
    );
  }

  testWidgets('names the type with a capital letter', (tester) async {
    await pumpBadge(tester, PokemonType.fire);

    expect(find.text('Fire'), findsOneWidget);
  });

  testWidgets('is filled with the type colour, with readable text', (
    tester,
  ) async {
    await pumpBadge(tester, PokemonType.electric);

    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(TypeBadge),
        matching: find.byType(DecoratedBox),
      ),
    );
    final text = tester.widget<Text>(find.text('Electric'));
    final fill = typeColour(PokemonType.electric);

    expect((box.decoration as BoxDecoration).color, fill);
    expect(text.style?.color, readableTextOn(fill));
  });
}
