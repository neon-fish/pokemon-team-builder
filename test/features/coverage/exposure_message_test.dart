import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/domain/team_analysis.dart';
import 'package:pokemon_team_builder/features/coverage/exposure_message.dart';

void main() {
  String? messageFor(PokemonType type, List<double?> multipliers) =>
      describeExposure(TypeMatchup(type, multipliers));

  test('says nothing when the team is not exposed', () {
    expect(messageFor(PokemonType.fire, [2, 0.5]), isNull);
    expect(messageFor(PokemonType.fire, [1, 1, 1]), isNull);
    expect(messageFor(PokemonType.fire, [0.5, 0.5]), isNull);
    expect(messageFor(PokemonType.fire, [null, null]), isNull);
  });

  test('says when nobody can resist the type', () {
    expect(
      messageFor(PokemonType.ground, [2, 2, 2, 1, 1, 1]),
      '3 of 6 are weak to Ground and nobody resists it.',
    );
  });

  test('says how few can resist it, when some can', () {
    expect(
      messageFor(PokemonType.fire, [2, 2, 2, 0.5, 1, 1]),
      '3 of 6 are weak to Fire, but only 1 resists or ignores it.',
    );
    expect(
      messageFor(PokemonType.fire, [2, 2, 2, 2, 0.5, 0]),
      '4 of 6 are weak to Fire, but only 2 resist or ignore it.',
    );
  });

  test('counts immune members among those that cover the weakness', () {
    expect(
      messageFor(PokemonType.ground, [2, 2, 0, 1]),
      '2 of 4 are weak to Ground, but only 1 resists or ignores it.',
    );
  });

  test('a single weak member is "is", not "are"', () {
    expect(
      messageFor(PokemonType.ice, [2, 1, 1]),
      '1 of 3 is weak to Ice and nobody resists it.',
    );
  });

  test('counts only the slots that were analysed', () {
    expect(
      messageFor(PokemonType.rock, [null, 4, null, 2]),
      '2 of 2 are weak to Rock and nobody resists it.',
    );
  });

  test('uses the tidied name of the type', () {
    expect(messageFor(PokemonType.fighting, [2]), contains('Fighting'));
  });
}
