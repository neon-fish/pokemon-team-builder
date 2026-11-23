import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/failure_message.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/domain/defences.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/features/coverage/multiplier_label.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/team/team_analysis_provider.dart';

/// What a Pokémon is weak to, resists and is immune to, from its [types].
///
/// It needs the type chart, which has a loading state and can fail like any
/// other request, so it has a way to try again.
class DefencesSection extends ConsumerWidget {
  const DefencesSection(this.types, {super.key});

  final List<PokemonType> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(typeChartProvider);
    // Null while loading, including a retry (see `SearchResultTile`).
    final chart = request.isLoading ? null : request.value;

    return switch (chart) {
      null => const Center(child: CircularProgressIndicator()),
      Ok(:final value) => _Groups(defencesOf(types, value)),
      Err(:final failure) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The type chart could not be loaded. ${describeFailure(failure)}',
          ),
          TextButton(
            onPressed: () => ref.invalidate(typeChartProvider),
            child: const Text('Try again'),
          ),
        ],
      ),
    };
  }
}

class _Groups extends StatelessWidget {
  const _Groups(this.defences);

  final Defences defences;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (defences.weakTo.isNotEmpty)
          _Group('Weak to', [
            for (final effect in defences.weakTo)
              _EffectChip(effect.type, multiplierLabel(effect.multiplier)),
          ]),
        if (defences.resists.isNotEmpty)
          _Group('Resists', [
            for (final effect in defences.resists)
              _EffectChip(effect.type, multiplierLabel(effect.multiplier)),
          ]),
        if (defences.immuneTo.isNotEmpty)
          _Group('Immune to', [
            for (final type in defences.immuneTo) _EffectChip(type, ''),
          ]),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.chips);

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 6, children: chips),
        ],
      ),
    );
  }
}

/// A type badge with the multiplier beside it, such as "Fire 2×". An immunity
/// has no multiplier to show (the group's title says it all).
class _EffectChip extends StatelessWidget {
  const _EffectChip(this.type, this.label);

  final PokemonType type;
  final String label;

  @override
  Widget build(BuildContext context) {
    // One item to a screen reader: "Fire, 2×". If very large text makes it
    // wider than the space there is, it shrinks to fit rather than overflow.
    return MergeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TypeBadge(type),
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
