import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/features/control_panel/data_reloader.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/search/search_providers.dart';
import 'package:pokemon_team_builder/features/team/team_analysis_provider.dart';

import '../../support/counting_transport.dart';

void main() {
  test(
    'asks for everything again, through a cache that has been emptied',
    () async {
      final transport = CountingTransport();
      final container = ProviderContainer(
        overrides: [httpTransportProvider.overrideWithValue(transport)],
      );
      addTearDown(container.dispose);
      Future<void> loadEverything() async {
        await container.read(pokemonIndexProvider.future);
        await container.read(pokemonProvider(25).future);
        await container.read(typeChartProvider.future);
      }

      await loadEverything();
      // Every address was asked for once.
      expect(transport.counts.values, everyElement(1));
      final addresses = transport.counts.length;
      expect(addresses, greaterThan(18), reason: 'index, Pikachu, 18 types');

      container.read(dataReloaderProvider).clearCacheAndReload();
      await loadEverything();

      expect(transport.counts.length, addresses);
      expect(transport.counts.values, everyElement(2));
    },
  );

  test('without the reload, loaded data is simply kept', () async {
    final transport = CountingTransport();
    final container = ProviderContainer(
      overrides: [httpTransportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await container.read(pokemonProvider(25).future);
    await container.read(pokemonProvider(25).future);

    expect(transport.counts['/api/v2/pokemon/25'], 1);
  });

  test('reloading puts everything back to loading', () async {
    final container = ProviderContainer(
      overrides: [httpTransportProvider.overrideWithValue(CountingTransport())],
    );
    addTearDown(container.dispose);
    await container.read(pokemonProvider(25).future);
    expect(container.read(pokemonProvider(25)).isLoading, isFalse);

    container.read(dataReloaderProvider).clearCacheAndReload();

    expect(container.read(pokemonProvider(25)).isLoading, isTrue);
  });
}
