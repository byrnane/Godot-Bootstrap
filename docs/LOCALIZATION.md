# Localization Workflow

## Goals

- Keep UI texts translatable without touching gameplay logic.
- Keep locale switching predictable at runtime.
- Catch missing translations before merge.

## Source Of Truth

- Translation table: `translations/UI.csv`
- Supported locales: `LocalizationManager.SUPPORTED_LOCALES`
- Static key coverage: `LocalizationManager.get_static_key_coverage_report()`

## Key Naming Rules

- Use uppercase snake case with `UI_` prefix.
- Group keys by surface, for example:
  - `UI_SETTINGS_*`
  - `UI_INPUT_*`
  - `UI_LOADING_*`
  - `UI_GAMEPLAY_*`
- Use named placeholders: `{value}`, `{percent}`, `{action}`.
- One key should represent one meaning. Do not reuse unrelated keys.

## Runtime Rules

- For static labels in `.tscn`, store `UI_*` keys as text values.
- For dynamic labels in scripts, use `tr("UI_*")`.
- Components that cache translated text must handle translation-change notifications.
- Shared UI properties such as `title_key` and `caption_key` take localization keys; gameplay-facing `text` and view model fields may take already prepared display strings. See [UI Framework](UI_FRAMEWORK.md).
- Change locale only through `LocalizationManager.set_locale(...)`.

## Update Flow

1. Add or update keys in `translations/UI.csv` for all supported locales.
2. Update scene/script references. Let the Godot CSV importer regenerate `UI.en.translation` and `UI.ru.translation`; do not edit the generated resources by hand.
3. Launch the project and switch locale on active screens.
4. Check static labels and dynamic labels for missing keys and stale text, including the component catalog.
5. Run `pwsh -File scripts/run_smoke.ps1 -Headless -Suite localization` when localization behavior or keys change.

## Coverage Report Fields

- `complete`: `true` if all detected static keys are translated for every locale.
- `used_keys`: static `UI_*` keys detected in `.tscn`.
- `missing_by_locale`: missing keys grouped by locale.
