# TODO

## EN

### Next

- polish `InputManager` after real project usage
- document postponed gamepad support and gamepad rebinding separately from keyboard and mouse

### Roadmap

#### `v0.2.x`

- improve how current bindings are shown in UI
- postpone gamepad support and gamepad rebinding until the keyboard and mouse layout is stable
- improve audio workflow for music, UI sounds, and common one-shot playback
- polish modal UX and common UI behavior

#### `v0.3.0`

- extract `GameConfig` as a separate runtime entity near `SessionContext`
- introduce typed payloads for scene transitions instead of generic `Variant`
- simplify starting a new session with explicit parameters
- add a cleaner music and ambient control layer for scene-driven playback
- add baseline gamepad support with a fixed default scheme

#### `v0.4.0`

- add more dev tools on top of `DebugOverlay`
- add quick debug actions: clear save, jump to scene, restart session
- add basic smoke checks for scene loading and core data
- add simple audio smoke checks for buses and missing playback paths
- add optional gamepad rebinding once the fixed scheme is validated

#### `v0.5.0`

- rework shared UI components
- replace the current `SettingsModal` tab solution with a cleaner custom one
- add a reusable custom button component with hover and press sounds
- add reusable UI and gameplay audio helper components
- continue polishing interface patterns for real projects

## RU

### Ближайшее

- отполировать `InputManager` после реального использования
- отдельно зафиксировать, что поддержка геймпада и ребиндинг геймпада отложены

### Дорожная карта

#### `v0.2.x`

- улучшить вывод текущих биндов в UI
- отложить поддержку геймпада и ребиндинг геймпада до стабилизации схемы клавиатуры и мыши
- улучшить workflow для музыки, UI-звуков и типового one-shot playback
- отполировать UX модалок и общее поведение UI

#### `v0.3.0`

- вынести `GameConfig` как отдельную runtime-сущность рядом с `SessionContext`
- ввести typed payload для переходов сцен вместо общего `Variant`
- упростить запуск новой сессии с явными параметрами
- добавить более чистый слой управления музыкой и ambient-воспроизведением на уровне сцен
- добавить базовую поддержку геймпада с фиксированной схемой управления

#### `v0.4.0`

- добавить больше dev-инструментов поверх `DebugOverlay`
- добавить быстрые debug-действия: очистка сохранения, переход на сцену, перезапуск сессии
- добавить базовые smoke-проверки для загрузки сцен и ключевых данных
- добавить простые audio smoke-checks для шин и типовых путей воспроизведения
- добавить опциональный ребиндинг геймпада после проверки фиксированной схемы

#### `v0.5.0`

- переработать общие UI-компоненты
- заменить текущее решение со вкладками в `SettingsModal` на более чистое кастомное
- добавить переиспользуемую кастомную кнопку со звуками hover и press
- добавить переиспользуемые UI- и gameplay-audio helper-компоненты
- продолжить полировку интерфейсных паттернов для реальных проектов
