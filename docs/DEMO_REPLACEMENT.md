# Demo Replacement Guide

This template ships with simulation-only demo content.

Use this guide to replace demo surfaces in the first integration pass.

## Files Intended For Early Replacement

- `features/main_menu/main_menu.tscn`
- `features/gameplay/gameplay.tscn`
- `features/gameplay/gameplay_hud.tscn`
- `features/levels/level_a.tscn`
- `features/levels/level_b.tscn`

## Minimal Replacement Flow

1. Replace menu scene content, keep emitted intent signals compatible.
2. Replace gameplay root scene while keeping scene contract methods:
   - `on_enter(payload)`
   - `get_hud_scene()`
   - `bind_hud(hud)`
   - `unbind_hud(hud)`
3. Replace the HUD composition and view model mapping; reuse resource bars, counters, objectives and input hints from `shared/ui/components/`. The demo HUD accepts optional resources without reading session data directly.
   Remove or replace its collapsible demo-actions panel when adding real gameplay.
4. Replace level stubs with your own world/content nodes.
5. Update `Scenes` registry paths and `GameConfig` defaults if ids change.

Style changes, component contracts and catalog: [UI Framework](UI_FRAMEWORK.md).
The local design reference is documented in [design/figma](../design/figma/README.md).

## Keep These Infrastructure Hooks

- `AppFlow` remains the orchestrator for top-level transitions.
- `SceneRouter` remains the only root-scene switch point.
- `UiShell` remains the owner of loading/modals/toasts/HUD host.
- `SessionContext` and `SaveData` remain the persistence bridge.

## Quick Validation After Replacement

Run focused checks:

- transitions (menu <-> gameplay);
- pause/settings modal stack;
- save/load and localization switch.
