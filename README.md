# Godot Bootstrap

Reusable Godot 4.x starter template for small and mid-sized games.

Current version: `0.2.0`

## EN

This template gives you project infrastructure, not gameplay systems.

Included:

- app entry point with `Main`
- top-level flow with `AppFlow`
- scene switching through `SceneRouter`
- global UI shell with HUD, modal stack, and loading layer
- `InputManager` with basic rebind support
- `TransitionManager` with async scene loading
- settings, save, audio, and localization services
- starter scenes for menu, gameplay, HUD, and levels

Project layout:

- `main/` - app entry
- `core/` - flow, services, state, scene registry
- `features/` - concrete game and UI scenes
- `shared/` - shared UI assets and reusable pieces
- `translations/` - localization source

Quick start:

1. Open the project in Godot 4.x.
2. Wait for resource import.
3. Run the main scene.
4. Replace demo scenes in `features/` with your own.
5. Extend `SessionContext`, `SaveData`, and `UserSettings`.
6. Add scene ids to `core/registry/scenes.gd`.
7. Add translation keys to `translations/UI.csv`.

Core rules:

- root scenes change only through `SceneRouter`
- top-level navigation lives in `AppFlow`
- long-lived app state lives in `AppContext`
- current run state lives in `SessionContext`
- feature scenes do not access the filesystem directly
- static UI text should use translation keys in `.tscn`

Input actions included by default:

- `ui_pause`
- `ui_cancel`

These actions can already be rebound through settings.

Project writes:

- `user://settings.cfg`
- `user://savegame.save`
- `user://input_bindings.save`

Docs:

- [Architecture](docs/ARCHITECTURE.md)
- [Code Style](docs/CODESTYLE.md)
- [Changelog](CHANGELOG.md)
- [Todo / Roadmap](TODO.md)
- [Bootstrap Checklist](docs/BOOTSTRAP_CHECKLIST.md)
- [Extension Guide](docs/EXTENSION_GUIDE.md)
- [Architecture Guardrails](docs/ARCHITECTURE_GUARDRAILS.md)
- [Demo Replacement Guide](docs/DEMO_REPLACEMENT.md)
- [Release Process](docs/RELEASE_PROCESS.md)
- [Manual Test Plan](docs/MANUAL_TEST_PLAN.md)
- [CI Smoke Troubleshooting](docs/CI_SMOKE_TROUBLESHOOTING.md)

Smoke (one command):

- `powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1`
- Optional explicit binary: `powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1 -GodotExecutable "C:\Path\To\godot.exe"`
- Optional headless mode: `powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1 -Headless`

## RU

Это стартовый шаблон на Godot 4.x для небольших и средних игр.

Здесь есть именно инфраструктура проекта, а не готовый gameplay-фреймворк.

Что уже входит:

- точка входа `Main`
- верхнеуровневый flow через `AppFlow`
- переключение сцен через `SceneRouter`
- общий UI-слой с HUD, модалками и экраном загрузки
- `InputManager` с базовым ребиндом управления
- `TransitionManager` и асинхронная загрузка сцен
- сервисы настроек, сохранений, аудио и локализации
- заготовки меню, gameplay-сцены, HUD и уровней

Структура проекта:

- `main/` - вход в приложение
- `core/` - flow, сервисы, состояние, реестр сцен
- `features/` - конкретные игровые и UI-сцены
- `shared/` - общие UI-ресурсы и переиспользуемые элементы
- `translations/` - исходники локализации

Быстрый старт:

1. Откройте проект в Godot 4.x.
2. Дождитесь импорта ресурсов.
3. Запустите главную сцену.
4. Замените демо-сцены в `features/` на свои.
5. Расширьте `SessionContext`, `SaveData` и `UserSettings`.
6. Добавьте свои scene id в `core/registry/scenes.gd`.
7. Добавьте ключи локализации в `translations/UI.csv`.

Основные правила:

- корневые сцены меняются только через `SceneRouter`
- верхнеуровневая навигация живёт в `AppFlow`
- долгоживущее состояние хранится в `AppContext`
- состояние текущей сессии хранится в `SessionContext`
- feature-сцены не работают с файловой системой напрямую
- статический UI-текст лучше задавать ключами локализации в `.tscn`

Действия ввода по умолчанию:

- `ui_pause`
- `ui_cancel`

Эти действия уже можно переназначать через настройки.

Проект пишет файлы:

- `user://settings.cfg`
- `user://savegame.save`
- `user://input_bindings.save`

Документация:

- [Архитектура](docs/ARCHITECTURE.md)
- [Стиль кода](docs/CODESTYLE.md)
- [История изменений](CHANGELOG.md)
- [Todo / Roadmap](TODO.md)
