import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/pokemon_summary.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_sprite.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

/// How long a row must stay on screen before it asks for its details.
///
/// Dragging the scroll bar sweeps thousands of rows past in a second. Without
/// this pause, every one of them would request its details (a response of
/// about 350 KB of JSON each) and nothing cancels a request once it is made.
/// Rows that are only passing through are gone before the pause ends.
const _loadDelay = Duration(milliseconds: 150);

/// One row of the search results.
///
/// The name and number come from the search list and show at once. The picture
/// and types need the Pokémon's details, which each row loads for itself once
/// it has been on screen for a moment ([_loadDelay]).
///
/// Tapping the row adds the Pokémon to the team, then calls [onPicked] (for a
/// host that wants to react, such as closing the search sheet). When the team
/// is full the row is disabled.
class SearchResultTile extends ConsumerStatefulWidget {
  const SearchResultTile(this.summary, {this.onPicked, super.key});

  final PokemonSummary summary;
  final VoidCallback? onPicked;

  @override
  ConsumerState<SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends ConsumerState<SearchResultTile> {
  Timer? _timer;

  /// Whether this row has started asking for its details.
  bool _loadDetails = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(pokemonProvider(widget.summary.id).exists)) {
      // Already asked for earlier (this row was scrolled away and back), so
      // there is no request to avoid. Show it straight away.
      _loadDetails = true;
    } else {
      _timer = Timer(_loadDelay, () => setState(() => _loadDetails = true));
    }
  }

  @override
  void dispose() {
    // A row that leaves the screen before the pause ends never asks.
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final request = _loadDetails
        ? ref.watch(pokemonProvider(summary.id))
        : null;
    // `details` is null while loading. That includes a retry: the state then
    // still holds the earlier failure in `.value`, so check `isLoading` first,
    // or the row would keep saying "unavailable" while it tries again.
    final details = (request == null || request.isLoading)
        ? null
        : request.value;

    final teamIsFull = ref.watch(
      teamProvider.select((team) => team.value?.isFull ?? false),
    );

    return ListTile(
      enabled: !teamIsFull,
      onTap: () {
        ref.read(teamProvider.notifier).addPicked(summary.id);
        widget.onPicked?.call();
      },
      leading: PokemonSprite(
        url: switch (details) {
          Ok(:final value) => value.spriteUrl,
          _ => null,
        },
      ),
      title: Text(displayName(summary.name)),
      // One `Wrap` for every state, so the badge, its placeholder and the
      // message all sit at the left at their own width, and the layout does not
      // jump when the state changes.
      subtitle: Wrap(
        spacing: 6,
        children: switch (details) {
          null => [const TypeBadgePlaceholder()],
          Ok(:final value) => [for (final type in value.types) TypeBadge(type)],
          Err() => [const Text('Details unavailable')],
        },
      ),
      // The number is always shown. A row whose details failed also gets a
      // button to ask again.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (details is Err)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Try loading the details again',
              onPressed: () => ref.invalidate(pokemonProvider(summary.id)),
            ),
          Text(
            '#${summary.id}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
