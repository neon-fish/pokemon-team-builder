import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/team/arrivals_notifier.dart';
import 'package:pokemon_team_builder/features/team/ball_painter.dart';
import 'package:pokemon_team_builder/features/team/throw_geometry.dart';

/// How long the ball takes to fly into the slot.
const throwFlightDuration = Duration(milliseconds: 700);

/// How long the flash and the reveal take, once the ball has landed and the
/// Pokémon is ready.
const throwRevealDuration = Duration(milliseconds: 350);

/// One controller runs the whole animation, from 0 to 1. The flight is the
/// first part of it, up to this point, and the reveal is the rest.
final _landedAt =
    throwFlightDuration.inMilliseconds /
    (throwFlightDuration + throwRevealDuration).inMilliseconds;

/// Plays the "ball thrown into the slot" animation over [child], if this slot
/// has just had a Pokémon arrive (see [ArrivalsNotifier]). Otherwise it shows
/// [child] as it is and does nothing.
///
/// The ball flies in, lands, and waits there until the Pokémon is ready
/// ([settled]: it has loaded, or has failed to). Then a flash fades the slot's
/// content in. So a slow load delays the reveal, and a failed one reveals the
/// error, never an endless ball. [child] is laid out the whole time, only
/// covered, so nothing jumps when it is revealed.
///
/// [coverColour] is the colour of the card behind [child], which the cover has
/// to match to be invisible. With the system's "reduce motion" setting on,
/// there is no animation and [child] simply shows.
///
/// The picture, which is the cover, the ball and the flash, is drawn over the
/// whole card, not only over [child]: [bleed] is how far the card reaches
/// beyond [child] on each side. (The card, not this widget, cuts it off at its
/// edge.) Covering all of the card matters: the card draws its hover colour on
/// its surface under the content, and a cover over only the content left that
/// colour showing round the edge while the ball was in flight.
class ThrowIn extends ConsumerStatefulWidget {
  const ThrowIn({
    required this.slot,
    required this.settled,
    required this.coverColour,
    required this.child,
    this.bleed = EdgeInsets.zero,
    super.key,
  });

  final int slot;
  final bool settled;
  final Color coverColour;
  final Widget child;
  final EdgeInsets bleed;

  @override
  ConsumerState<ThrowIn> createState() => _ThrowInState();
}

class _ThrowInState extends ConsumerState<ThrowIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _startTimer;

  // Whether this widget has yet looked for an arrival for its slot.
  var _checked = false;
  // Whether the ball has landed, and whether the reveal has begun.
  var _landed = false;
  var _revealing = false;

  @override
  void initState() {
    super.initState();
    // It starts at 1, the end: nothing to see. A throw, if there is one, winds
    // it back to the start.
    _controller = AnimationController(
      vsync: this,
      duration: throwFlightDuration + throwRevealDuration,
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first time only. (This is not in `initState`, because the system's
    // reduce-motion setting is read from the context.)
    if (_checked) return;
    _checked = true;

    final arrivals = ref.read(arrivalsProvider.notifier);
    final wait = ref.read(arrivalsProvider)[widget.slot];
    if (wait == null) return; // Not an arrival: show it as it is.

    // Used up, so a rebuild, or a change of layout that builds this slot again,
    // cannot play it a second time. Done after this frame, because providers
    // must not be changed while the widgets are being built.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => arrivals.consume(widget.slot),
    );

    if (MediaQuery.disableAnimationsOf(context)) return;

    _controller.value = 0;
    _startTimer = Timer(wait, _fly);
  }

  @override
  void didUpdateWidget(ThrowIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revealIfReady();
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _fly() {
    // `unawaited` says the result is deliberately not waited for.
    unawaited(
      _controller.animateTo(_landedAt, duration: throwFlightDuration).then((_) {
        _landed = true;
        _revealIfReady();
      }),
    );
  }

  /// The reveal rule: it begins once the ball has landed and the Pokémon is
  /// ready, whichever of the two comes last.
  void _revealIfReady() {
    if (!_landed || !widget.settled || _revealing) return;
    _revealing = true;
    unawaited(_controller.animateTo(1, duration: throwRevealDuration));
  }

  @override
  Widget build(BuildContext context) {
    // The picture sits on top of the content. `IgnorePointer` lets taps go
    // through to the content below (and, for a slot still loading, to the
    // remove button).
    return Stack(
      // The picture reaches outside this widget (by the bleed), so the stack
      // must not cut it off.
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: -widget.bleed.left,
          top: -widget.bleed.top,
          right: -widget.bleed.right,
          bottom: -widget.bleed.bottom,
          child: IgnorePointer(
            child: CustomPaint(
              key: const Key('throw-in-picture'),
              painter: _ThrowPainter(
                progress: _controller,
                coverColour: widget.coverColour,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws the cover, the ball and the flash for the point the animation has
/// reached.
class _ThrowPainter extends CustomPainter {
  // `repaint` makes Flutter call `paint` on every tick of the controller, with
  // no need to rebuild any widgets.
  _ThrowPainter({required this.progress, required this.coverColour})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color coverColour;

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value;
    if (value >= 1) return; // Finished: nothing to draw.

    // The two parts, each from 0 to 1: the flight, then the reveal.
    final flight = (value / _landedAt).clamp(0.0, 1.0);
    final reveal = ((value - _landedAt) / (1 - _landedAt)).clamp(0.0, 1.0);

    // The cover hides the whole card, content and surface, until the reveal is
    // under way. (The card's rounded corners cut it off, and its border and any
    // buttons on it are drawn above.)
    final coverOpacity = 1 - ((reveal - 0.3) / 0.7).clamp(0.0, 1.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = coverColour.withValues(alpha: coverOpacity),
    );

    // The ball. Until the flight begins it would be drawn out of sight, so it
    // is left out (and a slot waiting for its turn shows only the cover).
    if (flight > 0) {
      final t = Curves.easeOutCubic.transform(flight);
      // It spins as it flies and lands upright, then shrinks away as the slot
      // is revealed.
      final spin = (1 - t) * -4 * pi;
      final opening = 1 - (reveal * 2).clamp(0.0, 1.0);
      final radius = ballRadius(t, size) * opening;
      if (radius > 0) {
        paintBall(canvas, ballCentre(t, size), radius, rotation: spin);
      }
    }

    // The flash: a white glow that grows from the middle and fades. It never
    // grows past half the shorter side, so it has faded to nothing before it
    // reaches an edge. Where it was cut off by the edge, its outline showed.
    if (reveal > 0) {
      final centre = size.center(Offset.zero);
      final radius = size.shortestSide * (0.15 + 0.35 * reveal);
      final strength = sin(pi * reveal);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 255, 255, strength),
              const Color.fromRGBO(255, 255, 255, 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_ThrowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.coverColour != coverColour;
}
