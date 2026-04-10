# Manual Test Plan

Internal document for template maintainers.
This checklist is not required for teams that only consume the template for their own game.

## Scope

This checklist validates the template infrastructure only (no gameplay mechanics).

It focuses on:

- scene flow and transitions;
- pause/resume/modal behavior;
- save/load/settings/input/localization;
- UI shell and loading/debug layers;
- baseline audio and runtime stability.


## Test Environment

- Godot `4.6.x`
- Fresh run with existing user data
- Fresh run after deleting:
- `user://settings.cfg`
- `user://saves/` directory
- `user://input_bindings.save`


## Quick Automated Pre-Check

Run smoke scene:

- `res://core/debug/phase0_smoke_runner.tscn`
- `powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1`
- (optional) `powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1 -Headless`

Expected:

- `user://phase0_smoke_result.txt` contains `PASS`.
- No runtime errors.


## Manual Checklist

### A. Boot and Main Menu

1. Launch project from `res://main/main.tscn`.
2. Verify no warnings/errors in debug output.
3. Verify main menu appears and buttons are interactive.
4. Verify `Continue` is disabled when no save exists.

Expected:

- Stable startup, no broken UI state.


### B. Scene Transitions and Loading

1. Start new game from main menu.
2. Verify loading screen appears with title/message/progress.
3. Verify gameplay scene and HUD mount correctly.
4. Return to menu and repeat 3-5 times.

Expected:

- No stuck loading, no duplicate HUD, no transition errors.


### C. Pause, Resume, Settings Modal Stack

1. In gameplay, trigger pause (`ui_pause` and pause button).
2. Open settings from pause modal.
3. Close settings and resume.
4. Repeat multiple times.
5. Try pausing during transition moments (spam pause near scene switch).

Expected:

- Tree pause state always matches app state.
- Modals stack/unstack correctly.
- No frozen or permanently paused state after transitions.


### D. Save and Continue

1. In gameplay, change demo simulation state (Metric A/Counter B/level).
2. Save session.
3. Return to main menu.
4. Verify `Continue` is enabled.
5. Use `Continue` and verify state restoration.

Expected:

- Save writes correctly and load restores expected session values.


### E. Settings Persistence

1. Change language, volumes, fullscreen, vsync.
2. Apply settings and close.
3. Restart project.
4. Verify settings persisted and applied.
5. Use reset settings and re-check persistence.

Expected:

- Settings survive restart and apply safely.


### F. Input Rebinding

1. Open controls tab in settings.
2. Rebind keyboard keys and mouse buttons for several actions.
3. Verify conflict behavior for compatible and incompatible actions.
4. Restart project and verify bindings persist.
5. Reset bindings and verify defaults restored.

Expected:

- Rebind flow is clear and stable, persisted across restarts.


### G. Localization

1. Switch locale EN <-> RU.
2. Verify active screens update immediately.
3. Check dynamic labels (HUD/debug/loading/feedback text).

Expected:

- No missing keys, no stale language fragments on active UI.


### H. Audio Baseline

1. Verify menu music in main menu.
2. Enter gameplay and switch level A/B to verify music changes.
3. Press UI buttons and confirm hover/click sounds.
4. Trigger simulation actions and verify SFX playback.
5. Adjust volume sliders and verify bus effect.

Expected:

- Audio buses and playback paths function without errors.


### I. Debug Overlay

1. Toggle debug overlay (`ui_debug_overlay`).
2. Verify scene id, app state, paused/loading flags update.
3. Verify quick actions (clear saves, jump scene, restart session) behave correctly.
4. Open modals and transitions while overlay is visible.

Expected:

- Overlay reflects runtime state consistently.


### J. Failure Safety Checks

1. Trigger rapid repeated navigation (menu <-> gameplay).
2. Open/close modals quickly.
3. Spam pause/resume keys.

Expected:

- Runtime recovers cleanly, no irrecoverable state, no hard locks.


## Exit Criteria

Manual testing is considered passed when:

1. No critical runtime errors.
2. No persistent invalid state after stress actions.
3. Save/settings/input/localization/audio flows are stable and repeatable.
