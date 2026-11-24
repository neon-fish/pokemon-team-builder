import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/features/team/lifted_slot_notifier.dart';

void main() {
  late ProviderContainer container;
  late LiftedSlotNotifier lifted;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    lifted = container.read(liftedSlotProvider.notifier);
  });

  int? current() => container.read(liftedSlotProvider);

  test('starts with no slot lifted', () {
    expect(current(), isNull);
  });

  test('lifting a slot, and then another, leaves only the latest', () {
    lifted.lift(2);
    expect(current(), 2);

    lifted.lift(1);
    expect(current(), 1);
  });

  test('putting the lifted slot down clears it', () {
    lifted.lift(2);

    lifted.putDown(2);

    expect(current(), isNull);
  });

  test('putting down a slot that is not the lifted one does nothing', () {
    // An old dialog finishing closing must not put down a newer one's slot.
    lifted.lift(3);

    lifted.putDown(2);

    expect(current(), 3);
  });

  test('is harmless once the providers have gone', () {
    container.dispose();

    expect(() => lifted.lift(1), returnsNormally);
    expect(() => lifted.putDown(1), returnsNormally);
  });
}
