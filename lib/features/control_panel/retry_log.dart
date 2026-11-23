import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/data/retrying_api_client.dart';

/// The most recent retries, newest first, for the control panel to show.
///
/// A retry happens when a request fails in a way that may pass (a server error,
/// a timeout, being offline), and the app waits and tries again. Seeing them
/// is how you can tell the resilience is working when you turn the levers up.
class RetryLogNotifier extends Notifier<List<RetryEvent>> {
  /// Older entries are dropped, so a long session does not grow without limit.
  static const maxEntries = 50;

  @override
  List<RetryEvent> build() => const [];

  void add(RetryEvent event) {
    state = [event, ...state].take(maxEntries).toList();
  }

  void clear() => state = const [];
}

final retryLogProvider = NotifierProvider<RetryLogNotifier, List<RetryEvent>>(
  RetryLogNotifier.new,
);
