import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/features/theme/theme_mode_picker.dart';

/// TEMPORARY. A throwaway screen for exercising the API stack by hand. It will
/// be replaced by the real UI.
class ScratchHome extends ConsumerStatefulWidget {
  const ScratchHome({super.key});

  @override
  ConsumerState<ScratchHome> createState() => _ScratchHomeState();
}

class _ScratchHomeState extends ConsumerState<ScratchHome> {
  static const _prompt = 'Press the button to call PokeAPI.';

  String _output = _prompt;
  bool _busy = false;

  Future<void> _fetchRandomPokemon() async {
    setState(() => _busy = true);

    final id = Random().nextInt(151) + 1;
    final result = await ref
        .read(apiClientProvider)
        .getJson(Uri.https('pokeapi.co', '/api/v2/pokemon/$id'));

    // The widget may have gone away while we waited.
    if (!mounted) return;
    setState(() {
      _busy = false;
      _output = switch (result) {
        Ok(:final value) => _summarise(value),
        Err(:final failure) => 'Request failed:\n$failure',
      };
    });
  }

  /// The full response is hundreds of kilobytes, so show just a few fields.
  String _summarise(Object? json) {
    if (json is! Map<String, Object?>) {
      return 'Unexpected response: ${json.runtimeType}';
    }
    const fields = ['id', 'name', 'height', 'weight', 'base_experience'];
    return const JsonEncoder.withIndent('  ')
        .convert({for (final field in fields) field: json[field]});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokémon Team Builder'),
        actions: const [ThemeModePicker(), SizedBox(width: 16)],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(_output, textAlign: TextAlign.center),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _fetchRandomPokemon,
        tooltip: 'Fetch a random Pokémon',
        child: _busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : const Icon(Icons.catching_pokemon),
      ),
    );
  }
}
