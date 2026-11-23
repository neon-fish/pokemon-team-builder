import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/search/search_providers.dart';
import 'package:pokemon_team_builder/features/team/team_analysis_provider.dart';

/// Throws away what the app has loaded and asks for it all again.
///
/// Clearing the cache alone would change nothing you could see, because the
/// providers already hold their data. So this also invalidates them, and
/// everything that is on screen is requested again, through the cache that has
/// just been emptied. With the levers turned up, that shows the whole stack
/// working: slow loads, retries, and failures with their retry buttons.
class DataReloader {
  DataReloader(this._ref);

  final Ref _ref;

  void clearCacheAndReload() {
    _ref.read(apiCacheProvider).clear();
    _ref.invalidate(pokemonIndexProvider);
    // Invalidating a family like this does every Pokémon in it.
    _ref.invalidate(pokemonProvider);
    _ref.invalidate(typeChartProvider);
  }
}

final dataReloaderProvider = Provider<DataReloader>(DataReloader.new);
