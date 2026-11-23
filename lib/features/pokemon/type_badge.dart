import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/type_colours.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';

/// A small coloured label naming a type, such as "Fire".
class TypeBadge extends StatelessWidget {
  const TypeBadge(this.type, {super.key});

  final PokemonType type;

  @override
  Widget build(BuildContext context) {
    final colour = typeColour(type);
    return _BadgeShape(
      colour: colour,
      textColour: readableTextOn(colour),
      label: displayName(type.name),
    );
  }
}

/// A grey stand-in for a [TypeBadge] while the types are still loading.
///
/// It is built from the same shape as the real badge, with invisible text, so
/// it has exactly the same size and text baseline. A `ListTile` positions its
/// title and subtitle using the subtitle's baseline, so a stand-in that was only
/// roughly the right size would make the row's content jump when the real badges
/// replace it.
class TypeBadgePlaceholder extends StatelessWidget {
  const TypeBadgePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colour = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      // The text is the same colour as the background, so it takes up room but
      // cannot be seen. "Normal" is just a typical width.
      child: _BadgeShape(colour: colour, textColour: colour, label: 'Normal'),
    );
  }
}

/// The rounded, padded label shared by [TypeBadge] and [TypeBadgePlaceholder].
class _BadgeShape extends StatelessWidget {
  const _BadgeShape({
    required this.colour,
    required this.textColour,
    required this.label,
  });

  final Color colour;
  final Color textColour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: textColour, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
