# BLIKK Development Manual

This file is the authoritative repository-wide guide for AI coding agents working on BLIKK. It applies to the entire repository unless a more specific `AGENTS.md` exists deeper in the source tree.

Every agent must read this complete file before editing. The current user-approved sprint prompt must also be read in full. Neither may be treated as optional background context.

The current repository is the source of truth for implementation. Canonical design documents define intended behaviour. The sprint prompt defines the approved scope. Do not rely on remembered repository state, outdated summaries, or speculative future architecture.

## Instruction Precedence

When project instructions appear to compete, use this order:

1. Safety and preservation of user work.
2. The user’s explicit current request and approval.
3. The current sprint prompt and its scope restrictions.
4. This `AGENTS.md`.
5. Canonical design documents under `docs/`.
6. Existing implementation conventions.
7. Speculative future architecture.

If a genuine contradiction would materially alter the requested feature, stop and report the conflict before editing.

---

# Project Identity

BLIKK is a high-skill third-person movement fighter built natively for Roblox.

It is inspired by the speed, mechanical expression, weapon weaving, animation cancelling, movement vocabulary, and competitive legacy of *GunZ: The Duel*, but BLIKK must not become a shallow imitation or a collection of copied surface features.

BLIKK’s central mechanical language is formed by the interaction of:

- Character movement
- Jumping and directional dashing
- Surface movement
- Swordplay
- Gunplay
- Blocking and defensive timing
- Weapon switching
- Reloading
- Animation cancelling
- Momentum management
- Map traversal
- Player-authored technique sequences

Movement and combat are not separate systems. They must eventually operate as one expressive language that rewards execution, timing, positioning, adaptation, and mechanical understanding.

BLIKK should be immediately enjoyable at a basic level while supporting an effectively unbounded mastery curve.

## Non-Negotiable Product Principles

- Never simplify advanced techniques into cooldown abilities.
- Never replace execution with canned combo buttons.
- Never add a single button that automatically performs Butterfly, Slash Shot, Reload Shot, Half-Step, or another multi-input technique.
- Preserve player expression through timing, sequencing, direction, momentum, weapon choice, and defensive decisions.
- Competitive equipment must eventually be equalised.
- Competitive advantage must not be sold.
- Monetisation should remain cosmetic.
- Maps, effects, UI, audio, and animation must support movement readability.
- Visual spectacle must not obscure player state or combat information.
- The Movement Lab is a permanent core product, not a disposable tutorial.
- New-player teaching should explain execution without performing techniques for the player.
- BLIKK must remain performant and readable on both high-end and modest Roblox-capable hardware.
- The long-term goal is a mechanically respected game that remains challenging and discoverable for many years.

---

# Canonical Development Priority

Use the following order when evaluating major systems and long-term work:

1. **Movement Truth**
2. **Weapon Weaving**
3. **Surface Movement**
4. **Combat and Network Truth**
5. **Movement Lab Teaching**
6. **The Duels Competitive Structure**
7. **Clans and Legacy**
8. **PvE Operations**

This order expresses product dependency, not an absolute ban on small supporting work.

A narrowly scoped UI repair, developer tool, presentation correction, or stability fix may occur when it directly enables testing or protects current work. Such work must not silently displace the mechanical foundation.

The current sprint prompt determines the immediate task.

---

# Development Phase

BLIKK is currently in rapid playable prototyping with an increasingly structured foundation.

The project has moved beyond an empty movement experiment. Existing repository systems include client, shared, and server code; movement and dash behaviour; wall interaction; camera systems; katana presentation; frontend and profile interfaces; HUD and input visualisation; District Zero generation; spawning; networking infrastructure; and canonical documentation.

Agents must still inspect the repository before every task. This summary is contextual, not permission to assume a particular file or API still exists.

During this phase:

- Prioritise complete, testable vertical slices.
- Maintain short Roblox Studio feedback loops.
- Preserve systems that the user has already approved.
- Treat unapproved feel values as provisional.
- Keep module boundaries understandable without introducing enterprise architecture.
- Prefer a complete feature-sized change over empty scaffolding or broad frameworks.
- Expose gameplay and presentation tuning through appropriate configuration.
- Avoid speculative infrastructure that does not support the active sprint.
- Full production authority, anti-cheat, matchmaking, CI, and large-scale telemetry must not block local mechanical prototyping unless they are directly required.
- Player-data safety, cleanup, working-tree safety, and trust-boundary validation are mandatory whenever relevant.

---

# Current Repository Contract

Always inspect:

- `AGENTS.md`
- `README.md`
- `default.project.json`
- `rokit.toml`
- The current Git working tree
- Relevant canonical documentation
- Relevant configuration modules
- Every implementation file directly involved in the task

Do not claim a file, module, test, remote, service, or feature exists unless current inspection confirms it.

## Root

The repository currently uses:

- `AGENTS.md` as the development manual.
- `default.project.json` as the canonical Rojo mapping.
- `rokit.toml` to pin development tools including Rojo.
- `README.md` as a concise repository introduction.
- `docs/` for focused canonical design and technical documents.
- `Branding/` for approved BLIKK branding resources where present.

## Canonical Documentation

Relevant documents may include:

- `docs/MOVEMENT_SPEC.md`
- `docs/COMBAT_SPEC.md`
- `docs/CAMERA_SPEC.md`
- `docs/WALL_INTERACTION.md`
- `docs/DISTRICT_ZERO.md`
- `docs/MODULAR_URBAN_KIT.md`
- `docs/BLIKK_ROADMAP.md`
- `docs/BLIKK_LORE.md`
- `docs/MULTIPLAYER_CHAT.md`
- `docs/AUDIO.md`

Inspect the actual directory before relying on this list.

If implementation and documentation disagree:

- Do not silently choose one.
- Identify whether the implementation is intentionally ahead of the document or whether behaviour has drifted.
- Update focused documentation only when the sprint requires it or the change would otherwise create a misleading contract.

## `src/client`

Owns local orchestration, input adaptation, camera behaviour, presentation, UI, frontend state, local prediction or prototype movement, and other client-only systems.

The client composition root should initialise modules and wire dependencies. It must not become a large feature implementation file.

## `src/shared`

Owns code and configuration that are safe to replicate and useful to more than one runtime domain.

Everything under `src/shared` is visible to clients.

Never place secrets, privileged server logic, private persistence internals, or trusted competitive outcomes in shared modules.

A module being located in `src/shared` does not automatically make it server-safe. Inspect whether it accesses `LocalPlayer`, client-only services, input, camera, or render callbacks before describing it as runtime-neutral.

## `src/server`

Owns authoritative server behaviour, map construction, spawning, persistence, validation, combat outcomes, match state, and anti-abuse rules as those systems are introduced.

Keep the server composition root lightweight. Independent critical services should not become unavailable merely because an unrelated startup task fails.

## Incremental Structure

- Add folders only when an active feature needs them.
- Do not create empty future directories.
- Do not reorganise unrelated folders during feature work.
- Do not rename or relocate stable systems merely to impose a preferred architecture.
- Improve structure incrementally when the current sprint provides a concrete reason.

---

# Mandatory Agent Intake

Before editing, the agent must:

1. Read this entire file.
2. Read the entire current sprint prompt.
3. Inspect `git status` and the working tree.
4. Inspect `default.project.json`.
5. Inspect relevant canonical documents.
6. Inspect relevant config and implementation files.
7. Identify existing user work and preserve it.
8. Identify systems explicitly protected by the sprint.
9. Identify expected files that may require modification.
10. Identify the manual Roblox Studio acceptance gate.

Before changing files, briefly state:

- The understood sprint objective.
- The protected systems.
- The likely files involved.
- Any current working-tree modifications.
- What can be validated statically.
- What will still require Roblox Studio.

Do not begin editing until this intake is complete.

---

# Roblox Development Workflow

BLIKK is developed through the following loop:

1. Codex or another approved coding agent edits repository source files.
2. Rojo synchronises source into Roblox Studio.
3. The user runs the experience in Roblox Studio.
4. The user evaluates behaviour and feel.
5. The user reports results, screenshots, errors, and tuning feedback.
6. The agent iterates within the same scoped sprint.
7. The user explicitly gives visual and functional approval.
8. A checkpoint title and detailed description are prepared.
9. Only then may approved files be committed and pushed when explicitly requested.

Do not ask the user to create scripts or paste generated source manually into Roblox Studio when repository editing can safely perform the work.

Studio-only work is acceptable when Roblox tooling requires it, including:

- Roblox Animation Editor authoring
- Asset publication
- Place configuration
- DataStore testing settings
- Visual inspection
- Runtime profiling
- Scene or attachment inspection that cannot be represented in Rojo source

Clearly distinguish repository changes from Studio-only actions.

---

# Rojo Rules

- Never casually restructure `default.project.json`.
- Inspect mappings before adding or moving source.
- Keep new files within existing mapped locations unless the task explicitly requires a mapping change.
- Use the pinned Rojo version where available.
- A successful Rojo build confirms project construction, not gameplay correctness.
- Remove temporary build artifacts created only for validation.
- Never claim that a Rojo build proves Roblox Studio runtime behaviour or gameplay feel.

---

# Architecture Principles

- Keep composition roots thin.
- Give every module one clear responsibility.
- Give mutable state a clear owner.
- Separate input adaptation, gameplay rules, configuration, presentation, networking, and persistence where the current feature benefits from that separation.
- Prefer pure calculations for geometry, timing, eligibility, and state transitions when practical.
- Keep direct Roblox Instance manipulation near system boundaries.
- Avoid circular dependencies.
- Avoid uncontrolled global mutable state.
- Avoid surprising side effects during `require`.
- Preserve existing public APIs unless the sprint requires changing them.
- Update every known caller when an API changes.
- Prefer explicit states and transitions over growing groups of loosely related booleans.
- Do not perform broad architecture rewrites inside visual or tuning sprints.
- Build the smallest coherent architecture that supports the requested playable result and a clear next step.

---

# Configuration Rules

All meaningful tuning values must have one clear source of truth.

Configuration includes:

- Timing windows
- Speeds
- Distances
- Accelerations
- Momentum rules
- Cooldowns
- Limits
- Costs
- Camera offsets
- Field of view
- Sensitivity modifiers
- Pose angles
- Attachment offsets
- Weapon dimensions
- Effect durations
- Trail dimensions
- UI scaling values that are intentionally tuneable
- Thresholds and tolerances

Rules:

- Use domain-specific config modules.
- Include units in names when ambiguity is possible.
- Prefer names such as `DurationSeconds`, `SpeedStudsPerSecond`, and `FieldOfViewDegrees`.
- Config modules contain data and simple derived values, not event connections or gameplay services.
- Treat canonical config as read-only at runtime unless a system explicitly owns a mutable copy.
- Do not scatter related tuning values across controllers.
- Do not hide tuning values inside `task.wait`, animation lengths, Tween calls, effect lifetimes, physics expressions, or UI construction code.
- Structural constants such as `0`, `1`, axis vectors, array indices, and mathematical identities are permitted where they are not tuning values.
- Prefer derived geometry over manually coordinated offsets.
- Changing a weapon dimension should not require manually updating several unrelated centre positions.
- Do not create a general configuration framework without a present need.

---

# Input System Philosophy

- Convert physical input into semantic actions at the input boundary.
- Gameplay systems consume semantic actions rather than raw key codes.
- Preserve input phases when needed: began, changed or held, and ended.
- Input buffers must have configurable windows, deterministic ordering, bounded memory, and explicit expiry.
- Gameplay, chat, menus, free-look, spectating, and training contexts must not unknowingly compete for the same input.
- Input rebinding must continue to map into the same semantic action vocabulary.
- Temporary development bindings must still be represented through a clear semantic action where practical.
- Input timestamps support local sequencing and tuning but do not prove authoritative validity.
- Focused text input must suppress gameplay actions correctly.
- Closing text input must restore gameplay input and mouse behaviour cleanly.
- Never allow respawn or module reinitialisation to duplicate input connections.

---

# Camera Philosophy

The camera exists to support aim, movement readability, combat awareness, and player expression.

## Crosshair Camera

- Crosshair-first third-person aiming is the normal gameplay camera.
- The camera must provide a stable basis for camera-relative movement.
- Forward, backward, left, and right movement rules must use a clearly defined flattened camera basis.
- Camera smoothing must not introduce noticeable input delay.
- Character and camera behaviour must recover correctly after respawn.
- Crosshair state, mouse locking, and camera ownership must remain coherent when entering or leaving UI modes.

## Free-Look and Inspection Camera

BLIKK may use a temporary developer free-look mode to inspect weapon proportions, poses, outfits, and presentation from multiple angles.

The current intended prototype behaviour is:

- Hold `Ctrl` to enter free-look inspection mode.
- Hide the gameplay crosshair while free look is active.
- Release the normal crosshair mouse lock.
- Allow the camera to orbit around the local character.
- Keep the character visible and use the character as the orbit target.
- Do not rotate the character merely because the inspection camera rotates.
- Do not alter movement velocity, combat state, weapon state, or server state.
- Restore the previous crosshair camera cleanly when `Ctrl` is released.
- Restore mouse behaviour and crosshair visibility without requiring an additional click.
- Avoid a camera snap that loses the player or points into the floor.
- Treat `Ctrl` as a temporary development binding, not the permanent production binding.
- Keep the binding configurable so it may later move to a lobby, photo, outfit-inspection, or dedicated developer control.
- Do not enable unrestricted free look inside competitive play without a deliberate future design decision.
- The free-look tool must not reveal remote players or spaces through walls.
- Free look is a presentation and inspection mode, not a gameplay advantage.

Unless the sprint says otherwise, implement free look as **hold-to-activate**, not a persistent toggle. Hold behaviour reduces accidental camera-state confusion during rapid testing.

## Camera Obstruction

The camera should retain useful sight of the local fighter during normal navigation.

Future obstruction handling may combine:

- Camera collision that moves the camera closer.
- Local fading of geometry directly between the camera and the local fighter.

Rules:

- Only geometry directly obstructing the camera-to-character sightline may be locally faded.
- Restore original transparency when the obstruction ends.
- Do not permanently mutate shared world geometry.
- Do not reveal enemies, rooms, or remote areas through unrelated walls.
- Obstruction fading must not become a wall-vision mechanic.
- Camera obstruction work must be isolated from free-look work unless explicitly combined by the sprint.

---

# Movement Philosophy

BLIKK movement must feel native to Roblox while preserving the mechanical freedom and responsiveness that make K-style movement compelling.

- Movement is a first-class combat system.
- Prioritise immediate response, directional confidence, readable momentum, and consistent timing.
- Advanced techniques emerge from combinations of simple actions.
- Cancels must be intentional transitions with explicit eligibility.
- Camera-relative and character-relative rules must be documented.
- Do not replace BLIKK movement with default Roblox movement because it is easier.
- Do not let animation delay accepted movement input.
- Do not let visual effects determine movement state.
- Avoid random movement outcomes.
- Preserve skill expression through timing, direction, sequencing, and commitment.
- Use temporary diagnostics when useful, but deliver playable behaviour rather than print-only systems.

## Dash Contract

Dash tuning remains subject to user playtesting even when the implementation is structurally established.

Configurable dash behaviour should include, where relevant:

- Entry duration
- Travel duration
- Exit duration
- Horizontal speed
- Travel distance
- Direction rules
- Air-dash limits
- Vertical momentum handling
- Landing behaviour
- Recovery behaviour
- Camera impulse
- Presentation timing

Do not silently change approved dash distance or direction during an unrelated sprint.

## Airborne Dash Vertical Momentum

An airborne dash controls horizontal travel without freezing gravity.

Unless a specifically designed technique says otherwise:

- Vertical velocity continues evolving during the dash.
- The character may reach the jump apex while dashing.
- The character begins falling naturally while continuing lateral travel.
- Do not capture one Y velocity at dash start and reuse it for the entire dash.
- Do not force Y velocity to zero.
- Do not create a flat horizontal shelf followed by a separate vertical drop.

The intended visual path is a continuous arc:

```text
Jump upward: |
Air dash and descent: / or \
```

The unintended path is:

```text
Jump upward: |
Flat dash: -
Separate drop: |
```

Horizontal dash control and vertical physics should be calculated independently.

## Surface Movement

Wall and surface mechanics must:

- Use explicit contact and eligibility rules.
- Avoid infinite recontact loops.
- Cleanly handle landing and respawn.
- Preserve camera and movement readability.
- Expose relevant distances, angles, timings, and momentum through config.
- Yield to stronger combat presentation where appropriate without losing gameplay state.

---

# Combat and Weapon Weaving Philosophy

Swordplay, firearms, movement, blocking, reloading, and switching must eventually form one connected system.

- Weapons must not feel like isolated ability kits.
- Weapon switching should support deliberate cancels and transitions.
- Slash, block, reload, fire, and switch timing must be code-driven and configurable.
- Player intent is accepted by gameplay rules, not inferred only from animation playback.
- Competitive outcomes must eventually be server-authoritative.
- Client-only presentation prototypes must be clearly described as such.
- Do not implement client-authored damage, final hit results, ammunition authority, or inventory authority.
- Hitboxes, clash rules, damage, recoil, and ammunition must be scoped explicitly when introduced.
- Do not introduce a shotgun or firearm system incidentally during a melee presentation sprint.
- Preserve equalised competitive equipment as a long-term requirement.

---

# Weapon Geometry and Attachments

Weapon presentation must have a clear local coordinate convention.

For each weapon:

- Document the local axis from grip toward the weapon tip.
- Document the blade or barrel forward axis.
- Document the visible flat or edge axis where relevant.
- Use one deliberate model origin.
- Use explicit grip pivots rather than relying on unexplained part centres.
- Keep equipped and holstered transforms independent.
- Keep trail or muzzle attachments derived from physical geometry.
- Keep dimensions and attachment transforms configurable.
- Do not permanently rotate model geometry only to fake one idle pose if that compromises future animation authoring.
- Ensure exactly one presentation weapon is owned per character unless a feature deliberately requires more.
- Clean up presentation Instances during respawn, replacement, and teardown.

## Training Katana Direction

The Training Katana should support a compact one-handed movement-fighter silhouette:

- Hand beside or slightly behind the right hip.
- Relaxed arm.
- Blade angled downward and rearward.
- Tip around shin or ankle height.
- Blade clear of the leg.
- Weapon readable without dominating the avatar.
- Holstered sword close to the back on a separate transform.
- Proportions should take influence from the compact readability of GunZ melee weapons without copying a specific copyrighted model.

Authored slash and block animations should be created only after weapon dimensions, grip position, and base stance are visually approved.

---

# Animation and Pose Ownership

Animations and procedural poses present accepted gameplay state. They do not decide whether an input succeeds.

## Gameplay Timing

- Slash acceptance is code-driven.
- Block acceptance is code-driven.
- Cancel eligibility is code-driven.
- Damage timing is code-driven.
- Reload acceptance is code-driven.
- Technique recognition is code-driven.
- Animation markers may synchronise effects and presentation.
- Animation length must not become the only source of competitive timing truth.
- A missing animation must not silently change gameplay rules.

## Procedural Pose Ownership

A presentation controller may modify only the joints it explicitly owns.

It must not reset every character `Motor6D` merely because those joints were discovered.

Until a unified pose mixer exists, use this effective priority:

1. Combat actions such as slash and block
2. Strong movement actions such as dash and wall interaction
3. Equipped weapon idle
4. Neutral character presentation

Lower-priority presentation must yield to higher-priority state rather than overwriting it.

Rules:

- Equipped idle yields during slash and block.
- Equipped idle yields during active dash presentation.
- Equipped idle yields during active wall presentation.
- Equipped idle yields during equip, holster, and weapon-switch transitions.
- Stronger presentation returns cleanly to the appropriate idle state afterward.
- Joint cleanup resets only joints the system owns.
- Respawn must not preserve stale transforms.
- Procedural fallback must not compete with an authored animation track on the same joints without explicit layering rules.
- Avoid broad pose architecture rewrites during a narrow weapon-tuning sprint.

---

# Networking Philosophy

Networking may be postponed while validating local mechanical feel, but every introduced trust boundary must be handled deliberately.

- Clients send intent.
- Servers decide authoritative competitive outcomes.
- Treat client payloads as malformed, stale, duplicated, reordered, or adversarial.
- Never trust client-authored damage.
- Never trust client-authored hit confirmation.
- Never trust client-authored ammunition.
- Never trust client-authored inventory.
- Never trust client-authored cooldown completion.
- Never trust client-authored final movement state in competitive play.
- Validate payload types, sizes, ranges, rates, and current server state.
- Centralise remote creation and ownership.
- Required remotes should not disappear because an unrelated map builder fails.
- Do not create remotes from the client.
- Use rate limits where repeated requests can be abused.
- Add sequence numbers, reconciliation, lag compensation, and protocol versions only when the relevant feature requires them.
- Do not build a large speculative networking framework for a local presentation sprint.

---

# Persistence Philosophy

Player persistence is server-owned and safety-critical.

BLIKK’s intended player profile foundation includes:

- A maximum of five saved character profiles per Roblox account.
- Saved semantic custom bindings.
- Future account-level settings.
- Versioned schema migration.
- Safe defaults when data is missing or unavailable.

Persistence rules:

- Use a versioned schema.
- Validate all loaded data.
- Validate all requested mutations on the server.
- Enforce the five-character maximum on the server.
- Do not allow clients to submit arbitrary save tables.
- Character records must contain only approved bounded fields.
- Bindings must serialize semantic actions and approved input tokens.
- Reject unknown actions and invalid input tokens.
- Prefer `UpdateAsync` over blind replacement writes.
- Use bounded retries with backoff.
- Avoid rapid write spam.
- Use autosave at a sensible interval.
- Save during `PlayerRemoving`.
- Use `BindToClose` for shutdown handling.
- Preserve safe defaults when Roblox DataStores are unavailable.
- Report save failures clearly without destroying the player’s active session.
- Do not claim persistence works until tested with Studio API access or an appropriate published environment.
- Do not combine persistence with unrelated movement, camera, or weapon-presentation work.

---

# Maps and Movement Readability

Maps exist to support movement and combat.

- Gray-box dimensions must be evaluated against dash distance, jump height, wall interaction, camera visibility, and weapon ranges.
- Building height, alley width, ledge placement, stair spacing, and rooftop access must support readable traversal.
- Do not scale map geometry solely for visual grandeur.
- Expose reusable map-generation dimensions through focused configuration where practical.
- A generated map must fail clearly when construction errors occur.
- Failure in optional map construction must not prevent unrelated critical services from initialising.
- Effects, materials, and lighting must preserve character and projectile readability.
- District Zero may be tuned iteratively, but map tuning should remain separate from unrelated combat or persistence sprints.

---

# UI and Frontend Philosophy

- UI should communicate state without covering the movement space.
- HUD presentation must remain readable at common 16:9 resolutions.
- Branding should be prominent without blocking gameplay information.
- Input visualisation should help the player understand execution.
- Technique teaching should show what happened and what was missed.
- Do not let UI focus compete with gameplay input.
- Menus, chat, settings, and free-look must explicitly acquire and release input ownership.
- Use scale-based layout where appropriate, but visually inspect at representative resolutions.
- Do not infer that a mathematically centred image is optically centred.
- Source images may contain transparent margins; inspect actual artwork bounds before solving layout issues through extreme scale or cropping.
- Preserve aspect ratio for approved branding assets.
- Do not modify unrelated UI during mechanical sprints.

---

# Developer and Inspection Tools

Temporary developer tools are allowed when they materially improve iteration.

Examples include:

- Free-look pose inspection
- Hitbox visualisation
- Movement trajectories
- Timing diagnostics
- State labels
- Surface-contact rays
- Camera obstruction visualisation
- Weapon attachment guides

Rules:

- Give each tool a clear owner.
- Keep it locally scoped.
- Do not alter authoritative gameplay outcomes.
- Do not leak into competitive releases unintentionally.
- Prefer a config or environment gate where practical.
- Use semantic actions rather than unexplained raw key checks.
- Clean up temporary Instances, connections, and render bindings.
- Hide or disable the tool outside its intended environment.
- Do not leave high-frequency debug prints active.
- A developer tool may become a player-facing lobby or photo feature later, but that transition requires an explicit product decision.

---

# Determinism and Time

- Use explicit `deltaTime` for gameplay-critical stepping where appropriate.
- Pass time into reusable calculations when practical.
- Process actions in a stable order.
- Do not depend on `pairs()` ordering for gameplay.
- Use deliberate tolerances for floating-point comparisons.
- Keep gameplay state transitions independent from frame-rate where practical.
- Use seeded randomness for gameplay randomness.
- Cosmetic randomness may remain local where it has no gameplay consequence.
- Roblox physics is not fully deterministic; keep local rules consistent and introduce authoritative correction when competitive networking requires it.

---

# Safety and Cleanup

- Never discard, revert, overwrite, or destroy existing user changes.
- Inspect the working tree before editing.
- Treat modified and untracked files as user work.
- Do not use destructive Git or filesystem commands without explicit instruction.
- Do not expose or commit credentials, tokens, private keys, or sensitive player information.
- Give every connection, task, render binding, temporary Instance, and character-bound resource a clear owner.
- Disconnect owned `RBXScriptConnection`s during teardown.
- Cancel owned tasks during teardown where possible.
- Remove temporary Instances.
- Guard against destroyed Instances and stale character references.
- Rebind safely after respawn.
- Prevent duplicate connections after respawn or reinitialisation.
- Bound waits for optional or delayed dependencies.
- Avoid unbounded `WaitForChild` on dependencies that may legitimately be absent.
- Failure paths should emit useful one-shot diagnostics rather than warning spam.
- Do not silently swallow errors.
- Use protected calls around fallible independent startup work when failure isolation is required.

---

# Performance Rules

BLIKK must protect camera, input, movement, and combat responsiveness.

- Treat input, camera, movement, render callbacks, heartbeat callbacks, and future network handlers as hot paths.
- Keep per-frame work bounded.
- Avoid unnecessary `RenderStepped` and `Heartbeat` work.
- Prefer events when a system does not need per-frame updates.
- Do not create Instances every frame.
- Do not create unbounded tables, histories, queues, or buffers.
- Do not yield inside render-step callbacks.
- Avoid creating new closures or temporary tables every frame without reason.
- Cache stable service and Instance lookups.
- Rebind character references safely after respawn.
- Prevent memory leaks and duplicate render bindings.
- Use a stepped state machine instead of blocking loops when that improves cancellation and cleanup.
- Profile before broad optimisation.
- Do not sacrifice accepted gameplay feel based on speculative performance concerns.

---

# Roblox API Rules

- Use `game:GetService()` and cache stable service references at module scope.
- Prefer modern supported APIs.
- Avoid deprecated APIs.
- Use `RunService` deliberately for simulation or render scheduling.
- Use `UserInputService` for low-level device input.
- Use `ContextActionService` when priority, action binding, or cross-device behaviour requires it.
- Use `CollectionService` when tags provide meaningful discovery or lifecycle management.
- Use `TweenService` for presentation, not authoritative gameplay state.
- Use `Workspace.CurrentCamera` for the active local camera.
- Use `Humanoid`, `Animator`, and `HumanoidRootPart` deliberately.
- Choose an API because it fits the current feature, not because it appears in this list.

---

# Coding Standards

- Use `--!strict` for new modules where practical.
- Improve touched legacy typing incrementally without turning a small sprint into a migration.
- Cache services at module scope.
- Place requires near the top after services.
- Keep functions focused.
- Prefer guard clauses.
- Avoid `any` merely to silence normal type errors.
- Narrow untyped engine boundaries promptly.
- Avoid magic strings for actions and states where a shared definition exists.
- Do not leave noisy debug output in frequent paths.
- Make the smallest coherent change that fully implements the sprint.
- Do not combine feature work with unrelated formatting.
- Do not move files or rename APIs without need.
- Preserve existing style in touched files unless the sprint explicitly includes cleanup.

## Luau Style

- Indent with tabs.
- Do not mix tabs and spaces within a file.
- Prefer lines at or below 100 characters where practical.
- Use blank lines between logical sections.
- Use trailing commas in multiline tables.
- Suggested module order:
  1. Strict directive
  2. Services
  3. Requires
  4. Types
  5. Constants
  6. Private state
  7. Private functions
  8. Public API
  9. Return
- Use `local function name()` for private functions.
- Use `:` only when a method intentionally consumes `self`.
- Use `.` for stateless namespace functions.
- Use guard clauses for invalid state.
- Avoid metatables unless lifecycle or identity semantics require them.
- End statements without semicolons.

## Naming

- Files, modules, and exported types: `PascalCase`
- Local variables and functions: `camelCase`
- Structural constants: `UPPER_SNAKE_CASE`
- Boolean names read as predicates: `isDashing`, `hasCharacter`, `canCancel`
- Events describe occurrences: `DashStarted`, `ActionBegan`
- Requests describe intent: `RequestDash`, `RequestMovementLabSpawn`
- Include units where useful.
- Avoid unclear abbreviations.

---

# Comments and Documentation

- Comments explain why, not what.
- Document responsibility and lifecycle when code and types are insufficient.
- Explain non-obvious Roblox engine behaviour.
- Explain temporary compatibility workarounds.
- Avoid narrating obvious lines.
- Avoid vague TODOs.
- A TODO must state the missing decision or concrete reason.
- Update focused docs when behaviour or setup meaningfully changes.
- Keep documentation proportional to the feature.
- Do not claim a document exists without checking.
- Do not leave canonical docs knowingly contradicting accepted implementation when the sprint includes documentation maintenance.

---

# Verification and Roblox Studio Testing

The user is the final authority on gameplay feel and visual approval.

Static validation may include:

- `git status`
- `git diff`
- `git diff --check`
- Repository searches
- Type-aware inspection
- Rojo builds
- Existing automated tests
- Existing linting
- Existing CI

Static checks cannot approve:

- Movement feel
- Camera feel
- Pose quality
- Weapon proportions
- Optical UI alignment
- Animation quality
- Runtime replication
- DataStore behaviour
- Competitive responsiveness

## Manual Test Requirements

Every gameplay or presentation sprint must provide exact Roblox Studio steps.

Test as relevant:

- Initial load
- Repeated activation
- Character reset
- Multiple respawns
- Equip and holster
- Weapon switching
- Ground movement
- Air movement
- Dash directions
- Wall interaction
- Camera modes
- Chat and UI focus
- Error output
- Duplicate Instances
- Stale animation or pose state
- Representative resolutions
- Low and high frame-rate conditions where practical

Never claim a Studio test was performed when it was not.

## Visual Acceptance

For visual tuning, request clear screenshots from relevant angles.

For a weapon or pose, this may include:

- Rear
- Side
- Front three-quarter
- Equipped
- Holstered
- Idle
- Moving
- Dashing
- Blocking
- Slashing

Exact transform values remain provisional until the user approves the result visually.

---

# Git and Checkpoint Workflow

No agent may create or push a checkpoint before the user explicitly approves the sprint.

## Before Approval

Agents may use read-only Git commands to inspect:

- Working tree status
- Diffs
- History
- Current branch
- Configured remotes

Do not:

- Stage files
- Commit
- Push
- Switch branches
- Create branches
- Rewrite history
- Revert files
- Discard changes
- Open pull requests

unless the user explicitly requests the exact action.

## Required Approval Gate

Before every BLIKK commit:

1. The user completes Roblox Studio testing where applicable.
2. The user explicitly confirms functional and visual approval.
3. A clear sprint or commit title is provided.
4. A detailed commit description is provided.
5. The user approves or directs use of that title and description.
6. Only intended files are staged.
7. The staged diff is reviewed.
8. The commit is created.
9. A push occurs only when explicitly requested.

The sprint title and detailed description must be provided **before** commit commands or an instruction to commit.

## Commit Execution

When explicitly asked to commit and push:

- Confirm the intended file list.
- Run `git diff --check`.
- Review the complete diff.
- Stage only approved files.
- Run `git diff --cached --check`.
- Review the staged diff.
- Commit using the approved title and description.
- Push to the currently configured approved branch.
- Report:
  - Commit hash
  - Branch
  - Push result
  - Final Git status

Do not modify files during the checkpoint process.

---

# Sprint Workflow

1. **Read governance.** Read the complete `AGENTS.md`.
2. **Read the sprint.** Read the complete user-approved sprint prompt.
3. **Inspect.** Inspect the working tree, mappings, docs, config, and implementation.
4. **Restate scope.** State the objective, non-goals, protected systems, and likely files.
5. **Implement directly.** Edit repository files rather than asking the user to paste source.
6. **Keep scope tight.** Do not bundle unrelated technical domains.
7. **Complete the slice.** Avoid placeholders and disconnected scaffolding.
8. **Review.** Inspect the diff for accidental changes, hardcoded tuning, duplication, stale state, and cleanup issues.
9. **Validate statically.** Run all proportionate available checks.
10. **Hand off.** Provide files changed, behaviour implemented, exact Studio steps, expected results, and unverified risks.
11. **Wait for approval.** Do not provide or execute a checkpoint prematurely.
12. **Tune within the sprint.** Make small visual or feel adjustments without broadening scope.
13. **Receive explicit approval.**
14. **Provide title and description.**
15. **Checkpoint only when instructed.**
16. **Begin the next sprint only after the current working tree is safely understood.**

---

# Agent Completion Report

After implementation, provide one structured handoff containing:

## Files changed

List every modified file.

## Behaviour implemented

Explain the result in concrete terms.

## Exact values changed

For tuning work, report old and new values.

## Protected systems

Confirm what was intentionally left unchanged.

## Validation performed

List commands, searches, builds, and tests actually performed.

## Manual Roblox Studio validation

Provide exact steps and expected results.

## Remaining risks

State what could not be verified.

Do not claim approval.

Do not commit or push.

Do not provide a checkpoint title or description until the user confirms the sprint works and requests or expects checkpoint preparation.

---

# Prototype Definition of Done

A change is ready for user playtesting when:

- It implements the requested playable or visible behaviour.
- It does not consist only of placeholders or debug prints.
- Relevant values are configurable.
- Existing approved systems are preserved.
- Unrelated files remain untouched.
- Resource lifecycle and respawn cleanup are handled.
- Static checks pass where available.
- Runtime unknowns are stated honestly.
- Exact Studio test steps are supplied.

A gameplay-feel or presentation sprint is not accepted until the user has tested it and explicitly approved it.

A persistence sprint is not accepted until save and load behaviour has been tested in an environment with DataStore access.

A networked combat sprint is not accepted merely because local client presentation works.

---

# Final Decision Rule

When trade-offs compete, use this order:

1. Safety and preservation of user work
2. Playable correctness
3. Gameplay feel
4. Responsiveness
5. Competitive and player-data integrity where applicable
6. Clarity and maintainability
7. Performance
8. Visual polish

Visual polish remains important, but it must support—not obscure—the movement and combat language that defines BLIKK.