# CI Smoke Troubleshooting

Internal document for template maintainers.

## Scope

This playbook is used when GitHub Actions `Smoke Checks` fails.

The CI smoke gate is based on:

- running `res://core/debug/phase0_smoke_runner.tscn` in headless mode;
- reading `phase0_smoke_result.txt`;
- requiring final status `PASS`.

## Fast Triage

1. Open failed workflow run.
2. Download artifact `smoke-result`.
3. Read `phase0_smoke_result.txt`.
4. Identify first failing line and map it to a smoke assertion in `core/debug/phase0_smoke_runner.gd`.

## Local Reproduction

Run local headless smoke with explicit Godot binary:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1 -Headless -GodotExecutable "C:\Path\To\godot.exe"
```

If needed, also run with visible window mode:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1 -GodotExecutable "C:\Path\To\godot.exe"
```

## Common Failure Buckets

- Scene/transition failures:
  - messages include `loading state was not observed`, `expected scene ... was not reached`, `transition manager still active`;
  - check `SceneRouter`, `TransitionManager`, and `AppFlow` contracts.
- Pause/modal failures:
  - messages mention `PAUSED state`, `backdrop`, `resume request`;
  - check `UiShell` modal stack and pause state synchronization in `AppFlow`.
- Localization failures:
  - messages mention `localization coverage` or `missing key`;
  - add missing keys to `translations/UI.csv`, reopen project to refresh `.translation` resources.
- Audio failures:
  - messages mention missing bus or wrong playback path;
  - verify `AudioManager._ensure_bus_layout()` and one-shot/music playback paths.

## Fix Validation Checklist

1. Re-run local smoke until `PASS`.
2. Ensure result file `user://phase0_smoke_result.txt` contains only `PASS`.
3. Push changes and verify `Smoke Checks` workflow passes.

## Notes

- Treat smoke failures as release-blocking for template infrastructure changes.
- Keep smoke assertions deterministic; avoid timing races and hidden state dependencies.
