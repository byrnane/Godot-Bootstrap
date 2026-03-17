# TODO

## EN

### Next

- add `DebugOverlay`
- polish `LoadingScreen` UX after real project usage
- polish `InputManager` after real project usage

### Roadmap

#### `v0.2.x`

- add basic `DebugOverlay`
- expand the list of rebindable actions
- improve how current bindings are shown in UI
- improve audio workflow for music, UI sounds, and common one-shot playback
- polish modal UX and common UI behavior

#### `v0.3.0`

- extract `GameConfig` as a separate runtime entity near `SessionContext`
- introduce typed payloads for scene transitions instead of generic `Variant`
- simplify starting a new session with explicit parameters
- add a cleaner music and ambient control layer for scene-driven playback

#### `v0.4.0`

- add more dev tools on top of `DebugOverlay`
- add quick debug actions: clear save, jump to scene, restart session
- add basic smoke checks for scene loading and core data
- add simple audio smoke checks for buses and missing playback paths

#### `v0.5.0`

- rework shared UI components
- replace the current `SettingsModal` tab solution with a cleaner custom one
- add a reusable custom button component with hover and press sounds
- add reusable UI and gameplay audio helper components
- continue polishing interface patterns for real projects

## RU

### Ближайшее

- добавить `DebugOverlay`
- отполировать UX `LoadingScreen` после реального использования
- отполировать `InputManager` после реального использования

### Дорожная карта

#### `v0.2.x`

- добавить базовый `DebugOverlay`
- расширить список ребиндимых действий
- улучшить вывод текущих биндов в UI
- улучшить workflow для музыки, UI-звуков и типового one-shot playback
- отполировать UX модалок и общее поведение UI

#### `v0.3.0`

- вынести `GameConfig` как отдельную runtime-сущность рядом с `SessionContext`
- ввести typed payload для переходов сцен вместо общего `Variant`
- упростить запуск новой сессии с явными параметрами
- добавить более чистый слой управления музыкой и ambient-воспроизведением на уровне сцен

#### `v0.4.0`

- добавить больше dev-инструментов поверх `DebugOverlay`
- добавить быстрые debug-действия: очистка сохранения, переход на сцену, перезапуск сессии
- добавить базовые smoke-проверки для загрузки сцен и ключевых данных
- добавить простые audio smoke-checks для шин и типовых путей воспроизведения

#### `v0.5.0`

- переработать общие UI-компоненты
- заменить текущее решение со вкладками в `SettingsModal` на более чистое кастомное
- добавить переиспользуемую кастомную кнопку со звуками hover и press
- добавить переиспользуемые UI- и gameplay-audio helper-компоненты
- продолжить полировку интерфейсных паттернов для реальных проектов
