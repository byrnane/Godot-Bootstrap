# Architecture

## EN

Layers:
1. `main/` - bootstrap entry point
2. `core/` - app infrastructure and long-lived services
3. `features/` - concrete screens, gameplay stubs, modals
4. `shared/` - reusable UI pieces

Main runtime parts:
- `Main` - configures root container and starts app flow
- `AppFlow` - owns top-level navigation
- `SceneRouter` - swaps root scenes
- `UiShell` - owns overlays and modal stack
- `LocalizationManager` - applies locale
- `SettingsManager` - loads, validates, applies, saves settings
- `SaveManager` - loads, validates, migrates, saves game data
- `AppContext` - long-lived app state
- `SessionContext` - current run state
- `Scenes` - scene registry

Rules:
- root scenes change only through `SceneRouter`
- navigation decisions belong to `AppFlow`
- feature scenes use signals and typed APIs
- feature scenes do not read or write files directly
- avoid a global event bus

UI model:
- global UI lives in `UiShell`
- modals are stack-based
- shared modal behavior lives in `BaseModal`
- concrete modals should use inherited scenes

Localization:
- static text: translation keys in `.tscn`
- dynamic text: `tr()` in code
- translation source: `translations/UI.csv`

Persistence:
- `UserSettings` and `SaveData` are versioned
- unknown future versions are rejected
- persistence and migration logic stay inside managers

## RU

Слои:
1. `main/` - точка входа и bootstrap
2. `core/` - инфраструктура приложения и долгоживущие сервисы
3. `features/` - конкретные экраны, gameplay stub, модалки
4. `shared/` - переиспользуемые UI-части

Основные runtime-сущности:
- `Main` - настраивает root container и запускает app flow
- `AppFlow` - управляет верхнеуровневой навигацией
- `SceneRouter` - переключает root-сцены
- `UiShell` - владеет overlay и стеком модалок
- `LocalizationManager` - применяет локаль
- `SettingsManager` - загружает, валидирует, применяет и сохраняет настройки
- `SaveManager` - загружает, валидирует, мигрирует и сохраняет данные игры
- `AppContext` - долгоживущее состояние приложения
- `SessionContext` - состояние текущего запуска
- `Scenes` - реестр сцен

Правила:
- root-сцены меняются только через `SceneRouter`
- решения по навигации принимает `AppFlow`
- feature-сцены общаются через сигналы и typed API
- feature-сцены не работают с файлами напрямую
- глобальный event bus не используется

UI-модель:
- глобальный UI живет в `UiShell`
- модалки работают как стек
- общее поведение модалок живет в `BaseModal`
- конкретные модалки должны делаться через inherited scenes

Локализация:
- статический текст: ключи прямо в `.tscn`
- динамический текст: `tr()` в коде
- источник переводов: `translations/UI.csv`

Persistence:
- `UserSettings` и `SaveData` версионируются
- неизвестные будущие версии не читаются вслепую
- логика сохранения и миграций остается в менеджерах