# Architecture

## EN

This template is intentionally simple and predictable. It is not a universal game architecture. It is a clean application skeleton that keeps the project from turning into a pile of loosely connected scenes and scripts.

### Layers

`main/`

- application entry point

`core/`

- long-lived infrastructure
- flow
- services
- state containers
- types
- scene registry

`features/`

- concrete gameplay and UI scenes
- menu
- gameplay
- HUD
- levels
- modals

`shared/`

- shared UI assets
- theme
- fonts
- icons
- reusable UI pieces

### Main runtime parts

`Main`

- starts the application and wires the base runtime

`AppFlow`

- owns top-level application flow
- decides where the app should go next
- exposes explicit startup/session contracts via `AppStartupParams` and `SessionStartParams`

`SceneRouter`

- the only place that switches root scenes
- owns scene enter/exit flow
- now also owns async scene loading

`UiShell`

- global UI host above world scenes
- owns HUD host, modal stack, backdrop, and loading layer

`AppContext`

- long-lived application state

`SessionContext`

- current run state

`GameConfig`

- runtime template config separated from `SessionContext` and user settings
- resolves configured scene ids and default menu music with safe fallbacks
- loads defaults from `core/config/default_game_config.tres`
- supports optional project overrides via `core/config/game_config_override.tres`

`SettingsManager`

- loads, validates, applies, and saves settings
- keeps settings ownership split by domains (`language`, `audio`, `video`, `input`)
- persists domain sections with backward-compatible read fallback for legacy settings files
- enforces strict type/range validation with fallback defaults for corrupted persisted values
- applies domains through a recovery-aware pipeline and emits apply reports for diagnostics

`SaveManager`

- loads, validates, migrates, and saves game data
- provides minimal save slot support with legacy default-save migration
- keeps per-slot backups and restores from backup when a save file is corrupted

`AudioManager`

- owns runtime audio buses for `Music`, `UI`, and `SFX`
- applies volume settings to buses
- provides one-shot playback for UI and sound effects
- provides a dedicated music playback API

`LocalizationManager`

- applies the active locale

`Scenes`

- central registry of scene ids and paths

`InputManager`

- stores default bindings
- loads saved user bindings
- provides a clean API for UI rebinding
- edits Godot `InputMap` instead of replacing it
- keeps keyboard and mouse rebinding rules in one place
- lets compatible actions share one button through conflict groups
- emits conflict-resolution signals when a rebind clears overlapping bindings
- exposes active rebind action/slot so UI can show precise waiting state
- injects fixed default gamepad bindings for core UI actions

`UiFeedback`

- global entry point for confirm, alert, and toast requests
- keeps callback-based feedback requests out of feature scenes
- lets `UiShell` stay the only place that actually hosts feedback UI
- now uses stable payload fields such as `variant`, `title`, `message`, `duration`, `confirm_text`, `cancel_text`, `close_on_backdrop`, and `close_on_cancel`
- normalizes feedback payload values (variant, durations, booleans, labels) before handing requests to `UiShell`

`TransitionManager`

- coordinates scene transitions and loading UI
- shows loading screen
- updates progress
- finishes the transition cleanly
- supports loading status states (`loading/success/error`) and status-text updates

### Scene flow

Normal flow:

1. `AppFlow` decides which scene should be active.
2. `SceneRouter` starts the transition and async load if needed.
3. `TransitionManager` shows `LoadingScreen`.
4. `SceneRouter` swaps the root scene when loading is done.
5. `SceneRouter` mounts the HUD if the scene provides one.
6. The scene starts working and talks to its HUD through explicit methods and signals.

Transition payloads are passed as `SceneTransitionPayload` objects (instead of generic `Variant`), so scene enter contracts stay explicit and typed.

Important points:

- there is always exactly one active root scene
- HUD is separate from the world scene
- modals live in shared UI
- loading UI also lives in shared UI

### HUD model

A scene may optionally implement:

- `get_hud_scene()`
- `bind_hud(hud)`
- `unbind_hud(hud)`

The idea is simple:

- gameplay logic stays in the world scene
- HUD stays presentation-only
- `SceneRouter` mounts and unmounts it in a controlled way

### Scene contracts

Scenes can expose these optional integration methods:

- `on_enter(payload: SceneTransitionPayload)`
- `on_exit()`
- `get_hud_scene()`
- `bind_hud(hud)`
- `unbind_hud(hud)`

`SceneRouter` validates the HUD-related contract and warns when implementations are inconsistent.
Contract helper constants and checks live in `core/contracts/scene_contracts.gd`.

### Modal model

Modals work as a stack. Shared behavior lives in `BaseModal`, and concrete modals inherit from it.

That keeps modal behavior consistent and makes new windows easier to build.
Backdrop behavior is explicit per modal (`close_on_backdrop`), and cancel-close behavior is explicit via `close_on_cancel`.

Global confirm, alert, and toast requests should go through `UiFeedback`.
`UiShell` still owns the actual presentation layer and stacking.

### Shared UI toolkit

`shared/ui/components/`

- `UiCard`
- `UiSectionHeader`
- `UiFormRow`
- `UiActionBar`
- `UiStatusBadge`
- action rows are configured to keep long localized button labels readable on common template screens

`shared/ui/navigation/`

- `UiTabStrip`
- `UiFocus`
- `UiFocus` also provides reusable cyclic focus wiring for button stacks

`shared/ui/motion/`

- `UiMotion`

The current proving grounds for these primitives are `SettingsModal`, `FeedbackModal`, `ToastItem`, and `LoadingScreen`.

### Scene loading

The template now includes async scene loading through `ResourceLoader.load_threaded_request(...)`.

This gives you:

- fewer visible hitches on heavy scene changes
- a proper loading UI instead of an empty pause
- a clean place for tips, progress, and loading metadata
- per-transition context labels, status badges, and optional tip providers

### Localization

- static text: translation keys in `.tscn`
- dynamic text: `tr()` in code
- source: `translations/UI.csv`
- locale switch goes through `LocalizationManager` and propagates translation-change notifications to active UI
- static UI key coverage is available via `LocalizationManager.get_static_key_coverage_report()`
- workflow and naming conventions live in `docs/LOCALIZATION.md`

### Input binding model

- gameplay and UI still read input through Godot actions such as `Input.is_action_pressed(...)`
- `InputManager` does not introduce a second runtime input system
- `InputManager` only manages which keyboard and mouse events are assigned to those native actions
- user rebinds are saved to `user://input_bindings.save`
- compatible actions may share the same binding when they belong to the same conflict group
- controls UI includes conflict feedback and a confirmed reset-to-default flow
- fixed gamepad defaults are always applied for core UI actions
- gamepad rebinding is intentionally postponed until the fixed mapping is validated in real projects

### Persistence

- `UserSettings` and `SaveData` are versioned
- validation and migration stay inside managers
- save compatibility rules are explicit: versions below minimum or above current are rejected, and slot backup recovery is used when possible

### Rules

- do not change root scenes outside `SceneRouter`
- do not put top-level navigation decisions inside feature scenes
- do not let UI work with the filesystem directly
- do not mix save/load logic into visual scenes
- avoid a global event bus unless there is a strong reason
- prefer local signals and explicit APIs

## RU

Этот шаблон специально собран простым и предсказуемым. Это не универсальная игровая архитектура на все случаи жизни, а чистый каркас приложения, который не даёт проекту развалиться на набор случайно связанных сцен и скриптов.

### Слои

`main/`

- вход в приложение

`core/`

- долгоживущая инфраструктура
- flow
- сервисы
- контейнеры состояния
- типы
- реестр сцен

`features/`

- конкретные игровые и UI-сцены
- меню
- gameplay
- HUD
- уровни
- модалки

`shared/`

- общие UI-ресурсы
- тема
- шрифты
- иконки
- переиспользуемые UI-элементы

### Основные runtime-сущности

`Main`

- запускает приложение и собирает базовый runtime

`AppFlow`

- управляет верхнеуровневым flow приложения
- решает, куда приложение должно идти дальше

`SceneRouter`

- единственное место, которое переключает корневые сцены
- управляет enter/exit flow сцены
- теперь также отвечает за асинхронную загрузку сцен

`UiShell`

- глобальный UI-хост поверх world-сцен
- содержит хост для HUD, стек модалок, затемнение и loading layer

`AppContext`

- долгоживущее состояние приложения

`SessionContext`

- состояние текущего запуска

`SettingsManager`

- загружает, проверяет, применяет и сохраняет настройки

`SaveManager`

- загружает, проверяет, мигрирует и сохраняет игровые данные

`LocalizationManager`

- применяет активную локаль

`Scenes`

- центральный реестр scene id и путей

`InputManager`

- хранит дефолтные бинды
- загружает сохранённые пользовательские бинды
- даёт чистый API для UI-ребинда

`TransitionManager`

- координирует переходы между сценами и loading UI
- показывает экран загрузки
- обновляет прогресс
- корректно завершает переход

### Поток сцен

Нормальный сценарий такой:

1. `AppFlow` решает, какая сцена должна быть активной.
2. `SceneRouter` запускает переход и асинхронную загрузку, если она нужна.
3. `TransitionManager` показывает `LoadingScreen`.
4. `SceneRouter` подменяет корневую сцену после завершения загрузки.
5. `SceneRouter` подключает HUD, если сцена его предоставляет.
6. Сцена начинает работать и общается со своим HUD через явные методы и сигналы.

Что здесь важно:

- активная корневая сцена всегда одна
- HUD живёт отдельно от world-сцены
- модалки живут в общем UI-слое
- экран загрузки тоже живёт в общем UI-слое

### Модель HUD

Сцена может по желанию реализовать:

- `get_hud_scene()`
- `bind_hud(hud)`
- `unbind_hud(hud)`

Смысл простой:

- игровая логика остаётся в world-сцене
- HUD остаётся только слоем представления
- `SceneRouter` монтирует и снимает его в контролируемом порядке

### Модель модалок

Модалки работают как стек. Общее поведение лежит в `BaseModal`, а конкретные окна наследуются от него.

Это удерживает поведение модалок единым и упрощает создание новых окон.

### Загрузка сцен

В шаблоне уже есть асинхронная загрузка сцен через `ResourceLoader.load_threaded_request(...)`.

Это даёт:

- меньше заметных фризов на тяжёлых переходах
- нормальный loading UI вместо пустой паузы
- понятное место для подсказок, прогресса и служебной информации

### Локализация

- статический текст: ключи в `.tscn`
- динамический текст: `tr()` в коде
- источник: `translations/UI.csv`

### Сохранения

- `UserSettings` и `SaveData` версионируются
- проверка и миграции остаются внутри менеджеров

### Правила

- не меняйте корневые сцены в обход `SceneRouter`
- не принимайте верхнеуровневые навигационные решения внутри feature-сцен
- не давайте UI напрямую работать с файловой системой
- не смешивайте save/load логику с визуальными сценами
- не вводите глобальный event bus без серьёзной причины
- предпочитайте локальные сигналы и явные API
