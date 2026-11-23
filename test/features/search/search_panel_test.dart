import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/data/api_client.dart';
import 'package:pokemon_team_builder/features/pokemon/type_badge.dart';
import 'package:pokemon_team_builder/features/search/search_panel.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';

/// An [ApiClient] that lists one Pokémon (Pikachu) and holds back each request
/// for its details until the test answers it, so a test can look at the screen
/// while a request is still in flight.
class _HeldApiClient implements ApiClient {
  /// One per details request made so far, in order.
  final pending = <Completer<Result<Object?>>>[];

  @override
  Future<Result<Object?>> getJson(Uri url) {
    if (url.path.endsWith('/pokemon')) {
      return Future.value(
        const Ok({
          'results': [
            {'name': 'pikachu', 'url': 'https://pokeapi.co/api/v2/pokemon/25/'},
          ],
        }),
      );
    }
    final answer = Completer<Result<Object?>>();
    pending.add(answer);
    return answer.future;
  }
}

void main() {
  // What the fake API does, changed by tests to simulate trouble.
  var indexFails = false;
  late FakeApiClient api;

  setUp(() {
    indexFails = false;
    api = FakeApiClient((url) {
      if (url.path.endsWith('/pokemon')) {
        return indexFails
            ? const Err(OfflineFailure())
            : Ok(loadFixture('pokemon_index.json'));
      }
      // Only Pikachu has details; every other Pokémon fails to load.
      if (url.path.endsWith('/pokemon/25')) {
        return Ok(loadFixture('pokemon_pikachu.json'));
      }
      return const Err(NotFoundFailure());
    });
  });

  Future<void> pumpPanel(WidgetTester tester, [ApiClient? client]) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client ?? api)],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const Scaffold(body: SearchPanel()),
        ),
      ),
    );
  }

  /// Waits out the short pause rows make before asking for their details, then
  /// lets the requests finish.
  Future<void> settleWithDetails(WidgetTester tester) async {
    // First let the list itself appear, as that is when the rows are built.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  Future<void> typeIntoSearch(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  /// The row showing the Pokémon displayed as [name].
  Finder rowFor(String name) => find.widgetWithText(ListTile, name);

  /// [what], but only if it is inside the row for [name].
  Finder inRow(String name, Finder what) =>
      find.descendant(of: rowFor(name), matching: what);

  /// The requests made for one Pokémon's details.
  Iterable<Uri> detailRequests(FakeApiClient client) =>
      client.calls.where((url) => RegExp(r'/pokemon/\d+$').hasMatch(url.path));

  testWidgets('shows a spinner until the list arrives', (tester) async {
    await pumpPanel(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('lists the Pokémon with tidied names and their numbers', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.pumpAndSettle();

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('Pikachu'), findsOneWidget);
    expect(find.text('Pikachu Rock Star'), findsOneWidget);
    expect(find.text('Baxcalibur Mega'), findsOneWidget);
    expect(find.text('#25'), findsOneWidget);
    expect(find.text('#10080'), findsOneWidget);
  });

  testWidgets('typing narrows the list', (tester) async {
    await pumpPanel(tester);
    await tester.pumpAndSettle();

    await typeIntoSearch(tester, 'rock star');

    expect(find.text('Pikachu Rock Star'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsNothing);
    expect(find.text('Pikachu'), findsNothing);
  });

  testWidgets('a number finds that Pokémon', (tester) async {
    await pumpPanel(tester);
    await tester.pumpAndSettle();

    await typeIntoSearch(tester, '25');

    expect(find.text('Pikachu'), findsOneWidget);
    expect(find.text('Pikachu Rock Star'), findsNothing);
  });

  testWidgets('says so when nothing matches', (tester) async {
    await pumpPanel(tester);
    await tester.pumpAndSettle();

    await typeIntoSearch(tester, 'zzz');

    expect(find.text('No Pokémon match “zzz”.'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsNothing);
  });

  testWidgets('the clear button empties the field and shows everyone', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.pumpAndSettle();
    await typeIntoSearch(tester, 'zzz');

    await tester.tap(find.byTooltip('Clear the search'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.byTooltip('Clear the search'), findsNothing);
  });

  group('each row', () {
    testWidgets('shows its types once the details have loaded', (tester) async {
      await pumpPanel(tester);
      await settleWithDetails(tester);

      expect(inRow('Pikachu', find.text('Electric')), findsOneWidget);
    });

    testWidgets('does not move its content when the details arrive', (
      tester,
    ) async {
      await pumpPanel(tester);
      // The list is there, but the rows have not yet asked for their details.
      await tester.pump();
      await tester.pump();

      // The first row is Bulbasaur, whose details fail; Pikachu's succeed. Use
      // Pikachu's row, so the subtitle is the placeholder and then the badge.
      Rect rowPart(Finder part) => tester.getRect(part);
      final row = find.widgetWithText(ListTile, 'Pikachu');
      final placeholder = find.descendant(
        of: row,
        matching: find.byType(TypeBadgePlaceholder),
      );
      final title = find.descendant(of: row, matching: find.text('Pikachu'));
      final rowBefore = rowPart(row);
      final titleBefore = rowPart(title).top - rowBefore.top;
      final subtitleBefore = rowPart(placeholder);
      expect(placeholder, findsOneWidget);
      // It is the size of a badge, not stretched across the row.
      expect(subtitleBefore.width, lessThan(rowBefore.width / 4));

      await settleWithDetails(tester);

      final badge = find.descendant(of: row, matching: find.byType(TypeBadge));
      expect(badge, findsOneWidget);
      final rowAfter = rowPart(row);
      expect(rowAfter.height, rowBefore.height, reason: 'row height');
      expect(rowPart(title).top - rowAfter.top, titleBefore, reason: 'title');
      expect(
        rowPart(badge).top - rowAfter.top,
        subtitleBefore.top - rowBefore.top,
        reason: 'top of the badge',
      );
      expect(rowPart(badge).height, subtitleBefore.height, reason: 'badge');
    });

    testWidgets('shows it is loading again while a retry is in flight', (
      tester,
    ) async {
      final held = _HeldApiClient();
      await pumpPanel(tester, held);
      await settleWithDetails(tester);
      held.pending.single.complete(const Err(NotFoundFailure()));
      await tester.pumpAndSettle();
      expect(find.text('Details unavailable'), findsOneWidget);

      await tester.tap(find.byTooltip('Try loading the details again'));
      await tester.pump();

      // The second request has not been answered yet.
      expect(held.pending, hasLength(2));
      expect(find.text('Details unavailable'), findsNothing);
      expect(find.byType(TypeBadgePlaceholder), findsOneWidget);

      held.pending.last.complete(Ok(loadFixture('pokemon_pikachu.json')));
      await tester.pumpAndSettle();
      expect(inRow('Pikachu', find.text('Electric')), findsOneWidget);
    });

    testWidgets('says so when its details cannot be loaded', (tester) async {
      await pumpPanel(tester);
      await settleWithDetails(tester);

      // Pikachu has details; Bulbasaur does not.
      expect(inRow('Bulbasaur', find.text('Details unavailable')), findsOne);
      expect(inRow('Pikachu', find.text('Details unavailable')), findsNothing);
    });

    testWidgets('can ask for its details again', (tester) async {
      await pumpPanel(tester);
      await settleWithDetails(tester);
      final before = api.calls.where((u) => u.path.endsWith('/pokemon/1'));
      expect(before, hasLength(1));

      // The first row is Bulbasaur (number 1).
      await tester.tap(find.byTooltip('Try loading the details again').first);
      await settleWithDetails(tester);

      final after = api.calls.where((u) => u.path.endsWith('/pokemon/1'));
      expect(after, hasLength(2));
    });
  });

  group('with a long list', () {
    // 1,350 rows, as in the real index. Every Pokémon's details are Pikachu's.
    late FakeApiClient big;

    setUp(() {
      big = FakeApiClient((url) {
        if (url.path.endsWith('/pokemon')) {
          return Ok({
            'results': [
              for (var i = 1; i <= 1350; i++)
                {
                  'name': 'pokemon-$i',
                  'url': 'https://pokeapi.co/api/v2/pokemon/$i/',
                },
            ],
          });
        }
        return Ok(loadFixture('pokemon_pikachu.json'));
      });
    });

    /// Where the list is scrolled to. Jumping moves it in one go, as dragging
    /// the scroll bar does, rather than flicking it with momentum.
    ScrollPosition listPosition(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    testWidgets('only the rows on screen load their details', (tester) async {
      await pumpPanel(tester, big);
      await settleWithDetails(tester);

      final requested = detailRequests(big).length;
      expect(requested, greaterThan(0));
      expect(requested, lessThan(30), reason: 'not all 1,350');
      expect(find.text('Pokemon 1350'), findsNothing);
    });

    testWidgets('rows only passing through do not load their details', (
      tester,
    ) async {
      await pumpPanel(tester, big);
      await settleWithDetails(tester);
      final before = detailRequests(big).length;

      // Drag the scroll bar from top to bottom in about a second.
      final position = listPosition(tester);
      for (var frame = 1; frame <= 60; frame++) {
        position.jumpTo(position.maxScrollExtent * frame / 60);
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(detailRequests(big).length, before, reason: 'none for the sweep');

      // Stopping on a row is different: it does ask, once the pause is over.
      await settleWithDetails(tester);
      expect(detailRequests(big).length, greaterThan(before));
      // The last row is on screen now, and has its types.
      expect(inRow('Pokemon 1350', find.text('Electric')), findsOneWidget);
    });

    testWidgets('a row that was loaded shows at once when scrolled back to', (
      tester,
    ) async {
      await pumpPanel(tester, big);
      await settleWithDetails(tester);
      expect(inRow('Pokemon 1', find.text('Electric')), findsOneWidget);

      final position = listPosition(tester);
      position.jumpTo(50000);
      await tester.pump();
      position.jumpTo(0);
      // One frame, with no pause and no waiting for a response.
      await tester.pump();

      expect(inRow('Pokemon 1', find.text('Electric')), findsOneWidget);
    });
  });

  group('when the list cannot be loaded', () {
    testWidgets('says why, and offers to try again', (tester) async {
      indexFails = true;
      await pumpPanel(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('The list of Pokémon could not be loaded.'),
        findsOneWidget,
      );
      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('trying again shows the list once it works', (tester) async {
      indexFails = true;
      await pumpPanel(tester);
      await tester.pumpAndSettle();

      indexFails = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Bulbasaur'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });
}
