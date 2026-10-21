# Release Process

Internal document for template maintainers.

## Release Checklist

Before creating a template release:

1. Confirm roadmap phase criteria status in `TODO.md`.
2. Use the full local smoke result from the final task commit; rerun only if relevant changes invalidate it:
   - `pwsh -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1 -Headless -Suite all`
3. Run manual checklist from `docs/MANUAL_TEST_PLAN.md` (critical sections at minimum).
4. Update `CHANGELOG.md`:
   - `Added`
   - `Changed`
   - `Fixed`
   - `Removed`
5. Update `VERSION`.
6. If persistence contracts changed:
   - document migration notes;
   - confirm compatibility behavior for `SaveData` / `UserSettings`.
7. Ensure docs reflect current architecture and extension points. If UI changed, refresh the local design reference and document whether the native `.fig` backup exists.
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
