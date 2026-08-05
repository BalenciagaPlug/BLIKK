# BLIKK Movement Specification

## Purpose

BLIKK movement is a combat system built around speed, directional confidence, precise timing, and player expression. It draws inspiration from the cadence and combinatorial depth associated with K-style movement while remaining an original, Roblox-native design.

This specification defines the intended behavior and boundaries of BLIKK movement. Status labels have the following meanings:

- **Implemented:** present in the current client prototype.
- **Provisional:** implemented, but subject to playtest-driven tuning or replacement.
- **Planned:** design direction only; not current gameplay behavior.

## Movement Pillars

1. **Immediate response.** Accepted input affects movement without artificial anticipation.
2. **Directional commitment.** Committed actions have clear trajectories and do not bend accidentally.
3. **Combinatorial depth.** Advanced play should emerge from a small vocabulary of reliable primitives.
4. **Readable momentum.** Entry, travel, and exit behavior must be understandable to both the player and opponents.
5. **Deterministic rules where practical.** Identical ordered inputs and state should produce consistent decisions.
6. **Gameplay feel before spectacle.** Presentation communicates movement but never delays or determines it.
7. **Configurable tuning.** Every value affecting timing, distance, speed, momentum, limits, or feedback belongs in shared configuration.

## Input Architecture

**Implemented.** Raw keyboard and mouse inputs are translated into semantic actions by the client input layer. Movement consumes `Forward`, `Backward`, `Left`, `Right`, and `Jump`, not physical key names. Two binding slots are supported, and rebinding updates the token-to-action lookup without changing movement-domain logic.

Input begins and ends are represented separately. Directional held state drives walking; ordered directional presses drive double-tap recognition. Accepted actions are also placed in a bounded shared action buffer for systems that require short timing windows.

Gameplay input is suppressed while BLIKK settings are open. Interface actions remain independently available where appropriate. Escape is reserved from gameplay binding capture.

**Planned.** Future devices should map into the same semantic actions. Combat and movement contexts may later add explicit priority and consumption rules, but raw device checks must not leak into movement mechanics.

## Timing Philosophy

Timing windows are deliberate contracts, not animation side effects. Each window must have a named configuration value, stable clock source, explicit start event, and explicit expiry.

The current dash recognises a second press of the same direction within `0.25` seconds. This value is **provisional**. A rejected dash must not erase ordinary held movement. Presentation timing follows accepted gameplay state and cannot extend eligibility or delay activation.

Future cancel windows must identify the source action, destination action, open time, close time, and resulting momentum rule. Frame-rate-dependent counters are not acceptable substitutes for elapsed time.

## Movement State Model

**Implemented states:**

- **Grounded locomotion:** camera-relative walking with normal jump and ground-dash eligibility.
- **Airborne locomotion:** normal airborne Roblox physics with one provisional air dash.
- **Dash Entry:** rapid acceleration into a captured direction.
- **Dash Travel:** committed displacement with no camera steering.
- **Dash Exit:** controlled deceleration to retained horizontal momentum.
- **Gameplay Suppressed:** movement input cleared while an interface owns input.

Dash state owns horizontal velocity during its three phases. Walking remains logically held but sends zero locomotion while the dash is active, preventing the default run cycle from presenting a run-in-place state. Held walking resumes after dash completion.

**Planned states:** wall interaction, weapon-action commitment, technique recovery, knockback, stagger, and other combat-driven states. These must integrate through explicit transitions rather than unrelated flags.

## Dash Specification

**Implemented; all values below are provisional.**

Dash activates by double-tapping one semantic direction. On the accepted second tap, the system captures the flat camera basis and resolves a fixed world-space direction. Camera movement after acceptance cannot curve the dash.

| Property | Current value |
|---|---:|
| Double-tap window | 0.25 s |
| Ground distance target | 14.5 studs |
| Air distance target | 13 studs |
| Entry duration | 0.035 s |
| Travel duration | 0.115 s |
| Exit duration | 0.085 s |
| Entry speed multiplier | 0.90 |
| Peak speed multiplier | 1.55 |
| Travel-end multiplier | 1.00 |
| Exit momentum retention | 0.34 |
| Ground cooldown | 0.24 s |
| Air cooldown | 0.30 s |
| Air-dash limit | 1 per airborne period |
| Vertical momentum mode | Preserve at activation |
| Future cancel hook | 0.05–0.19 s |

The phase curve is normalised against the configured distance target. Entry accelerates to peak speed, travel eases toward its ending multiplier, and exit eases toward retained momentum. Completion must not force horizontal velocity to zero. Directional actions share the same distances unless an intentional, documented balance requirement introduces differences.

Dash exposes start, update, and end events for presentation and future technique integration. Diagnostics are disabled by default and may report direction, grounded state, phase, displacement, duration, peak speed, rejection, and interruption information.

## Jump and Air Control

**Implemented.** Jump is a semantic action that requests a Humanoid jump. Airborne state is detected through Humanoid floor and state information. One air dash is allowed before landing; the allowance resets on landing, grounded running, or respawn. Dash preserves the vertical velocity captured at activation.

The configured jump height of `7.2` is **provisional but not currently applied by the movement engine**; current jump magnitude remains governed by the Humanoid configuration. This discrepancy must be resolved before jump tuning is considered authoritative.

**Planned.** Dedicated air acceleration, friction, gravity shaping, jump buffering, coyote time, and landing recovery require explicit designs and configuration before implementation.

## Camera Relationship

**Implemented.** Walking and dash direction use the camera’s yaw-only forward and right vectors. Pitch does not introduce vertical dash direction. The character follows camera yaw while alive.

The gameplay camera is scriptable, mouse-driven, centre-locked during gameplay, and paired with a centred crosshair. Camera framing, distance, shoulder offset, field of view, sensitivity, invert-Y behavior, and pitch limits are configurable independently from movement.

Dash may request a small presentation-only FOV impulse. Camera feedback cannot change the captured dash direction, delay input, or become the source of movement state.

## Presentation Rules

Presentation observes gameplay state and is always optional. Dash must remain mechanically complete if animation, effects, or audio are disabled or unavailable.

**Implemented and provisional:** directional procedural poses modify root, waist, shoulders, and hips after the default character animation update. Forward, backward, left, and right poses are distinct. Transforms reset on completion, interruption, settings suppression, death, and respawn. Empty directional animation slots exist for future authored assets; no fabricated asset identifiers are permitted.

Dash effects use original Roblox-native beams at head, waist, and foot height, plus a restrained grounded departure accent. Quality settings reduce count, width, or lifetime; Reduced Effects disables presentation. Temporary instances have bounded lifetimes and cleanup ownership. Audio uses an optional empty sound hook routed through the BLIKK dash sound group.

## K-Style Technique Framework

**Planned.** K-style depth will emerge from legal sequences of movement, melee, defence, weapon switching, reload, and environment interaction. Candidate techniques include Butterfly, Slash Shot, Reload Shot, Half Step, and wall-based transitions.

Technique names describe player-facing combinations, not monolithic hardcoded abilities. Each technique must be decomposed into reusable primitives, ordered semantic inputs, state requirements, cancel windows, momentum consequences, and recovery. No future technique may require rewriting dash direction capture or presentation ownership.

## Cancellation Model

**Planned foundation.** A cancellation is an explicit state transition permitted during a configured interval. It must define:

- source and destination states;
- opening and closing times;
- required semantic input;
- grounded, airborne, equipment, and resource requirements;
- retained, replaced, or redirected momentum;
- presentation interruption and recovery behavior.

The current dash configuration reserves a provisional `0.05–0.19` second hook, and dash presentation exposes immediate interruption. No gameplay technique currently consumes this hook. Visual completion never determines cancel eligibility.

## Environment Requirements

Movement test spaces must provide long flat lanes, directional reference markings, ledges for air-dash testing, repeatable elevation changes, and enough clearance to observe full displacement. Surfaces must not conceal collision defects or compensate for incorrect movement tuning.

**Planned.** Wall mechanics will require clearly classified wall surfaces, predictable normals, minimum dimensions, and test geometry covering corners, seams, slopes, and invalid surfaces. Environment art must preserve movement readability and collision consistency.

## Networking Direction

**Current status:** the movement prototype is client-side and is not secure competitive authority.

**Planned.** The client will submit semantic intent and predict responsive local movement. The server will validate competitive outcomes, action eligibility, rates, state transitions, and plausible movement envelopes. Reconciliation must preserve responsiveness without accepting client-authored final state. Networking work should begin when multiplayer movement validation enters scope, not by prematurely weakening the local feel prototype.

## Performance Requirements

- Movement hot paths must perform bounded work and avoid per-frame allocation.
- Dash uses one shared state update rather than per-dash event connections or blocking loops.
- Camera and procedural pose callbacks must not yield.
- Temporary presentation instances must have deterministic cleanup.
- Character and Humanoid references must be rebound safely after respawn.
- Reinitialisation must not duplicate connections or render-step bindings.
- Effects quality must reduce real BLIKK-owned work.
- Optimisation must be guided by profiling without sacrificing input response.

## Testing Standard

Every movement change must be evaluated in Roblox Studio across:

- all four camera-relative directions;
- primary and secondary rebound inputs;
- held input after the accepted second tap;
- rapid direction changes and camera rotation during commitment;
- ground and air activation, air-dash exhaustion, and landing reset;
- entry, travel, exit, retained momentum, and cooldown cadence;
- settings suppression, interruption, death, and respawn;
- presentation enabled, Reduced Effects, and each effects-quality level;
- representative frame rates and viewport sizes;
- measured displacement and duration when tuning is under review.

Automated deterministic tests are **planned** for pure timing, curve, eligibility, and state-transition logic. Studio playtesting remains required for subjective feel and Roblox physics integration.

## Definition of Done

A movement feature is complete when:

- its player-facing behavior is playable and approved through feel testing;
- semantic input, eligibility, state transitions, momentum, and cancellation are explicit;
- every gameplay value is named and configurable;
- behavior is deterministic where Roblox physics permits;
- camera-relative rules remain consistent;
- presentation cannot delay or determine gameplay;
- interruption, death, respawn, and interface suppression restore clean state;
- temporary instances, connections, and callbacks have bounded ownership;
- rebound controls remain functional;
- relevant performance and regression tests pass;
- implemented, provisional, and planned behavior are documented accurately.
