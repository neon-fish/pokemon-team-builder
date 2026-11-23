import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/features/control_panel/format_seconds.dart';

void main() {
  String format(int milliseconds) =>
      formatSeconds(Duration(milliseconds: milliseconds));

  test('whole seconds have no decimal point', () {
    expect(format(2000), '2 s');
    expect(format(10000), '10 s');
    expect(format(1000), '1 s');
  });

  test('drops a trailing zero', () {
    expect(format(1500), '1.5 s');
    expect(format(500), '0.5 s');
  });

  test('keeps hundredths when there are some', () {
    expect(format(250), '0.25 s');
    expect(format(750), '0.75 s');
  });

  test('rounds anything finer', () {
    // A retry delay has random jitter, so it is rarely a round number.
    expect(format(703), '0.7 s');
    expect(format(1996), '2 s');
  });

  test('zero is zero', () {
    expect(format(0), '0 s');
  });
}
