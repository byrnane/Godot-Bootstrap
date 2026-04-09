# Localization Workflow

## Goals

- Keep UI texts translatable without touching gameplay code.
- Keep locale switching predictable at runtime.
- Catch missing translations before regressions reach feature branches.

## Source Of Truth

- Translation table: `translations/UI.csv`
- Active locales: `LocalizationManager.SUPPORTED_LOCALES`
- Static key coverage check: `LocalizationManager.get_static_key_coverage_report()`

## Key Naming

- Use uppercase snake case with `UI_` prefix.
- Group by feature/surface:
- `UI_SETTINGS_*` for settings.
- `UI_INPUT_*` for input/rebinding.
- `UI_LOADING_*` for loading flow.
- `UI_GAMEPLAY_*` for HUD/gameplay shell.
- Use placeholders with named tokens: `{value}`, `{percent}`, `{action}`.
- Keep one key = one semantic meaning; do not reuse unrelated keys.

## Runtime Rules

- For `.tscn` static texts, store translation keys (`UI_*`) in text properties.
- For script-driven text, use `tr("UI_*")` at update points.
- Shared UI components that cache translated text must handle `NOTIFICATION_TRANSLATION_CHANGED`.
- Locale changes should always go through `LocalizationManager.set_locale(...)`.

## Update Workflow

1. Add/rename translation keys in `translations/UI.csv` for all supported locales.
2. Update scene/script references to use the new keys.
3. Run smoke: `res://core/debug/phase0_smoke_runner.tscn`.
4. Check `user://phase0_smoke_result.txt` is `PASS`.

## Coverage Report

- `LocalizationManager.get_static_key_coverage_report()` returns:
- `complete`: `true` when all scanned static keys have values for every supported locale.
- `used_keys`: detected static `UI_*` keys from `.tscn` files.
- `missing_by_locale`: dictionary of missing keys grouped by locale.
