# TODO

## EN

### Next

- validate the new shared UI infrastructure on more screens and future template flows
- keep keyboard and mouse rebinding polish separate from postponed gamepad support

### Roadmap

#### `v0.2.x`

- improve how current bindings are shown in UI
- postpone gamepad support and gamepad rebinding until the keyboard and mouse layout is stable
- continue polishing modal UX and common UI behavior on top of the new shared UI layer

#### `v0.3.0`

- extract `GameConfig` as a separate runtime entity near `SessionContext`
- introduce typed payloads for scene transitions instead of generic `Variant`
- simplify starting a new session with explicit parameters
- add a cleaner music and ambient control layer for scene-driven playback
- add baseline gamepad support with a fixed default scheme
- continue adopting `shared/ui/components`, `shared/ui/navigation`, and `shared/ui/motion` in new template features

#### `UI/UX infrastructure`

- [done] `Components + feedback`
- [done] `Navigation primitives`
- [done] `Transitions + motion`

#### `v0.4.0`

- add more dev tools on top of `DebugOverlay`
- add quick debug actions: clear save, jump to scene, restart session
- add basic smoke checks for scene loading and core data
- add simple audio smoke checks for buses and missing playback paths
- add optional gamepad rebinding once the fixed scheme is validated

## RU

### Ближайшее

- проверить новую общую UI-инфраструктуру на других экранах и будущих flow шаблона
- держать полировку ребиндинга клавиатуры и мыши отдельно от отложенной поддержки геймпада

### Дорожная карта

#### `v0.2.x`

- улучшить вывод текущих биндов в UI
- отложить поддержку геймпада и ребиндинг геймпада до стабилизации схемы клавиатуры и мыши
- продолжить полировку UX модалок и общего поведения UI уже поверх нового shared UI-слоя

#### `v0.3.0`

- вынести `GameConfig` как отдельную runtime-сущность рядом с `SessionContext`
- ввести typed payload для переходов сцен вместо общего `Variant`
- упростить запуск новой сессии с явными параметрами
- добавить более чистый слой управления музыкой и ambient-воспроизведением на уровне сцен
- добавить базовую поддержку геймпада с фиксированной схемой управления
- продолжить внедрение `shared/ui/components`, `shared/ui/navigation` и `shared/ui/motion` в новые части шаблона

#### `UI/UX инфраструктура`

- [done] `Components + feedback`
- [done] `Navigation primitives`
- [done] `Transitions + motion`

#### `v0.4.0`

- добавить больше dev-инструментов поверх `DebugOverlay`
- добавить быстрые debug-действия: очистка сохранения, переход на сцену, перезапуск сессии
- добавить базовые smoke-проверки для загрузки сцен и ключевых данных
- добавить простые audio smoke-checks для шин и типовых путей воспроизведения
- добавить опциональный ребиндинг геймпада после проверки фиксированной схемы
