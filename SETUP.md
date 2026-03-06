# Setup

Этот документ описывает, как подключить и запустить шаблон в новом пустом проекте Godot 4.x.

## 1. Базовая структура

В корне проекта должны существовать каталоги:

- `main/`
- `core/`
- `features/`
- `shared/`

И файлы документации:

- `README.md`
- `ARCHITECTURE.md`
- `COMMUNICATION.md`
- `CODESTYLE.md`
- `STRUCTURE.md`
- `SETUP.md`

## 2. Главная сцена приложения

Нужно создать стартовую сцену:

- `res://main/main.tscn`

Эта сцена будет корневой точкой приложения.

Внутри нее ожидаются:

- корневой узел `Node`
- контейнер для root-сцен

После создания сцены ее нужно назначить как `Main Scene` в `project.godot`.

## 3. Autoload-модули

Шаблон предполагает следующие autoload-модули.

Порядок важен.

1. `AppContext` -> `res://core/context/app_context.gd`
2. `SessionContext` -> `res://core/context/session_context.gd`
3. `SettingsManager` -> `res://core/services/settings_manager.gd`
4. `SaveManager` -> `res://core/services/save_manager.gd`
5. `AudioManager` -> `res://core/services/audio_manager.gd`
6. `SceneRouter` -> `res://core/services/scene_router.gd`
7. `UiShell` -> `res://core/services/ui_shell.tscn`
8. `AppFlow` -> `res://core/flow/app_flow.gd`

Важно:

- `AppContext` и `SessionContext` в шаблоне являются singleton-нодами и создают внутренние данные состояния;
- `Main` должен вызвать bootstrap после запуска сцены, чтобы `SceneRouter` получил корневой контейнер до первого перехода;
- `AppFlow` не должен сам загружать сцену до вызова `startup()` из `Main`.

## 4. Настройка project.godot

Нужно проверить или настроить:

- `run/main_scene` -> `res://main/main.tscn`
- автозагрузки из списка выше
- базовые input actions, если они нужны шаблону

Минимально стоит добавить action:

- `ui_pause`

Рекомендуемая привязка:

- `Escape`

## 5. Обязательные feature-сцены

Для рабочего минимального шаблона нужны сцены:

- `res://features/main_menu/main_menu.tscn`
- `res://features/gameplay/gameplay_stub.tscn`
- `res://features/levels/level_stub_a.tscn`
- `res://features/levels/level_stub_b.tscn`
- `res://features/ui/modals/pause_modal.tscn`
- `res://features/ui/modals/settings_modal.tscn`

Пути этих сцен уже должны совпадать с `Scenes` registry.

## 6. Обязательные контракты

### Root-сцены

Root-сцены могут реализовывать методы:

- `on_enter(payload: Variant = null) -> void;`
- `on_exit() -> void;`

Если методы существуют, `SceneRouter` будет их вызывать.

### Main

`Main` должен в `_ready()` сделать минимум два действия:

1. передать `SceneRouter` ссылку на root-container;
2. вызвать `AppFlow.startup()`.

## 7. Сохранения и настройки

Ожидаемые файлы в `user://`:

- `settings.cfg`
- `savegame.save`

Важно:

- `UserSettings` и `SaveData` должны иметь версию формата;
- `SaveManager` должен корректно обрабатывать отсутствие файла.

## 8. Проверка после подключения

После настройки проекта нужно проверить:

1. Проект стартует и не падает на инициализации autoload.
2. `Main` вызывает bootstrap корректно.
3. `AppFlow` переводит приложение в главное меню.
4. `SceneRouter` умеет загрузить `main_menu`.
5. `UiShell` создается корректно.
6. Настройки можно прочитать и применить.
7. `SaveManager` корректно переживает отсутствие сохранения.
