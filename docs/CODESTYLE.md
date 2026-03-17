# Code Style

## EN

These are not abstract perfect rules. These are working agreements for this project so the code stays readable and consistent.

### General principles

- write so the next person understands intent quickly
- prefer simple solutions over clever ones
- if a value should be tuned in the editor, usually move it into `@export`
- if a constant matters, give it a name instead of leaving a magic value
- add type hints where they improve clarity

### GDScript rules

- use `=` instead of `:=`
- keep semicolons to match project style
- use explicit names
- add types where they make code clearer and safer

### Recommended file order

1. `class_name` and `extends`
2. `signal`
3. `enum`
4. `const`
5. `@export`
6. fields
7. `@onready`
8. lifecycle methods
9. public methods
10. private methods
11. signal handlers

### UI rules

- static text should use translation keys in `.tscn`
- `tr()` in code is for dynamic text only
- modals should inherit from `BaseModal`
- do not save `.tscn` files with BOM

### Architecture rules

- no root scene changes outside `SceneRouter`
- no filesystem access from feature scenes
- no persistence logic inside UI
- prefer local signals and explicit APIs over a global event bus

### Practical check

When adding code, quickly ask:

- is this feature code or infrastructure code?
- did I mix UI, navigation, and persistence in one place?
- is the intent obvious from names?
- should this value be an `@export`?
- did I leave unexplained magic values?

## RU

Это не абстрактные идеальные правила. Это рабочие договорённости именно для этого проекта, чтобы код оставался читаемым и единообразным.

### Общие принципы

- пишите так, чтобы следующий человек быстро понял намерение
- предпочитайте простые решения хитрым
- если значение должно настраиваться в редакторе, обычно его лучше вынести в `@export`
- если константа важна, дайте ей имя вместо магического числа или строки
- добавляйте типы там, где они улучшают читаемость

### Правила для GDScript

- используем `=`, а не `:=`
- сохраняем `;`, чтобы стиль проекта оставался единым
- используем явные имена
- добавляем типы там, где они делают код яснее и безопаснее

### Рекомендуемый порядок внутри файла

1. `class_name` и `extends`
2. `signal`
3. `enum`
4. `const`
5. `@export`
6. поля
7. `@onready`
8. lifecycle-методы
9. публичные методы
10. приватные методы
11. обработчики сигналов

### Правила для UI

- статический текст должен использовать ключи локализации в `.tscn`
- `tr()` в коде используем только для динамического текста
- модалки должны наследоваться от `BaseModal`
- не сохраняем `.tscn` с BOM

### Архитектурные правила

- не меняем корневые сцены вне `SceneRouter`
- feature-сцены не работают с файловой системой напрямую
- логика сохранений не должна жить в UI
- вместо глобального event bus предпочитаем локальные сигналы и явные API

### Практическая проверка

Когда добавляете новый код, быстро проверьте:

- это код фичи или код инфраструктуры?
- не смешал ли я UI, навигацию и сохранение в одном месте?
- понятен ли смысл по именам?
- не лучше ли вынести значение в `@export`?
- не оставил ли я магические значения без объяснения?
