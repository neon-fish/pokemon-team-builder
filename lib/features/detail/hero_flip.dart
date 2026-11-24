import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// The `Hero` tag shared by the card in team slot [slot] (counting from 0) and
/// the details dialog opened from it. The slot number, not the Pokémon, because
/// the same Pokémon can be in several slots.
String slotHeroTag(int slot) => 'team-slot-$slot';

/// Whether the card is the face showing, [t] of the way through the flip. The
/// flip runs from 0 (the card) to 1 (the dialog), and the faces swap halfway,
/// when the card is edge-on and cannot be seen.
bool showsCardFace(double t) => t < 0.5;

/// How far round the vertical axis the showing face is turned, in radians,
/// [t] of the way through the flip.
///
/// The card turns from facing us (0) to edge-on (a quarter turn). Then the
/// dialog turns from edge-on, on the other side, to facing us. That is a
/// negative quarter turn at the swap and 0 at the end, so the dialog is never
/// shown back to front.
double flipAngle(double t) => t < 0.5 ? t * pi : (t - 1) * pi;

/// What a `Hero` shows while it flies between a card and a dialog: a card that
/// turns edge-on and a dialog that turns back to face us.
///
/// Give it as `flightShuttleBuilder` to both the card's `Hero` and the
/// dialog's.
///
/// The animation it is given follows the dialog's route: 0 is the card, 1 is
/// the dialog, whichever way the flight goes. Opening runs it from 0 to 1 and
/// closing from 1 to 0, so the same rule plays the flip forwards and then
/// backwards.
Widget flipShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  // Opening goes from the card to the dialog, and closing the other way round.
  final opening = direction == HeroFlightDirection.push;
  // Both faces are made now, once, as the flight starts. Their sizes are only
  // known now, and a card that is removed part-way through the flight cannot
  // then be asked for its size.
  final cardFace = _face(opening ? fromHeroContext : toHeroContext);
  final dialogFace = _face(opening ? toHeroContext : fromHeroContext);

  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = animation.value;
      return Transform(
        // So a test can tell that the flight is under way.
        key: const Key('flip-shuttle'),
        alignment: Alignment.center,
        // The 0.0012 gives a little perspective, so the far edge looks smaller
        // as the face turns, rather than the face being squashed flat.
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(flipAngle(t)),
        child: showsCardFace(t) ? cardFace : dialogFace,
      );
    },
  );
}

/// The content of the `Hero` whose context this is, laid out at that Hero's own
/// size and then stretched to whatever space the flight gives it.
///
/// Laid out at its own size so that it never has to fit a space too small for
/// it (which would overflow) or change its layout part-way through.
Widget _face(BuildContext heroContext) {
  final hero = heroContext.widget as Hero;
  // `heroContext.size` refuses to be read while widgets are being built, which
  // is when this runs. The size the box was given in the last layout is fine.
  final size = (heroContext.findRenderObject()! as RenderBox).size;
  return FittedBox(
    fit: BoxFit.fill,
    child: SizedBox.fromSize(size: size, child: hero.child),
  );
}
