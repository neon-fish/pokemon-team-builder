import 'dart:ui' show SemanticsRole;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/domain/pokemon.dart';
import 'package:pokemon_team_builder/features/detail/defences_section.dart';
import 'package:pokemon_team_builder/features/detail/hero_flip.dart';
import 'package:pokemon_team_builder/features/detail/move_controls.dart';
import 'package:pokemon_team_builder/features/detail/radar_chart.dart';
import 'package:pokemon_team_builder/features/detail/stat_bars.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';
import 'package:pokemon_team_builder/features/pokemon/pokemon_sprite.dart';
import 'package:pokemon_team_builder/features/pokemon/stat_labels.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/team/lifted_slot_notifier.dart';

/// The most width the dialog takes.
const _dialogMaxWidth = 640.0;

/// The width of the dialog's content from which its chart and bars sit side by
/// side rather than one above the other, and the name sits beside the picture
/// rather than below it.
const _sideBySideFrom = 480.0;
const _nameBesidePictureFrom = 420.0;

/// How long the card takes to flip open into the dialog, and back.
const detailFlipDuration = Duration(milliseconds: 600);

/// How long the dialog takes to fade in and out instead, when the system asks
/// for less motion.
const detailFadeDuration = Duration(milliseconds: 200);

/// Shows everything about one Pokémon in a dialog over the current screen.
///
/// If the Pokémon is on the team, [slot] is the slot it is in (counting from 0).
/// The card in that slot then flips open into the dialog, and the dialog offers
/// to move the Pokémon. With the system's "reduce motion" setting on, or with no
/// slot, the dialog just fades in.
///
/// This is a route of its own, not `showDialog`, because a `Hero` only flies
/// between page routes, and a dialog from `showDialog` is not one.
Future<void> showPokemonDetail(
  BuildContext context,
  Pokemon pokemon, {
  int? slot,
}) {
  final duration = MediaQuery.disableAnimationsOf(context)
      ? detailFadeDuration
      : detailFlipDuration;
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      // The screen behind stays visible, dimmed, as with a dialog; tapping the
      // dimmed part closes it.
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) =>
          PokemonDetailDialog(pokemon, slot: slot),
      // While the card flies, its place in the dialog is empty, so this fade is
      // only seen when there is no flight.
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// A Pokémon's picture, types, base stats (as a radar chart and as bars), and
/// what it is weak to and resists.
///
/// With a [slot], it also has buttons to move the Pokémon earlier or later in
/// the team, and the card in that slot flips open into it (see
/// [showPokemonDetail]). Without one (a Pokémon that is not on the team) it does
/// neither.
class PokemonDetailDialog extends ConsumerStatefulWidget {
  const PokemonDetailDialog(this.pokemon, {this.slot, super.key});

  final Pokemon pokemon;
  final int? slot;

  @override
  ConsumerState<PokemonDetailDialog> createState() =>
      _PokemonDetailDialogState();
}

class _PokemonDetailDialogState extends ConsumerState<PokemonDetailDialog> {
  // Where the Pokémon is now. It starts as `widget.slot` and follows the
  // Pokémon when the buttons move it, so that the dialog closes by flipping back
  // into the card the Pokémon is in now, not the slot it started in.
  int? _slot;

  // Kept, so it can still be used after this widget has gone: the closing
  // animation ends after the widget has stopped being part of the screen.
  late final LiftedSlotNotifier _liftedSlot;

  // Whether this dialog has lifted its card out of the team, leaving a gap.
  var _lifting = false;

  @override
  void initState() {
    super.initState();
    _slot = widget.slot;
    _liftedSlot = ref.read(liftedSlotProvider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first time only, and only for a dialog that is flipped open from a
    // card: it needs a route to follow, a slot to lift, and motion to be
    // allowed. (Without motion, the card stays where it is behind the fade.)
    final route = ModalRoute.of(context);
    if (_lifting ||
        _slot == null ||
        route == null ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _lifting = true;

    // Lifted after this frame, which is when the card's flight begins. Earlier,
    // the card would vanish a moment before its flying copy appeared. A moment
    // later does not show, since the copy is on top of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final slot = _slot;
      if (mounted && slot != null) _liftedSlot.lift(slot);
    });

    // Put down when the closing animation has finished, which is the moment the
    // card's flight back ends, so the card is there as its copy goes.
    route.animation!.addStatusListener((status) {
      final slot = _slot;
      if (status == AnimationStatus.dismissed && slot != null) {
        _liftedSlot.putDown(slot);
      }
    });
  }

  @override
  void dispose() {
    // In case the dialog goes without its animation finishing, so no gap is
    // left behind.
    final slot = _slot;
    if (_lifting && slot != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _liftedSlot.putDown(slot),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A local copy, because a field is not promoted to non-null by the check.
    final slot = _slot;
    final pokemon = widget.pokemon;

    // What `Dialog` would draw: a rounded surface in the dialog colour. It is
    // built by hand because the flip needs this surface inside a `Hero`. The
    // values are the ones a Material 3 `Dialog` uses, shadow included: it has
    // none (the default black one drew a dark outline).
    final surface = Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      elevation: 6,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      type: MaterialType.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(pokemon),
          // Only the part below the header scrolls, so the close button is
          // always in reach however tall the content gets.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // First, so it is in view when the dialog opens. (Pinned
                  // below the body instead, it left no room for the body on a
                  // small screen with large text.)
                  if (slot != null) ...[
                    MoveControls(
                      slot,
                      onMoved: (moved) {
                        setState(() => _slot = moved);
                        // The gap goes with the Pokémon.
                        if (_lifting) _liftedSlot.lift(moved);
                      },
                    ),
                    const Divider(height: 32),
                  ],
                  _Body(pokemon),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Says "this is a dialog" to a screen reader, as a `Dialog` does.
    return Semantics(
      role: SemanticsRole.dialog,
      child: SafeArea(
        // The gap a `Dialog` leaves round itself.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 280,
                maxWidth: _dialogMaxWidth,
              ),
              child: slot == null
                  ? surface
                  // `HeroMode` off: no flip, and the dialog simply fades in.
                  : HeroMode(
                      enabled: !MediaQuery.disableAnimationsOf(context),
                      child: Hero(
                        tag: slotHeroTag(slot),
                        flightShuttleBuilder: flipShuttleBuilder,
                        child: surface,
                      ),
                    ),
            ),
          ),
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
