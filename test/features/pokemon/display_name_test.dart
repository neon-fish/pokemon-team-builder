import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';

void main() {
  test('capitalises a plain name', () {
    expect(displayName('pikachu'), 'Pikachu');
  });

  test('turns hyphens into spaces and capitalises each word', () {
    expect(displayName('mr-mime'), 'Mr Mime');
    expect(displayName('pikachu-rock-star'), 'Pikachu Rock Star');
    expect(displayName('charizard-mega-x'), 'Charizard Mega X');
  });

  test('leaves an already tidy name alone', () {
    expect(displayName('Pikachu'), 'Pikachu');
  });

  test('copes with odd input', () {
    expect(displayName(''), '');
    expect(displayName('a--b'), 'A  B');
  });
}
