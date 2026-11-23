import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/features/detail/radar_geometry.dart';
import 'package:pokemon_team_builder/features/pokemon/stat_labels.dart';

/// The six base stats, each as a name, a number and a bar, and the total.
///
/// This is the accessible version of the radar chart: the same numbers, as
/// text. Each row is read out as one sentence, such as "Attack: 55", and the
/// bar (a picture of the same number) is left out.
class StatBars extends StatelessWidget {
  const StatBars(this.stats, {super.key});

  final BaseStats stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final stat in Stat.values)
          _StatRow(name: statName(stat), value: stats.valueOf(stat)),
        const SizedBox(height: 4),
        Semantics(
          label: 'Total: ${stats.total}',
          excludeSemantics: true,
          child: Row(
            children: [
              Expanded(child: Text('Total', style: textTheme.titleSmall)),
              Text('${stats.total}', style: textTheme.titleSmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.name, required this.value});

  final String name;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    // The name and number share a line above the bar, so a long name or large
    // text never has to fit beside a bar of a set width.
    return Semantics(
      label: '$name: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(name)),
                Text(
                  '$value',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colours.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  // `Align` loosens the height, and a box with no child shrinks
                  // to nothing when it can, so the fill is told to be as tall
                  // as the track.
                  child: FractionallySizedBox(
                    widthFactor: statFraction(value),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colours.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
