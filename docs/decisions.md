# Decision log

One entry per significant decision: what we chose, what else we considered, and why. This feeds the README.

Format: **Decision**, **Options considered**, **Why**, **Trade-offs / revisit if**.

---

## D1. Data source: PokeAPI

- **Decision:** Use PokeAPI (`pokeapi.co/api/v2`) as the sole data source.
- **Options considered:** Several other free, keyless public APIs: UK Environment Agency flood monitoring, Open Food Facts, iNaturalist/GBIF, Carbon Intensity, Launch Library 2.
- **Why:**
  - Free, keyless, CDN-backed, stable schema, so effort goes into the client rather than fighting the API.
  - CORS verified: `access-control-allow-origin: *` on API responses, 404s and the sprite host.
  - Cacheable (`max-age=86400`, `ETag`), which supports a principled caching design.
  - The list endpoint returns only names and URLs, so showing rich data requires a real fan-out, which is a good place to demonstrate request batching, limiting and caching.
  - Messy-enough data (null sprites, form variants, multilingual text, nested relations) for defensive parsing to matter.
- **Trade-offs / revisit if:** It is a very common demo API, so the product angle (team coverage analysis) has to carry the originality. It has no real rate limiting or outages, so failures are simulated (see D6).

## D2. Product angle: team builder with coverage analysis

- **Decision:** An analytical dashboard that answers "where is this team weak?", rather than a Pokédex list.
- **Options considered:** Plain Pokédex browser; collection ("found") dashboard with breakdowns.
- **Why:** Gives the data a purpose, produces a natural comparison view, and keeps scope tight (search, team, analysis) while leaving room to go deep.
- **Trade-offs / revisit if:** Offensive coverage needs move data, which is out of scope for v1. v1 approximates it with STAB and states this limitation.

## D3. Camera / image recognition: not doing it

- **Decision:** Out of scope.
- **Why:** Needs an ML model or a keyed API (conflicts with the keyless rule); flaky on Flutter web; non-deterministic and hard to test meaningfully; does not demonstrate front-end Flutter skill; conflicts with "go deep, not wide".
- **Revisit if:** Never for this project. A silhouette guessing game is the cheap, testable alternative (stretch goal).

## D4. No client library for the API

- **Decision:** Hand-write the API client over a plain HTTP package.
- **Why:** Demonstrates proper integration: error mapping, retries, caching, defensive parsing. A wrapper package would hide exactly the parts being assessed.
- **Trade-offs:** More code to own and test.

## D5. State management: Riverpod

- **Decision:** Riverpod (`Notifier` / `AsyncNotifier`, no code generation).
- **Options considered:**
  - `ChangeNotifier` + `provider`: simpler and perfectly adequate at this size; async state, derived state and request races would be hand-rolled.
  - `ChangeNotifier` + `get_it`: `get_it` is a service locator, not state management. Dependencies become hidden and the registry is global state, which brings back the testability problem of a hard singleton.
  - Bloc: strong and common in larger teams; more ceremony (events, states) than this app needs.
  - Hard singleton: not substitutable in tests.
- **Why Riverpod:**
  - `AsyncValue` models loading / error / data directly.
  - Derived state fits the problem: team analysis depends on the team, each member's details and the type chart, each loading independently. Riverpod recomputes derived values when inputs change.
  - `autoDispose` and request scoping help with races (e.g. fast typing in search).
  - Tests override providers with fakes through a `ProviderContainer`, with no global state.
  - Widely used: currently the most downloaded Flutter state-management package on pub.dev, actively maintained, shares an author with `provider`.
- **Trade-offs / revisit if:** Steeper learning curve than `provider`. Mitigation: the data and domain layers are plain Dart with no state-management dependency, so the state layer is thin and replaceable.

## D6. Resilience demonstration: fault-injecting control panel

- **Decision:** Build an in-app control panel (levers for latency, failure rate, forced 429 with `Retry-After`, timeouts, malformed or truncated JSON, offline mode, cache clear), implemented as a decorator around the HTTP client.
- **Why:** PokeAPI is too reliable to exercise failure paths organically. A decorator keeps the app code free of special cases, and the same fault injector drives the UI levers and the automated tests.
- **Trade-offs:** Extra UI surface to build and test. Kept dev-facing and clearly separated from the product UI.

## D7. Persistence: `shared_preferences` behind a `KeyValueStore` interface

- **Decision:** Persist the team, type chart and index through a `KeyValueStore` interface, implemented with `shared_preferences`.
- **Options considered:** `package:web` `window.localStorage` directly; IndexedDB.
- **Why:**
  - On web, `shared_preferences` is a thin wrapper over `localStorage`, so there is no practical difference in capability.
  - Direct `localStorage` access only works in a browser, which would break plain Dart VM unit tests without conditional imports or an abstraction, and we want the abstraction anyway.
  - `shared_preferences` ships a test mock, and the interface allows an in-memory fake.
- **Trade-offs / revisit if:** `localStorage` is string-only, synchronous and limited to about 5 MB. IndexedDB would be the move if we persist large per-Pokémon caches (e.g. a full Box).

## D8. UI: Material as a base, heavily themed, with custom components

- **Decision:** Use Material (`material_ui` package) for structure (scaffold, text fields, dialogs, navigation); apply a custom colour scheme, typography and component themes; build signature components from primitives and `CustomPaint`.
- **Context:** The project targets Flutter 3.50, where Material is a separate official package (`material_ui`) decoupled from the core framework. It is the same code that was previously `package:flutter/material.dart`.
- **Options considered:** Fully custom UI on the core `widgets` layer.
- **Why:** A fully custom UI means rebuilding accessible text fields, focus and keyboard handling, tooltips and screen-reader semantics, which is costly and risky within the time box. Theming plus custom signature components gives a distinctive look without losing accessibility.
- **Trade-offs / revisit if:** Risk of looking like default Material; mitigated by theming and custom components.

## D9. Team first, Box later

- **Decision:** v1 ships the team (six slots, persisted). The Box ("found" collection) is a stretch goal.
- **Why:** Keeps v1 finishable to a high standard. The persistence layer stores IDs as a generic collection so the Box can be added without rework.

## D10. Flutter version

- **Decision:** Target Flutter 3.50 (Dart `^3.14.0`), as generated by the scaffold.
- **Action:** State the exact version in the README so the project can be run as intended.

## D11. Failures are values: a sealed `ApiFailure` inside a `Result`

- **Decision:** The API layer never throws for expected problems. It returns `Result<T>` (`Ok` or `Err`), and `Err` carries a sealed `ApiFailure` (offline, timeout, rate-limited, server, not found, client error, malformed response). Each failure says whether it is transient.
- **Options considered:**
  - Throw typed exceptions.
  - Return nullable values.
  - Use a functional-programming package that provides `Either` (a value that is either a `Left` failure or a `Right` success, plus helpers such as `map` and `flatMap`). `fpdart` is actively maintained but brings a large vocabulary (`Option`, `TaskEither` and so on). `dartz` is popular but unmaintained (last release December 2021). Small `Result`-only packages also exist.
- **Why:** Dart 3 sealed classes give exhaustive `switch`, so the compiler forces every consumer to handle every failure and flags any newly added one. Expected failures stop being invisible control flow. `Ok` and `Err` need no explanation, the type is about 25 lines, and no dependency is needed.
- **Revisit if:** we end up writing long chains of fetch, parse and combine steps, where a library's helpers would start to pay for themselves.
- **Trade-offs:** Slightly more ceremony than exceptions. Genuine bugs (programmer errors) still throw, deliberately.

## D12. Decorator stack, with faults injected at the transport level

- **Decision:** Behaviour is layered by wrapping one `ApiClient` in another: transport, fault injection, status and JSON handling, retry, concurrency limit (cache to follow). Each layer does one job and is tested alone.
- **Why fault injection sits at the transport:** an injected 429 or truncated body then passes through the same decoding, retry and caching code as a real one, so the control panel demonstrates real behaviour. It also means no special cases in app code, and the same injector serves the UI levers and the tests.
- **Retry policy:** only transient failures are retried; exponential backoff with "equal jitter" (half fixed, half random); `Retry-After` is honoured, but if the server asks for more than 30 seconds we give up rather than leave the user waiting.
- **Concurrency limit outside retry:** a request keeps its slot while backing off, which also eases pressure on a struggling server.
- **Known limitation:** browsers only expose `Retry-After` to scripts if the server lists it in `Access-Control-Expose-Headers`. PokeAPI does not, so against the real API the header is invisible and retries fall back to plain backoff. Only the "seconds" form of the header is parsed.

## D13. Time is injectable, so time-based code is tested without waiting

- **Decision:** Retry delays, timeouts and (to come) cache TTLs are tested with `fake_async`, and randomness (jitter, fault selection) is injected as a `Random`.
- **Why:** The suite stays fast and deterministic; exact timings can be asserted (for example, no second request at 499 ms and one at 500 ms).
- **Note:** `DateTime.now()` is not controlled by `fake_async`, so the cache takes a `now` function (see D15) rather than a clock package.

## D14. Composition root: `lib/app/providers.dart`

- **Decision:** All wiring of real implementations lives in one place. Features depend on interfaces such as `ApiClient`; tests override the provider with a fake.
- **Why:** One place to see how the app is assembled, and no global singletons.
- **Detail:** The fault injector reads its settings with `ref.read` on each request, so moving a lever changes behaviour live without rebuilding the stack.
- **Two override points:** widget tests that do not care about the network replace `apiClientProvider` with a fake `ApiClient`. Tests of the stack itself replace `httpTransportProvider` with a fake transport, so the real wiring (layer order, fault levers, retries) is exercised without the network.
- **Lifetime:** the stack is a single long-lived instance, because the limiter's queue and the future cache are state. The real transport is closed when its provider is disposed.
- **Fault injection is always in the stack.** With `FaultSettings.none` it is a pass-through. It is a deliberate feature (it makes resilience demonstrable), and the control panel UI is the part to gate behind a flag.

## D15. Cache: in memory, with stale-while-revalidate

- **Decision:** `CachingApiClient` is the outermost layer. It keeps successful responses in memory with a time-to-live (10 minutes), serves slightly older data instantly while refreshing in the background (up to 1 hour past the TTL), shares one network call between simultaneous requests for the same URL, and keeps at most 200 entries (oldest dropped first). Failures are never cached.
- **Options considered:**
  - Persist the cache in `KeyValueStore` (`localStorage`). Rejected for now: the limit is about 5 MB and a single Pokémon response is large, so it would fill up and then fail. The browser's own HTTP cache already honours PokeAPI's `max-age=86400`, so a reload is cheap anyway.
  - `package:clock` for time. Rejected: a plain `DateTime Function() now` constructor parameter does the same job with no dependency, and the cache tests only need to move time by hand.
- **Why:** The cache sits outside the concurrency limiter so a hit never takes a slot. Stale-while-revalidate means the UI is never blocked on a refresh, and a failed refresh quietly keeps the old data, which is also what makes the app usable during a brief outage.
- **Known limitations:**
  - Cached JSON maps are shared, so a caller that mutated one would change it for everyone. Repositories turn them into immutable models straight away.
  - Eviction is by age of storage, not by last use.
  - Nothing is remembered across a page reload. Small, valuable data (the team, perhaps the type chart) will be persisted by the repositories that own it.
  - `clear()` was added for the control panel (D27).
- **Amended (found with the control panel): a response the app cannot use is forgotten.** "Only successes are stored" was true at the HTTP level: a 200 with valid JSON counts as a success. But a response can be valid JSON and still the wrong shape, and that is only discovered later, when a repository parses it. The cache had already stored it, so "Try again" was handed the same bad answer from the cache, with no request made, and could not recover until the entry expired or the cache was cleared. Now `CachingApiClient` can `forget(url)` (the small `ResponseCache` interface), and the repositories call it through `parseResponse` when an answer arrived but failed to parse. Tests: each repository over a real cache (bad answer, then good), `parseResponse` itself, and the user's whole flow through the control panel. A client without a cache (the fakes) is simply unaffected.

## D16. Defensive parsing: small hand-written readers, one exception type, caught at the repository

- **Decision:** API JSON is read with small helpers in `lib/data/json_reader.dart` (`asJsonObject`, `asJsonList`, `asJsonString`). Each checks one expectation and throws a `FormatException` saying what was wrong. A repository catches that one exception type around its parsing and returns `Err(MalformedResponseFailure(...))`. The UI never sees the exception.
- **Options considered:** `json_serializable` / `freezed` (code generation, extra dependencies, and generated casts that throw unhelpful errors); parse functions that return `Result` at every step (more ceremony for no extra safety here).
- **Why:** Plain functions can be read and explained line by line. Throwing inside the parse step and catching at a single boundary keeps the parsing code short, while the public API of every repository still follows D11 (failures are values).
- **Forward compatibility:** values we do not model (for example the `stellar` type) are skipped rather than treated as errors, so a new entry in the API cannot break the app. A wrong *shape* (a missing list, a string where an object should be) is an error.
- **Fixtures:** `test/fixtures/` holds trimmed copies of real responses, loaded by `loadFixture`. A later opt-in live test can check they still match the real API.
- **Layering:** `PokemonType` and `TypeChart` live in `lib/domain` as plain Dart. The data layer knows about them, never the other way round.

### D16 addendum: the Pokémon detail

- **`parseResult`** (`lib/data/parse_result.dart`) is the single place a `FormatException` becomes a `MalformedResponseFailure`. It was written when the second repository needed the same step, which is the point at which the earlier "no `Result.map` until needed" rule said to add it.
- **Required vs cosmetic fields.** Id, name, types and stats are required: if one is missing or the wrong kind, the whole Pokémon is rejected. The picture is cosmetic: the official artwork is preferred, then the small sprite, else none, and a missing or odd `sprites` field never fails the Pokémon. Real data forced this: some form variants have artwork but no small sprite, and a few have neither.
- **Types.** Only current `types` are read (the API also returns `past_types` for older games). Unknown names are skipped; a Pokémon with no recognised type is rejected.
- **Fixtures** are trimmed real responses: Pikachu (single type), and two Koraidon forms (dual type; no picture; artwork only).

### D16 addendum: the search index

- **One request, 5,000 limit.** The real list is about 1,350 entries (about 90 KB) with no `next` page, so a single request suffices. The limit leaves roughly 3.7 times headroom. If the API ever outgrows it the list would be silently cut short; this is a known limitation.
- **Forms are included** (mega evolutions, regional forms, ids from 10001): they matter for team building. Names are shown as the API gives them for now.
- **Strict for the structure, lenient for single entries.** A response with no usable `results` is rejected. A single bad entry is skipped, because the entries are independent and one oddity should not take away search for everyone. The type chart is the opposite on purpose: every one of its 18 rows is needed.
- **The id comes from the URL** (`/pokemon/25/`) by a small regular expression that also checks the path, so a URL for something else is not mistaken for a Pokémon.

## D17. The team: persistence, state and what "a team" means

*Partly superseded by D20: the team is now six fixed slots that may be empty, so removal no longer shifts later members along. The rest of this entry (persistence, state, no lost updates) still stands.*

- **Team rules (domain).** Up to six slots, ordered. The same Pokémon may fill several slots, as in the games. (The first version refused duplicates on the grounds that they add nothing to a coverage analysis; that was reversed: stacking one weakness six times is exactly what the analysis should reveal, and a team of six identical Pokémon makes a good demonstration.) `Team` is immutable and holds ids only; details are loaded separately. `add` and `removeAt` return the same object when nothing changes, which lets the notifier skip a pointless save.
- **Removal is by slot position, not by id,** because an id can now appear more than once. The UI should key slots by position too, and cannot use "already in the team" to disable adding.
- **Storage.** `KeyValueStore` is a two-method interface (`read`, `write`), implemented by `SharedPreferencesKeyValueStore` (which on the web is `localStorage`). It uses the newer `SharedPreferencesAsync` API, so there is no instance to initialise at start-up. The cache stays in memory (D15); only the team is persisted, because it is small and it is the user's own data.
- **Best-effort persistence.** If storage is unavailable or its contents are unreadable, loading gives an empty team and saving does nothing, so the app still works for the session. The cost is that a user with blocked storage loses their team on reload without being told. The repository catches `Object` around the storage calls only (storage errors on the web are not reliably `Exception`s), and `FormatException` around decoding; programmer errors are not swallowed.
- **Saved data is re-validated.** The saved ids are rebuilt through `Team.add`, so a hand-edited or corrupted value cannot produce a seventh Pokémon. Values that are not integers are skipped.
- **State: `AsyncNotifier<Team>`.** It loads once, then every change is applied and saved. Consumers see `AsyncValue` (loading, then data). The alternative, loading before `runApp` and overriding a synchronous provider, would make the UI simpler, but spreads start-up wiring over two places.
- **No lost updates.** Each change waits for the load, then reads the state, computes the new team and assigns it with no `await` in between. Dart runs one piece of code at a time, so two quick changes cannot overwrite each other. A test covers two changes made before loading finishes.
- **Known limitation:** saves are not queued. Two saves in quick succession are issued in order, but if storage reordered them the older team could win. In practice `localStorage` writes are synchronous underneath, so this is theoretical.
- **New dev dependency:** `shared_preferences_platform_interface`, for its in-memory test platform, so the real `SharedPreferencesKeyValueStore` is tested with a genuine save and reload. It is already in the dependency tree (a dependency of `shared_preferences`); this only declares it, as the linter requires for a direct import.

## D18. Team analysis: defence only, counts not scores

- **Decision:** `analyseTeam(memberTypes, chart)` returns one `TypeMatchup` per attacking type (the standard 18, in a fixed order). Each holds the damage multiplier every member takes, in slot order, with counts of weak, resistant and immune members. A type is **exposed** when more members are weak to it than can resist or ignore it.
- **Dual types** combine by multiplying (2 x 2 = 4, 2 x 0.5 = 1, anything x 0 = 0). Every value is a power of two, so the arithmetic is exact and the code compares with `==` safely.
- **Input is types, not whole Pokémon.** The analysis needs nothing else, so it depends on nothing else; the state layer maps loaded Pokémon to their types. It is pure domain code with no Flutter, Riverpod or data imports.
- **Why "exposed" is a rule of thumb, stated as one:** it counts members, so a 4x weakness weighs the same as a 2x one, and it considers defence only. Offensive coverage needs move data, which is out of scope (D2). A more refined score is possible but would be harder to explain and to test, and the count is something a player can check by eye on the matrix.
- **Tested against the real chart.** `test/fixtures/type_chart_responses.json` holds trimmed copies of all 18 API responses, loaded through the real repository, so the expected answers (Charizard is 4x weak to rock, immune to ground, and neutral to ice because fire's resistance cancels flying's weakness) are independent of the code. A further test checks the real data contains exactly the eight known immunities.

## D19. Async state: failures are values inside `AsyncValue`

- **Decision:** Loader providers (`pokemonProvider`, `typeChartProvider`) have state `AsyncValue<Result<T>>`. `AsyncValue` answers "still loading?"; `Result` answers "finished, did it work?", with a typed `ApiFailure` on failure. `AsyncError` is left to mean a genuine bug.
- **Why not let the provider throw the failure?** Riverpod 3 retries any provider that throws an ordinary exception, by default up to 10 times with backoff from 200 ms to 6.4 s (checked in the source: `ProviderContainer.defaultRetry`). A failure thrown from a provider would be retried again on top of the API client's own retries (D12): a permanent 404 would be requested over and over, and a transient failure would take far longer to report. Keeping failures as values avoids hidden retries and keeps the one retry policy in one place. A test fails if the providers are changed to throw.
- **Retrying by hand** is `ref.invalidate(provider)`. Failures are never cached by the API client (D15), so this really does ask again.
- **Families:** `pokemonProvider(id)` is one provider per id, remembered, so a Pokémon shown in several places (or several times in a team) is loaded once.
- **Team analysis state** is a sealed `TeamAnalysisState`: `Loading`, `Unavailable(failure)` (the type chart failed) or `Ready(matchups, missingCount)`. Members that are still loading or failed are counted in `missingCount` and left out of the analysis, never silently ignored, because a team that looks safe may only be missing a member. Each slot shows its own loading or error state by watching its own `pokemonProvider(id)`.
- **Not built yet, on purpose:** a provider for the search index. It has no caller until the search UI exists.

## D20. The team is six fixed slots, and a slot may be empty

- **Decision:** `Team` holds exactly six slots, each an id or empty. `add` fills the first empty slot, `removeAt(i)` empties slot `i` and nothing else moves. The UI always shows six slots.
- **Options considered:** keep the compact list (removal shifts later members left) and make the UI cope; fixed slots with the list still compacting.
- **Why:** With a compact list, removing slot 2 changes what every later slot shows, so the UI cannot tell "a Pokémon was added" from "the slots shifted". That matters for the throw-in animation, for Hero tags and for reordering. A sparse list gives each slot a stable identity, so animations, drag targets and tags can all be keyed by slot position. Empty slots are always on screen, so they invite a click to add and give the throw a target.
- **Storage:** `{"ids":[25,null,6,null,null,null]}`. Loading is defensive: anything that is not a whole number becomes an empty slot and entries past six are dropped, so old compact saves (`[25,6]`) load as the first two slots, and a hand-edited value cannot give a seventh Pokémon.
- **Analysis:** skips empty slots. `missingCount` counts only members that are loading or failed.
- **Trade-offs:** team order is now meaningful and may have gaps (the first slot acts as the "lead"). `add` uses the first empty slot (for the search panel); `addAt(index, id)` fills a chosen empty slot (for the "add" button on an empty slot). `addAt` never overwrites: on a slot that is taken it does nothing, so a stray call cannot silently replace a Pokémon. There is deliberately no `replaceAt` yet (see below).
- **As built:**
  - `Team.slots` is a `List<int?>` that is always six long. `const Team()` is six empty slots; `Team.fromSlots(list)` pads a short list with empty slots and cuts a long one, so it is the single place that enforces the size (used by loading saved data). `memberIds` gives the filled slots' ids in order, for the analysis.
  - `add`, `removeAt` and `move(from, to)` return the same object when they change nothing, so the notifier skips the save. `move` is a plain exchange; moving to an empty slot is the same operation, because the other slot is empty. Swapping two empty slots, or two slots holding the same Pokémon, counts as no change.
  - Saved data is positional, so a value that is not a whole number leaves its own slot empty without shifting the others (the earlier version skipped such values and closed the gap).
  - The analysis iterates `memberIds`, so an empty slot is not counted as a missing member.
  - **No `replaceAt` yet.** Replacing a Pokémon in a slot is `removeAt` then `addAt`, which works but saves twice and briefly shows an empty slot. Nothing in the planned UI replaces in place, so the atomic version waits for its first real caller (for example choosing a different Pokémon for an occupied slot). If it is added it should be a separate, explicit overwrite, so `addAt` keeps its "never overwrites" guarantee.

## D21. Reordering swaps two slots; others do not shuffle along

- **Decision:** Dragging a card onto another slot exchanges the two (dropping on an empty slot moves the card). `Team.move(from, to)` is the domain rule. Built with `Draggable` and `DragTarget`, which start a drag only after a small movement.
- **Options considered:** insert-and-shift with the other cards animating out of the way (as `ReorderableListView` does).
- **Why:** Shuffling conflicts with fixed slots (D20) and is hard in a layout that changes between a row, a grid and a stack. Swapping is simple to explain, test and make accessible.
- **Accessibility:** dragging is not reachable by keyboard or screen reader, so cards expose "move earlier / later" semantics actions and the detail dialog has the same buttons.
- **Consequence for animation:** the throw plays on add and on loading the saved team, never because a slot became filled, or dragging into an empty slot would throw a ball. The state layer records which slots have just arrived. *This is built with the throw-in animation, not with reordering: there is no caller for it until then.*
- **Known limitation:** no shuffle-along animation.
- **As built (the drag):**
  - **Press and hold, then drag** (`LongPressDraggable`, 300 ms), not a plain `Draggable`. Checked in the SDK source: a plain drag starts once the pointer has moved past the "hit slop", which is 1 px for a mouse and 18 px for touch. So a slightly shaky click would drag instead of opening the details, and on a touch screen the drag would compete with scrolling the page. The delayed version rejects itself if the pointer moves before the time is up, which leaves the press to the click or the scroll. The default delay is 500 ms; that felt slow with a mouse. This replaces the plan's "starts after a small movement".
  - What is carried is the number of the slot it came from. Every slot is a `DragTarget`, so a drop calls `TeamNotifier.move(from, to)`, the same rule as before. Any filled slot can be picked up, including one that failed to load, so a bad slot can be moved as well as removed. Empty slots cannot be picked up. Dropping on its own slot or outside the slots does nothing.
  - While dragging: a small preview follows the pointer, the slot it came from stays in place at 35% opacity (so nothing jumps), and the slot under the pointer gets the primary-colour border.
  - A line under the team heading says how to do it, since a drag cannot be seen. It is always shown, so adding the first Pokémon does not move the layout.
- **As built (without dragging):**
  - Each filled slot offers "Move earlier" and "Move later" as screen-reader actions, and the details dialog has two buttons with the slot number between them (`MoveControls`). Both swap with the neighbouring slot, which is what dropping there would do, including moving into an empty slot. The first slot has no "earlier" and the last no "later".
  - **A bug the tests caught:** the actions were first put on a `Semantics` wrapped around the whole card. The semantics tree showed they landed on a separate node with no label that could not take focus, so a screen reader would never have offered them. They now sit inside the `InkWell`, where they join the focusable "Pikachu, Electric" item, and a test checks that they are on the same node as the label and the tap. The label also starts with "Slot 3", so the moves have something to be relative to.
  - In the dialog the buttons are at the top of the scrolling part, above the stats. They were first pinned at the bottom, outside the scrolling part, like the header; a layout test at 320 px wide, 480 px high and double text size then overflowed by 293 px, because the header and the pinned buttons together were taller than the dialog. Inside the scrolling part nothing can overflow, and at the top they are in view when it opens.
  - A keyboard user reaches the moves through the dialog: tab to the card, Enter, then tab to the buttons.
- **Known limitations:** the page does not scroll while a Pokémon is dragged near its edge (all six slots are normally on screen together, but a small window could need it). A press held for 300 ms without moving starts a drag, so it no longer opens the details; letting go on the same slot cancels it. Verified in widget tests, not by hand on a real touch screen.

## D22. UI direction: themes, animation and reduced motion

- **Themes:** light, dark and system (follows the browser), persisted through `KeyValueStore`. The saved choice is read before the first frame so there is no flash of the wrong theme. This is an exception to the "start-up loads inside a notifier" approach of D17, because the theme is needed for the first frame and the team is not.
- **Animation:** a drawn pokéball thrown into the slot, a flash, then the card is revealed once a minimum time has passed and the data has loaded; selecting a card flips and grows it into a detail dialog (`Hero` with a custom shuttle). All custom-painted with no image assets. Built after the control panel so the resilience demonstration is complete first.
- **Reduced motion:** when the system asks for less animation, the throw and flip are skipped; cards appear at once and the dialog fades.
- **Failure during a throw:** a failed load opens to an error card with a retry, never a stuck ball.
- **Fallback:** if the flip proves unreliable, the detail becomes a grow-and-fade dialog.
- See [plans/01-ui.md](plans/01-ui.md) for layout, build order and testing.

## D23. Search: filtered on the client, ranked, with rows that load their own details

- **Decision:** The whole index (D16) is held in memory and searched on every keystroke by a pure function, `searchPokemon`. The text is trimmed, lower-cased, and spaces become hyphens (so `Mr Mime` finds `mr-mime`). Best matches come first: names that *start with* the text, or a Pokémon whose number is exactly the text. Names that merely *contain* it follow. Within each group the order of the list is kept. Empty text gives everyone.
- **Why no debounce and no server search:** about 1,350 short strings is far too little work to wait for the user to stop typing, and PokeAPI has no search endpoint anyway.
- **Why partial numbers do not match:** typing `2` would otherwise match 2, 20 to 29, 200 to 299 and the 10000s, which is noise. Only an exact number matches.
- **State:** `pokemonIndexProvider` (failure is a value, as in D19), `searchQueryProvider` (the text), and `searchProvider`, a sealed `SearchState`: `Loading`, `Unavailable(failure)` or `Ready(matches, query)`.
- **Rows load their own details.** The index has only names and ids, so the picture and types need `pokemonProvider(id)`. Each row watches its own, and a scrolling list builds a row only when it comes into view, so only the visible rows (about a dozen) are requested, not 1,350. A test builds a 1,350-entry list and checks fewer than 30 detail requests are made; I confirmed it fails if the list is swapped for one that builds every row.
- **A row waits 150 ms before asking** (found by use, then measured). Building rows lazily was not enough: dragging the scroll bar sweeps the whole list past in a second, and a test that simulates that made 1,339 detail requests, each a response of about 350 KB of JSON (9 KB compressed) to decode, with no way to cancel them. The page stuttered, and the rows finally left on screen queued behind a thousand stale requests. Now a row starts a timer when it is built and cancels it if it leaves first, so rows only passing through ask for nothing (0 requests in the same test). A row whose provider already exists (scrolled away and back) shows at once. Both behaviours have tests, and each was checked to fail with the feature removed.
- **The loading placeholder is built from the badge itself** (`TypeBadgePlaceholder`: same shape, invisible text). `ListTile` positions its title and subtitle using the subtitle's text baseline, and a plain grey box has none, so the old placeholder made the title and subtitle jump about 2 to 4 px when the real badges arrived, although the row height stayed at 72. A test compares the row's positions before and after, and fails with the old placeholder.
- **A retry shows as loading.** After `ref.invalidate`, Riverpod keeps the previous result in `.value` while the new request runs, so a failed row would have kept saying "Details unavailable" with no sign of life. The row checks `isLoading` first. A test holds the second request open and looks at the screen meanwhile; it failed before the fix. The subtitle is a single `Wrap` in every state, which keeps the three states laid out the same way.
- **A row whose details fail** still shows its name and number, says "Details unavailable" and has its own retry button. One bad Pokémon does not spoil the list.
- **Known limitations:**
  - A request that has been made for a row that then scrolls out of view is not cancelled; it finishes and is cached (D15).
  - The pictures are the official artwork, which is much larger than a thumbnail. Decoding is scaled down to the size shown, but the download is not. If this proves slow on a real connection, the small sprite is the alternative for list rows.
  - Matches are not highlighted in the names.

## D24. Presentation conventions: colours, names and messages

- **Type colours** live in `lib/app/type_colours.dart`, not the domain (which has no colours). One `switch` with no default, so a new type cannot compile without a colour. They are the same in light and dark themes.
- **Text on a coloured badge** is black or white, whichever contrasts more, chosen by the colour's luminance (the switch-over point, 0.179, is where both give a ratio of about 4.58). A test checks all 18 types reach the 4.5 ratio of WCAG AA, using its own contrast formula rather than the app's rule.
- **Display names** (`mr-mime` becomes `Mr Mime`) are made by a small function in the UI layer. It is deliberately simple: names with a real hyphen come out as two words (`ho-oh` gives `Ho Oh`). The domain keeps the API's names, and search matches against those.
- **Failure messages** are one exhaustive `switch` over `ApiFailure` in `lib/app/failure_message.dart`. They say what happened in plain words and never show status codes or class names. Tests check each failure has its own, non-empty message.
- **Sprites** (`PokemonSprite`) always draw a faint placeholder icon underneath. The picture fades in over it; a missing or failed picture leaves the placeholder, never a broken-image box. The fade is skipped when the system asks for reduced motion.
- **UI text is inline English.** Translating it would mean Flutter's localisation system, which is out of scope. Known limitation.
- **The scratch screen is gone.** It existed to exercise the API stack by hand. The search list now does that for real (index, details, cache, retries), and the control panel will make the failures visible, so keeping it had no purpose.

## D25. The team screen: layouts, and how a slot is chosen

- **Two layouts, switched at 900 px** (`HomeScreen`, a `LayoutBuilder`). Wide: the search is a fixed 420 px column on the left, always showing, with the team on the right. Narrower: the team has the whole width and the search opens in a modal bottom sheet (nearly full height, field focused, clear of the keyboard). The same `SearchPanel` is used in both; the sheet only hosts it. The slots go two across below 520 px of available width and three across above it.
- **Choosing a slot.** Tapping an empty slot records it in `addTargetProvider`; the next pick goes there (`addAt`), and the choice is used up. Without a choice, a pick takes the first empty slot (`add`). This gives the slot's add button (D20) a meaning in both layouts: on a phone it opens the sheet for that slot; on a wide screen it marks the slot and the next click in the search fills it. `TeamNotifier.addPicked` makes the decision inside `_change`, so a slot that was filled in the meantime is not overwritten. A choice that is never used does not linger: closing the sheet forgets it.
- **Rows are disabled when the team is full**, and the panel says why. Picking the same Pokémon twice is allowed (D17).
- **Slot states:** empty (chosen or not), loading (spinner), failed (reason, retry, still removable), and filled. A slot watches only its own entry in the team (`select`), so a change elsewhere does not rebuild it. While the saved team is still loading, slots show as empty for a moment.
- **Slot height follows the content.** The first version used a grid with a fixed 208 px row height; at double text size a slot overflowed by up to 252 px. Rows are now `IntrinsicHeight` around a `Row` of slots, each at least 208 px. A `Table` with `intrinsicHeight` was tried first and does not work here: it lays each cell out a second time with a fixed height and does not notice later changes in size, so a slot that changed from a spinner to an error card stayed too short. Tests with a failing Pokémon at double size caught both versions.
- **Two searches can exist at once.** If the window is widened while the sheet is open, the sheet and the permanent panel share one query. Each box now follows the query (`ref.listen`), so the box and the results cannot disagree. Found by a test of exactly that sequence.
- **The sheet's cleanup uses the app's container, not a widget's `ref`.** It runs after the sheet closes, when the widget that opened it may have been replaced by a layout change, and Riverpod forbids using a `ref` after its widget has gone. Same test.
- **Found by testing:** the first version put "Add Pokémon" under the six slots, which on an 800 px-high phone put it at y = 828, below the fold. It is now above the team. A test checks it is on screen without scrolling.
- **Known limitations:**
  - **No chosen-slot clearing on wide screens:** once chosen, a slot stays chosen until a pick or another choice. There is no way to un-choose it.
  - **Large text** is handled but only tested at double size, on a phone, in the light and dark themes. Slots are at least 208 px tall and grow with their content.
  - **Picked Pokémon appear without animation** for now (step 7).

## D26. The coverage matrix

- **One row per attacking type, one cell per team slot.** Each cell shows the damage that slot's Pokémon takes (`4×`, `2×`, `½`, `¼`, `0`; normal damage is left blank). Red is a weakness (stronger red for 4×), green resists or ignores it, grey is normal. The multiplier is written in the cell, so colour is never the only signal. A last column counts the weak members.
- **The analysis keeps slot positions (a change to D18).** `analyseTeam` takes one entry per slot, and a slot with nothing to analyse (empty, still loading, or failed) is `null`, so every result lines up with its column in the team above. Nulls are left out of every count. Before this, empty slots were skipped, which would have shifted the cells left under the wrong Pokémon. `TeamAnalysisReady` also gained `analysedCount`.
- **Net exposure** is weak members minus members that resist or are immune. `isExposed` is now defined as net exposure above zero (the same rule as before, written differently).
- **Ordering** (`sortMatchups`, a pure function). "Standard order" is the game's order of the types. "Biggest gaps first" ranks by net exposure, then by number of weak members, then by standard order; the last rule is explicit because `List.sort` is not guaranteed stable. A menu on the "Type" heading chooses between them. The default is biggest gaps first, since it answers the question the app exists for. A known cost: rows move as the team changes. The choice is kept in memory only (not saved).
- **Plain-language sentences** (`describeExposure`) appear under the types the team is exposed to, and only those: "3 of 6 are weak to Ground and nobody resists it." or "3 of 6 are weak to Fire, but only 1 resists or ignores it." The counts are of the members analysed.
- **Every state is shown.** Empty team (an invitation to add someone, not 18 blank rows), loading, type chart unavailable (reason and retry), and **incomplete**: when any member is loading or failed, a notice says so, because a team that looks safe may only be missing a member. If nobody could be analysed, the notice shows without the rows.
- **Screen readers** get one sentence per row ("Ground: 1 weak, 0 resist, 0 immune. 1 of 1 is weak to Ground and nobody resists it.") instead of 108 cells of symbols. The consequence is that which member is weak is not available to a screen reader. Known limitation.
- **Large text:** cells, the type badge and the "Type" heading scale their text down to fit instead of growing, so rows keep their height. Tested at double size at phone width.
- **Colours:** red comes from the theme (`error`, `errorContainer`). Material has no "good" colour, so the greens are chosen (pale with dark text in light, the reverse in dark). A test checks every cell, in both themes, reaches the 4.5 contrast ratio.
- **Known limitations:**
  - The order choice is not saved.
  - Rows are not animated when they move.
  - Offence is not shown (that would need move data; see the overview).

## D27. The control panel, the retry log and the five-second timeout

- **An end drawer, from an app-bar icon.** It slides in from the right edge (up to 380 px wide, narrower on a phone so a strip of the page shows and tapping it closes the panel). It works at every width, never takes permanent space and can be opened mid-demo. The icon is a plain "tune" button with the tooltip "Simulate problems". The title and close button are pinned; everything under them scrolls.
- **The levers** are the ones `FaultSettings` already had: delay (0 to 5 s), failure rate (0 to 100%), which failures may happen (chips), how long a simulated 429 asks to wait, and an offline switch, plus "Back to normal". The wait slider is disabled unless "Too many requests" is chosen, since it would do nothing. At least one kind of failure always stays chosen: with none, the injector injects nothing, and a failure rate would silently have no effect.
- **Not saved.** A reload puts every lever back to normal, so one left on cannot make the next visit look broken. The README's manual test plan should say so.
- **The retry log.** The retry layer already had an `onRetry` hook; the composition root now feeds it into `retryLogProvider`, which keeps the latest 50 events, newest first. The panel shows each as the request, the attempt that failed, the reason, and how long the app will wait. It shows only waits before a retry, not the final failure (that appears where the data was needed) and not cache hits.
- **"Clear cache and reload".** Clearing the cache alone would show nothing, since providers already hold their data. So `DataReloader` clears the cache and invalidates the index, every Pokémon and the type chart, and everything on screen asks again. The cache is its own provider (`apiCacheProvider`) so the panel can reach `clear()`; `apiClientProvider` is the same object under its general name, which is what tests replace with fakes. Requests already under way are not stopped by a clear and may store their answer when they finish.
- **The timeout is now five seconds (was ten).** With three attempts and the backoff, a request that never answers is given up on after about 16.5 seconds, not about 31. Longer was a poor fit for a live demonstration of the timeout failure, and PokéAPI normally answers in well under a second. Not chosen: retrying a timeout once only (about 20 s, and needs failure-specific limits in the retry policy); both (about 10.5 s, more code).
- **Tested end to end.** A test runs the whole app over the real networking stack and a fake network: failures at 100%, "Clear cache and reload", then it checks that each request was tried three times, both waits are logged, the team slot and the coverage matrix say what failed and offer a retry, and that going back to normal and retrying recovers. A second checks a two-second delay is waited for with no retries at all.
- **Known limitations:**
  - No cache hit or stale-refresh events in the log.
  - The log has no timestamps, only order.
  - A timed-out request carries on in the background (Dart cannot cancel it); only its answer is ignored (D12).

## D28. The detail dialog and the radar chart

- **Opening.** Tapping a Pokémon that has loaded opens a dialog about it. A slot that is loading, or failed, does nothing when tapped (a failed one has its own "Try again"). The remove button sits inside the tappable card and takes its own taps, so removing never opens the dialog. This is the plain dialog; the flip transition (D22) is built later, with the other animations, and replaces only how the dialog appears.
- **What it holds:** picture, name, number and types; the six base stats as a radar chart and as bars with a total; and what the Pokémon is weak to, resists and is immune to, sorted into those three groups with the multiplier beside each type. When opened from a team slot it also has the move earlier / later buttons (D21).
- **The type matchups are the team analysis applied to a team of one** (`defencesOf` calls `analyseTeam`), so a dual-typed Pokémon's multipliers combine in exactly one place. It needs the type chart, so the dialog shows a spinner while that loads and, if it fails, says so with a "Try again". The rest of the dialog does not wait for it.
- **The radar chart is custom-painted.** The geometry (`axisDirection`, `radarPoints`, `statFraction`) is plain functions with their own tests, apart from the drawing. The painter measures its labels first and gives the chart whatever room is left, so larger text shrinks the chart rather than overlapping it. The first axis points straight up and the rest follow clockwise. Colours come from the theme.
- **One fixed scale, 0 to 200,** for the chart and the bars, so two Pokémon can be compared by eye. A few stats are higher (Blissey's HP is 255) and are drawn at the edge; the bars give the exact number. A scale fitted to each Pokémon was rejected because it would make every shape look similar.
- **Screen readers.** The radar chart is a picture of numbers that are also given as text, so it is hidden from them rather than read twice. Each bar row is one sentence ("Attack: 55"), and each weakness is one item ("Rock, 4×"). Which type each multiplier belongs to is therefore still available to a screen reader, unlike the coverage matrix (D26).
- **Layout.** Chart and bars sit side by side from 480 px of content, one above the other below that. The name sits beside the picture from 420 px, below it narrower: beside the picture and close button it got so little width on a phone with large text that "Charizard" broke mid-word. Found by a test at 320 px wide and double text size. The header does not scroll, so the close button is always in reach.
- **Known limitations:**
  - Stats above 200 are drawn at the edge.
  - The sort of ties in the weakness groups is explicit, but the test cannot prove it: a short list happens to stay in order whether or not the tie-break is there.
  - The radar chart's `shouldRepaint` is not tested directly; the tests check that a new shape reaches the picture.
