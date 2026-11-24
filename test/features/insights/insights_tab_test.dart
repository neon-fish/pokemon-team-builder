import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_team_builder/features/insights/insights_tab.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts on coverage', () {
    expect(container.read(insightsTabProvider), InsightsTab.coverage);
  });

  test('choosing a tab shows it, and choosing the other goes back', () {
    final notifier = container.read(insightsTabProvider.notifier);

    notifier.choose(InsightsTab.stats);
    expect(container.read(insightsTabProvider), InsightsTab.stats);

    notifier.choose(InsightsTab.coverage);
    expect(container.read(insightsTabProvider), InsightsTab.coverage);
  });
}
