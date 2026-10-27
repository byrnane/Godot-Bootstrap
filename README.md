# Godot Game Template

Current version: `0.4.0` + unreleased template variants and universal UI

Цель проекта — универсальный шаблон разработки игр на Godot и специализированные шаблоны для 2D, 2D PixelArt и 3D. Игры создаются в отдельных репозиториях клонированием выбранной ветки.

Основное ядро и основная разработка находятся в `main`. Ветки `2d` и `3d` получают его изменения напрямую, а `2d-pixelart` наследует ядро и игровую логику через `2d`. Все варианты должны содержать актуальную закоммиченную базу `main`. Специфика PixelArt — собственные ассеты, представление и настройки. Общие изменения переносятся обычным merge в порядке `main → 2d → 2d-pixelart` и `main → 3d`.

Начать работу: [короткая инструкция](docs/START_HERE.md). Состав и обновления: [варианты шаблона](docs/VARIANTS.md). Текущее состояние и границы проверки: [READINESS.md](docs/READINESS.md).

В этой ветке: [3D-прототип](docs/3D_EXAMPLE.md) — три комнаты, зомби, пистолет,
переключение первого и третьего лица. [Рабочий процесс Blender/MCP/Godot](docs/3D_WORKFLOW.md).

## EN

A clean Godot 4.x starter for 2D and 3D games.
The common `main` base provides project infrastructure without genre mechanics; specialized branches add their own gameplay features and content.

### What you get out of the box

- app flow and scene transitions;
- save slots and load flow;
- quick save and autosave (timer, exit, checkpoint);
- settings (audio, video, language) with persistence;
- input rebinding (keyboard/mouse) with persistence;
- localization pipeline (`translations/UI.csv`);
- shared UI shell (HUD host, modals, loading screen, feedback);
- native Godot Theme with semantic roles, reusable controls and HUD components, and an F6 component catalog;
- a shared UI contract for all variants, with a compact layout for the 640×360 pixelart viewport.

### Quick start

Choose `3d`, `2d`, or `2d-pixelart` and clone that branch into a separate game repository first. See the [branch selection guide](docs/START_HERE.md).

1. Install pinned addons: `pwsh -File scripts/install_addons.ps1`, then open the project in Godot (`4.7.2`).
2. Run `res://main/main.tscn`.
3. Replace demo scenes in `features/` with your own scenes.
4. Extend `SessionContext`, `SaveData`, and `UserSettings` for your game.
5. Rename project metadata in `project.godot` and replace `icon.svg`.

### Runtime files

- `user://settings.cfg`
- `user://saves/manual_*.save`, `user://saves/quick.save`, `user://saves/autosave.save`
- `user://input_bindings.save`
- `user://saves/thumbnails/*.png` (optional, if thumbnail capture is enabled)

### Start here

- [Docs Index](docs/README.md)
- [Bootstrap Checklist](docs/BOOTSTRAP_CHECKLIST.md)
- [Demo Replacement Guide](docs/DEMO_REPLACEMENT.md)
- [Extension Guide](docs/EXTENSION_GUIDE.md)
- [Localization Workflow](docs/LOCALIZATION.md)
- [UI Framework](docs/UI_FRAMEWORK.md)

### About documentation

- If you use this repository as a game template, stay with the guides above.
- Internal template-maintenance docs are grouped in [Maintainer Guide](docs/MAINTAINER_GUIDE.md).

## RU

Понятный стартовый шаблон на Godot 4.x для 2D- и 3D-игр.
Общая база `main` предоставляет инфраструктуру; эта ветка добавляет игровой 3D-пример.

### Что есть из коробки

- flow приложения и переходы между сценами;
- слоты сохранений и загрузка;
- быстрый сейв и автосейвы (таймер, выход, чекпоинт);
- настройки (аудио, видео, язык) с сохранением;
- ребинд ввода (клавиатура/мышь) с сохранением;
- пайплайн локализации (`translations/UI.csv`);
- общий UI-слой (HUD-хост, модалки, экран загрузки, feedback);
- нативная Godot Theme с семантическими ролями, компоненты экранов и HUD, каталог для запуска через F6;
- общий UI-контракт для всех вариантов и компактная компоновка под viewport 640×360.

### Быстрый старт

Сначала выберите `3d`, `2d` или `2d-pixelart` и клонируйте выбранную ветку в отдельный репозиторий игры. Команды — в [инструкции начала работы](docs/START_HERE.md).

1. Установите аддоны: `pwsh -File scripts/install_addons.ps1`, затем откройте проект в Godot (`4.7.2`).
2. Запустите `res://main/main.tscn`.
3. Замените demo-сцены в `features/` на свои.
4. Расширьте `SessionContext`, `SaveData` и `UserSettings` под свою игру.
5. Обновите метаданные проекта в `project.godot` и замените `icon.svg`.

### Файлы, которые создаются во время работы

- `user://settings.cfg`
- `user://saves/manual_*.save`, `user://saves/quick.save`, `user://saves/autosave.save`
- `user://input_bindings.save`
- `user://saves/thumbnails/*.png` (опционально, если включены превью)

### С чего начать

- [Docs Index](docs/README.md)
- [Bootstrap Checklist](docs/BOOTSTRAP_CHECKLIST.md)
- [Demo Replacement Guide](docs/DEMO_REPLACEMENT.md)
- [Extension Guide](docs/EXTENSION_GUIDE.md)
- [Localization Workflow](docs/LOCALIZATION.md)
- [UI Framework](docs/UI_FRAMEWORK.md)

### О документации

- Если вы используете репозиторий как шаблон игры, вам достаточно гайдов выше.
- Внутренние документы для развития самого шаблона вынесены в [Maintainer Guide](docs/MAINTAINER_GUIDE.md).
