# Pokémon Team Builder: overview plan

Status: draft, living document. Decisions and their rationale are logged in [../decisions.md](../decisions.md).

## 1. What we're building

A Flutter web dashboard for building a team of up to six Pokémon and understanding **where that team is weak**.

The user searches for Pokémon, adds them to a team, and the dashboard answers one question: *what is this team vulnerable to, and what does it cover?*

### The app at a glance

| Area | What it does |
|---|---|
| **Search & browse** | Fast local search over the full Pokémon index (one request, searched client-side). Results show sprite, name, types. |
| **Team** | Six slots. Add, remove, persist across reloads. |
| **Coverage analysis** | For each of the 18 attacking types: how many teammates are weak to it, resist it, or are immune. Gaps are flagged in plain language ("3 of 6 are weak to Ground and nobody resists it"). |
| **Stat breakdown** | Team totals and spread by stat; breakdown by type. |
| **Compare** | Two or more selected Pokémon side by side, with a custom-painted radar chart. |
| **Control panel** | A dev-facing panel with levers that inject latency, failures, rate limiting, malformed payloads and offline mode, plus cache controls. Makes the resilience behaviour visible and demonstrable on demand. |

### Why this angle

A list-and-detail Pokédex is the obvious demo. The product here is analytical: it takes a well-known dataset and does something useful with it. The interesting engineering is in the API client, caching, and failure handling, which the control panel makes visible.

### Data (PokeAPI, keyless, CORS-enabled)

- `GET /pokemon?limit=1400`: the name and ID index, fetched once and cached.
- `GET /pokemon/{id}`: types, base stats, sprites.
- `GET /type/{name}`: damage relations. All 18 are fetched on first analysis and cached.

Responses are cacheable (`cache-control: max-age=86400`, `ETag`). No rate limiting was observed (80 requests at concurrency 20, all 200), so failure modes are simulated by the control panel and exercised in tests. Sprites are served from a separate host (`raw.githubusercontent.com`) with their own caching behaviour.

No client library is used for the API. The client is hand-written over a plain HTTP package, to demonstrate the integration properly.

## 2. Scope

### v1 (the slice we finish well)

- Search, team (add/remove/persist), coverage analysis, stat breakdown, compare.
- Full resilience stack and control panel.
- Unit, widget and flow tests; README with manual test plan.

### Deliberately out of scope

- Moves, abilities, evolution chains, flavour text.
- Camera / image recognition (needs a model or a keyed API, is non-deterministic, and does not demonstrate front-end Flutter skill).
- Accounts or any backend.

Offensive coverage would need move data, so v1 approximates it with STAB (a Pokémon's own types) and says so.

### Stretch goals (in rough priority order)

1. **Box**: a larger "found" collection that the team is drawn from, with its own breakdowns. The persistence layer stores IDs as a generic collection so this slots in without rework.
2. Offensive coverage using real move data.
3. "Who's that Pokémon?" silhouette guessing game.
4. Shareable team via URL.

## 3. Architecture

Feature-first folders, four layers: **data → domain → state → UI**. Everything below the state layer is plain Dart with no Flutter or state-management dependency.

```
lib/
  core/          # result/failure types, key-value store, utilities
  data/          # api client, decorators, cache, repositories, DTO parsing
  domain/        # models, type-chart maths (pure functions)
  features/      # team, search, compare, control_panel (state + UI per feature)
  app/           # theme, routing, composition root
```

### API stack

`PokeApiClient` is a small interface. Behaviour is added by composition, not inheritance:

```
HttpClient
  → FaultInjector            (control panel levers; also used by tests)
  → Retry / Backoff          (exponential + jitter, honours Retry-After, idempotent GETs only)
  → ConcurrencyLimiter       (caps parallel requests)
  → CachingRepository        (TTL, in-flight de-duplication, stale-while-revalidate)
```

- **Typed failures**: a sealed `ApiFailure` (offline, timeout, rate-limited with retry time, server error, not found, malformed). The UI never sees raw exceptions.
- **Defensive parsing**: null sprites, unexpected types and missing stats fall back to sensible defaults and are surfaced where it matters.
- **Persistence**: `KeyValueStore` interface, implemented with `shared_preferences`, with an in-memory fake for tests. Team, type chart and index are persisted; storage corruption falls back to a clean state.
- **State**: Riverpod (`Notifier` / `AsyncNotifier`, no code generation). See the decision log.
- **Sprites**: loaded from a separate host with placeholder, error and fade-in states.

### UI approach

Material as the structural base (scaffold, text fields, dialogs, navigation), heavily themed. Signature components (type badges, stat bars, team slots, coverage matrix, radar chart) are custom-built from primitives and `CustomPaint`. Responsive from phone to desktop width; accessible contrast and semantics.

## 4. How this meets the brief

| Requirement | Approach |
|---|---|
| Creativity & product thinking | Team coverage analysis rather than a list-and-detail Pokédex |
| Reliability & resilience | Decorator stack, typed failures, stale-while-revalidate, explicit loading / error / empty states everywhere, control panel |
| Testing | Unit: type-chart maths, parsers, retry/backoff (fake clock), cache, limiter. Widget: state transitions, retry flows, control panel. One end-to-end flow on a fake transport. Opt-in live contract test checks fixtures against the real API. |
| QA & documentation | README with manual test plan (throttling, offline, clear storage, narrow widths, keyboard and screen-reader pass) and known limitations |
| Code quality & architecture | Strict lints, small files, no logic in widgets, pure domain layer |
| UX & polish | Themed Material, custom components, responsive, accessible, no jank during request fan-out |
| Communication | Decision log feeding the README; note on how AI tools were used |
| Final presentation | The control panel allows live demonstration of every failure mode |

## 5. Risks and watch-outs

- **Real failures are rare.** PokeAPI is stable, so resilience has to be demonstrated through fault injection rather than waiting for real outages.
- **Flutter version.** The project targets Flutter 3.50 (Material is the separate `material_ui` package). The README must state the version.
- **Fan-out.** Showing rich data means one detail request per Pokémon. The limiter and cache keep this under control; this needs to be verified, not assumed.
- **Public repo hygiene.** Keep the repo, project, and docs free of any reference to any documents or parties that it shouldn't.

## 6. Progress

- [x] Project setup: dependencies, strict lints, folder skeleton, `AGENTS.md`, decision log.
- [x] API stack, minus the cache: typed failures and `Result`, transport, fault injector, status/JSON handling, retry with backoff, concurrency limiter. Unit tested with a fake clock.
- [x] Composition root (`lib/app/providers.dart`) and a **temporary** scratch screen (`lib/app/scratch_home.dart`) with a button that calls the real API through the full stack. To be deleted once the real UI exists.
- [x] Caching layer: in-memory, TTL, in-flight de-duplication, stale-while-revalidate, size cap (D15). The `KeyValueStore` arrives with the first thing that must persist (the team).
- [ ] Cache "clear" lever for the control panel: add when the panel needs it.
- [x] Type chart: `PokemonType`, `TypeChart`, `TypeChartRepository`, JSON reading helpers, fixture (D16).
- [x] Pokémon detail: `Pokemon`, `BaseStats`, `PokemonRepository`, `parseResult`, real-response fixtures.
- [x] Search index: `PokemonSummary`, `PokemonIndexRepository` (one request, ids parsed from URLs).
- [x] Team: `Team` rules, `KeyValueStore` (`shared_preferences`), `TeamRepository`, `TeamNotifier` (D17).
- [x] Team analysis (domain): `analyseTeam`, `TypeMatchup`, tested against the real type chart (D18).
- [x] State: `pokemonProvider` (family), `typeChartProvider`, `teamAnalysisProvider` with `Loading` / `Unavailable` / `Ready` states (D19).
- [ ] Search state (index provider and query), added with the search UI.
- [ ] Domain: type chart and team analysis.
- [ ] UI: theme, search, team, analysis, compare.
- [ ] Control panel UI (the levers' state already exists as `faultSettingsProvider`).
- [ ] README: setup, decisions, QA approach, manual test plan, known limitations.
