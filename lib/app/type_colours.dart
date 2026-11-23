import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/domain/pokemon_type.dart';

/// The colour used for [type] on badges and in the coverage matrix.
///
/// These are the colours people associate with each type. They are the same in
/// light and dark themes; [readableTextOn] picks text that works on any of them.
/// The `switch` has no default, so adding a type to the enum will not compile
/// until it gets a colour here.
Color typeColour(PokemonType type) => switch (type) {
  PokemonType.normal => const Color(0xFFA8A77A),
  PokemonType.fighting => const Color(0xFFC22E28),
  PokemonType.flying => const Color(0xFFA98FF3),
  PokemonType.poison => const Color(0xFFA33EA1),
  PokemonType.ground => const Color(0xFFE2BF65),
  PokemonType.rock => const Color(0xFFB6A136),
  PokemonType.bug => const Color(0xFFA6B91A),
  PokemonType.ghost => const Color(0xFF735797),
  PokemonType.steel => const Color(0xFFB7B7CE),
  PokemonType.fire => const Color(0xFFEE8130),
  PokemonType.water => const Color(0xFF6390F0),
  PokemonType.grass => const Color(0xFF7AC74C),
  PokemonType.electric => const Color(0xFFF7D02C),
  PokemonType.psychic => const Color(0xFFF95587),
  PokemonType.ice => const Color(0xFF96D9D6),
  PokemonType.dragon => const Color(0xFF6F35FC),
  PokemonType.dark => const Color(0xFF705746),
  PokemonType.fairy => const Color(0xFFD685AD),
};

/// The luminance at which black and white text are equally easy to read. Any
/// lighter background reads better with black, any darker with white. At that
/// point both give a contrast ratio of about 4.58.
const _equalContrastLuminance = 0.179;

/// Black or white, whichever is easier to read on [background]. The result
/// always reaches the 4.5 contrast ratio that accessibility guidelines (WCAG
/// AA) ask for in normal-sized text.
Color readableTextOn(Color background) {
  return background.computeLuminance() > _equalContrastLuminance
      ? Colors.black
      : Colors.white;
}
