# Pokémon Team Builder

A Flutter web app for building a team of up to six Pokémon and seeing where it is weak. Search the Pokédex, fill six slots, and a coverage matrix shows which of the 18 attacking types the team is exposed to, and says so in plain language. A second tab gives the team's average stats.

It runs on [PokeAPI](https://pokeapi.co) (free, keyless). A built-in control panel injects latency, failures and bad payloads on demand, so the resilience behaviour can be demonstrated rather than taken on trust.

## Run it

Requires Flutter 3.50 (stable) and Dart 3.14. Material comes from the separate `material_ui` package, which Flutter 3.50 introduced.

```sh
flutter pub get
flutter run -d chrome        # run the app
flutter test                 # whole suite, no network needed
flutter analyze              # must report no issues
```

To check persistence in a real browser, use a release build (see the manual test plan):

```sh
flutter build web
python -m http.server 8080 -d build/web
```

## Data source and product angle

**PokeAPI**, because it is stable, CORS-enabled and cacheable, and its list endpoint returns only names and URLs. Showing anything rich means a real request fan-out, which is where batching, limiting and caching earn their place. It rarely fails, so failures are simulated (see below).

**The angle** is analysis, not a list-and-detail Pokédex: the app answers "what is this team vulnerable to, and does anyone cover it?" Offence is not covered, because it would need move data. See [D1, D2](docs/decisions.md).

## How it works

Feature-first folders under `lib/features/`, with four layers. Dependencies point inwards, and `domain` is plain Dart (no Flutter, Riverpod or `data`).

```text
data  →  domain  →  state (Riverpod)  →  UI
```

The API client is hand-written (no client library) and built from decorators, each doing one job and tested alone:

```text
PackageHttpTransport → FaultInjectingTransport → HttpApiClient (5 s timeout)
  → RetryingApiClient (3 attempts, backoff + jitter) → ConcurrencyLimitedApiClient (6)
  → CachingApiClient (10 min TTL, stale-while-revalidate, de-duplicated)
```

- **Failures are values.** Expected problems never throw. Every call returns `Result<T>`, and `Err` carries a sealed `ApiFailure` (offline, timeout, rate-limited, server, not found, client, malformed). Exhaustive `switch`es force each consumer to handle each case. Failures are not cached, so "Try again" really asks again. (D11, D19)
- **Faults are injected at the transport,** so an injected 429 or truncated body goes through the same decoding, retry and cache code as a real one. (D12)
- **Defensive parsing.** Null sprites, missing stats and wrong-shaped JSON become typed failures or sensible defaults at one boundary, never exceptions in the UI. (D16)
- **State** is Riverpod (`Notifier`, `AsyncNotifier`, no code generation); the choice is argued in D5. Team analysis is derived state that recomputes as each member loads.
- **Persistence** is `shared_preferences` (`localStorage` on web) behind a `KeyValueStore` interface with an in-memory fake. Only the team and theme choice persist. Corrupt storage falls back to a clean state. (D7, D17)
- **Time and randomness are injected,** so retry delays and timeouts are tested with `fake_async`. (D13)

All wiring is in one place, `lib/app/providers.dart` (D14). The full decision log, with options considered, is [docs/decisions.md](docs/decisions.md). Plans are in [docs/plans/](docs/plans/).

## The control panel

The tune icon in the app bar ("Simulate problems") opens it. Levers: delay (0 to 5 s), failure rate, which failures may happen, how long a simulated 429 asks to wait, an offline switch, and "Back to normal". It also has a live retry log, and "Clear cache and reload" to make every request go out again. Levers are deliberately not saved, so a reload resets them. (D27)

| To see | Do this |
| --- | --- |
| Loading states | Delay 3 s, clear cache and reload |
| Retry and backoff | Failure rate 100% with "Server error", clear cache and reload. The log shows three attempts per request and the waits. |
| Failure UI | Same as above, once the retries are exhausted. Slots, search and the matrix each say what failed and offer "Try again". |
| Recovery | "Back to normal", then "Try again". Nothing bad was cached. |
| Bad payloads | "Cut-off response" or "Unexpected response" at 100%. These show as a malformed-response failure rather than a crash. |
| Incomplete analysis | Make one slot fail. The matrix says its picture may be incomplete rather than looking falsely safe. |

## Testing

Tests use fakes, not the network: an in-memory `KeyValueStore`, a fake transport and the fault-injecting client. `flutter test` runs everything offline.

- **Domain:** type-chart maths, team rules (including old saved formats), search ranking, matchup ordering, defences.
- **Data:** each decorator alone (retry timing to the millisecond with `fake_async`, limiter, cache, de-duplication, stale-while-revalidate), the parsers against trimmed real responses, and the repositories.
- **Widgets:** every state of each feature (loading, empty, error with retry, incomplete), drag and drop, screen-reader actions, the control panel, and the two animations (pumped through their durations: the throw-in's reveal waits for the ball and for the data and never replays, the flip shows the card then the dialog and back again, and reduced motion skips both).
- **Flow:** the whole app over the real networking stack and a fake network. Failures at 100%, three attempts each, the waits logged, the screen saying what failed, and recovery after going back to normal.
- **Live contract (opt-in):** `flutter test --run-skipped --tags live` asks the real PokeAPI for the index, two Pokémon and all 18 types, parses them with the app's own code, and compares each saved fixture's shape with the live response. It is skipped by default. A failure means the API changed, or had a bad moment; the message names the request. (D32)
- **Layout and accessibility:** overflow checks at 320 px wide and double text size, contrast checks for every type colour and matrix cell in both themes, and semantics checks.

Several tests were written to fail first, or checked to fail with the behaviour removed. Each of those is noted in the decision log. One of them found that the stat bars rendered at zero height, which a property check had missed (D28). A check that measures the rendered size now catches it.

## Manual test plan

Run with `flutter run -d chrome` unless stated.

| Area | Steps | Expect |
| --- | --- | --- |
| First run | Open the app | Six empty slots, an invitation in the matrix, a searchable list with pictures |
| Add and remove | Click a result. Click an empty slot, then a result. Click ✕. | First empty slot fills. The chosen slot fills. Only that slot empties. |
| Persistence | **Release build.** Add three Pokémon, choose dark, reload. Then clear site data and reload. | Team and theme survive the reload. After clearing, an empty team and system theme. |
| Coverage | Add Charizard | Rock shows 4×, with a sentence naming the gap |
| Team stats | Add two or three Pokémon, open the Stats tab, then resize across 900 px | A radar chart of the average stats, and each stat's average with who is highest and lowest. The tab stays on Stats. |
| Details flip | Click a card. Close it with ✕, Esc and a click outside. Move a Pokémon with the buttons, then close. | The card turns and the dialog comes round from the other side. The card leaves a gap that follows the Pokémon when it is moved, and the other cards update behind the dialog. Closing flips back into the card the Pokémon is in now. |
| Throw-in | Add a Pokémon. Reload with a saved team. Drag one into an empty slot. | A ball is thrown in and the slot is revealed. Saved slots throw one after another. Dragging throws nothing. |
| Reduced motion | DevTools → Rendering → emulate `prefers-reduced-motion: reduce`, then add a Pokémon | No ball: slots show their normal loading spinner, then the Pokémon. The details dialog fades instead of flipping. (The ball was checked by hand in Chrome; the fade was not.) |
| Failures | Control panel: 100% failures, clear cache and reload, then back to normal and "Try again" | See the table above |
| Real network | DevTools: Network → Slow 3G, then Offline | Visible rows load progressively. Placeholders instead of broken images. Already-loaded data still works offline. |
| Reordering | Hold a Pokémon about 0.3 s and drag onto another slot, then onto an empty one | Swap, then move. The state is saved. |
| Without a mouse | Tab to a card, Enter, then "Move earlier" / "Move later" | The Pokémon moves, and the slot number in the dialog follows |
| Layout | Widths of 320, 600 and 1000 px. Browser zoom to 200%. | Two or three slots across, search in a sheet below 900 px, nothing overflows |
| Themes | Light, dark and system. Reload. | No flash of the wrong theme |
| Screen reader | NVDA or VoiceOver over a slot, the matrix and the dialog | "Slot 2, Pikachu, Electric" with move actions. One sentence per matrix row and per stat. |

Not yet checked by hand on a physical touch screen or with a real screen reader.

## Known limitations

- **Not built:** a compare view (two Pokémon side by side). The team stats and the dialog's radar chart cover most of it.
- **The throw-in waits for the data.** With every request failing, a slot shows the resting ball for about 16 seconds before the error card. The remove button works meanwhile. (D29)
- **Defence only.** Offence needs move data (D2).
- **`Retry-After` is invisible to browsers** unless the server exposes it, and PokeAPI does not. Against the real API retries use plain backoff. The injected 429s do honour it. (D12)
- **The cache is in memory only.** A reload refetches, helped by the browser's own HTTP cache. A timed-out request keeps running in the background, and only its answer is ignored. (D15, D27)
- **Dragging** needs a short hold, does not auto-scroll the page near its edge, and swaps rather than shuffling the others along. (D21)
- **Screen readers** hear one sentence per matrix row, so which member is weak is not available to them. (D26)
- **Names:** hyphenated names such as `ho-oh` display as `Ho Oh` (D24). UI text is English only.
- **Not saved:** the control-panel levers, the matrix order and the chosen analysis tab.
- **Artwork** is the large official picture, scaled down on decode but fully downloaded. (D23)
- **Fixtures** are trimmed copies of real responses. The opt-in live test checks their shape, by hand and not in any scheduled run. It compares shapes, not values. (D32)

## With more time

- Running the live contract test on a schedule, so API drift shows up without anyone remembering to look.
- A compare view, reusing the radar chart.
- A browser-driven integration test for persistence and drag, which widget tests only simulate.
- Offence coverage from move data, and a Box (a larger collection the team is drawn from).
- Cancellable requests, and moving the cache to IndexedDB so it survives a reload.

## How AI tools were used

The code was written with Claude Code. Conventions it works to are in [AGENTS.md](AGENTS.md), and the plans and the decision log in [docs/](docs/) were written first and kept up to date, so the choices are the author's and recorded. Generated code was reviewed and walked through function by function, and tests were checked to fail when the behaviour they cover is removed.
