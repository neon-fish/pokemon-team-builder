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
- **Why:** gives the data a purpose and keeps scope tight (search, team, analysis) while leaving room to go deep.
- **Trade-offs / revisit if:** Offensive coverage needs move data, which is out of scope for v1. v1 covers defence only and states this limitation. (An approximation from a Pokémon's own types, STAB, was considered and not built.)

## D3. Camera / image recognition: not doing it

- **Decision:** Out of scope.
- **Why:** Needs an ML model or a keyed API (conflicts with the keyless rule); flaky on Flutter web; non-deterministic and hard to test meaningfully; does not demonstrate front-end Flutter skill; conflicts with keeping the scope tight.
- **Revisit if:** Never for this project. A silhouette guessing game is the cheap, testable alternative (stretch goal).

## D4. No client library for the API

- **Decision:** Hand-write the API client over a plain HTTP package.
- **Why:** Demonstrates proper integration: error mapping, retries, caching, defensive parsing. A wrapper package would hide exactly the parts worth showing.
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
- **Trade-offs / revisit if:** Steeper learning curve than `provider`. Mitigation: the data and domain layers are plain Dart with no state-management dependency, so the state layer is thin and replaceable.

## D6. Resilience demonstration: fault-injecting control panel

- **Decision:** Build an in-app control panel (levers for latency, failure rate, forced 429 with `Retry-After`, timeouts, malformed or truncated JSON, offline mode, cache clear), implemented as a decorator around the HTTP client.
- **Why:** PokeAPI is too reliable to exercise failure paths organically. A decorator keeps the app code free of special cases, and the same fault injector drives the UI levers and the automated tests.
- **Trade-offs:** Extra UI surface to build and test. Kept dev-facing and clearly separated from the product UI.

## D7. Persistence: `shared_preferences` behind a `KeyValueStore` interface

- **Decision:** persist the team (and the theme choice, D22) through a `KeyValueStore` interface, implemented with `shared_preferences`. The type chart and index are refetched each visit (D15).
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

- **Decision:** Behaviour is layered by wrapping one `ApiClient` in another: transport, fault injection, status and JSON handling, retry, concurrency limit, cache. Each layer does one job and is tested alone.
- **Why fault injection sits at the transport:** an injected 429 or truncated body then passes through the same decoding, retry and caching code as a real one, so the control panel demonstrates real behaviour. It also means no special cases in app code, and the same injector serves the UI levers and the tests.
- **Retry policy:** only transient failures are retried; exponential backoff with "equal jitter" (half fixed, half random); `Retry-After` is honoured, but if the server asks for more than 30 seconds we give up rather than leave the user waiting.
- **Concurrency limit outside retry:** a request keeps its slot while backing off, which also eases pressure on a struggling server.
- **Known limitation:** browsers only expose `Retry-After` to scripts if the server lists it in `Access-Control-Expose-Headers`. PokeAPI does not, so against the real API the header is invisible and retries fall back to plain backoff. Only the "seconds" form of the header is parsed.

## D13. Time is injectable, so time-based code is tested without waiting

- **Decision:** Retry delays, timeouts and cache TTLs are tested with `fake_async`, and randomness (jitter, fault selection) is injected as a `Random`.
- **Why:** The suite stays fast and deterministic; exact timings can be asserted (for example, no second request at 499 ms and one at 500 ms).
- **Note:** `DateTime.now()` is not controlled by `fake_async`, so the cache takes a `now` function (D15).

## D14. Composition root: `lib/app/providers.dart`

- **Decision:** All wiring of real implementations lives in one place. Features depend on interfaces such as `ApiClient`; tests override the provider with a fake.
- **Why:** One place to see how the app is assembled, and no global singletons.
- **Detail:** The fault injector reads its settings with `ref.read` on each request, so moving a lever changes behaviour live without rebuilding the stack.
- **Two override points:** widget tests that do not care about the network replace `apiClientProvider` with a fake `ApiClient`. Tests of the stack itself replace `httpTransportProvider` with a fake transport, so the real wiring (layer order, fault levers, retries) is exercised without the network.
- **Lifetime:** the stack is a single long-lived instance, because the limiter's queue and the future cache are state. The real transport is closed when its provider is disposed.
- **Fault injection is always in the stack.** With `FaultSettings.none` it is a pass-through. It is a deliberate feature (it makes resilience demonstrable), and the control panel UI is the part to gate behind a flag.

## D15. Cache: in memory, with stale-while-revalidate

- **Decision:** `CachingApiClient` is the outermost layer. It keeps successful responses in memory for 10 minutes, serves slightly older data instantly while refreshing in the background (up to 1 hour past the TTL), shares one network call between simultaneous requests for the same URL, and keeps at most 200 entries (oldest dropped first). Failures are never cached.
- **Options considered:**
  - Persist the cache in `KeyValueStore`. Rejected for now: `localStorage` holds about 5 MB and one Pokémon response is large, so it would fill and then fail. The browser's HTTP cache already honours PokeAPI's `max-age=86400`, so a reload is cheap anyway.
  - `package:clock` for time. Rejected: a `DateTime Function() now` constructor parameter does the same with no dependency.
- **Why:** the cache sits outside the concurrency limiter, so a hit never takes a slot. Stale-while-revalidate means the UI never waits on a refresh, and a failed refresh keeps the old data, which helps during a brief outage.
- **A response the app cannot use is forgotten.** A 200 with valid JSON of the wrong shape was cached, so "Try again" got the same bad answer with no request. `CachingApiClient` now has `forget(url)` (through the small `ResponseCache` interface), which the repositories call via `parseResponse` when an answer arrives but fails to parse. Tested for each repository over a real cache, and through the control-panel flow.
- **Limitations:** cached JSON maps are shared, so a caller that mutated one would change it for everyone (repositories turn them into immutable models at once). Eviction is by age of storage, not last use. Nothing survives a page reload.

## D16. Defensive parsing: small hand-written readers, one exception type, caught at the repository

- **Decision:** API JSON is read with small helpers in `lib/data/json_reader.dart` (`asJsonObject`, `asJsonList`, `asJsonString`). Each checks one expectation and throws a `FormatException` saying what was wrong. A repository catches that one exception type around its parsing and returns `Err(MalformedResponseFailure(...))`, so the UI never sees it.
- **Options considered:** `json_serializable` or `freezed` (code generation, extra dependencies, generated casts with unhelpful errors); parse functions returning `Result` at every step (more ceremony for no extra safety).
- **Why:** plain functions can be read line by line. Throwing in the parse step and catching at one boundary keeps parsing short, and every repository's public API still follows D11.
- **Forward compatibility:** values we do not model (such as the `stellar` type) are skipped, so a new entry in the API cannot break the app. A wrong shape (a missing list, a string where an object belongs) is an error.
- **Fixtures:** `test/fixtures/` holds trimmed copies of real responses: Pikachu (single type), two Koraidon forms (dual type; one with no picture, one with artwork only), the type chart and the index. The opt-in live test checks they still match the real API (D32).
- **Layering:** `PokemonType` and `TypeChart` live in `lib/domain` as plain Dart. The data layer knows about them, never the reverse.
- **`parseResponse`** (`lib/data/parse_result.dart`) is the one place a `FormatException` becomes a `MalformedResponseFailure`. It was written when the second repository needed the same step.
- **Required and cosmetic fields.** Id, name, types and stats are required, and a Pokémon missing one is rejected. The picture is cosmetic: official artwork is preferred, then the small sprite, else none, and an odd `sprites` field never fails the Pokémon. Real data forced this, since some forms have no small sprite and a few have neither. Only current `types` are read (not `past_types`), and a Pokémon with no recognised type is rejected.
- **The search index** is one request with a limit of 5,000. The real list is about 1,350 entries (90 KB) with no next page, so one request suffices with about 3.7 times headroom. If the API outgrew it the list would be cut short silently, which is a known limitation. Forms are included, since they matter for team building. A response with no usable `results` is rejected, but one bad entry is skipped, because the entries are independent. The type chart is the opposite, as all 18 of its rows are needed. The id comes from the URL by a small regular expression that also checks the path.

## D17. The team: persistence, state and what "a team" means

*Partly superseded by D20: the team is six fixed slots that may be empty, so removal no longer shifts later members. The rest stands.*

- **Rules (domain).** Up to six slots, ordered. The same Pokémon may fill several slots, as in the games. The first version refused duplicates, and that was reversed: stacking one weakness six times is what the analysis should reveal. `Team` is immutable and holds ids only. `add` and `removeAt` return the same object when nothing changes, so the notifier skips a pointless save. Removal is by slot position, because an id can appear more than once.
- **Storage.** `KeyValueStore` is a two-method interface (`read`, `write`), implemented with `shared_preferences` (`localStorage` on web) using the `SharedPreferencesAsync` API, which needs no start-up initialisation. Only the team is persisted (the theme choice joined it later, D22), because it is small and the user's own data. The cache stays in memory (D15).
- **Best-effort.** If storage is unavailable or unreadable, loading gives an empty team and saving does nothing, so the app still works for the session. The cost is that blocked storage loses the team on reload without saying so. The repository catches `Object` around the storage calls only (web storage errors are not reliably `Exception`s) and `FormatException` around decoding. Programmer errors are not swallowed.
- **Saved data is re-validated.** Ids are rebuilt through the team's own rules, so a hand-edited value cannot produce a seventh Pokémon, and non-integers are dropped.
- **State: `AsyncNotifier<Team>`.** It loads once, then every change is applied and saved. The alternative, loading before `runApp` and overriding a synchronous provider, would simplify the UI but spread start-up wiring over two places.
- **No lost updates.** Each change waits for the load, then reads the state, computes the new team and assigns it with no `await` between. Dart runs one piece of code at a time, so two quick changes cannot overwrite each other. A test covers two changes made before loading finishes.
- **Limitation:** saves are not queued. They are issued in order, but if storage reordered them the older team could win. `localStorage` writes are synchronous underneath, so this is theoretical.
- **Dev dependency:** `shared_preferences_platform_interface`, for its in-memory test platform, so the real `SharedPreferencesKeyValueStore` is tested with a genuine save and reload. It was already in the tree, and this only declares it for the linter.

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
- **A retry shows as loading, not as the old failure.** After `ref.invalidate`, Riverpod keeps the previous result in `.value` while the new one loads, so a provider that turns `.value` into UI state kept showing the failure and its "Try again" as if nothing had started. The coverage panel and the search list both had this. `teamAnalysisProvider` and `searchProvider` now return loading when a reload is under way and the previous result was a failure. A result that had loaded stays on show, so "Clear cache and reload" does not blank the matrix or the list. The slot cards, result rows and the dialog's weaknesses check `isLoading` themselves. Tested at provider level, and for the matrix with an unanswered retry.

## D20. The team is six fixed slots, and a slot may be empty

- **Decision:** `Team` holds exactly six slots, each an id or empty. `add` fills the first empty slot, `removeAt(i)` empties slot `i` and nothing else moves. The UI always shows six slots.
- **Options considered:** keep the compact list and make the UI cope; fixed slots with the list still compacting.
- **Why:** with a compact list, removing slot 2 changes what every later slot shows, so the UI cannot tell "a Pokémon was added" from "the slots shifted". That matters for the throw-in, for Hero tags and for reordering. A sparse list gives each slot a stable identity, so animations, drag targets and tags can be keyed by position. Empty slots are always on screen, which invites a click to add and gives the throw a target.
- **Storage:** `{"ids":[25,null,6,null,null,null]}`. Loading is defensive and positional: a value that is not a whole number leaves its own slot empty without shifting the others, entries past six are dropped, and old compact saves (`[25,6]`) load as the first two slots.
- **As built:**
  - `Team.slots` is always six long. `Team.fromSlots` pads a short list and cuts a long one, so it is the one place that enforces the size. `memberIds` gives the filled ids in order.
  - `add`, `removeAt` and `move(from, to)` return the same object when nothing changes, so the notifier skips the save. `move` is a plain exchange, and moving to an empty slot is the same operation.
  - `addAt(index, id)` fills a chosen empty slot and never overwrites, so a stray call cannot replace a Pokémon.
  - The analysis skips empty slots, and `missingCount` counts only members that are loading or failed.
- **Trade-offs:** order is meaningful and may have gaps. There is no `replaceAt`: replacing is `removeAt` then `addAt`, which saves twice and briefly shows an empty slot. Nothing in the UI replaces in place, so it waits for a real caller, and should then be a separate explicit overwrite so `addAt` keeps its guarantee.

## D21. Reordering swaps two slots; others do not shuffle along

- **Decision:** dragging a card onto another slot exchanges the two, and dropping on an empty slot moves the card. `Team.move(from, to)` is the domain rule.
- **Options considered:** insert-and-shift with the other cards animating aside, as `ReorderableListView` does.
- **Why:** shuffling conflicts with fixed slots (D20) and is hard in a layout that changes between a row, a grid and a stack. Swapping is simple to explain, test and make accessible.
- **Press and hold, then drag** (`LongPressDraggable`, 300 ms), not a plain `Draggable`. In the SDK source a plain drag starts once the pointer moves past the hit slop, 1 px for a mouse and 18 px for touch. A shaky click would then drag instead of opening the details, and on touch the drag would compete with page scrolling. The delayed version rejects itself if the pointer moves early, leaving the press to the click or the scroll. The default delay is 500 ms, which felt slow with a mouse.
- **Dragging:** what is carried is the slot number. Every slot is a `DragTarget` that calls `TeamNotifier.move`. Any filled slot can be picked up, including a failed one, so a bad slot can be moved as well as removed. Dropping on its own slot or outside does nothing. A preview follows the pointer, the origin stays at 35% opacity, and the slot under the pointer gets a primary-colour border. A line under the team heading explains it, always shown so the layout does not shift.
- **Without dragging:** each filled slot offers "Move earlier" and "Move later" as screen-reader actions, and the details dialog has two buttons with the slot number between them (`MoveControls`). Both swap with the neighbour, as a drop there would. The first slot has no "earlier" and the last no "later". The actions sit inside the `InkWell`, because a test of the semantics tree showed they had first landed on a separate unlabelled node that could not take focus. The dialog's buttons are at the top of the scrolling part, because pinned at the bottom they overflowed by 293 px at 320 px wide and double text size.
- **Animation:** the throw plays on add and on loading the saved team, never because a slot became filled, or dragging into an empty slot would throw a ball. The state layer records which slots have just arrived (D29).
- **Limitations:** no shuffle-along animation, and the page does not scroll while dragging near its edge. A press held for 300 ms without moving starts a drag, so it no longer opens the details. Verified in widget tests and with a mouse, not on a touch screen.

## D22. UI direction: themes, animation and reduced motion

- **Themes:** light, dark and system (follows the browser), persisted through `KeyValueStore`. The saved choice is read before the first frame so there is no flash of the wrong theme. This is an exception to the "start-up loads inside a notifier" approach of D17, because the theme is needed for the first frame and the team is not.
- **Animation:** a drawn pokéball thrown into the slot, a flash, then the card is revealed once a minimum time has passed and the data has loaded; selecting a card flips and grows it into a detail dialog (`Hero` with a custom shuttle). All custom-painted with no image assets. Built after the control panel so the resilience demonstration is complete first.
- **Reduced motion:** when the system asks for less animation, the throw and flip are skipped; cards appear at once and the dialog fades.
- **Failure during a throw:** a failed load opens to an error card with a retry, never a stuck ball.
- **Fallback:** if the flip proves unreliable, the detail becomes a grow-and-fade dialog.
- See [plans/01-ui.md](plans/01-ui.md) for layout, build order and testing.

## D23. Search: filtered on the client, ranked, with rows that load their own details

- **Decision:** the whole index (D16) is held in memory and searched on every keystroke by a pure function, `searchPokemon`. The text is trimmed, lower-cased, and spaces become hyphens (so `Mr Mime` finds `mr-mime`). Names that start with the text, or a Pokémon whose number is exactly the text, come first. Names that contain it follow, each group keeping the list's order. Empty text gives everyone.
- **No debounce and no server search:** about 1,350 short strings is far too little work to wait for, and PokeAPI has no search endpoint.
- **Partial numbers do not match:** `2` would match 2, 20 to 29, 200 to 299 and the 10000s, which is noise.
- **State:** `pokemonIndexProvider` (failure is a value, D19), `searchQueryProvider`, and `searchProvider`, a sealed `SearchState`: `Loading`, `Unavailable(failure)` or `Ready(matches, query)`.
- **Rows load their own details.** The index has only names and ids, so the picture and types need `pokemonProvider(id)`. A scrolling list builds a row only when it comes into view, so about a dozen rows are requested, not 1,350. A test builds the full list and checks fewer than 30 requests.
- **A row waits 150 ms before asking.** Lazy building was not enough: dragging the scroll bar sweeps the list past in a second, and a test of that made 1,339 requests, each about 350 KB of JSON to decode and none cancellable. The page stuttered and the visible rows queued behind stale requests. Now a row starts a timer when built and cancels it if it leaves first, so rows passing through ask for nothing (0 requests in the same test). A row whose provider already exists shows at once.
- **The loading placeholder is built from the badge itself** (`TypeBadgePlaceholder`: same shape, invisible text). `ListTile` positions its title and subtitle from the subtitle's text baseline, and a plain grey box has none, so the title jumped 2 to 4 px when the real badges arrived. A test compares positions before and after.
- **A retry shows as loading.** After `ref.invalidate`, Riverpod keeps the previous result in `.value` while the request runs, so a failed row kept saying "Details unavailable". The row checks `isLoading` first (see D19).
- **A row whose details fail** still shows its name and number, says "Details unavailable" and has its own retry. One bad Pokémon does not spoil the list.
- **Limitations:** a request for a row that scrolls away is not cancelled, and finishes into the cache. The pictures are the official artwork, scaled down on decode but fully downloaded, and the small sprite is the alternative if that proves slow. Matches are not highlighted in the names.

## D24. Presentation conventions: colours, names and messages

- **Type colours** live in `lib/app/type_colours.dart`, not the domain (which has no colours). One `switch` with no default, so a new type cannot compile without a colour. They are the same in light and dark themes.
- **Text on a coloured badge** is black or white, whichever contrasts more, chosen by the colour's luminance (the switch-over point, 0.179, is where both give a ratio of about 4.58). A test checks all 18 types reach the 4.5 ratio of WCAG AA, using its own contrast formula rather than the app's rule.
- **Display names** (`mr-mime` becomes `Mr Mime`) are made by a small function in the UI layer. It is simple on purpose: names with a real hyphen come out as two words (`ho-oh` gives `Ho Oh`). The domain keeps the API's names, and search matches against those.
- **Failure messages** are one exhaustive `switch` over `ApiFailure` in `lib/app/failure_message.dart`. They say what happened in plain words and never show status codes or class names. Tests check each failure has its own, non-empty message.
- **Sprites** (`PokemonSprite`) always draw a faint placeholder icon underneath. The picture fades in over it; a missing or failed picture leaves the placeholder, never a broken-image box. The fade is skipped when the system asks for reduced motion.
- **UI text is inline English.** Translating it would mean Flutter's localisation system, which is out of scope. Known limitation.

## D25. The team screen: layouts, and how a slot is chosen

- **Two layouts, switched at 900 px** (`HomeScreen`, a `LayoutBuilder`). Wide: the search is a fixed 420 px column on the left, always showing, with the team on the right. Narrower: the team has the full width and the search opens in a modal bottom sheet, nearly full height with the field focused. The same `SearchPanel` is used in both. The slots go two across below 520 px of available width and three across above it. On a phone "Add Pokémon" sits above the team, because below the slots it was off screen on an 800 px-high display (a test checks it is visible without scrolling).
- **Choosing a slot.** Tapping an empty slot records it in `addTargetProvider`. The next pick goes there (`addAt`) and the choice is used up. Without a choice, a pick takes the first empty slot (`add`). On a phone the empty slot's add button opens the sheet for that slot, and on a wide screen it marks the slot for the next click in the search. `TeamNotifier.addPicked` makes the decision inside `_change`, so a slot filled in the meantime is not overwritten. Closing the sheet forgets an unused choice.
- **Rows are disabled when the team is full,** and the panel says why. Picking the same Pokémon twice is allowed (D17).
- **Slot states:** empty (chosen or not), loading, failed (reason, retry, still removable) and filled. A slot watches only its own entry (`select`), so a change elsewhere does not rebuild it.
- **Slots are equal in width.** The gap was padding inside every slot but the last, so the last column was 12 px wider. The gaps are now separate boxes, and a test checks equal widths, even gaps and a row that fills the space.
- **Slot height follows the content.** A fixed 208 px grid row overflowed by up to 252 px at double text size. Rows are `IntrinsicHeight` around a `Row`, each slot at least 208 px. A `Table` with `intrinsicHeight` did not work: it lays cells out a second time at a fixed height and missed later size changes, so a slot going from spinner to error card stayed too short.
- **Two searches can exist at once.** Widening the window while the sheet is open leaves the sheet and the permanent panel sharing one query. Each box follows the query (`ref.listen`), so the box and results cannot disagree. The sheet's cleanup uses the app's container, not a widget's `ref`, because it runs after the sheet closes, when the widget that opened it may have been replaced.
- **Limitations:** a chosen slot stays chosen until a pick or another choice, and there is no way to un-choose it. Large text is handled but tested only at double size, on a phone, in both themes.

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

- **An end drawer, from an app-bar icon** (a "tune" button, tooltip "Simulate problems"). It slides in from the right, up to 380 px wide and narrower on a phone so a strip of the page shows and tapping it closes the panel. It works at every width and never takes permanent space. The title and close button are pinned, and the rest scrolls.
- **The levers** are those `FaultSettings` has: delay (0 to 5 s), failure rate (0 to 100%), which failures may happen (chips), how long a simulated 429 asks to wait, an offline switch, and "Back to normal". The wait slider is disabled unless "Too many requests" is chosen. At least one failure kind always stays chosen, because with none the injector injects nothing and a failure rate would silently do nothing.
- **Not saved.** A reload resets every lever, so one left on cannot make the next visit look broken.
- **The retry log.** The retry layer's `onRetry` hook feeds `retryLogProvider`, which keeps the latest 50 events, newest first. Each shows the request, the failed attempt, the reason and the wait. It shows waits before a retry only, not the final failure (which appears where the data was needed) or cache hits.
- **"Clear cache and reload".** Clearing the cache alone would show nothing, since providers already hold their data. So `DataReloader` clears the cache and invalidates the index, every Pokémon and the type chart, and everything on screen asks again. The cache is its own provider (`apiCacheProvider`) so the panel can reach `clear()`, and `apiClientProvider` is the same object under its general name, which tests replace with fakes. Requests already under way are not stopped and may store their answer.
- **The timeout is five seconds (it was ten).** With three attempts and backoff, a request that never answers is given up on after about 16.5 seconds, not about 31. Ten seconds suited a live demonstration poorly, and PokeAPI normally answers well under a second. Rejected: retrying a timeout once only (about 20 s, and needs failure-specific limits in the policy), and both (about 10.5 s, more code).
- **Tested end to end.** One test runs the whole app over the real networking stack and a fake network: failures at 100% and "Clear cache and reload", then checks each request was tried three times, both waits are logged, the team slot and the matrix say what failed and offer a retry, and going back to normal and retrying recovers. Another checks a two-second delay is waited for with no retries.
- **Limitations:** no cache hits or stale refreshes in the log, and no timestamps, only order. A timed-out request carries on in the background, because Dart cannot cancel it, and only its answer is ignored (D12).

## D28. The detail dialog and the radar chart

- **Opening.** Tapping a loaded Pokémon opens a dialog. A loading or failed slot does nothing when tapped (a failed one has its own "Try again"). The remove button takes its own taps, so removing never opens the dialog. The flip transition is D30.
- **Contents:** picture, name, number and types; the base stats as a radar chart and as bars with a total; and what the Pokémon is weak to, resists and is immune to, with the multiplier beside each type. From a team slot it also has the move earlier and later buttons (D21).
- **Matchups are the team analysis for a team of one** (`defencesOf` calls `analyseTeam`), so dual-type multipliers combine in one place. The dialog shows a spinner while the type chart loads and a "Try again" if it fails. The rest of the dialog does not wait for it.
- **The radar chart is custom-painted.** The geometry (`axisDirection`, `radarPoints`, `statFraction`) is plain functions with their own tests. The painter measures its labels first and gives the chart the room that is left, so larger text shrinks the chart instead of overlapping it.
- **One fixed scale, 0 to 200,** for the chart and the bars, so two Pokémon can be compared by eye. Higher stats (Blissey's HP is 255) are drawn at the edge, and the bars give the number. A scale fitted to each Pokémon was rejected because every shape would look similar.
- **Screen readers.** The chart is a picture of numbers that are also given as text, so it is hidden. Each bar row is one sentence ("Attack: 55") and each weakness one item ("Rock, 4×"), so which type a multiplier belongs to is available, unlike the coverage matrix (D26).
- **Layout.** Chart and bars sit side by side from 480 px of content. The name sits beside the picture from 420 px, because beside the picture and close button it got so little width at 320 px and double text size that "Charizard" broke mid-word. The header does not scroll, so the close button is always reachable.
- **A test once passed while the stat bars were invisible.** The fill is a childless `DecoratedBox` in an `Align`, which loosens the height constraint, so it was 0 px tall. The test only read the `widthFactor` it had passed in. The fix is `heightFactor: 1`, and a test now measures the rendered size.
- **Limitations:** stats above 200 are drawn at the edge. The tie-break in the weakness groups cannot be proved by its test, because a short list stays in order either way. `shouldRepaint` is not tested directly.

## D29. The throw-in animation

- **Decision:** when a Pokémon arrives in a slot, a ball is thrown over the slot's content, lands, and a flash reveals the content.
- **Which slots throw is state,** not something the widgets work out. `arrivalsProvider` maps a slot number to how long that slot waits before throwing. `TeamNotifier` marks the slots an add fills (found by comparing the team before and after, for `add`, `addAt` and `addPicked` only), and every filled slot when the saved team loads, 150 ms apart (`startupThrowStagger`). `move` and `removeAt` never mark anything, so dragging a Pokémon into an empty slot throws nothing (D21). Tests check this at both levels.
- **A slot uses its arrival up** after its first frame, so a rebuild or a change of layout never replays it.
- **One controller, three phases:** the flight (700 ms), the ball resting where it landed, and the reveal (350 ms). The reveal starts when the ball has landed and the Pokémon has settled (loaded or failed). A slow load keeps the ball waiting, and a failed one reveals the error card with "Try again", never an endless ball.
- **It is drawn over the whole card,** not just the content. `ThrowIn` takes a `bleed`, how far the card reaches beyond its content, and the cover, ball and flash are drawn across that. The card clips the picture at its rounded edge, so the ball seems to arrive from beyond the corner. The card's border and remove button are drawn above it, so a waiting slot can still be removed. The cover has to match the card's colour exactly, so the colour is set once and shared, with a test.
- **Covering only the content showed the card's hover colour round the edge mid-throw,** because `InkWell` paints it on the card's surface, under the content. A pixel test hovers a card that has not thrown and compares the padding with the middle. Hovering a card mid-throw now shows no hover colour until the reveal.
- **Drawing.** The ball follows a curve pulled up and to the left, starting large outside the bottom-left corner. The geometry is plain functions with tests. The ball is drawn in code, in the app icon's colours, so it looks the same in both themes. The flash fades before it reaches an edge, because otherwise it showed as a grey rectangle in dark mode.
- **Reduced motion:** nothing is drawn and the content shows. The arrival is still used up. A waiting slot's `Timer` is cancelled when the widget goes away.
- **Tests.** The first reveal-rule tests passed with the rule removed, because one `pump` delivers a single frame and an animation's first frame has no time elapsed. They now use `pumpAndSettle`, and one test loads the Pokémon mid-flight. Each rule was checked to make a test fail when removed.
- **Limitations:**
  - With every request failing, a slot shows the resting ball for about 16 seconds (D27) before the error card. The remove button works meanwhile.
  - The ball does not wobble while waiting, because a repeating animation would keep widget tests from settling.
  - Checked in widget tests, rendered frames and, for reduced motion, by hand in Chrome: the browser setting does reach `disableAnimations`, no ball is thrown, and the usual loading spinner shows.
  - That spinner is itself a looping animation, kept because it says "loading". Whether to swap it for a still indicator under reduced motion is undecided.

## D30. The flip into the details dialog

- **Decision:** tapping a team card flips it open into the dialog. The card turns edge-on, the dialog comes round from the other side, and the shape grows from the card's rectangle to the dialog's. Closing plays it backwards into the card the Pokémon is in now. With reduced motion there is no flip: the dialog fades in 200 ms.
- **A route of its own, not `showDialog`.** A `Hero` only flies between `PageRoute`s (checked in the SDK), and a `showDialog` route is not one. `showPokemonDetail` pushes a non-opaque `PageRouteBuilder` with a dimmed barrier. The `Dialog` widget could not be kept either, because its surface has to be the thing inside the `Hero`. So the dialog draws that surface itself, with the values a Material 3 `Dialog` uses (shape, surface-container-high colour, a transparent shadow). The barrier and Esc still close it, and it still announces itself as a dialog (`SemanticsRole.dialog`).
- **The shuttle** (`flipShuttleBuilder`) decides what is seen during the flight. Its animation follows the dialog's route, so 0 is the card and 1 is the dialog in both directions, and opening and closing are one rule: the card face before the halfway point, the dialog face after. The angle is a plain, tested function of the position (`showsCardFace`, `flipAngle`). The card turns a quarter turn to edge-on and the dialog starts a negative quarter turn, so the swap is hidden and no face is ever back to front.
- **Each face is laid out at its own size and stretched** to the space the flight gives it (`FittedBox`, fill). Laying the dialog out in the flight's space overflows in a card-sized box and switches layouts part-way. The cost is a slight stretch while turning. Both faces are built once at the start of the flight, and their sizes read from the render objects, because `context.size` cannot be read while widgets build.
- **The tag is the slot number, and the dialog follows its Pokémon.** The dialog holds the slot and passes it to `MoveControls`, so after "Move earlier" the tag is the new slot and closing flies to the card the Pokémon is in now. A dialog with no slot (a Pokémon not on the team) has no `Hero` and just fades.
- **The card leaves a gap, and the gap follows it.** Using the `Hero`'s blank placeholder as the gap stays in the slot the dialog opened from, so after a move the cards behind the dialog did not update until the closing flight released it. Showing the real card as the placeholder kept them live but showed the Pokémon twice. So:
  - `liftedSlotProvider` holds the slot whose card is in the dialog. That slot is drawn as a gap: invisible, the same size, untouchable and hidden from screen readers. The slot the Pokémon left shows the card that took its place. The `Hero` still shows its real card as its placeholder.
  - The dialog drives it: it lifts its slot, moves the gap when the buttons move the Pokémon, and puts it down at the end. The wrappers that make the gap are always present and only switched on and off, because adding or removing one would rebuild the `Hero` mid-flight.
  - **Timing only has to be right in one direction.** A gap a frame late is invisible, because the flying copy sits exactly on the card. A gap a frame early, or one that outlasts the landing, is a visible hole. So the slot is lifted after the dialog's first frame (the frame the flight starts) and put down when the route's animation ends (the moment the flight lands). A frame-by-frame test steps through the open, a move and the close, and checks that no frame has a gap without the flying copy or the open dialog covering it.
  - The dialog also puts the slot down when disposed, as a backstop for a dialog that goes without finishing its animation. `putDown` only acts if the slot is still the lifted one, so an older dialog finishing cannot clear a newer one's. The notifier ignores calls after the providers are gone.
  - With reduced motion, or no slot, there is no flight and no gap.
- **Checked** by pumping through the flight, with and without reduced motion, and by mutation (the swap point, the faces reversed, reduced motion ignored, the tag not following a move, the dialog role). The first reduced-motion test passed with the feature removed, because at 100 ms the contents are still on screen in the flight's picture. It now checks they belong to the dialog itself. Rendering the flight also showed a heavy outline from the `Material`'s default black shadow, hence the transparent one.
- **Limitations:**
  - Rendered frames and widget tests only. The flip and the gap were also looked at in Chrome, but not on a touch device.
  - During the flight the dialog's own place is empty and its picture is a second copy of its contents, so a dialog still loading its weaknesses shows its spinner in the picture first.
  - A face is stretched a little while it turns.
  - Opening another dialog while one is closing works when tried by hand, but no test covers it.
  - Opening the dialog on a card whose throw-in is still playing is untested, and the two animations are not co-ordinated.

## D31. Team stats, in a tab beside the coverage matrix

- **A segmented control, "Coverage" and "Stats", swapping the content in place.** The matrix is 18 rows tall, so stacking the stats under it would make a very long page. Coverage is first and the default, because "where is this team weak?" is the headline. The cost is switching tabs to see how the stats changed.
- **Not a `TabBar` with a `TabBarView`,** which needs a bounded height and swipes sideways, fighting the page's own scrolling. A `SegmentedButton` just chooses what to show, and reads to a screen reader as a choice of one. It fills the width (`expandedInsets`).
- **The chosen tab is a provider (`insightsTabProvider`),** because the panel is rebuilt from scratch when the window crosses 900 px. It is not saved between visits, like the matrix order. A test rebuilds the panel and checks the tab survives.
- **The "may be incomplete" notice is on both tabs** (`IncompleteWarning`, moved out of the matrix), because stats from a team with a member missing are as unreliable as the matrix. The stats do not need the type chart, so a failed chart does not hide them.
- **`teamMembersProvider`** goes through the team slot by slot, loading each member and counting those missing. The analysis and the stats both read it. The analysis used to do this itself, and its tests are unchanged.
- **`summariseStats` is a pure domain function** over the loaded members: for each stat the mean, the highest and lowest, and the member behind each (the earlier slot on a tie). It returns nothing for an empty team. Averages keep their fraction and are rounded only for display, so the chart and the rows agree.
- **The tab shows** a radar chart of the averages (reusing `RadarChart` on the same 0 to 200 scale), then a row per stat with its average and "Highest: X 135 · Lowest: Y 55", then the average total. A team of one has no range, and equal values show "All the same" instead of naming one member.
- **Left out:** a breakdown by type, which the matrix answers, and any score for the team, which would be an opinion presented as a measurement.
- **Screen readers** get one sentence per stat ("Attack: average 95. Highest: Koraidon Limited Build 135 · Lowest: Pikachu 55"). The chart is hidden.
- **Limitations:** rendered frames and widget tests only. A tie names one member even if several share the value. Base stats only, so the averages describe the species, not a trained team.

## D32. An opt-in live contract test

- **Why:** every other test uses fixtures, which are trimmed copies of real responses, so nothing noticed if PokeAPI changed shape.
- **Opt-in, by a tag.** `test/live/pokeapi_contract_test.dart` is tagged `live`, and `dart_test.yaml` skips that tag. `flutter test --run-skipped --tags live` runs it. It stays out of the default run because it needs the network, and a public API having a bad moment should not fail a build that did nothing wrong.
- **It checks** the app's own code against real responses (the index, Pikachu, an alternative form, and the whole type chart with a few spot checks), and each saved fixture's shape against the matching live response, all 18 type fixtures included. About 25 requests, one pass.
- **Shape, not values.** `shapeDifferences` (`test/live/json_shape.dart`, with its own ordinary tests) reports every key the fixture has and the live response lacks, and every value that changed kind. Extra keys are fine, as the fixtures are trimmed. A list is judged by its first item, and a null on either side is fine. Values are not compared, because stats legitimately change.
- **It uses the app's layers less the cache and simulated faults.** The retrying layer stays, so a passing wobble does not fail a run. It is plain `test`, not `testWidgets`, because the widget test binding blocks real network access.
- **Checked to fail** by renaming one fixture key and changing one number to a string. The right tests failed with the fixture and path in the message, and passed again once restored. At the first run (24 November 2026) every fixture matched.
- **Limitations:** run by hand, not on a schedule. A failure does not say whether the API changed or was briefly down, so check the named request. It covers only the endpoints and fields the app uses.
