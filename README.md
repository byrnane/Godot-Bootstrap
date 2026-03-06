# Godot Bootstrap

## EN

Reusable Godot 4.x starter project for small and mid-sized games.

Included:
- app bootstrap with `Main`, `AppFlow`, `SceneRouter`
- global `UiShell` with modal stack and backdrop
- inherited modal scenes based on `BaseModal`
- main menu, gameplay stub, level stubs
- versioned settings and save pipelines
- Godot-native localization from `translations/UI.csv`

Use this template as app infrastructure, not as a gameplay framework.

Core rules:
- root scene changes only through `SceneRouter`
- top-level flow lives in `AppFlow`
- app state lives in `AppContext`
- session state lives in `SessionContext`
- feature scenes do not access filesystem directly
- static UI text should use translation keys directly in `.tscn`

Using the template:
1. Open the project in Godot 4.x.
2. Let Godot import resources.
3. Run the configured main scene.
4. Replace demo feature scenes with your own.
5. Extend `Scenes`, `SessionContext`, `SaveData`, `UserSettings`.
6. Add new translation keys to `translations/UI.csv`.
7. Build new modals as inherited scenes from `BaseModal`.

Project writes to:
- `user://settings.cfg`
- `user://savegame.save`

Template input actions:
- `ui_pause`
- `ui_cancel`

Docs:
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [CODESTYLE.md](./CODESTYLE.md)

## RU

Переиспользуемый стартовый проект на Godot 4.x для небольших и средних игр.

Внутри:
- bootstrap приложения: `Main`, `AppFlow`, `SceneRouter`
- глобальный `UiShell` со стеком модалок и backdrop
- наследуемые modal-сцены на базе `BaseModal`
- главное меню, gameplay stub и заглушки уровней
- версионируемые пайплайны настроек и сохранений
- нативная локализация Godot через `translations/UI.csv`

Шаблон задуман как инфраструктура приложения, а не как gameplay-framework.

Основные правила:
- root-сцены меняются только через `SceneRouter`
- верхнеуровневый flow живет в `AppFlow`
- состояние приложения живет в `AppContext`
- состояние игровой сессии живет в `SessionContext`
- feature-сцены не работают с файловой системой напрямую
- статический UI-текст лучше задавать translation key прямо в `.tscn`

Как использовать шаблон:
1. Открыть проект в Godot 4.x.
2. Дождаться импорта ресурсов.
3. Запустить главную сцену.
4. Заменить demo feature-сцены своими.
5. Расширить `Scenes`, `SessionContext`, `SaveData`, `UserSettings`.
6. Добавлять новые ключи в `translations/UI.csv`.
7. Новые модалки делать через наследование от `BaseModal`.

Проект пишет файлы:
- `user://settings.cfg`
- `user://savegame.save`

Input actions шаблона:
- `ui_pause`
- `ui_cancel`

Документация:
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [CODESTYLE.md](./CODESTYLE.md)