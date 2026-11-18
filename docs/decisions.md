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
