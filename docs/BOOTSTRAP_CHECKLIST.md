# Project Bootstrap Checklist

Use this checklist when creating a new game from this template.

## 1. Identity and Metadata

- Rename project in `project.godot` (`application/config/name`).
- Replace `icon.svg`.
- Set initial template version policy in `VERSION`.
- Add your team/project metadata in `README.md`.

## 2. Scene and Flow Wiring

- Register your root scenes in `core/registry/scenes.gd`.
- Update runtime defaults in `core/config/default_game_config.tres`:
  - `start_scene_id`
  - `gameplay_scene_id`
  - `main_menu_music`
- Verify startup flow from `AppFlow.startup()`.

## 3. State and Persistence Contracts

- Extend `SessionContext` with your runtime session fields.
- Extend `SaveData` and migration logic for new persisted fields.
- Extend `UserSettings` only for real user-owned options.
- Run save/load flows and confirm backward compatibility behavior.

## 4. Input and Localization Baseline

- Define required input actions in `InputManager` metadata.
- Verify default keyboard and gamepad mappings.
- Add all required static and runtime localization keys to `translations/UI.csv`.
- Verify locale switch and text refresh on active screens.

## 5. UI and Feature Surfaces

- Replace template demo scenes in `features/` with your own screens.
- Keep HUD/modals inside shared `UiShell` contracts.
- Reuse shared components from `shared/ui/components` before creating custom duplicates.

## 6. Quality Gates Before First Milestone

- Launch the game from `res://main/main.tscn`.
- Check your core loop: main menu -> gameplay -> pause/settings -> back to menu.
- Verify save/load, settings persistence, and locale switch in your customized scenes.
