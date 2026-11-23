import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/failure_message.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/domain/pokemon_summary.dart';
import 'package:pokemon_team_builder/features/search/search_providers.dart';
import 'package:pokemon_team_builder/features/search/search_result_tile.dart';

/// The search field and the list of matching Pokémon below it.
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Start from the current query, so the field and the results agree even if
    // this panel is built again somewhere else later.
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).update('');
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final hasQuery = ref.watch(searchQueryProvider).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onChanged: (text) =>
                ref.read(searchQueryProvider.notifier).update(text),
            decoration: InputDecoration(
              hintText: 'Search by name or number',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear the search',
                      onPressed: _clear,
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: switch (search) {
            SearchLoading() => const Center(child: CircularProgressIndicator()),
            SearchUnavailable(:final failure) => _Unavailable(failure),
            SearchReady(:final matches, :final query) =>
              matches.isEmpty ? _NoMatches(query) : _Results(matches),
          },
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results(this.matches);

  final List<PokemonSummary> matches;

  @override
  Widget build(BuildContext context) {
    // A scrolling list builds a row only when it comes into view, and a row's
    // details are requested when it is built. `builder` also avoids creating a
    // widget for each of the 1,350 rows up front. (A `Column` in a scroll view
    // would build every row, and request every Pokémon at once.)
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final summary = matches[index];
        return SearchResultTile(summary, key: ValueKey(summary.id));
      },
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches(this.query);

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No Pokémon match “$query”.', textAlign: TextAlign.center),
      ),
    );
  }
}

class _Unavailable extends ConsumerWidget {
  const _Unavailable(this.failure);

  final ApiFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: 12),
            Text(
              'The list of Pokémon could not be loaded.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(describeFailure(failure), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(pokemonIndexProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
