# Manual Test Plan

Internal document for template maintainers.
This checklist is not required for teams that only consume the template for their own game.
During development, use only sections affected by the change; do not repeat this checklist after every edit. See [Local Testing](TESTING.md).

## Scope

This checklist validates the template infrastructure only (no gameplay mechanics).

It focuses on:

- scene flow and transitions;
- pause/resume/modal behavior;
- save/load/settings/input/localization;
- UI shell and loading/debug layers;
- baseline audio and runtime stability.


## Test Environment

- Godot `4.7.2`
- Fresh run with existing user data
- Fresh run in a separate disposable profile; preserve real `user://settings.cfg`, saves and `input_bindings.save`.
- Existing-data scenarios use a copied test profile, not deletion of the owner's data.
- Start graphical automation with `--audio-driver Dummy`; perform audio acceptance separately at a comfortable volume. Default Master is 15%, existing settings take priority.


## Quick Automated Pre-Check

Run only the affected smoke suite in PowerShell 7 (it isolates user data); for flow changes:

- `pwsh -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1 -Suite flow`
- (optional) `pwsh -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1 -Headless -Suite flow`

Expected:

- The current isolated `.local/smoke/<run-id>` contains exactly one `phase0_smoke_result.txt` with `PASS`, the process exits 0, and the log has no `SCRIPT ERROR`/`ERROR`.
- No runtime errors.


## Manual Checklist

### A. Boot and Main Menu

1. Launch project from `res://main/main.tscn`.
2. Verify no runtime errors. Record any warnings separately; known shutdown warnings are documented in [READINESS.md](READINESS.md).
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


### D. Save Slots and Continue

1. In gameplay, expand the demo-actions panel and change health, score and level.
2. Open save slots modal from pause.
3. Create a new manual slot.
4. Verify the new slot is selected and overwrite becomes available; overwrite it and verify confirmation. Create another slot and check selection follows it. Cancel a delete confirmation and verify the slot remains.
5. Run quick save and verify `quick` slot appears in list.
6. Return to main menu.
7. Verify `Continue` is enabled.
8. Use `Continue` and verify latest slot state restoration.

Expected:

- Manual slot, quick slot, and continue-from-latest work consistently.
- Overwrite and delete flows are explicit and safe.


### E. Autosave

1. In settings, enable autosave and set short timer interval.
2. In gameplay, wait until timer autosave is produced.
3. Increase score until checkpoint threshold is reached and verify autosave update.
4. Return to menu and quit; relaunch project.
5. Verify autosave slot metadata has recent timestamp and valid state.

Expected:

- Timer, checkpoint, and exit autosave triggers are stable and non-spammy.
- Autosave does not overwrite manual slots.


### F. Settings Persistence

1. Change language, volumes, fullscreen, vsync.
2. Apply settings and close.
3. Restart project.
4. Verify settings persisted and applied.
5. Use reset settings and re-check persistence.
6. Change a value without applying, close settings, cancel the discard confirmation, and verify the draft remains. Close again and confirm discard; persisted values must remain unchanged.

Expected:

- Settings survive restart and apply safely.


### G. Input Rebinding

1. Open controls tab in settings.
2. Rebind keyboard keys and mouse buttons for several actions, including the second binding slot.
3. Verify conflict behavior for compatible and incompatible actions.
4. Restart project and verify bindings persist.
5. Reset bindings and verify defaults restored.

Expected:

- Rebind flow is clear and stable, persisted across restarts.


### H. Localization

1. Switch locale EN <-> RU.
2. Verify active screens update immediately.
3. Check dynamic labels (HUD/debug/loading/feedback text).

Expected:

- No missing keys, no stale language fragments on active UI.


### I. Audio Baseline

1. Verify menu music in main menu.
2. Enter gameplay and switch level A/B to verify music changes.
3. Press UI buttons and confirm hover/click sounds.
4. Trigger simulation actions and verify SFX playback.
5. Adjust volume sliders and verify bus effect.

Expected:

- Audio buses and playback paths function without errors.


### J. Debug Overlay

1. Toggle debug overlay (`ui_debug_overlay`).
2. Verify scene id, app state, paused/loading flags update.
3. Verify quick actions (clear saves, jump scene, restart session) behave correctly.
4. Open modals and transitions while overlay is visible.

Expected:

- Overlay reflects runtime state consistently.


### K. Failure Safety Checks

1. Trigger rapid repeated navigation (menu <-> gameplay).
2. Open/close modals quickly.
3. Spam pause/resume keys.

Expected:

- Runtime recovers cleanly, no irrecoverable state, no hard locks.


### L. UI Theme, Components and Layout

1. Open `shared/ui/catalog/ui_catalog.tscn` with F6; inspect controls, resource bars, input rows, save cards, feedback and result content.
2. Check hover, pressed, disabled and visible focus states; keyboard focus must follow visual order.
3. Check settings General/Graphics/Controls in RU/EN, scrolling of bindings and a footer that remains usable.
4. Check menu, pause, saves in both modes, destructive confirmation, dismissible toast and loading/spinner.
5. Verify the HUD over the actual 2D or 3D world; absent optional resources should be hidden.
6. When changing a skin, verify inherited Theme variations in the catalog and full screens. Pixelart 640×360 requires separate layout acceptance.
7. Record whether gamepad checks used physical hardware or injected events.

Theme/component contracts: [UI Framework](UI_FRAMEWORK.md). This checklist describes required scenarios, not a claim that all were run.

## Exit Criteria

Manual testing is considered passed when:

1. No critical runtime errors.
2. No persistent invalid state after stress actions.
3. Save/settings/input/localization/audio flows are stable and repeatable.
