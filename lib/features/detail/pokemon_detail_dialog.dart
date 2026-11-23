import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/features/detail/defences_section.dart';
import 'package:pokemon_team_builder/features/detail/radar_chart.dart';
import 'package:pokemon_team_builder/features/detail/stat_bars.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_sprite.dart';
import 'package:pokemon_team_builder/features/pokemon/stat_labels.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';

/// The most width the dialog takes.
const _dialogMaxWidth = 640.0;

/// The width of the dialog's content from which its chart and bars sit side by
/// side rather than one above the other, and the name sits beside the picture
/// rather than below it.
const _sideBySideFrom = 480.0;
const _nameBesidePictureFrom = 420.0;

/// Shows everything about one Pokémon in a dialog over the current screen.
Future<void> showPokemonDetail(BuildContext context, Pokemon pokemon) {
  return showDialog<void>(
    context: context,
    builder: (context) => PokemonDetailDialog(pokemon),
  );
}

/// A Pokémon's picture, types, base stats (as a radar chart and as bars), and
/// what it is weak to and resists.
class PokemonDetailDialog extends StatelessWidget {
  const PokemonDetailDialog(this.pokemon, {super.key});

  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(pokemon),
            // Only the part below the header scrolls, so the close button is
            // always in reach however tall the content gets.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: _Body(pokemon),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picture, name and types, with the close button.
///
/// Wide enough, the name sits beside the picture. Narrower (a phone), it goes
/// below it: beside the picture and the close button it would get so little
/// width that a name like "Charizard" would break in the middle of a word,
/// especially with large text.
class _Header extends StatelessWidget {
  const _Header(this.pokemon);

  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    final sprite = PokemonSprite(url: pokemon.spriteUrl, size: 96);
    final close = IconButton(
      icon: const Icon(Icons.close),
      tooltip: 'Close',
      onPressed: () => Navigator.of(context).maybePop(),
    );
    final title = _Title(pokemon);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth < _nameBesidePictureFrom
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [sprite, const Spacer(), close]),
                  title,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sprite,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: title,
                    ),
                  ),
                  close,
                ],
              ),
      ),
    );
  }
}

/// The name, number and types.
class _Title extends StatelessWidget {
  const _Title(this.pokemon);

  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayName(pokemon.name), style: textTheme.headlineSmall),
        Text('#${pokemon.id}', style: textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [for (final type in pokemon.types) TypeBadge(type)],
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.pokemon);

  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chart = RadarChart(
      labels: [for (final stat in Stat.values) statAbbreviation(stat)],
      values: [for (final stat in Stat.values) pokemon.stats.valueOf(stat)],
    );
    final bars = StatBars(pokemon.stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Base stats', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= _sideBySideFrom
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 240, child: chart),
                    const SizedBox(width: 24),
                    Expanded(child: bars),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: chart,
                      ),
                    ),
                    const SizedBox(height: 12),
                    bars,
                  ],
                ),
        ),
        const Divider(height: 32),
        Text('Weaknesses and resistances', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        DefencesSection(pokemon.types),
      ],
    );
  }
}
