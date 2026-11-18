# Project conventions for AI tools

A Flutter web app (Flutter 3.50 / Dart 3.14) for building a Pokémon team and analysing its type coverage, built on PokeAPI.

Read first:

- [docs/plans/00-overview.md](docs/plans/00-overview.md): what we are building, scope, architecture.
- [docs/decisions.md](docs/decisions.md): decisions made and why. Add an entry when making a significant new one; do not silently contradict an existing one.

## Language and style

- **Use British spellings** in code, comments, docs and UI text (colour, behaviour, initialise, analyse, centre, cancelled). Exceptions: names imposed by Flutter, Dart or third-party APIs (for example `Color`, `Center`, `initState`).
- Single quotes for strings. Follow `analysis_options.yaml`; `flutter analyze` must pass with no issues.
- Format with `dart format`.
- Package imports only (`package:pokemon_team_builder/...`), never relative.

## Architecture

- Layers: `data` → `domain` → `state` (Riverpod) → UI. Dependencies point inwards: `domain` is plain Dart and must not import Flutter, Riverpod or `data`.
- Feature-first folders under `lib/features/`.
- No logic in widgets. Widgets read state and dispatch intents.
- Handle API failures with the typed `ApiFailure` result, never by leaking raw exceptions to the UI.
- No third-party client library for PokeAPI; the client is hand-written.

## Testing

- Every behaviour change comes with a test. Prefer meaningful tests over coverage numbers.
- Tests use fakes, not the network. Use the in-memory `KeyValueStore` and the fault-injecting client. Time-dependent code is tested with `fake_async`.
- Live API checks are opt-in and must be tagged so they are excluded from the default run.
- Commands: `flutter test`, `flutter analyze`.

## Working agreements

- Keep scope tight: finish one thing well before starting the next.
- Do not add dependencies without noting the reason in `docs/decisions.md`.
- Keep the repo free of any reference to where the project came from or who asked for it.
