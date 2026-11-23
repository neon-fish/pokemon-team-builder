import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokemon_team_builder/app/failure_message.dart';
import 'package:pokemon_team_builder/data/http/fault_settings.dart';
import 'package:pokemon_team_builder/data/retrying_api_client.dart';
import 'package:pokemon_team_builder/features/control_panel/data_reloader.dart';
import 'package:pokemon_team_builder/features/control_panel/fault_settings_notifier.dart';
import 'package:pokemon_team_builder/features/control_panel/format_seconds.dart';
import 'package:pokemon_team_builder/features/control_panel/retry_log.dart';

/// The most the delay slider goes to, and the steps it moves in.
const _maxLatency = Duration(seconds: 5);
const _latencyStep = Duration(milliseconds: 250);

/// The most the "Retry-After" slider goes to, in whole seconds.
const _maxRetryAfterSeconds = 10;

/// The drawer that slides in from the right edge, holding the [ControlPanel].
/// On a narrow screen it leaves a strip of the page showing, so it is clear it
/// can be dismissed.
class ControlPanelDrawer extends StatelessWidget {
  const ControlPanelDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: min(380, screenWidth - 56),
      child: const SafeArea(child: ControlPanel()),
    );
  }
}

/// Levers for making the API misbehave, so the app's handling of slow, failing
/// and malformed responses can be seen on demand, and a log of the retries it
/// makes in response.
class ControlPanel extends ConsumerWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    // The title and close button stay put; everything below them scrolls.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Simulate problems', style: textTheme.titleLarge),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'Make the Pokémon API misbehave, to see how the app copes. '
                'Everything here goes back to normal when the page is '
                'reloaded.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const _Levers(),
              const Divider(height: 32),
              const _CacheSection(),
              const Divider(height: 32),
              const _RetryLog(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

/// The sliders, chips and switch that set the [FaultSettings].
class _Levers extends ConsumerWidget {
  const _Levers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(faultSettingsProvider);
    final notifier = ref.read(faultSettingsProvider.notifier);
    final rateLimitedChosen = settings.kinds.contains(FaultKind.rateLimited);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Slow responses'),
        Text(
          settings.latency == Duration.zero
              ? 'No extra delay'
              : 'Every request waits ${formatSeconds(settings.latency)} first',
        ),
        Slider(
          key: const Key('delay-slider'),
          value: settings.latency.inMilliseconds.toDouble(),
          max: _maxLatency.inMilliseconds.toDouble(),
          divisions: _maxLatency.inMilliseconds ~/ _latencyStep.inMilliseconds,
          label: formatSeconds(settings.latency),
          semanticFormatterCallback: (value) =>
              formatSeconds(Duration(milliseconds: value.round())),
          onChanged: (value) =>
              notifier.setLatency(Duration(milliseconds: value.round())),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('Failures'),
        Text(
          settings.failureRate == 0
              ? 'No requests fail'
              : '${(settings.failureRate * 100).round()}% of requests fail, '
                    'in one of the ways chosen below',
        ),
        Slider(
          key: const Key('failure-rate-slider'),
          value: settings.failureRate,
          divisions: 20,
          label: '${(settings.failureRate * 100).round()}%',
          semanticFormatterCallback: (value) => '${(value * 100).round()}%',
          onChanged: notifier.setFailureRate,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final kind in FaultKind.values)
              FilterChip(
                label: Text(_kindLabel(kind)),
                selected: settings.kinds.contains(kind),
                onSelected: (_) => notifier.toggleKind(kind),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          rateLimitedChosen
              ? 'A "too many requests" asks the app to wait '
                    '${formatSeconds(settings.retryAfter)}'
              : 'Choose "Too many requests" to set how long it asks the app '
                    'to wait',
        ),
        Slider(
          key: const Key('retry-after-slider'),
          value: settings.retryAfter.inSeconds.toDouble(),
          max: _maxRetryAfterSeconds.toDouble(),
          divisions: _maxRetryAfterSeconds,
          label: formatSeconds(settings.retryAfter),
          semanticFormatterCallback: (value) =>
              formatSeconds(Duration(seconds: value.round())),
          // Disabled while it would have no effect.
          onChanged: rateLimitedChosen
              ? (value) =>
                    notifier.setRetryAfter(Duration(seconds: value.round()))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Offline'),
          subtitle: const Text(
            'Every request fails, as if there were no connection.',
          ),
          value: settings.offline,
          onChanged: (value) => notifier.setOffline(offline: value),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: notifier.reset,
          child: const Text('Back to normal'),
        ),
      ],
    );
  }
}

String _kindLabel(FaultKind kind) => switch (kind) {
  FaultKind.serverError => 'Server error',
  FaultKind.rateLimited => 'Too many requests',
  FaultKind.timeout => 'No answer',
  FaultKind.offline => 'Connection lost',
  FaultKind.truncatedJson => 'Cut-off response',
  FaultKind.wrongShape => 'Unexpected response',
};

class _CacheSection extends ConsumerWidget {
  const _CacheSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Cache'),
        const SizedBox(height: 4),
        const Text(
          'Answers are remembered for a while, so they load instantly. Clear '
          'them to see the app ask the API again.',
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => ref.read(dataReloaderProvider).clearCacheAndReload(),
          icon: const Icon(Icons.refresh),
          label: const Text('Clear cache and reload'),
        ),
      ],
    );
  }
}

class _RetryLog extends ConsumerWidget {
  const _RetryLog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(retryLogProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Retry log')),
            TextButton(
              onPressed: log.isEmpty
                  ? null
                  : () => ref.read(retryLogProvider.notifier).clear(),
              child: const Text('Clear'),
            ),
          ],
        ),
        if (log.isEmpty)
          const Text(
            'Nothing yet. When a request fails in a way that might pass, the '
            'app waits and tries again, and it is noted here. Turn on some '
            'failures, then clear the cache and reload.',
          )
        else
          for (final event in log) _RetryTile(event),
      ],
    );
  }
}

class _RetryTile extends StatelessWidget {
  const _RetryTile(this.event);

  final RetryEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.url.path, style: theme.textTheme.labelLarge),
          Text(
            'Attempt ${event.failedAttempt} failed. '
            '${describeFailure(event.failure)} '
            'Trying again in ${formatSeconds(event.delay)}.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
