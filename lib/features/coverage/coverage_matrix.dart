import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/failure_message.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/domain/matchup_order.dart';
import 'package:pokemon_team_builder/domain/team.dart';
import 'package:pokemon_team_builder/domain/team_analysis.dart';
import 'package:pokemon_team_builder/features/coverage/cell_colours.dart';
import 'package:pokemon_team_builder/features/coverage/coverage_providers.dart';
import 'package:pokemon_team_builder/features/coverage/exposure_message.dart';
import 'package:pokemon_team_builder/features/coverage/multiplier_label.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_provider.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_sprite.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/team/team_analysis_provider.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

/// The width of the column naming the type, and of the one counting weak
/// members. The six cells share what is left.
const _typeColumnWidth = 88.0;
const _countColumnWidth = 40.0;

/// The height of a cell. A cell's text is scaled down to fit if the user has
/// asked for large text, so the rows stay the same size.
const _cellHeight = 32.0;

/// Where the team is weak: one row for each attacking type, with a cell for
/// each team slot showing the damage that slot's Pokémon takes from it.
class CoverageMatrix extends ConsumerWidget {
  const CoverageMatrix({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = ref.watch(coverageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coverage', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        switch (coverage) {
          TeamAnalysisLoading() => const _Loading(),
          TeamAnalysisUnavailable(:final failure) => _Unavailable(failure),
          TeamAnalysisReady() => _Ready(coverage),
        },
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
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
              'The type chart could not be loaded, so the team cannot be '
              'analysed.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(describeFailure(failure), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(typeChartProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready(this.analysis);

  final TeamAnalysisReady analysis;

  @override
  Widget build(BuildContext context) {
    // Nobody to analyse and nobody missing: an empty team.
    if (analysis.analysedCount == 0 && analysis.missingCount == 0) {
      return const _Message('Add a Pokémon to see where your team is weak.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Said out loud: a team that looks safe may just be missing a member.
        if (analysis.missingCount > 0)
          _IncompleteWarning(analysis.missingCount),
        if (analysis.analysedCount > 0) _Matrix(analysis.matchups),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    );
  }
}

class _IncompleteWarning extends StatelessWidget {
  const _IncompleteWarning(this.missingCount);

  final int missingCount;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    final who = missingCount == 1
        ? '1 team member is'
        : '$missingCount team members are';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colours.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colours.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$who still loading or could not be loaded, so this may be '
                  'incomplete.',
                  style: TextStyle(color: colours.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Matrix extends StatelessWidget {
  const _Matrix(this.matchups);

  final List<TypeMatchup> matchups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'The damage each Pokémon takes from each type. Red is a weakness, '
          'green resists or ignores it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        const _HeaderRow(),
        for (final matchup in matchups) MatchupRow(matchup),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const SizedBox(width: _typeColumnWidth, child: _OrderMenu()),
          for (var slot = 0; slot < Team.slotCount; slot++)
            Expanded(child: _SlotHeader(slot)),
          SizedBox(
            width: _countColumnWidth,
            child: Center(
              child: Text(
                'Weak',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _orderLabel(MatchupOrder order) => switch (order) {
  MatchupOrder.standard => 'Standard order',
  MatchupOrder.biggestGapsFirst => 'Biggest gaps first',
};

/// The "Type" heading, which opens a menu to choose the order of the rows.
class _OrderMenu extends ConsumerWidget {
  const _OrderMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(matchupOrderProvider);

    return PopupMenuButton<MatchupOrder>(
      tooltip: 'Change the order of the types',
      initialValue: current,
      onSelected: (order) =>
          ref.read(matchupOrderProvider.notifier).choose(order),
      itemBuilder: (context) => [
        for (final order in MatchupOrder.values)
          CheckedPopupMenuItem<MatchupOrder>(
            value: order,
            checked: order == current,
            child: Text(_orderLabel(order)),
          ),
      ],
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 48,
        // Scaled down, like the other fixed-width parts, if the text is large.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text('Type', style: Theme.of(context).textTheme.labelLarge),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

/// The head of one column: the Pokémon in that slot, or the slot's number.
class _SlotHeader extends ConsumerWidget {
  const _SlotHeader(this.index);

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(
      teamProvider.select((team) => team.value?.slots[index]),
    );
    if (id == null) {
      return Center(
        child: Text(
          '${index + 1}',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }

    final pokemon = ref.watch(pokemonProvider(id)).value?.valueOrNull;
    return Tooltip(
      message: pokemon == null ? 'Pokémon #$id' : displayName(pokemon.name),
      child: Center(child: PokemonSprite(url: pokemon?.spriteUrl, size: 28)),
    );
  }
}

/// One row: an attacking type, what each slot takes from it, and how many are
/// weak. A row the team is exposed to is tinted and says why underneath.
class MatchupRow extends StatelessWidget {
  const MatchupRow(this.matchup, {super.key});

  final TypeMatchup matchup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exposure = describeExposure(matchup);
    final name = displayName(matchup.attacking.name);

    // A screen reader gets one sentence for the row, rather than 18 cells' worth
    // of symbols to work through.
    final summary =
        '$name: ${matchup.weakCount} weak, ${matchup.resistantCount} resist, '
        '${matchup.immuneCount} immune.';

    return Semantics(
      container: true,
      label: exposure == null ? summary : '$summary $exposure',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: exposure == null
                ? null
                : theme.colorScheme.errorContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: _typeColumnWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: TypeBadge(matchup.attacking),
                        ),
                      ),
                    ),
                    for (final multiplier in matchup.multipliers)
                      Expanded(child: MatchupCell(multiplier)),
                    SizedBox(
                      width: _countColumnWidth,
                      child: Center(
                        child: Text(
                          matchup.knownCount == 0 ? '' : '${matchup.weakCount}',
                          style: exposure == null
                              ? null
                              : const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                if (exposure != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(exposure, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What one slot takes from one type, such as `2×`. Blank for a slot that was
/// not analysed.
class MatchupCell extends StatelessWidget {
  const MatchupCell(this.multiplier, {super.key});

  final double? multiplier;

  @override
  Widget build(BuildContext context) {
    // Copied to a local variable as only local variables have their types narrowed by null-safety.
    // `this.multiplier` is a field, so it is not narrowed.
    final multiplier = this.multiplier;
    if (multiplier == null) return const SizedBox(height: _cellHeight + 4);

    final colours = cellColours(Theme.of(context).colorScheme, multiplier);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        height: _cellHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colours.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            multiplierLabel(multiplier),
            style: TextStyle(color: colours.text, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
