# Project Bootstrap Checklist

Use this checklist when creating a new game from this template.

## 0. Выбор варианта и отдельный репозиторий

- Выберите ветку: `3d` для 3D, `2d` для обычного 2D, `2d-pixelart` для пиксельного 2D. `main` содержит только общую базу с нейтральными заглушками.
- Клонируйте выбранную ветку в отдельный репозиторий игры и назначьте ему собственный `origin`: [команды](START_HERE.md).
- Обновите `AGENTS.md` под игру. Правила обновления веток шаблона к игре не относятся; она развивается самостоятельно.
- Установите закрепленные аддоны выбранной ветки командой `pwsh -File scripts/install_addons.ps1`.
- Для `2d-pixelart` проверьте компактный UI при 640×360 и целочисленное увеличение окна; функции общих экранов сохраняются.

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
- Open `shared/ui/catalog/ui_catalog.tscn` with F6 and choose or duplicate `shared/ui/theme/neutral_theme.tres`; preserve semantic Theme variations. See [UI Framework](UI_FRAMEWORK.md).
- Replace the menu illustration in `shared/ui/theme/art/` if needed; keep licenses for bundled fonts and any replacement assets.
- Check long RU/EN labels, visible keyboard focus, scrolling, and your target viewport. Pixelart needs its own skin and layout acceptance.

## 6. Quality Gates Before First Milestone

- Launch the game from `res://main/main.tscn`.
- Check your core loop: main menu -> gameplay -> pause/settings -> back to menu.
- Verify save/load, settings persistence, and locale switch in your customized scenes.
- Verify save-slots UX (manual, quick, autosave) and continue-from-latest behavior.
