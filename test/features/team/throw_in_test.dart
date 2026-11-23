import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/features/team/arrivals_notifier.dart';
import 'package:pokemon_team_builder/features/team/throw_in.dart';

/// An arrivals notifier that starts with some arrivals already in it.
class _SeededArrivals extends ArrivalsNotifier {
  _SeededArrivals(this._seed);

  final Map<int, Duration> _seed;

  @override
  Map<int, Duration> build() => _seed;
}

void main() {
  const cover = Color(0xFFEEEEEE);
  const slotSize = Size(200, 200);
  const frame = Duration(milliseconds: 16);

  late ValueNotifier<bool> settled;
  late ValueNotifier<bool> shown;

  setUp(() {
    settled = ValueNotifier(true);
    shown = ValueNotifier(true);
  });
  tearDown(() {
    settled.dispose();
    shown.dispose();
  });

  /// Shows a [ThrowIn] for slot 0. [arrivals] is what is waiting for the
  /// slots. [settled] says whether the Pokémon is ready, and [shown] whether
  /// the slot is on screen at all; they are notifiers so a test can change
  /// them, and so take the slot away and put it back.
  Future<ProviderContainer> pumpThrowIn(
    WidgetTester tester, {
    Map<int, Duration> arrivals = const {},
    bool reduceMotion = false,
    EdgeInsets bleed = EdgeInsets.zero,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arrivalsProvider.overrideWith(() => _SeededArrivals(arrivals)),
        ],
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox.fromSize(
                  size: slotSize,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([settled, shown]),
                    builder: (context, child) => shown.value
                        ? ThrowIn(
                            slot: 0,
                            settled: settled.value,
                            coverColour: cover,
                            bleed: bleed,
                            child: const Center(child: Text('Pikachu')),
                          )
                        : const SizedBox(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(ThrowIn)));
  }

  RenderObject picture(WidgetTester tester) =>
      tester.renderObject(find.byKey(const Key('throw-in-picture')));

  /// Whether anything is being drawn over the content.
  void expectNothingDrawn(WidgetTester tester) =>
      expect(picture(tester), paintsNothing);

  /// Whether the slot is covered, and whether the ball is on show.
  void expectCoveredWithBall(WidgetTester tester) {
    expect(
      picture(tester),
      paints
        ..rrect(color: cover)
        ..circle(),
    );
  }

  void expectCoveredWithoutBall(WidgetTester tester) {
    expect(picture(tester), paints..rrect(color: cover));
    expect(picture(tester), isNot(paints..circle()));
  }

  group('a slot that has not just had an arrival', () {
    testWidgets('shows its content as it is, with nothing over it', (
      tester,
    ) async {
      await pumpThrowIn(tester);
      await tester.pump(frame);

      expect(find.text('Pikachu'), findsOneWidget);
      expectNothingDrawn(tester);
    });
  });

  group('an arrival', () {
    testWidgets('is covered at once, then the ball flies in', (tester) async {
      await pumpThrowIn(tester, arrivals: {0: Duration.zero});

      // Covered from the very first frame, so the content never flashes.
      expectCoveredWithoutBall(tester);

      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 300));
      expectCoveredWithBall(tester);
    });

    testWidgets('is revealed after the flight and the reveal', (tester) async {
      await pumpThrowIn(tester, arrivals: {0: Duration.zero});
      await tester.pump(frame);

      // Still flying just before it lands...
      await tester.pump(throwFlightDuration - const Duration(milliseconds: 50));
      expectCoveredWithBall(tester);

      // ...and fully revealed once the reveal has also run its course.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(throwRevealDuration + frame);
      expectNothingDrawn(tester);
    });

    testWidgets('waits for its turn when it has a wait', (tester) async {
      await pumpThrowIn(tester, arrivals: {0: const Duration(seconds: 1)});

      await tester.pump(const Duration(milliseconds: 900));
      expectCoveredWithoutBall(tester);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      expectCoveredWithBall(tester);
    });

    testWidgets('does not move its content, or resize it', (tester) async {
      await pumpThrowIn(tester, arrivals: {0: Duration.zero});
      final before = tester.getRect(find.text('Pikachu'));

      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getRect(find.text('Pikachu')), before);

      await tester.pump(const Duration(seconds: 2));
      expect(tester.getRect(find.text('Pikachu')), before);
    });
  });

  group('the area it draws on', () {
    // As in a slot: the card reaches further above the content than to the
    // sides or below, to leave room for the remove button.
    const bleed = EdgeInsets.fromLTRB(12, 32, 12, 12);

    testWidgets('is the content plus the bleed, so the ball can use the card', (
      tester,
    ) async {
      await pumpThrowIn(tester, arrivals: {0: Duration.zero}, bleed: bleed);
      final content = tester.getRect(find.text('Pikachu').first);
      final stack = tester.getRect(find.byType(ThrowIn));

      final drawing = tester.getRect(find.byKey(const Key('throw-in-picture')));

      expect(drawing, bleed.inflateRect(stack));
      expect(drawing.size, greaterThan(content.size));
    });

    testWidgets('but the cover is only over the content', (tester) async {
      await pumpThrowIn(tester, arrivals: {0: Duration.zero}, bleed: bleed);
      await tester.pump(frame);

      final size = tester.getSize(find.byKey(const Key('throw-in-picture')));
      final contentArea = Rect.fromLTRB(
        bleed.left,
        bleed.top,
        size.width - bleed.right,
        size.height - bleed.bottom,
      );

      expect(
        picture(tester),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(contentArea, const Radius.circular(8)),
          color: cover,
        ),
      );
    });
  });

  group('the reveal rule', () {
    testWidgets('a Pokémon that is slow to load keeps the ball waiting', (
      tester,
    ) async {
      settled.value = false;
      await pumpThrowIn(tester, arrivals: {0: Duration.zero});
      await tester.pump(frame);

      // Runs everything that is scheduled: the flight, and the reveal too if it
      // were going to happen. With the ball waiting nothing is left to run.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Landed long ago, and still covered, with the ball sitting there.
      expectCoveredWithBall(tester);
    });

    testWidgets('and reveals it once it has loaded', (tester) async {
      settled.value = false;
      await pumpThrowIn(tester, arrivals: {0: Duration.zero});
      await tester.pumpAndSettle();
      expectCoveredWithBall(tester);

      settled.value = true;
      await tester.pumpAndSettle();

      expectNothingDrawn(tester);
    });

    testWidgets('one that loads while the ball is still flying waits for it', (
      tester,
    ) async {
      settled.value = false;
      await pumpThrowIn(tester, arrivals: {0: Duration.zero});
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 200));
      expectCoveredWithBall(tester);

      // Loaded with about 500 ms of the flight to go.
      settled.value = true;
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 300));
      // Still flying, and the cover is still whole, not yet fading.
      expectCoveredWithBall(tester);

      await tester.pumpAndSettle();
      expectNothingDrawn(tester);
    });

    testWidgets('a quick Pokémon still waits for the ball to land', (
      tester,
    ) async {
      settled.value = true; // Ready from the start.
      await pumpThrowIn(tester, arrivals: {0: Duration.zero});
      await tester.pump(frame);

      await tester.pump(throwFlightDuration ~/ 2);

      expectCoveredWithBall(tester);
    });
  });

  group('once it has played', () {
    testWidgets('it is used up, so it cannot play again', (tester) async {
      final container = await pumpThrowIn(
        tester,
        arrivals: {0: Duration.zero, 3: Duration.zero},
      );
      await tester.pump(frame);

      // Only this slot's entry is taken; the other slot's is left alone.
      expect(container.read(arrivalsProvider).keys, [3]);
    });

    testWidgets('a later change in readiness does not start it again', (
      tester,
    ) async {
      await pumpThrowIn(tester, arrivals: {0: Duration.zero});
      await tester.pumpAndSettle(); // Runs the whole throw to its end.
      expectNothingDrawn(tester);

      // For example, the user asks to try loading the Pokémon again.
      settled.value = false;
      await tester.pump(frame);
      settled.value = true;
      await tester.pumpAndSettle();

      expectNothingDrawn(tester);
    });

    testWidgets('a slot built again later, as in a new layout, shows at once', (
      tester,
    ) async {
      await pumpThrowIn(tester, arrivals: {0: Duration.zero});
      await tester.pump(frame);

      // Take the slot away and build it again, as a change of layout does,
      // while the first throw is still going on.
      shown.value = false;
      await tester.pump(frame);
      shown.value = true;
      await tester.pump(frame);

      expect(find.text('Pikachu'), findsOneWidget);
      expectNothingDrawn(tester);
    });
  });

  group('with reduced motion', () {
    testWidgets('shows the content at once, with no ball', (tester) async {
      await pumpThrowIn(
        tester,
        arrivals: {0: Duration.zero},
        reduceMotion: true,
      );
      await tester.pump(frame);

      expect(find.text('Pikachu'), findsOneWidget);
      expectNothingDrawn(tester);
    });

    testWidgets('still uses the arrival up', (tester) async {
      final container = await pumpThrowIn(
        tester,
        arrivals: {0: Duration.zero},
        reduceMotion: true,
      );
      await tester.pump(frame);

      expect(container.read(arrivalsProvider), isEmpty);
    });
  });

  testWidgets('leaves nothing running if it goes away while waiting', (
    tester,
  ) async {
    await pumpThrowIn(tester, arrivals: {0: const Duration(seconds: 30)});

    await tester.pumpWidget(const SizedBox());

    // A timer left behind would make the test fail when it ends.
  });
}
