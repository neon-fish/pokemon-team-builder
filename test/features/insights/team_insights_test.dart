import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/providers.dart';
import 'package:pokemon_team_builder/app/theme.dart';
import 'package:pokemon_team_builder/core/api_failure.dart';
import 'package:pokemon_team_builder/core/result.dart';
import 'package:pokemon_team_builder/features/coverage/coverage_matrix.dart';
import 'package:pokemon_team_builder/features/detail/radar_chart.dart';
import 'package:pokemon_team_builder/features/insights/insights_tab.dart';
import 'package:pokemon_team_builder/features/insights/team_insights.dart';
import 'package:pokemon_team_builder/features/team/team_notifier.dart';

import '../../support/fake_api_client.dart';
import '../../support/fixtures.dart';
import '../../support/in_memory_key_value_store.dart';

void main() {
  // Pikachu (25) and Koraidon (10264) load; every other Pokémon fails.
  const pikachu = 25;
  const koraidon = 10264;
  final chartResponses =
      loadFixture('type_chart_responses.json')! as Map<String, Object?>;

  late InMemoryKeyValueStore store;

  setUp(() => store = InMemoryKeyValueStore());

  Future<void> pumpInsights(
    WidgetTester tester, {
    String? saved,
    double width = 700,
  }) async {
    if (saved != null) store.data['team'] = saved;
    final api = FakeApiClient((url) {
      if (url.path.contains('/type/')) {
        return Ok(chartResponses[url.pathSegments.last]);
      }
      if (url.path.endsWith('/pokemon/$pikachu')) {
        return Ok(loadFixture('pokemon_pikachu.json'));
      }
      if (url.path.endsWith('/pokemon/$koraidon')) {
        return Ok(loadFixture('pokemon_koraidon_limited_build.json'));
      }
      return const Err(NotFoundFailure());
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          keyValueStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: width, child: const TeamInsights()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<InsightsTab>),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the tabs', () {
    testWidgets('open on coverage, the first and the headline', (tester) async {
      await pumpInsights(tester, saved: '{"ids":[25]}');

      expect(find.byType(CoverageMatrix), findsOneWidget);
      expect(find.byType(RadarChart), findsNothing);
    });

    testWidgets('Stats swaps the coverage for the stats, and back', (
      tester,
    ) async {
      await pumpInsights(tester, saved: '{"ids":[25]}');

      await chooseTab(tester, 'Stats');
      expect(find.byType(CoverageMatrix), findsNothing);
      expect(find.byType(RadarChart), findsOneWidget);

      await chooseTab(tester, 'Coverage');
      expect(find.byType(CoverageMatrix), findsOneWidget);
      expect(find.byType(RadarChart), findsNothing);
    });

    testWidgets('mark which one is showing', (tester) async {
      await pumpInsights(tester, saved: '{"ids":[25]}');

      bool selected() =>
          tester
              .widget<SegmentedButton<InsightsTab>>(
                find.byType(SegmentedButton<InsightsTab>),
              )
              .selected
              .single ==
          InsightsTab.stats;

      expect(selected(), isFalse);
      await chooseTab(tester, 'Stats');
      expect(selected(), isTrue);
    });

    testWidgets('keep the choice when the panel is rebuilt from scratch', (
      tester,
    ) async {
      // What happens when the window crosses the width where the layout
      // changes: the panel is thrown away and built again. The choice lives in
      // a provider, so it must come back as it was.
      await pumpInsights(tester, saved: '{"ids":[25]}');
      await chooseTab(tester, 'Stats');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeamInsights)),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            // A different shape above it, so the old panel is not reused.
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(1),
                  child: TeamInsights(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RadarChart), findsOneWidget);
    });

    testWidgets('fit a phone-sized width, with the segments filling it', (
      tester,
    ) async {
      await pumpInsights(tester, saved: '{"ids":[25,10264]}', width: 320);
      await chooseTab(tester, 'Stats');

      final control = tester.getRect(find.byType(SegmentedButton<InsightsTab>));
      expect(control.width, 320);
      expect(tester.takeException(), isNull);
    });
  });

  group('the stats tab', () {
    testWidgets('invites you to add someone when the team is empty', (
      tester,
    ) async {
      await pumpInsights(tester);
      await chooseTab(tester, 'Stats');

      expect(
        find.text('Add a Pokémon to see what your team is made of.'),
        findsOneWidget,
      );
      expect(find.byType(RadarChart), findsNothing);
    });

    testWidgets('shows the average of each stat, rounded', (tester) async {
      // Pikachu is 35, 55, 40, 50, 50, 90; Koraidon is 100, 135, 115, 85, 100,
      // 135. The averages are 67.5, 95, 77.5, 67.5, 75 and 112.5.
      await pumpInsights(tester, saved: '{"ids":[25,10264]}');
      await chooseTab(tester, 'Stats');

      Finder valueOf(String stat) => find.descendant(
        of: find.bySemanticsLabel(RegExp('^$stat: average')),
        matching: find.byType(Text),
      );
      // The row's number is the second text in it: name, then value.
      String shown(String stat) =>
          tester.widgetList<Text>(valueOf(stat)).elementAt(1).data!;

      expect(shown('HP'), '68');
      expect(shown('Attack'), '95');
      expect(shown('Defence'), '78');
      expect(shown('Sp. attack'), '68');
      expect(shown('Sp. defence'), '75');
      expect(shown('Speed'), '113');
      expect(find.bySemanticsLabel('Total: average 495'), findsOneWidget);
    });

    testWidgets('draws the radar chart from the rounded averages', (
      tester,
    ) async {
      await pumpInsights(tester, saved: '{"ids":[25,10264]}');
      await chooseTab(tester, 'Stats');

      final chart = tester.widget<RadarChart>(find.byType(RadarChart));

      expect(chart.labels, ['HP', 'Atk', 'Def', 'SpA', 'SpD', 'Spe']);
      expect(chart.values, [68, 95, 78, 68, 75, 113]);
    });

    testWidgets('says who is highest and lowest in each stat', (tester) async {
      await pumpInsights(tester, saved: '{"ids":[25,10264]}');
      await chooseTab(tester, 'Stats');

      expect(
        find.text('Highest: Koraidon Limited Build 135 · Lowest: Pikachu 55'),
        findsOneWidget, // Attack.
      );
      expect(
        find.text('Highest: Koraidon Limited Build 100 · Lowest: Pikachu 35'),
        findsOneWidget, // HP.
      );
    });

    testWidgets('a team of one has no highest or lowest to give', (
      tester,
    ) async {
      await pumpInsights(tester, saved: '{"ids":[25]}');
      await chooseTab(tester, 'Stats');

      expect(find.textContaining('Highest'), findsNothing);
      // Not even "all the same": with one member there is nothing to compare.
      expect(find.text('All the same'), findsNothing);
      expect(find.text('55'), findsWidgets);
    });

    testWidgets('a tie is "all the same", not one member named twice', (
      tester,
    ) async {
      await pumpInsights(tester, saved: '{"ids":[25,25]}');
      await chooseTab(tester, 'Stats');

      expect(find.text('All the same'), findsNWidgets(6));
      expect(find.textContaining('Highest'), findsNothing);
    });

    testWidgets('is spoken as one sentence a stat', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpInsights(tester, saved: '{"ids":[25,10264]}');
      await chooseTab(tester, 'Stats');

      expect(
        find.bySemanticsLabel(
          'Attack: average 95. Highest: Koraidon Limited Build 135 · '
          'Lowest: Pikachu 55',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('does not need the type chart', (tester) async {
      // The stats come from the Pokémon alone, so a failed chart must not hide
      // them.
      store.data['team'] = '{"ids":[25]}';
      final api = FakeApiClient((url) {
        if (url.path.endsWith('/pokemon/$pikachu')) {
          return Ok(loadFixture('pokemon_pikachu.json'));
        }
        return const Err(ServerFailure(503));
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            keyValueStoreProvider.overrideWithValue(store),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: TeamInsights())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await chooseTab(tester, 'Stats');

      expect(find.byType(RadarChart), findsOneWidget);
    });

    testWidgets('follows the team as it changes', (tester) async {
      await pumpInsights(tester, saved: '{"ids":[25]}');
      await chooseTab(tester, 'Stats');
      expect(find.bySemanticsLabel('Total: average 320'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TeamInsights)),
      );
      await container.read(teamProvider.notifier).add(koraidon);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Total: average 495'), findsOneWidget);
    });
  });

  group('when a member could not be included', () {
    testWidgets('both tabs say the picture may be incomplete', (tester) async {
      // Pokémon 7 fails to load.
      await pumpInsights(tester, saved: '{"ids":[25,7]}');
      const warning =
          '1 team member is still loading or could not be loaded, so this may '
          'be incomplete.';

      expect(find.text(warning), findsOneWidget);
      await chooseTab(tester, 'Stats');
      expect(find.text(warning), findsOneWidget);
      // And the stats are still shown, for the one that did load.
      expect(find.byType(RadarChart), findsOneWidget);
    });

    testWidgets('with nobody loaded, warns and shows no chart', (tester) async {
      await pumpInsights(tester, saved: '{"ids":[7]}');
      await chooseTab(tester, 'Stats');

      expect(find.textContaining('may be incomplete'), findsOneWidget);
      expect(find.byType(RadarChart), findsNothing);
      expect(find.textContaining('Add a Pokémon'), findsNothing);
    });

    testWidgets('no warning when everyone is included', (tester) async {
      await pumpInsights(tester, saved: '{"ids":[25]}');
      await chooseTab(tester, 'Stats');

      expect(find.textContaining('may be incomplete'), findsNothing);
    });
  });
}
