# Release Process

Internal document for template maintainers.

## Release Checklist

Before creating a template release:

1. Confirm roadmap phase criteria status in `TODO.md`.
2. Use current results for the changed behavior from [TESTING.md](TESTING.md). Run `-Suite all` only on owner request or for a concrete broad risk that selected suites cannot cover; explain the reason first. A release commit alone does not require it.
3. Use only the relevant sections of `docs/MANUAL_TEST_PLAN.md` when the release needs native or visual acceptance; reuse current results.
4. Update `CHANGELOG.md`:
   - `Added`
   - `Changed`
   - `Fixed`
   - `Removed`
5. Update `VERSION`.
6. If persistence contracts changed:
   - document migration notes;
   - confirm compatibility behavior for `SaveData` / `UserSettings`.
7. Ensure docs reflect current architecture and extension points. If UI changed, check the local OpenPencil source (`Game Template UI.fig`) and the UI Framework guide.
8. Merge the accepted common commits from `main` into `3d`, `2d`, and `2d-pixelart`, preserving variant settings; follow [VARIANTS.md](VARIANTS.md). Uncommitted worktree copies do not update branch history.
9. Build and accept target-platform exports from the release candidate when packaging or native behavior changed. Earlier pre-UI exports do not validate a new UI. Record actual results and remaining limits in [READINESS.md](READINESS.md).
10. Create the release commit and git tag only with owner authorization. Push/publication require a separate instruction.

## Semantic Version Policy

Template follows `MAJOR.MINOR.PATCH`.

### MAJOR

Use MAJOR bump when template compatibility is broken, for example:

- incompatible changes in core runtime contracts (`AppFlow`, `SceneRouter`, `UiShell`);
- persistence compatibility break requiring consumer-side migration changes;
- removal or replacement of expected extension points.

### MINOR

Use MINOR bump for backward-compatible infrastructure improvements:

- new services or extension hooks;
- new reusable UI primitives;
- additional smoke checks and tooling;
- non-breaking config/schema extension with migration support.

### PATCH

Use PATCH bump for fixes and maintenance with no contract break:

- bug fixes in existing systems;
- docs and test improvements;
- non-breaking UX polish.

## Tagging Convention

- Tag format: `vMAJOR.MINOR.PATCH` (example: `v0.3.0`).
- Tag only after local smoke + relevant checklist are green.
- Tag message should reference changelog section for that version.
