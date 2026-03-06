# Архитектура

Проект делится на четыре слоя.

1. Bootstrap.
2. Infrastructure.
3. Features.
4. Shared.

Базовые сущности:

- `Main`
- `AppFlow`
- `SceneRouter`
- `UiShell`
- `SettingsManager`
- `SaveManager`
- `AudioManager`
- `AppContext`
- `SessionContext`
- `SaveData`
- `UserSettings`
- `Scenes`

Инварианты:

1. Root-сцены меняются только через `SceneRouter`.
2. Решения о навигации принимает только `AppFlow`.
3. Состояние приложения и сессии хранится в `Context` и `SaveData`.
4. `UiShell` не решает, какую root-сцену грузить.
5. Feature-сцены не работают с файловой системой напрямую.
6. Ядро не содержит жанровых сущностей.
