# Release Process

## Release Checklist

Before creating a template release:

1. Confirm roadmap phase criteria status in `TODO.md`.
2. Run smoke checks and get `PASS`:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1`
3. Run manual checklist from `docs/MANUAL_TEST_PLAN.md` (critical sections at minimum).
4. Review CI run for `Smoke Checks`.
5. Update `CHANGELOG.md`:
   - `Added`
   - `Changed`
   - `Fixed`
   - `Removed`
6. Update `VERSION`.
7. If persistence contracts changed:
   - document migration notes;
   - confirm compatibility behavior for `SaveData` / `UserSettings`.
8. Ensure docs reflect current architecture and extension points.
9. Create git tag for release.

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
- Tag only after smoke + CI + checklist are green.
- Tag message should reference changelog section for that version.
