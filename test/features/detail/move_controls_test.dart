import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/features/detail/move_controls.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

import '../../support/in_memory_key_value_store.dart';

void main() {
  late InMemoryKeyValueStore store;

  setUp(() => store = InMemoryKeyValueStore());

  /// Shows the controls for the Pokémon in slot [slot] of a team that has
  /// Pikachu (25) there and Koraidon (10264) in every other slot.
  ///
  /// The controls only say where the Pokémon has moved to; whoever shows them
  /// keeps track and shows them again, as the details dialog does. So here a
  /// small stand-in does the same.
  Future<void> pumpControls(WidgetTester tester, int slot) async {
    final ids = [for (var i = 0; i < 6; i++) i == slot ? 25 : 10264];
    store.data['team'] = '{"ids":$ids}';
    var where = slot;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MoveControls(
                where,
                onMoved: (moved) => setState(() => where = moved),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Where Pikachu is now.
  int pikachuSlot(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MoveControls)),
    );
    return container.read(teamProvider).requireValue.slots.indexOf(25);
  }

  Finder button(String label) => find.widgetWithText(TextButton, label);

  bool isEnabled(WidgetTester tester, String label) =>
      tester.widget<TextButton>(button(label)).onPressed != null;

  testWidgets('says which slot the Pokémon is in', (tester) async {
    await pumpControls(tester, 2);

    expect(find.text('Slot 3 of 6'), findsOneWidget);
  });

  testWidgets('"Move earlier" moves it one slot, and the label follows', (
    tester,
  ) async {
    await pumpControls(tester, 2);

    await tester.tap(button('Move earlier'));
    await tester.pumpAndSettle();

    expect(pikachuSlot(tester), 1);
    expect(find.text('Slot 2 of 6'), findsOneWidget);
  });

  testWidgets('"Move later" moves it one slot, and the label follows', (
    tester,
  ) async {
    await pumpControls(tester, 2);

    await tester.tap(button('Move later'));
    await tester.pumpAndSettle();

    expect(pikachuSlot(tester), 3);
    expect(find.text('Slot 4 of 6'), findsOneWidget);
  });

  testWidgets('can be pressed again and again', (tester) async {
    await pumpControls(tester, 1);

    await tester.tap(button('Move later'));
    await tester.pumpAndSettle();
    await tester.tap(button('Move later'));
    await tester.pumpAndSettle();
    await tester.tap(button('Move earlier'));
    await tester.pumpAndSettle();

    expect(pikachuSlot(tester), 2);
    expect(find.text('Slot 3 of 6'), findsOneWidget);
  });

  testWidgets('in the first slot there is nothing earlier', (tester) async {
    await pumpControls(tester, 0);

    expect(isEnabled(tester, 'Move earlier'), isFalse);
    expect(isEnabled(tester, 'Move later'), isTrue);
  });

  testWidgets('in the last slot there is nothing later', (tester) async {
    await pumpControls(tester, 5);

    expect(isEnabled(tester, 'Move earlier'), isTrue);
    expect(isEnabled(tester, 'Move later'), isFalse);
  });

  testWidgets('reaching the end turns that button off', (tester) async {
    await pumpControls(tester, 4);

    await tester.tap(button('Move later'));
    await tester.pumpAndSettle();

    expect(find.text('Slot 6 of 6'), findsOneWidget);
    expect(isEnabled(tester, 'Move later'), isFalse);
  });

  testWidgets('fits a narrow space at double text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    store.data['team'] = '{"ids":[25]}';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 280, child: MoveControls(2, onMoved: (_) {})),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
