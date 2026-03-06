# Godot Bootstrap

## EN

Reusable Godot 4.x starter project for small and mid-sized games.

Included:
- app bootstrap with `Main`, `AppFlow`, `SceneRouter`
- global `UiShell` with HUD host, modal stack, and backdrop
- scene-driven HUD lifecycle through `SceneRouter`
- inherited modal scenes based on `BaseModal`
- main menu, gameplay world stub, gameplay HUD, and level stubs
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

Scene and HUD lifecycle:
- `SceneRouter` mounts exactly one root scene
- scenes may optionally expose `get_hud_scene()`, `bind_hud(hud)`, and `unbind_hud(hud)`
- `UiShell` hosts the active HUD separately from the world scene
- world logic pushes data to HUD through feature-level signals or typed APIs

Using the template:
1. Open the project in Godot 4.x.
2. Let Godot import resources.
3. Run the configured main scene.
4. Replace demo feature scenes with your own.
5. Extend `Scenes`, `SessionContext`, `SaveData`, `UserSettings`.
6. Add new translation keys to `translations/UI.csv`.
7. Build new modals as inherited scenes from `BaseModal`.
8. For scenes with HUD, expose the optional HUD hooks and keep HUD presentation-only.

Project writes to:
- `user://settings.cfg`
- `user://savegame.save`

Template input actions:
- `ui_pause`
- `ui_cancel`

Docs:
- [ARCHITECTURE.md](./docs/ARCHITECTURE.md)
- [CODESTYLE.md](./docs/CODESTYLE.md)

## RU

Переиспользуемый стартовый проект на Godot 4.x для небольших и средних игр.

Внутри:
- bootstrap приложения: `Main`, `AppFlow`, `SceneRouter`
- глобальный `UiShell` с хостом для HUD, стеком модалок и backdrop
- lifecycle HUD на стороне сцены через `SceneRouter`
- наследуемые modal-сцены на базе `BaseModal`
- главное меню, gameplay world stub, gameplay HUD и заглушки уровней
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

Lifecycle сцены и HUD:
- `SceneRouter` монтирует ровно одну root-сцену
- сцена может опционально объявить `get_hud_scene()`, `bind_hud(hud)` и `unbind_hud(hud)`
- `UiShell` отображает активный HUD отдельно от world-сцены
- логика мира отправляет данные в HUD через сигналы feature-слоя или typed API

Как использовать шаблон:
1. Открыть проект в Godot 4.x.
2. Дождаться импорта ресурсов.
3. Запустить главную сцену.
4. Заменить demo feature-сцены своими.
5. Расширить `Scenes`, `SessionContext`, `SaveData`, `UserSettings`.
6. Добавлять новые ключи в `translations/UI.csv`.
7. Новые модалки делать через наследование от `BaseModal`.
8. Для сцен с HUD объявлять опциональные HUD-хуки и держать HUD только слоем представления.

Проект пишет файлы:
- `user://settings.cfg`
- `user://savegame.save`

Input actions шаблона:
- `ui_pause`
- `ui_cancel`

Документация:
- [ARCHITECTURE.md](./docs/ARCHITECTURE.md)
- [CODESTYLE.md](./docs/CODESTYLE.md)

