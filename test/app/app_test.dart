import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/app.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';

import '../support/fake_api_client.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, FakeApiClient client) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const PokemonTeamBuilderApp(),
      ),
    );
  }

  testWidgets('shows a prompt before anything is fetched', (tester) async {
    final client = FakeApiClient((_) => const Ok(null));
    await pumpApp(tester, client);

    expect(find.text('Press the button to call PokeAPI.'), findsOneWidget);
    expect(client.calls, isEmpty);
  });

  testWidgets('the button fetches a Pokémon and shows a summary', (
    tester,
  ) async {
    final client = FakeApiClient(
      (_) => const Ok({
        'id': 25,
        'name': 'pikachu',
        'height': 4,
        'weight': 60,
        'base_experience': 112,
        'sprites': {'ignored': true},
      }),
    );
    await pumpApp(tester, client);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(client.calls.single.host, 'pokeapi.co');
    expect(client.calls.single.path, startsWith('/api/v2/pokemon/'));
    expect(find.textContaining('"name": "pikachu"'), findsOneWidget);
    expect(find.textContaining('ignored'), findsNothing);
  });

  testWidgets('a failure is shown instead of crashing', (tester) async {
    final client = FakeApiClient((_) => const Err(OfflineFailure('no wifi')));
    await pumpApp(tester, client);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Request failed'), findsOneWidget);
    expect(find.textContaining('no wifi'), findsOneWidget);
  });

  testWidgets('an unexpected response shape is reported, not parsed', (
    tester,
  ) async {
    final client = FakeApiClient((_) => const Ok(<Object?>[1, 2]));
    await pumpApp(tester, client);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unexpected response'), findsOneWidget);
  });
}
