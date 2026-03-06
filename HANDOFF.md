# HANDOFF

## Project
`C:\GameDev\game-template`

Godot 4.x template project with a balanced reusable architecture: simple enough for prototypes, but structured enough to scale.

## Current State
The project launches and the current vertical slice works:
- `Main` bootstraps the app
- `AppFlow` controls top-level flow
- `SceneRouter` switches root scenes
- `UiShell` hosts global overlays and modal stack
- `MainMenu` works
- `GameplayStub` works
- `LevelStubA` and `LevelStubB` are embedded into gameplay correctly
- `PauseModal` works
- `SettingsModal` works
- basic save/load works
- basic localization works

## Core Architecture
Main infrastructure:
- `AppFlow`
- `SceneRouter`
- `UiShell`
- `AppContext`
- `SessionContext`
- `SettingsManager`
- `SaveManager`
- `AudioManager`
- `LocalizationManager`
- `Scenes` registry

Important rules:
- root scenes change only through `SceneRouter`
- top-level navigation decisions live in `AppFlow`
- long-lived state lives in `AppContext` and `SessionContext`
- UI should not directly manage filesystem or root-scene navigation
- no global event bus

## Important Files
Core:
- `res://core/flow/app_flow.gd`
- `res://core/services/scene_router.gd`
- `res://core/services/ui_shell/ui_shell.gd`
- `res://core/services/localization_manager.gd`
- `res://core/services/settings_manager.gd`
- `res://core/services/save_manager.gd`
- `res://core/context/app_context.gd`
- `res://core/context/session_context.gd`
- `res://core/context/user_settings.gd`
- `res://core/context/save_data.gd`
- `res://core/registry/scenes.gd`

Features:
- `res://features/main_menu/main_menu.tscn`
- `res://features/gameplay/gameplay_stub.tscn`
- `res://features/levels/level_stub_a.tscn`
- `res://features/levels/level_stub_b.tscn`
- `res://features/ui/modals/pause_modal.tscn`
- `res://features/ui/modals/settings_modal.tscn`

Docs:
- `README.md`
- `ARCHITECTURE.md`
- `COMMUNICATION.md`
- `CODESTYLE.md`
- `STRUCTURE.md`
- `SETUP.md`

## Recent Changes
- fixed autoload/class-name conflicts
- fixed Godot `.tscn` parse issues caused by UTF-8 BOM
- fixed recursive pause/settings modal opening
- fixed gameplay/level scene composition
- upgraded `UiShell` with modal stack and backdrop
- added `LocalizationManager`
- wired UI texts to locale updates
- expanded settings modal with language + audio + display settings
- fixed `%UniqueName` lookups in `GameplayStub`

## Notes About Editing
This project is sensitive to text file encoding for `.tscn` files.
Use UTF-8 without BOM when writing scene files manually.

## What Was Reused From Old Projects
Useful takeaways from old projects:
- instant settings apply is good
- keeping user settings separate from save data is good
- a dedicated UI shell / UI manager is useful
- language handling should be centralized

What should not be copied directly:
- global event bus everywhere
- hardcoded language buttons per locale
- save services that directly serialize unrelated gameplay managers

## Suggested Next Steps
1. Polish modal UX further.
2. Improve settings UX.
3. Strengthen localization pipeline.
4. Improve save-system versioning and migration strategy.
5. Add a lightweight screen base / modal base only if duplication starts to grow.
6. Add a better loading transition in `SceneRouter`.
7. Review current docs so they match the implemented code exactly.

## Quick Prompt For New Chat
Use this if work continues in a fresh chat:

```text
Continue work on the Godot template project.

Project:
C:\GameDev\game-template

Current state:
- AppFlow, SceneRouter, UiShell, SettingsManager, SaveManager, AudioManager, AppContext, SessionContext are in place
- Main menu, gameplay stub, level stubs, pause modal, settings modal are implemented
- modal stack with backdrop works
- basic localization via LocalizationManager is implemented
- settings and save/load work in a basic form

Next task:
Continue polishing the template and extend the foundation without overcomplicating it.
```