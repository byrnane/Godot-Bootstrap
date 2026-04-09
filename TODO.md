# TODO / Production Roadmap

## Goal

Bring this repository to a production-ready 2D game template state:

- suitable as a base for many 2D game genres;
- focused on infrastructure only;
- no built-in gameplay mechanics (demo simulation only);
- stable, debuggable, testable, and easy to extend.


## Non-Goals

- No genre-specific gameplay systems.
- No hardcoded game loop mechanics.
- No feature logic that cannot be cleanly removed by template users.


## Definition Of Done (Template Level)

The template is considered production-ready when:

1. Core runtime is stable under repeated scene transitions and pause/resume cycles.
2. Save/settings/input/localization systems are validated, versioned, and documented.
3. Basic gamepad support exists with a fixed default mapping.
4. Debug and smoke-check tooling can catch regressions quickly.
5. New project onboarding from this template is fast and predictable.


## Phase 0 - Stabilization And Tech Debt (Start Here)

Focus: remove current risks, warnings, and architectural rough edges.

### 0.1 Runtime warnings and script hygiene

- [x] Remove class-name shadowing warnings (`UiFocus`, `UiMotion` constants vs global classes).
- [ ] Standardize script structure and formatting where inconsistent with `docs/CODESTYLE.md`.
- [x] Eliminate dead/unused code paths and placeholder `pass` blocks where behavior is expected.

### 0.2 State flow correctness

- [x] Integrate `AppState.LOADING` into real transition flow (set/unset in transition lifecycle).
- [ ] Verify pause/resume/tree pause behavior across all modal and transition combinations.
- [x] Add guardrails for invalid scene contracts (missing signals/methods on connected scenes).

### 0.3 Integration safety

- [x] Harden scene signal wiring in `AppFlow` (explicit checks before every connect).
- [x] Improve error diagnostics for failed scene/hud/modal setup.
- [x] Ensure all failure paths leave runtime in a recoverable state.

### Exit criteria for Phase 0

- [x] Project launches without warnings.
- [ ] Main menu -> gameplay -> pause/settings -> back to menu works repeatedly without regressions.
- [ ] No known runtime blockers in current infrastructure.


## Phase 1 - Core Runtime Hardening

Focus: make the app skeleton strongly typed and extensible.

### 1.1 Typed transitions and startup contracts

- [ ] Replace generic scene `Variant` payload usage with typed transition payload objects.
- [ ] Introduce explicit startup/session parameters API in `AppFlow`.
- [ ] Define and document scene contract interfaces (`on_enter`, `on_exit`, HUD binding contract).

### 1.2 Runtime configuration layer

- [ ] Add `GameConfig` as a dedicated runtime entity (separate from user settings/session data).
- [ ] Define config source strategy (defaults + optional project override).
- [ ] Route non-user, game-level constants through `GameConfig`.

### 1.3 Scene and UI shell robustness

- [ ] Improve `SceneRouter` and `UiShell` behavior under rapid consecutive requests.
- [ ] Add deterministic handling for duplicate transition requests.
- [ ] Ensure modal stack, feedback queue, and loading layer cannot enter invalid states.

### Exit criteria for Phase 1

- [ ] Transition API is typed and documented.
- [ ] Runtime config and user settings are clearly separated.
- [ ] Transition/UI shell edge cases are reproducible and handled.


## Phase 2 - Data And Player-Facing Infrastructure

Focus: ship-grade save/settings/input/localization baseline.

### 2.1 Save system maturity

- [ ] Add save slots support (at least minimal slot model).
- [ ] Add backup/restore strategy for corrupted save data.
- [ ] Extend migration/versioning policy with explicit compatibility rules.
- [ ] Add helper APIs for common save operations (exists/load/save/delete/list slots).

### 2.2 Settings system maturity

- [ ] Split settings by domains (audio/video/language/input) with clear ownership.
- [ ] Add robust validation boundaries for all persisted values.
- [ ] Improve apply pipeline so partial failures are visible and recoverable.

### 2.3 Input system maturity

- [ ] Finish keyboard/mouse rebinding polish (UI clarity, conflict resolution UX, reset flows).
- [ ] Add baseline gamepad support with fixed default mapping.
- [ ] Keep gamepad rebinding postponed until fixed mapping is validated.

### 2.4 Localization maturity

- [ ] Add localization coverage check for all static UI keys.
- [ ] Ensure locale switching updates all active runtime UI surfaces.
- [ ] Document translation workflow and key naming conventions.

### Exit criteria for Phase 2

- [ ] Save/settings/input/localization are stable for daily development use.
- [ ] Migration and fallback behavior is deterministic and tested.
- [ ] Baseline gamepad input works with default mapping.


## Phase 3 - UX Infrastructure And Reusable UI Toolkit

Focus: improve template UX quality and reusability without adding game mechanics.

### 3.1 Shared UI primitives adoption

- [ ] Complete migration of template screens to `shared/ui/components`, `navigation`, `motion`.
- [ ] Remove duplicated UI logic from feature scenes where shared primitives exist.
- [ ] Ensure consistent focus/navigation behavior for keyboard/gamepad.

### 3.2 Feedback, loading, and modal UX

- [ ] Polish `UiFeedback` workflows (confirm/alert/toast variants and defaults).
- [ ] Expand loading screen metadata model (tip providers, context labels, status states).
- [ ] Validate backdrop/cancel behavior across all modal types.

### 3.3 Accessibility and readability baseline

- [ ] Verify minimum contrast and text readability on default theme.
- [ ] Ensure focus visibility and tab order quality on all template UI screens.
- [ ] Add localization-safe layouts for longer translated strings.

### Exit criteria for Phase 3

- [ ] UI layer is coherent, reusable, and consistent.
- [ ] Keyboard/gamepad navigation is predictable across shared screens.
- [ ] No major UX regressions in modals/loading/feedback flows.


## Phase 4 - Debug Tooling, Smoke Checks, And Quality Gates

Focus: faster diagnosis and safer refactors.

### 4.1 Debug overlay and quick actions

- [ ] Extend `DebugOverlay` with quick actions:
- [ ] clear save;
- [ ] jump to scene;
- [ ] restart session.
- [ ] Add runtime snapshots for scene/router/loading/modal/input state.

### 4.2 Smoke test suite

- [ ] Add smoke checks for scene loading pipeline and core data containers.
- [ ] Add audio smoke checks (bus presence, one-shot playback path, music playback path).
- [ ] Add localization smoke checks (key existence, locale switch sanity).
- [ ] Define one-command local smoke run for template maintainers.

### 4.3 CI quality gates

- [ ] Add automated smoke run in CI (headless where possible).
- [ ] Fail builds on critical smoke regressions.
- [ ] Document troubleshooting playbook for CI failures.

### Exit criteria for Phase 4

- [ ] Core regressions are caught automatically.
- [ ] Debug tools accelerate local diagnosis.
- [ ] Template updates are safer to merge and release.


## Phase 5 - Packaging, Documentation, And Release Readiness

Focus: make the template easy to adopt and evolve.

### 5.1 Template onboarding experience

- [ ] Add project bootstrap checklist for new games.
- [ ] Add clear extension guide: where to add scenes/services/context data.
- [ ] Add "what not to modify" architecture guardrails.

### 5.2 Demo simulation scope

- [ ] Keep demo scenes simulation-only (state/view/input/save demonstration).
- [ ] Remove any remaining mechanic-like behavior that is not template infrastructure.
- [ ] Ensure demo content is easy to replace in first integration pass.

### 5.3 Release process

- [ ] Create release checklist (version, changelog, migration notes, smoke status).
- [ ] Define semantic version policy for template compatibility.
- [ ] Tag first production template release after all phase exit criteria pass.

### Exit criteria for Phase 5

- [ ] New team can start a fresh 2D project from template with minimal friction.
- [ ] Documentation matches actual architecture and workflows.
- [ ] Template release process is repeatable.


## Backlog (After Production Baseline)

- [ ] Optional gamepad rebinding (only after fixed default gamepad scheme is validated in real projects).
- [ ] Additional editor tooling and project generation helpers.
- [ ] Optional presets for specific 2D subgenres as separate add-ons (not in core template).
