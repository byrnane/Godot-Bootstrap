# Architecture Guardrails

This file defines boundaries that keep the template stable.

## Do Not Modify These Contracts Blindly

## 1. Scene Switching Boundary

- Root scene switches must go only through `SceneRouter`.
- Do not call `change_scene*` directly from feature scripts.
- Do not mount/unmount root scenes from UI nodes.

Why: transition lifecycle, loading state, and HUD binding depend on `SceneRouter`.

## 2. Flow Ownership

- Top-level navigation decisions stay in `AppFlow`.
- Feature scenes emit intent signals, they do not own app routing policy.

Why: keeps global behavior deterministic and testable.

## 3. UI Shell Ownership

- Global modals, loading layer, and toasts are hosted by `UiShell`.
- Do not create ad-hoc global modal stacks in feature scenes.

Why: modal/input/backdrop behavior must remain consistent.

## 4. Persistence Ownership

- Filesystem access for saves/settings/input persistence stays in managers.
- Feature scenes should never read/write `user://` files directly.

Why: versioning, validation, and backup/recovery rules live in one place.

## 5. Context Separation

- `AppContext` is app-lifetime state.
- `SessionContext` is run-lifetime state.
- Do not mix long-lived and per-run state arbitrarily.

Why: prevents hidden reset/persistence bugs.

## 6. Localization Discipline

- Static UI labels should be translation keys in `.tscn`.
- Runtime labels should use `tr("UI_*")` keys.
- Keep keys in `translations/UI.csv`.

Why: smoke checks and runtime locale switch rely on this convention.

## Safe Customization Surface

You can safely extend:

- `features/` scenes and UI;
- `SessionContext`, `SaveData`, `UserSettings` schemas;
- `InputManager` metadata/default bindings;
- `shared/ui/components` with new reusable primitives;
- `core/config/game_config_override.tres` for per-project runtime defaults.

## Change Control for Core Runtime

If you touch `AppFlow`, `SceneRouter`, `UiShell`, `TransitionManager`, or persistence managers:

1. Run smoke checks.
2. Re-run manual checklist sections for transitions/modals/save/settings.
3. Document behavior changes in `CHANGELOG.md`.
