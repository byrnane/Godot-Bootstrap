# Code Style

## EN

GDScript rules:
- use `=` instead of `:=`
- keep semicolons, matching current project style
- add type hints where they help
- prefer explicit names
- move tunable editor values into `@export`
- avoid magic constants when they should be named

Recommended file order:
1. `class_name` and `extends`
2. `signal`
3. `enum`
4. `const`
5. `@export`
6. fields
7. `@onready`
8. lifecycle methods
9. public API
10. private helpers
11. signal handlers

UI rules:
- static text should use translation keys in `.tscn`
- `tr()` in code is for dynamic text only
- modals should inherit from `BaseModal`
- avoid writing `.tscn` files with BOM

Architecture rules:
- no root scene changes outside `SceneRouter`
- no filesystem access from feature scenes
- no persistence logic inside UI
- prefer local signals and typed APIs over a global event bus

## RU

Правила для GDScript:
- использовать `=` вместо `:=`
- сохранять `;`, как принято в проекте
- добавлять типы там, где это улучшает читаемость
- использовать явные имена
- значения, настраиваемые в редакторе, выносить в `@export`
- избегать магических констант, если им нужно имя

Рекомендуемый порядок в файле:
1. `class_name` и `extends`
2. `signal`
3. `enum`
4. `const`
5. `@export`
6. поля
7. `@onready`
8. lifecycle methods
9. публичный API
10. приватные helper-методы
11. signal handlers

Правила для UI:
- статический текст лучше задавать translation key в `.tscn`
- `tr()` в коде использовать только для динамического текста
- модалки должны наследоваться от `BaseModal`
- не сохранять `.tscn` с BOM

Архитектурные правила:
- не менять root-сцены вне `SceneRouter`
- feature-сцены не должны работать с файловой системой
- логика сохранений не должна жить в UI
- вместо глобального event bus использовать локальные сигналы и typed API
