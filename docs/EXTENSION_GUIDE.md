# Extension Guide

This guide shows where to extend the template without breaking core flow.

## Add a New Root Scene

1. Create scene under `features/` (example: `features/your_mode/your_mode.tscn`).
2. Register scene id and path in `core/registry/scenes.gd`.
3. Route transitions from `AppFlow` (new method or branch).
4. Trigger transitions only through `SceneRouter.go_to(...)`.

Do not switch root scenes directly from feature scripts.

## Add Scene-Specific HUD

In your root scene script, optionally implement:

- `get_hud_scene()`
- `bind_hud(hud)`
- `unbind_hud(hud)`

`SceneRouter` mounts and unmounts HUD through `UiShell`.

## Add New Service

1. Place service in `core/services/`.
2. If global lifetime is needed, register it in `[autoload]` section of `project.godot`.
3. Keep APIs explicit (methods/signals), avoid hidden side effects.
4. Keep service independent from concrete feature scenes.

Use `AppFlow` as orchestration layer for top-level behavior.

## Extend App Context vs Session Context

- `AppContext`: long-lived app-level state (settings, debug flags, runtime mode).
- `SessionContext`: current run/session state (level, health, score, etc.).

If data should reset on new run, keep it in `SessionContext`.
If data should survive while app is open globally, keep it in `AppContext`.

## Extend Persistence

### User Settings

- Add fields to `core/context/user_settings.gd`.
- Add read/write/validate/apply logic in `SettingsManager`.
- Keep strict sanitization and fallback behavior.

### Save Data

- Add fields to `core/context/save_data.gd`.
- Update migration/normalization in `SaveData.from_variant(...)`.
- Keep compatibility rules explicit and deterministic.

## Extend Input

- Add action metadata in `InputManager.ACTION_METADATA`.
- Add action to `InputManager.REBINDABLE_ACTIONS` if user-editable.
- Add default bindings and gamepad defaults where required.
- Expose labels through localization keys.

## Extend Localization

- Add keys to `translations/UI.csv`.
- Use static keys in `.tscn` for fixed labels.
- Use `tr("UI_KEY")` in scripts for runtime strings.
- Run smoke and check localization coverage before merge.

## Add New Modal or Shared UI Primitive

- Prefer `shared/ui/components/` for reusable primitives.
- Inherit modals from `BaseModal`.
- Keep backdrop/cancel behavior explicit.
- Let `UiShell` own stacking and visibility behavior.
