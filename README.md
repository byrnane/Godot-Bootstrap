# Godot 2D Game Template

Current version: `0.4.0`

## EN

A clean Godot 4.x starter for 2D games.
It gives you ready-to-use project infrastructure, but no gameplay mechanics.

### What you get out of the box

- app flow and scene transitions;
- save slots and load flow;
- quick save and autosave (timer, exit, checkpoint);
- settings (audio, video, language) with persistence;
- input rebinding (keyboard/mouse) with persistence;
- localization pipeline (`translations/UI.csv`);
- shared UI shell (HUD host, modals, loading screen, feedback).

### Quick start

1. Open the project in Godot (`4.6.x`).
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

### About documentation

- If you use this repository as a game template, stay with the guides above.
- Internal template-maintenance docs are grouped in [Maintainer Guide](docs/MAINTAINER_GUIDE.md).

## RU

Понятный стартовый шаблон на Godot 4.x для 2D-игр.
В нем есть готовая инфраструктура проекта, но нет игровых механик.

### Что есть из коробки

- flow приложения и переходы между сценами;
- слоты сохранений и загрузка;
- быстрый сейв и автосейвы (таймер, выход, чекпоинт);
- настройки (аудио, видео, язык) с сохранением;
- ребинд ввода (клавиатура/мышь) с сохранением;
- пайплайн локализации (`translations/UI.csv`);
- общий UI-слой (HUD-хост, модалки, экран загрузки, feedback).

### Быстрый старт

1. Откройте проект в Godot (`4.6.x`).
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

### О документации

- Если вы используете репозиторий как шаблон игры, вам достаточно гайдов выше.
- Внутренние документы для развития самого шаблона вынесены в [Maintainer Guide](docs/MAINTAINER_GUIDE.md).
