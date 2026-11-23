import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/features/coverage/multiplier_label.dart';

void main() {
  test('each damage multiplier has its own short label', () {
    expect(multiplierLabel(4), '4×');
    expect(multiplierLabel(2), '2×');
    expect(multiplierLabel(0.5), '½');
    expect(multiplierLabel(0.25), '¼');
    expect(multiplierLabel(0), '0');
  });

  test('normal damage has no label', () {
    expect(multiplierLabel(1), '');
  });

  test('an unexpected value is shown as it is, not hidden', () {
    expect(multiplierLabel(1.5), '1.5×');
  });
}
