import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';

void main() {
  late FakeApiClient api;

  ProviderContainer appWith(FakeApiClient client) {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    api = FakeApiClient(
      (url) => url.path.endsWith('/pokemon/25')
          ? Ok(loadFixture('pokemon_pikachu.json'))
          : const Err(NotFoundFailure()),
    );
  });

  test('loads a Pokémon', () async {
    final container = appWith(api);

    final result = await container.read(pokemonProvider(25).future);

    expect(result.valueOrNull?.name, 'pikachu');
  });

  test('is loading until the answer arrives', () {
    final container = appWith(api);

    expect(container.read(pokemonProvider(25)).isLoading, isTrue);
  });

  test('a failure arrives as a value, not an error', () async {
    final container = appWith(api);

    final result = await container.read(pokemonProvider(99999).future);

    expect(result.failureOrNull, isA<NotFoundFailure>());
    expect(container.read(pokemonProvider(99999)).hasError, isFalse);
  });

  test('a failure is requested once, not retried by Riverpod', () async {
    final container = appWith(api);

    await container.read(pokemonProvider(99999).future);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(api.calls, hasLength(1));
  });

  test('the same id is loaded only once', () async {
    final container = appWith(api);

    await container.read(pokemonProvider(25).future);
    await container.read(pokemonProvider(25).future);

    expect(api.calls, hasLength(1));
  });

  test('different ids are separate requests', () async {
    final container = appWith(api);

    await container.read(pokemonProvider(25).future);
    await container.read(pokemonProvider(26).future);

    expect(api.calls.map((url) => url.path), [
      '/api/v2/pokemon/25',
      '/api/v2/pokemon/26',
    ]);
  });

  test('invalidating asks again, so a failure can be retried', () async {
    var working = false;
    final flaky = FakeApiClient(
      (_) => working
          ? Ok(loadFixture('pokemon_pikachu.json'))
          : const Err(ServerFailure(503)),
    );
    final container = appWith(flaky);

    final first = await container.read(pokemonProvider(25).future);
    working = true;
    container.invalidate(pokemonProvider(25));
    final second = await container.read(pokemonProvider(25).future);

    expect(first.failureOrNull, isA<ServerFailure>());
    expect(second.valueOrNull?.name, 'pikachu');
  });
}
