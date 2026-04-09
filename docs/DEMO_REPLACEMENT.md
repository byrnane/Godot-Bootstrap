# Demo Replacement Guide

This template ships with simulation-only demo content.

Use this guide to replace demo surfaces in the first integration pass.

## Files Intended For Early Replacement

- `features/main_menu/main_menu.tscn`
- `features/gameplay/gameplay_stub.tscn`
- `features/gameplay/gameplay_hud.tscn`
- `features/levels/level_stub_a.tscn`
- `features/levels/level_stub_b.tscn`

## Minimal Replacement Flow

1. Replace menu scene content, keep emitted intent signals compatible.
2. Replace gameplay root scene while keeping scene contract methods:
   - `on_enter(payload)`
   - `get_hud_scene()`
   - `bind_hud(hud)`
   - `unbind_hud(hud)`
3. Replace HUD with your own controls and view model mapping.
4. Replace level stubs with your own world/content nodes.
5. Update `Scenes` registry paths and `GameConfig` defaults if ids change.

## Keep These Infrastructure Hooks

- `AppFlow` remains the orchestrator for top-level transitions.
- `SceneRouter` remains the only root-scene switch point.
- `UiShell` remains the owner of loading/modals/toasts/HUD host.
- `SessionContext` and `SaveData` remain the persistence bridge.

## Quick Validation After Replacement

- Run smoke checks:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\run_smoke.ps1`
- Run focused manual checks:
  - transitions (menu <-> gameplay)
  - pause/settings modal stack
  - save/load and localization switch
