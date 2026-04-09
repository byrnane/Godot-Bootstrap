# Changelog

## EN

This file tracks template changes by version.

Sections:

- `Added`
- `Changed`
- `Fixed`
- `Removed`

## [0.3.0] - 2026-04-09

Template hardening and production-readiness update focused on debug tooling, smoke quality gates, and onboarding docs.

### Added

- extended `DebugOverlay` with quick actions (clear saves, jump scene, restart session)
- runtime snapshots in debug overlay for router/loading/modal/input state
- expanded smoke checks for scene pipeline, core data containers, audio paths, and runtime localization keys
- one-command local smoke script: `scripts/run_smoke.ps1`
- CI smoke workflow and troubleshooting playbook
- bootstrap checklist, extension guide, architecture guardrails, demo replacement guide, and release process docs

### Changed

- demo gameplay surface is explicitly simulation-only (no mechanic-oriented framing)
- roadmap progress updated through Phase 5.3 documentation tasks

### Fixed

- removed a race condition in smoke transition fallback checks for unknown scenes

## [0.2.0] - 2026-03-17

First production-ready template version with input rebinding and scene transition flow.

### Added

- `InputManager` with saved user bindings
- basic controls rebinding UI in settings
- `TransitionManager` for loading transitions
- separate `LoadingScreen` with text, tip, and progress
- async scene loading in `SceneRouter`
- roadmap in `TODO.md`

### Changed

- `UiShell` now hosts a full loading layer instead of a simple overlay
- base modals were adjusted to be easier to work with in the Godot editor
- documentation was updated to reflect the new template systems

### Fixed

- reduced unpleasant loading screen flicker on fast transitions with a minimum visible time

## [0.1.0] - 2026-03-17

First recorded version of the template.

### Added

- base infrastructure for a Godot 4.x project
- `Main`, `AppFlow`, `SceneRouter`, `UiShell`
- starter menu, gameplay, HUD, and level stub scenes
- settings, save, localization, and audio managers
- base project documentation

### Changed

- documentation was rewritten in a more human-readable project style

## RU

Этот файл фиксирует изменения шаблона по версиям.

Разделы:

- `Added`
- `Changed`
- `Fixed`
- `Removed`

## [0.2.0] - 2026-03-17

Первая рабочая версия шаблона с переназначением управления и системой переходов между сценами.

### Added

- `InputManager` с сохранением пользовательских биндов
- базовый UI для ребинда управления в настройках
- `TransitionManager` для координации загрузочных переходов
- отдельный `LoadingScreen` с текстом, подсказкой и прогрессом
- асинхронная загрузка сцен в `SceneRouter`
- roadmap в `TODO.md`

### Changed

- `UiShell` теперь хостит полноценный loading layer вместо простого overlay
- базовые модалки приведены к более удобному виду для работы в редакторе Godot
- документация обновлена с учётом новых систем шаблона

### Fixed

- убран неприятный эффект мигания loading screen на быстрых переходах через минимальное время показа

## [0.1.0] - 2026-03-17

Первая зафиксированная версия шаблона.

### Added

- базовый инфраструктурный каркас проекта на Godot 4.x
- `Main`, `AppFlow`, `SceneRouter`, `UiShell`
- заготовки главного меню, gameplay-сцены, HUD и уровней
- менеджеры настроек, сохранений, локализации и аудио
- базовая документация по устройству проекта

### Changed

- документация полностью переписана в более человеческий и проектный стиль
