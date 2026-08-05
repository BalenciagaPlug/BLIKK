# BLIKK Development Manual

This file is the authoritative guide for AI coding agents working in BLIKK. It applies to the entire repository unless a more specific `AGENTS.md` exists deeper in the tree. Follow the current repository and the user's task over speculative future architecture.

## Project Overview

BLIKK is a competitive Roblox movement shooter inspired by the speed, mechanical depth, and expressive K-style movement of *GunZ: The Duel*. The first playable project is **BLIKK Movement Lab**, a private environment for learning, practising, and tuning BLIKK's movement and K-style-inspired mechanics.

Development uses Roblox Studio, Luau, Rojo, GitHub, VS Code, and Codex. Rojo is pinned through Rokit. At the time this guide was revised, the repository contains a client bootstrap, a client input manager, a shared action buffer, shared movement configuration, and a shared movement engine. `default.project.json` also maps a future `src/server` path, but no server source files currently exist. There are currently no automated tests, CI workflows, or project documentation directory. Agents must inspect the repository again before each task and must not assume this description remains current.

## Development Phase

BLIKK is currently in **rapid gray-box prototyping**. The immediate goal is to make complete, playable movement slices quickly enough for hands-on Roblox Studio testing and feel iteration.

During this phase:

- Prioritise playable vertical slices and short feedback loops.
- Keep clean module boundaries between input, configuration, movement logic, and presentation without introducing enterprise architecture.
- Prefer a complete feature-sized change over placeholder files, empty scaffolding, print-only behaviour, or a broad framework with no playable result.
- Implement the smallest coherent version that the user can test in Studio, then tune it in place.
- Expose gameplay-feel values through shared config, but avoid unnecessary interfaces, factories, schemas, and abstraction layers.
- Automated tests, full server authority, ADRs, protocol versioning, CI, pull requests, and production-grade documentation are desirable as the project matures. They must not block early client-side movement prototypes unless the task specifically requires them.
- Safety, cleanup, clear ownership, configurable gameplay values, and preservation of user work remain mandatory even during fast iteration.

The current development priority is **crosshair camera and camera-relative dash**. The current Dash V2 implementation is provisional and uncommitted from the project owner's perspective: its distance and directional feel have not been accepted. Preserve it and improve it in place; do not treat its tuning or behaviour as final.

## Roblox Development Workflow

Always assume BLIKK is developed through this workflow:

1. Codex edits the required repository files in VS Code's source tree.
2. The user saves changes.
3. Rojo synchronises the source tree into Roblox Studio.
4. The user presses **Play** in Roblox Studio.
5. The user reports whether the behaviour works and how it feels.
6. Codex iterates directly in the repository.

Do not ask the user to create scripts or manually paste generated code into Roblox Studio unless repository-based editing is genuinely impossible or the user specifically requests a Studio-only change.

### Roblox Architecture

- Follow current Roblox best practices and respect the Roblox client/server model.
- Access Roblox services with `game:GetService()` and cache stable service references at module scope.
- Use `ReplicatedStorage` only for shared modules and assets that are intended to replicate to clients.
- Never place server-authoritative code in client folders.
- Never place client-only code in server folders.
- Keep `init.client.luau` and any future `init.server.luau` lightweight composition roots. They should initialise modules and wire dependencies rather than contain feature implementations.
- A client-side movement prototype may establish feel before server authority exists, but it must not be mistaken for secure competitive authority.

### Rojo Rules

- Never break or casually restructure `default.project.json` mappings.
- Place new files inside the existing mapped source tree so Rojo synchronises them automatically.
- Inspect the mapping before adding a new source location or changing a path.
- Do not suggest creating source scripts directly inside Roblox Studio unless specifically requested.

### Roblox APIs

- Prefer modern, supported Roblox APIs and avoid deprecated APIs.
- Use `RunService` for deliberately scheduled render or simulation work.
- Use `UserInputService` for low-level device input and `ContextActionService` when action binding, input priority, or cross-device handling makes it appropriate.
- Use `CollectionService` when tagged groups provide a clear lifecycle or discovery benefit.
- Use `TweenService` for presentation only, never as the source of authoritative gameplay state or movement timing.
- Use `Workspace.CurrentCamera` for the active local camera.
- Use `Humanoid` and `HumanoidRootPart` deliberately for character state and movement integration.
- Choose an API because it fits the feature; do not introduce a service merely because it is listed here.

## Vision

BLIKK should be approachable at a basic level and highly expressive at mastery. Players should discover a deep vocabulary of timing, direction, cancels, and chained techniques through a small set of consistent movement and combat primitives. The game should feel fast, precise, legible, and fair.

Features should improve at least one of the following:

- Player agency and mechanical expression.
- Responsiveness and consistency of gameplay feel.
- Clarity of feedback and ease of practice.
- Competitive integrity as networked play is introduced.
- The codebase's ability to support fast, safe iteration.

## Core Philosophy

1. **Gameplay feel always takes priority over visual polish.** Establish input response, timing, direction, momentum, and feedback before spending time on effects.
2. **Build playable slices.** A working gray-box mechanic that can be tested is more valuable than placeholders or premature infrastructure.
3. **Depth comes from interacting primitives.** Prefer a small number of dependable actions that combine into advanced techniques.
4. **All gameplay values are configurable.** Timing windows, distances, speeds, cooldowns, limits, accelerations, costs, thresholds, camera behaviour, and other feel values belong in shared config modules.
5. **Never hardcode gameplay numbers.** If changing a number changes feel, balance, timing, reach, or difficulty, give it a descriptive config key. Structural and mathematical identities such as `0`, `1`, axis vectors, and array indices are allowed when they are not tuning values.
6. **Prefer reusable modules.** Extract stable domain behaviour and avoid duplication, but do not create abstraction without a present need.
7. **Be deterministic where possible.** Given the same state and ordered input, gameplay logic should produce the same result. Isolate engine, clock, physics, and future network variability.
8. **Comments explain why, not what.** Preserve intent, constraints, trade-offs, and non-obvious Roblox behaviour rather than narrating visible code.
9. **The client must feel responsive.** Future competitive outcomes will require server authority, but that future architecture must not prevent local movement prototyping now.

## Current Repository Responsibilities

Always read `default.project.json` and inspect actual files before describing or changing the project. Do not claim that files, folders, tests, server systems, CI, or documentation exist unless they do.

### Root

- `default.project.json`: canonical Rojo DataModel mapping.
- `rokit.toml`: pinned development tools.
- `README.md`: concise project introduction.
- `AGENTS.md`: this development manual.

### `src/client`

Owns client-only orchestration and presentation, including device input, camera, crosshair, UI, visual/audio feedback, and local movement control or prediction.

- `init.client.luau` is the current client composition root. Keep it small and use it to initialise and connect modules.
- `Input/` translates device-specific Roblox input into semantic gameplay actions.

### `src/shared`

Owns code and data that are safe to replicate and useful across gameplay domains. It currently contains input buffering and movement code/configuration.

- `Input/` owns device-agnostic action buffering and shared input concepts.
- `Movement/` owns movement configuration and movement behaviour.
- Prefer domain-specific configuration such as `MovementConfig.luau` over a single global configuration table.

Everything in `src/shared` is visible to clients. Never put secrets or privileged future server rules there.

### `src/server`

`default.project.json` maps this path, but it does not currently exist. Create server files only when a requested feature needs server behaviour. Future server code will own authoritative validation, combat results, match state, persistence, and anti-abuse rules.

### Incremental Structure

- Add folders only when a real feature needs them.
- Do not reorganise existing folders such as `src/shared/Utils` solely because a guide discourages generic utility folders. Preserve user structure and improve naming incrementally when feature work provides a concrete reason.
- Do not create empty future folders, placeholder modules, or speculative architecture.
- Organise new code by domain and responsibility where practical.

## Architecture Principles

- Keep input adapters, configuration, gameplay logic, and presentation separate enough to tune or replace independently.
- Keep composition roots thin; initialise modules and wire dependencies there rather than implementing mechanics there.
- Give each module one clear responsibility and one clear owner of mutable state.
- Prefer pure functions for calculations and state transitions when they make iteration easier. Keep direct Roblox Instance and service access near system boundaries.
- Avoid circular dependencies, uncontrolled global mutable state, and surprising side effects during `require`.
- Model increasingly complex movement with explicit states and transitions rather than an expanding set of unrelated booleans.
- Preserve existing public APIs unless the task requires changing them, and update all known callers when an API changes.
- Preserve the user's current work and improve it in place. Never replace a working provisional system merely to impose a preferred pattern.
- Choose the smallest architecture that produces a complete, testable feature now while leaving an understandable path forward.

## Configuration Rules

- Put all tunable gameplay and camera values in shared, domain-specific config modules.
- Use descriptive names and include units when ambiguity is likely, such as `DurationSeconds`, `SpeedStudsPerSecond`, or `FieldOfViewDegrees`.
- Config modules should contain data, not connect events, mutate Instances, or run gameplay services.
- Treat shared configuration as read-only during play. Select explicit variants rather than mutating the canonical table unexpectedly.
- Group related values and explain non-obvious relationships or constraints.
- Do not hide tuning values in `task.wait`, animation lengths, particle lifetimes, camera scripts, physics expressions, or UI code.
- During prototyping, add only the config and validation needed by the feature. Do not build a general configuration framework.

## Input System Philosophy

- Translate raw keys, mouse buttons, gamepad controls, and future touch input into semantic actions at the input boundary.
- Movement and combat systems consume semantic actions, not raw `UserInputService` events.
- Preserve action phases—began, held/changed, and ended—when the mechanic requires them.
- Buffer inputs deliberately with configurable windows, stable ordering, deterministic expiry, and bounded memory.
- Make gameplay, menu, chat, spectating, and training contexts explicit when they begin to overlap.
- Input rebinding and alternative devices should eventually map into the same action vocabulary rather than duplicate gameplay logic.
- Input timestamps help sequence and tune local mechanics; they are not future proof of authoritative validity.

## Camera Philosophy

- Crosshair camera is the current priority and should establish a stable basis for camera-relative movement.
- Camera behaviour must support aiming and movement readability; it must not fight player input or obscure the character's movement state.
- Camera-relative dash direction must be derived consistently from the intended camera basis, projected appropriately onto the movement plane.
- Define explicitly how forward, backward, and lateral dash relate to camera facing, character facing, and crosshair aim.
- Keep camera presentation separate from movement rules while sharing the minimum directional data needed for consistent behaviour.
- Put field of view, offsets, sensitivity modifiers, smoothing, recentering, and other feel values in config.
- Avoid smoothing that introduces noticeable input lag. Responsive control takes precedence over cinematic motion.
- Test camera and dash together across all four directions, rapid direction changes, airborne states, respawn, and unusual pitch angles.

## Movement Philosophy

BLIKK is inspired by *GunZ: The Duel* but should build a coherent identity rather than reproduce quirks blindly.

- BLIKK is not trying to imitate default Roblox movement. Its movement should feel inspired by *GunZ: The Duel* while remaining completely native to Roblox.
- Never replace an intentional BLIKK movement rule with Roblox default behaviour merely because the default is easier to implement.
- Movement is a first-class combat system, not traversal attached to weapons.
- Prioritise immediate response, directional confidence, readable momentum, and consistent timing windows.
- Advanced techniques should emerge from composable primitives such as dash, jump, slash, block, weapon swap, and reload.
- Butterfly, slash shot, reload shot, half-step, and later techniques require explicit, configurable timing and state rules rather than animation coincidences.
- Preserve skill expression through timing, sequencing, positioning, and commitment. Avoid random movement outcomes.
- Cancels must be intentional transitions with clear eligibility and consequences.
- Camera-relative and character-relative rules must be explicit and consistent across mechanics.
- Momentum preservation, vertical velocity, friction, acceleration, air control, duration, distance, and cooldown must be configurable and evaluated together.
- Animation and effects follow gameplay state; they must not delay accepted input or block an allowed cancel.
- Use temporary diagnostics when useful for tuning, but deliver actual playable behaviour rather than print-only implementations.
- Always prioritise responsiveness over flashy visuals.

For Dash V2 specifically, do not assume the current distance or directional feel is correct. Expose relevant values in config, preserve provisional work, and make changes easy to playtest and revise.

## Determinism and Time

- Use explicit `deltaTime` for gameplay-critical stepping where appropriate.
- Prefer passing time into reusable logic instead of scattering clock reads throughout a system.
- Process actions and state transitions in a stable order. Never depend on `pairs()` iteration order for gameplay results.
- Use seeded randomness if gameplay randomness is introduced; cosmetic randomness may remain local.
- Compare floating-point values with deliberate tolerances when exact equality is unsafe.
- Roblox physics is not fully deterministic. Keep local prototype rules consistent, and introduce authoritative reconciliation when networked competitive behaviour is actually in scope.

## Networking Philosophy

Networking is not required to validate the current local movement feel. When a requested feature introduces networking:

- Clients send intent; the server decides authoritative competitive results.
- Treat client messages as malformed, stale, duplicated, reordered, or adversarial until validated.
- Never trust client-authored damage, hits, ammunition, cooldown completion, inventory, or final movement state.
- Keep payloads typed, compact, bounded, and validated against current server state.
- Predict only what improves responsiveness and reconcile deliberately.
- Centralise remote ownership rather than creating remotes ad hoc throughout features.
- Add sequence numbers, rate limits, lag compensation, protocol versions, and production schemas when their actual feature requirements justify them; do not pre-build them for a client-only prototype.

## Safety and Cleanup

- Never rewrite, revert, discard, overwrite, or otherwise destroy existing user changes.
- Inspect the working tree before editing and treat all existing modifications and untracked files as user work.
- Do not use destructive filesystem or Git operations unless the user explicitly requests the exact action.
- Never expose secrets or commit credentials, tokens, private keys, or sensitive player data.
- Validate data at trust boundaries when such boundaries are introduced.
- Give every connection, task, temporary Instance, and character-bound resource a clear owner and cleanup path.
- Disconnect `RBXScriptConnection`s and cancel owned tasks during teardown, respawn, or replacement.
- Rebinding after respawn must not duplicate connections or preserve stale character references/state.
- Guard against destroyed Instances, missing character parts, dead Humanoids, and asynchronous character replacement.

## Performance Rules

- Work within Roblox frame budgets; camera, input, and movement must remain responsive on representative client hardware.
- Treat input, camera, movement simulation, render callbacks, heartbeat callbacks, and future network handlers as hot paths.
- Avoid unnecessary `RenderStepped` and `Heartbeat` work. Prefer events or lower-frequency work when the feature does not need per-frame updates.
- Keep per-frame work bounded. Avoid unbounded buffers, histories, scans, or queues.
- Do not create Instances, connections, coroutines, closures, or temporary tables every frame without a measured reason.
- Use the appropriate scheduler event and do not yield inside render-step callbacks.
- Prefer a stepped state machine over a blocking gameplay `while` loop when it improves cancellation, cleanup, or consistency.
- Cache stable lookups, but rebind character Instances safely after respawn.
- Prevent memory leaks and duplicate event connections, especially across character respawns and module reinitialisation.
- Profile before performing broad optimisations. Do not sacrifice gameplay feel based on speculation.

## Coding Standards

- Use `--!strict` for new modules where it does not obstruct a fast prototype. Improve touched legacy typing incrementally and safely.
- Cache Roblox services once at module scope with `game:GetService()`.
- Place requires near the top of the file after services.
- Keep functions focused and use guard clauses to reduce nesting.
- Avoid magic strings for semantic actions and states when a shared definition is warranted.
- Avoid deprecated Roblox APIs.
- Do not use `any` to silence ordinary type errors. If an untyped boundary requires it, narrow the value promptly.
- Do not leave noisy debug output in per-frame or frequently triggered production paths.
- Make the smallest coherent change that fully implements the requested feature.
- Do not combine feature work with unrelated formatting, folder moves, or refactors.

## Luau Style Guide

- Indent with tabs and do not mix tabs and spaces within a file.
- Prefer lines at or below 100 characters when practical.
- Use blank lines between logical sections and trailing commas in multiline tables.
- Order modules consistently: strict directive, services, requires, types, constants, private state, private functions, public API, return.
- Use `local function name()` for private functions.
- Use `:` only when a method intentionally consumes `self`; use `.` for stateless namespaced functions.
- Add useful types to public interfaces and domain data without turning a prototype into a type-framework exercise.
- Use guard clauses for invalid states.
- Avoid metatables unless lifecycle or identity semantics genuinely require them.
- End statements without semicolons.

## Naming Conventions

- Files, modules, and exported types: `PascalCase` (`MovementEngine`, `ActionBuffer`, `DashState`).
- Local variables, parameters, fields, and private functions: `camelCase` (`airDashCount`, `getWorldDirection`).
- Constants that are not tunable gameplay values: `UPPER_SNAKE_CASE` (`WORLD_UP`).
- Boolean names read as predicates: `isDashing`, `hasCharacter`, `canCancel`.
- Events describe occurrences (`ActionBegan`, `DashCompleted`); requests describe intent (`RequestDash`).
- Include units where useful: `durationSeconds`, `speedStudsPerSecond`, `fieldOfViewDegrees`.
- Avoid unclear abbreviations.

## Comments and Documentation

- Comments explain why a constraint, workaround, or surprising choice exists—not what the next line does.
- Document module responsibility, lifecycle, and non-obvious invariants when code and types do not make them clear.
- Update `README.md` or focused documentation when setup or user-facing workflows change.
- Keep documentation proportional to the prototype. ADRs, full protocol documents, and production documentation are optional unless specifically requested or needed to prevent a costly misunderstanding.
- Do not claim documentation exists when it does not.
- Avoid stale examples and vague TODOs. A TODO should state a concrete reason or missing decision.

## Verification and Roblox Studio Testing

- The user is the authority on whether movement feels acceptable.
- Gameplay-feel changes require explicit Roblox Studio playtesting; a build or static check cannot approve feel.
- Test the complete vertical slice, not only whether it loads. Include respawn, repeated activation, edge timing, low/high frame-rate behaviour where practical, and interactions with existing mechanics.
- For camera-relative dash, test forward, backward, left, and right from multiple camera headings and pitch angles, on ground and in air.
- Run available local checks in proportion to the change. Automated tests and CI are encouraged later but are not currently prerequisites unless requested.
- Never claim a build, automated test, Studio test, or playtest was performed when it was not.

## Git Workflow

- Do not create or switch branches, commit, push, open pull requests, stage files, rewrite history, or perform destructive Git operations unless the user explicitly asks.
- The user reviews and playtests each sprint, then commits approved work through GitHub Desktop.
- Agents may use read-only Git commands such as `git status` and `git diff` to understand and review changes.
- Preserve all user modifications and untracked files. Never revert or discard them, including changes that appear unrelated or provisional.
- Do not provide a Git checkpoint title or description until the user confirms that the feature works and feels acceptable.
- After approval, provide checkpoint text only if the user asks for it or the established workflow explicitly calls for it.

## Sprint Workflow

1. **Inspect.** Read this guide, the actual repository, working tree, relevant modules, and configuration.
2. **Define the slice.** Identify the playable outcome, success criteria, expected feel, and important non-goals.
3. **Implement directly.** Edit every required repository file yourself. Do not ask the user to manually paste code that Codex can add safely.
4. **Keep boundaries clean.** Separate input, configuration, gameplay logic, and presentation only as much as the working feature needs.
5. **Complete the feature.** Avoid empty scaffolding, disconnected modules, print-only results, and partial placeholders unless the user explicitly asks for a spike.
6. **Review.** Inspect the diff for accidental edits, hardcoded tuning values, duplicated logic, cleanup issues, stale state, and scope creep.
7. **Hand off for playtest.** Give exact Studio steps and expected results. Clearly state anything Codex could not verify.
8. **Wait for feel approval.** Treat movement tuning as provisional until the user confirms it works and feels acceptable.
9. **Checkpoint only after approval.** The user commits through GitHub Desktop; do not provide checkpoint wording early.

## AI Agent Operating Rules

Before editing:

- Read this file, the current task, `README.md`, `default.project.json`, the working tree, and every relevant source/config file.
- Base all repository claims on current inspection, not prior messages or expected structure.
- Identify existing user work and preserve it.
- Make a reasonable in-scope assumption when safe; ask only when a missing choice would materially alter the feature.

While editing:

- Edit all required repository files directly instead of instructing the user to paste code.
- Preserve and improve current work in place.
- Implement a complete, playable feature-sized change.
- Never hardcode gameplay-feel values; add or reuse shared config fields.
- Prefer reusable modules when they solve a present need, without unnecessary abstraction.
- Keep logic deterministic where possible and isolate engine variability.
- Add cleanup for every resource the change owns.
- Write comments only to explain why.
- Do not silently change config meaning, public APIs, gameplay feel, or future trust boundaries.
- Do not reorganise unrelated folders or impose future architecture on the prototype.

After implementation, provide **one concise handoff** containing:

- Files changed.
- Behaviour implemented.
- Exact Roblox Studio test steps.
- Expected result.
- Remaining risks or unverified behaviour.

Do not add a Git checkpoint title or description to that handoff. Wait until the user explicitly confirms the feature works and feels acceptable.

## Prototype Definition of Done

A prototype change is ready for user playtesting when:

- It provides the requested playable behaviour rather than placeholders.
- Gameplay and camera tuning values are exposed through shared config.
- Existing user work is preserved and unrelated files are untouched.
- Module boundaries remain understandable without unnecessary architecture.
- Repeated use, respawn, connections, tasks, and temporary state are cleaned up safely.
- Relevant local checks have been run where available, with unverified behaviour stated honestly.
- The handoff includes exact Studio test steps and expected results.

A gameplay-feel sprint is not accepted or ready for a Git checkpoint until the user has playtested it and confirmed that it works and feels acceptable.

When rules compete, use this order: **safety and preservation of user work, playable correctness, gameplay feel, responsiveness, clarity and maintainability, performance, then visual polish**. Competitive integrity and player-data safety become non-negotiable wherever the feature introduces those concerns.
