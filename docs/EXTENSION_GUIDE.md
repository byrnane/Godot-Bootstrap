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

### Alternate Root Scene IDs

`GameConfig.start_scene_id` and `gameplay_scene_id` set the default registered IDs.
`AppStartupParams.main_menu_scene_id` and `SessionStartParams.gameplay_scene_id`
can override them. AppFlow connects menu/gameplay intent signals to the selected
roots and preserves the selected gameplay root for pause, restart and slot loading
in the current process. Return-to-menu uses the menu selected at startup.
A failed load leaves the previous gameplay role intact.

Root IDs are not stored in SaveData. To use the same roots after restarting the
application, set them in GameConfig or provide the startup/session parameters again.

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
- Use `SaveManager.saves_changed` to refresh save-dependent UI after a successful write or a delete request. Technical recovery preserves the original timestamp and thumbnail; it does not make a save newer.

### Autosave Hooks

- Timer and exit autosave are handled by `AutosaveManager`.
- For gameplay checkpoints, emit explicit hooks:
  - `AutosaveManager.emit_checkpoint(checkpoint_id, payload)`
- For score-based checkpoint simulation, call:
  - `AutosaveManager.notify_score_changed(score)`

## Extend Input

- Add action metadata in `InputManager.ACTION_METADATA`.
- Add action to `InputManager.REBINDABLE_ACTIONS` if user-editable.
- Add default bindings and gamepad defaults where required.
- Expose labels through localization keys.

## Extend Localization

- Add keys to `translations/UI.csv`.
- Use static keys in `.tscn` for fixed labels.
- Use `tr("UI_KEY")` in scripts for runtime strings.
- Run only affected smoke suites; use `-Suite localization` for localization changes. See `TESTING.md`.

## Add New Modal or Shared UI Primitive

- Prefer `shared/ui/components/` for reusable primitives.
- Inherit modals from `BaseModal`.
- Keep backdrop/cancel behavior explicit.
- Let `UiShell` own stacking and visibility behavior.
- Keep component data and intent signals separate from screen controllers and managers.
- Use semantic Godot Theme variations; replace the theme to change appearance.
- Add a standalone example to `shared/ui/catalog/ui_catalog.tscn`.

See [UI Framework](UI_FRAMEWORK.md) for the component contracts and skin workflow. A new visual style does not need a separate autoload, modal stack or persistence implementation.

## Дополнительные игровые данные и ввод

`SaveData.game_data` и `SessionContext.game_data` — словарь конкретной игры. Общая база
не интерпретирует его содержимое. При загрузке прежних сейвов словарь пустой; при
снимках, восстановлении и преобразовании данных он копируется глубоко.

`SessionContext.session_exists` изначально false; `reset()` создает новую сессию.
Режим `SessionStartParams.Mode.RESUME_OR_CONTINUE_OR_NEW` сохраняет текущую сессию
в памяти, если она есть, иначе загружает последнее сохранение или создает новую.
Существующие режимы запуска сохраняют прежний смысл. Меню может объявить
`session_start_requested(params: SessionStartParams)`; AppFlow подключит его
к общему запуску сессии.

Игровые действия объявляются в ProjectSettings/InputMap. Их метаданные задаются в
`GameConfigData.input_actions`: имя действия и словарь `label_key`, `group_key`,
`conflict_group`. Привязки клавиатуры/мыши редактирует существующий InputManager,
геймпадные события проекта сохраняются как фиксированные. Игровые действия могут
использовать клавиши навигации меню; системные пауза/отмена и отладка участвуют
в обычном разрешении конфликтов. Противоположные игровые направления должны
иметь разные conflict_group. `InputManager.last_device` и `device_changed`
помогают обновлять подсказки. `UiShell.has_open_modals()` позволяет блокировать
игровой ввод, пока открыто общее окно.

Начальный fullscreen следует `display/window/size/mode`; значение из settings.cfg
имеет приоритет. В Web fullscreen запрашивается только из обработчика ввода.
