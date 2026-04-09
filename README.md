# Godot Bootstrap Template

Current version: `0.3.0`

## EN

Infrastructure-first Godot 4.x template for building 2D games.

This repository is not a gameplay framework. It gives you a stable project base:

- app flow and scene transitions
- save/settings/input/localization services
- shared UI shell (HUD, modals, loading, feedback)
- debug overlay and smoke checks

### Requirements

- Godot `4.6.x`
- Windows/macOS/Linux (tested mainly on Windows)

### Quick Start

1. Open the project in Godot.
2. Wait for import to finish.
3. Run `res://main/main.tscn`.
4. Replace demo scenes in `features/` with your own.
5. Extend `SessionContext`, `SaveData`, `UserSettings` for your project.

### Daily Workflow

1. Implement or change your feature.
2. Run smoke:
   `powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1`
3. If needed, run manual checklist:
   `docs/MANUAL_TEST_PLAN.md`
4. Commit only after smoke is `PASS`.

### Files Written At Runtime

- `user://settings.cfg`
- `user://saves/slot_XX.save` and backups (`.bak`)
- `user://input_bindings.save`
- `user://phase0_smoke_result.txt` (after smoke run)

### Documentation

- [Bootstrap Checklist](docs/BOOTSTRAP_CHECKLIST.md)
- [Extension Guide](docs/EXTENSION_GUIDE.md)
- [Demo Replacement Guide](docs/DEMO_REPLACEMENT.md)
- [Manual Test Plan](docs/MANUAL_TEST_PLAN.md)
- [Release Process](docs/RELEASE_PROCESS.md)
- [CI Smoke Troubleshooting](docs/CI_SMOKE_TROUBLESHOOTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Architecture Guardrails](docs/ARCHITECTURE_GUARDRAILS.md)
- [Localization Workflow](docs/LOCALIZATION.md)
- [Code Style](docs/CODESTYLE.md)
- [Changelog](CHANGELOG.md)
- [Roadmap](TODO.md)

## RU

Шаблон на Godot 4.x для старта 2D-игр с упором на инфраструктуру.

Это не набор игровых механик. Репозиторий дает стабильную базу проекта:

- flow приложения и переходы между сценами
- сервисы сохранений, настроек, ввода и локализации
- общий UI-слой (HUD, модалки, загрузка, feedback)
- debug overlay и smoke-проверки

### Требования

- Godot `4.6.x`
- Windows/macOS/Linux (основная проверка на Windows)

### Быстрый старт

1. Откройте проект в Godot.
2. Дождитесь завершения импорта.
3. Запустите `res://main/main.tscn`.
4. Замените demo-сцены в `features/` на свои.
5. Расширьте `SessionContext`, `SaveData`, `UserSettings` под ваш проект.

### Ежедневный процесс работы

1. Внесите изменения.
2. Запустите smoke:
   `powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1`
3. При необходимости пройдите ручной чеклист:
   `docs/MANUAL_TEST_PLAN.md`
4. Коммитьте изменения только после `PASS` в smoke.

### Какие файлы пишутся во время работы

- `user://settings.cfg`
- `user://saves/slot_XX.save` и backup-файлы (`.bak`)
- `user://input_bindings.save`
- `user://phase0_smoke_result.txt` (после smoke)

### Документация

- [Bootstrap Checklist](docs/BOOTSTRAP_CHECKLIST.md)
- [Extension Guide](docs/EXTENSION_GUIDE.md)
- [Demo Replacement Guide](docs/DEMO_REPLACEMENT.md)
- [Manual Test Plan](docs/MANUAL_TEST_PLAN.md)
- [Release Process](docs/RELEASE_PROCESS.md)
- [CI Smoke Troubleshooting](docs/CI_SMOKE_TROUBLESHOOTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Architecture Guardrails](docs/ARCHITECTURE_GUARDRAILS.md)
- [Localization Workflow](docs/LOCALIZATION.md)
- [Code Style](docs/CODESTYLE.md)
- [Changelog](CHANGELOG.md)
- [Roadmap](TODO.md)
