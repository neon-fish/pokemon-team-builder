import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/features/search/search_providers.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';

void main() {
  // What the fake API does, changed by tests to simulate trouble.
  var indexFails = false;
  late FakeApiClient api;

  setUp(() {
    indexFails = false;
    api = FakeApiClient(
      (url) => indexFails
          ? const Err(OfflineFailure())
          : Ok(loadFixture('pokemon_index.json')),
    );
  });

  ProviderContainer appWithApi() {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// The names in the search results, which must be ready.
  List<String> namesIn(ProviderContainer app) {
    final state = app.read(searchProvider);
    expect(state, isA<SearchReady>());
    return [for (final match in (state as SearchReady).matches) match.name];
  }

  test('is loading until the list arrives', () {
    final app = appWithApi();

    expect(app.read(searchProvider), isA<SearchLoading>());
  });

  test('lists everyone when nothing has been typed', () async {
    final app = appWithApi();

    await app.read(pokemonIndexProvider.future);

    expect(namesIn(app), [
      'bulbasaur',
      'ivysaur',
      'pikachu',
      'pikachu-rock-star',
      'baxcalibur-mega',
    ]);
  });

  test(
    'a list that has loaded stays on show while it is loaded again',
    () async {
      final app = appWithApi();
      await app.read(pokemonIndexProvider.future);

      app.invalidate(pokemonIndexProvider);

      expect(namesIn(app), hasLength(5));
    },
  );

  test('narrows as the query changes', () async {
    final app = appWithApi();
    await app.read(pokemonIndexProvider.future);

    app.read(searchQueryProvider.notifier).update('pika');
    expect(namesIn(app), ['pikachu', 'pikachu-rock-star']);

    app.read(searchQueryProvider.notifier).update('pikachu rock');
    expect(namesIn(app), ['pikachu-rock-star']);

    app.read(searchQueryProvider.notifier).update('');
    expect(namesIn(app), hasLength(5));
  });

  test(
    'keeps what was typed, without surrounding spaces, in the state',
    () async {
      final app = appWithApi();
      await app.read(pokemonIndexProvider.future);

      app.read(searchQueryProvider.notifier).update('  zzz ');

      final state = app.read(searchProvider) as SearchReady;
      expect(state.matches, isEmpty);
      expect(state.query, 'zzz');
    },
  );

  test(
    'a query typed before the list arrives is applied when it does',
    () async {
      final app = appWithApi();
      app.read(searchQueryProvider.notifier).update('mega');
      expect(app.read(searchProvider), isA<SearchLoading>());

      await app.read(pokemonIndexProvider.future);

      expect(namesIn(app), ['baxcalibur-mega']);
    },
  );

  group('when the list cannot be loaded', () {
    test('the search is unavailable, with the reason', () async {
      indexFails = true;
      final app = appWithApi();

      await app.read(pokemonIndexProvider.future);

      final state = app.read(searchProvider);
      expect(state, isA<SearchUnavailable>());
      expect((state as SearchUnavailable).failure, isA<OfflineFailure>());
    });

    test('it arrives as a value and is requested once, not retried', () async {
      indexFails = true;
      final app = appWithApi();

      await app.read(pokemonIndexProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(app.read(pokemonIndexProvider).hasError, isFalse);
      expect(api.calls, hasLength(1));
    });

    test('while retrying it is loading, not the old failure', () async {
      indexFails = true;
      final app = appWithApi();
      await app.read(pokemonIndexProvider.future);

      // The retry has started but has not finished.
      app.invalidate(pokemonIndexProvider);

      expect(app.read(searchProvider), isA<SearchLoading>());
    });

    test('retrying recovers', () async {
      indexFails = true;
      final app = appWithApi();
      await app.read(pokemonIndexProvider.future);

      indexFails = false;
      app.invalidate(pokemonIndexProvider);
      await app.read(pokemonIndexProvider.future);

      expect(namesIn(app), hasLength(5));
    });
  });
}
