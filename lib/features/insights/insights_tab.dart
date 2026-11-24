import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The views of the team that share one panel.
enum InsightsTab { coverage, stats }

/// Which tab is showing. It lives here, not in the panel's own state, because
/// the panel is rebuilt from scratch when the window crosses the width at which
/// the layout changes, and the tab you were looking at should survive that.
/// (Not saved between visits, like the order of the coverage rows.)
class InsightsTabNotifier extends Notifier<InsightsTab> {
  @override
  InsightsTab build() => InsightsTab.coverage;

  void choose(InsightsTab tab) => state = tab;
}

final insightsTabProvider = NotifierProvider<InsightsTabNotifier, InsightsTab>(
  InsightsTabNotifier.new,
);
