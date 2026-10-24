# Architecture Guardrails

This file defines boundaries that keep the template stable.

## Общая база и варианты шаблона

Источник общей логики — `main`. Ветки `3d`, `2d`, `2d-pixelart` получают ее через merge и не заменяют независимыми реализациями.
Специфика варианта находится в настройках, представлении, мировых сценах, ресурсах и аддонах.
Она не должна обходить `AppFlow`, `SceneRouter`, `UiShell` и менеджеры, менять общие контракты или нарушать сценарии сохранений, переходов, настроек, ввода и локализации.
Общие системы не должны обязательно зависеть от ресурсов либо аддонов одного варианта.
Если для варианта нужно расширить общий контракт или сервис, сначала внесите общее изменение в `main`, затем перенесите его во все варианты и проверьте затронутые сценарии.

Порядок обновления: [VARIANTS.md](VARIANTS.md). В отдельном репозитории игры правила веток шаблона не применяются.

## Do Not Modify These Contracts Blindly

## 1. Scene Switching Boundary

- Root scene switches must go only through `SceneRouter`.
- Do not call `change_scene*` directly from feature scripts.
- Do not mount/unmount root scenes from UI nodes.

Why: transition lifecycle, loading state, and HUD binding depend on `SceneRouter`.

## 2. Flow Ownership

- Top-level navigation decisions stay in `AppFlow`.
- Feature scenes emit intent signals, they do not own app routing policy.

Why: keeps global behavior deterministic and testable.

## 3. UI Shell Ownership

- Global modals, loading layer, and toasts are hosted by `UiShell`.
- Do not create ad-hoc global modal stacks in feature scenes.

Why: modal/input/backdrop behavior must remain consistent.

## 4. Persistence Ownership

- Filesystem access for saves/settings/input persistence stays in managers.
- Feature scenes should never read/write `user://` files directly.

Why: versioning, validation, and backup/recovery rules live in one place.

## 5. Context Separation

- `AppContext` is app-lifetime state.
- `SessionContext` is run-lifetime state.
- Do not mix long-lived and per-run state arbitrarily.

Why: prevents hidden reset/persistence bugs.

## 6. Localization Discipline

- Static UI labels should be translation keys in `.tscn`.
- Runtime labels should use `tr("UI_*")` keys.
- Keep keys in `translations/UI.csv`.

Why: smoke checks and runtime locale switch rely on this convention.

## 7. UI Appearance and Component Boundary

- Use native Godot Theme roles for appearance; keep reusable component scenes in `shared/ui/components/`.
- Components receive values and emit intent signals. They do not read contexts, write files, choose routes or implement game rules.
- Screen controllers adapt manager/context data to component properties and view models.
- A different skin preserves these contracts and the existing `UiShell` / `BaseModal` stack.

The catalog and extension rules are in [UI Framework](UI_FRAMEWORK.md). Prototype context copies in the Figma design are a design-preview workaround, not additional runtime modal stacks.

## Safe Customization Surface

You can safely extend:

- `features/` scenes and UI;
- `SessionContext`, `SaveData`, `UserSettings` schemas;
- `InputManager` metadata/default bindings;
- `shared/ui/components` with new reusable primitives;
- `core/config/game_config_override.tres` for per-project runtime defaults.

## Change Control for Core Runtime

If you touch `AppFlow`, `SceneRouter`, `UiShell`, `TransitionManager`, or persistence managers:

1. Run only the affected smoke suites from `TESTING.md`.
2. Use the relevant manual checklist section only when the changed behavior needs native or visual acceptance.
3. Document behavior changes in `CHANGELOG.md`.

Use `-Suite all` only on owner request or when a concrete broad risk cannot be checked with selected suites; explain that risk first. A commit or review alone does not require it. Reuse current results. GitHub Actions are not used.
