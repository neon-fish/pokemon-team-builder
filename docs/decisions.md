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
  - There is no `clear` yet; it is added when the control panel needs it.

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
