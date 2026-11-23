import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/data/caching_api_client.dart';
import 'package:pokemon_team_builder/data/concurrency_limited_api_client.dart';
import 'package:pokemon_team_builder/data/http/fault_injecting_transport.dart';
import 'package:pokemon_team_builder/data/http/http_transport.dart';
import 'package:pokemon_team_builder/data/http/package_http_transport.dart';
import 'package:pokemon_team_builder/data/http_api_client.dart';
import 'package:pokemon_team_builder/data/pokemon_index_repository.dart';
import 'package:pokemon_team_builder/data/pokemon_repository.dart';
import 'package:pokemon_team_builder/data/retrying_api_client.dart';
import 'package:pokemon_team_builder/data/storage/key_value_store.dart';
import 'package:pokemon_team_builder/data/storage/shared_preferences_key_value_store.dart';
import 'package:pokemon_team_builder/data/team_repository.dart';
import 'package:pokemon_team_builder/data/type_chart_repository.dart';
import 'package:pokemon_team_builder/features/control_panel/fault_settings_notifier.dart';
import 'package:pokemon_team_builder/features/control_panel/retry_log.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_repository.dart';

/// Where the team is saved. Tests override this with an in-memory store.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SharedPreferencesKeyValueStore(),
);

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.watch(keyValueStoreProvider)),
);

final themeModeRepositoryProvider = Provider<ThemeModeRepository>(
  (ref) => ThemeModeRepository(ref.watch(keyValueStoreProvider)),
);

/// The real network connection. Tests override this with a fake transport so
/// the whole stack above it can be exercised without the network.
final httpTransportProvider = Provider<HttpTransport>((ref) {
  final transport = PackageHttpTransport();
  ref.onDispose(transport.close);
  return transport;
});

/// The composition root for networking: assembles the decorator stack.
///
/// Inner to outer: real transport, fault injection, status/JSON handling,
/// retries (each one noted in the retry log), concurrency limit, cache.
///
/// This is the cache at the top of the stack. It is a provider of its own so the
/// control panel can clear it; everything else asks for [apiClientProvider].
///
/// This must stay a single long-lived instance: the limiter's queue and the
/// cache are state.
final apiCacheProvider = Provider<CachingApiClient>((ref) {
  final transport = FaultInjectingTransport(
    ref.watch(httpTransportProvider),
    // `read`, not `watch`: the transport asks for the latest settings on each
    // request, so changing a lever never rebuilds the whole stack.
    settings: () => ref.read(faultSettingsProvider),
  );
  return CachingApiClient(
    ConcurrencyLimitedApiClient(
      RetryingApiClient(
        HttpApiClient(transport),
        onRetry: (event) => ref.read(retryLogProvider.notifier).add(event),
      ),
    ),
  );
});

/// What the app talks to. Widget tests that do not care about the stack replace
/// this provider with a fake [ApiClient]; tests of the stack itself override
/// [httpTransportProvider] instead.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ref.watch(apiCacheProvider),
);

final pokemonIndexRepositoryProvider = Provider<PokemonIndexRepository>(
  (ref) => PokemonIndexRepository(ref.watch(apiClientProvider)),
);

final pokemonRepositoryProvider = Provider<PokemonRepository>(
  (ref) => PokemonRepository(ref.watch(apiClientProvider)),
);

final typeChartRepositoryProvider = Provider<TypeChartRepository>(
  (ref) => TypeChartRepository(ref.watch(apiClientProvider)),
);
