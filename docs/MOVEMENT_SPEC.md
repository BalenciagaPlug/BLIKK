# BLIKK Movement Specification

## 1. Purpose

This document is the movement source of truth for BLIKK. Gameplay feel is authoritative: responsiveness, predictable direction, and player expression take priority over realism or visual polish. Current behaviour is distinguished from provisional tuning and planned systems.

## 2. Movement Pillars

- **Responsiveness:** accepted input affects play immediately.
- **Flow:** compatible actions chain without artificial pauses.
- **Commitment:** recovery matters only when it creates readable, fair decisions.
- **Readability:** players can understand direction, state, and cancellation.
- **Consistency:** equal state and ordered input produce equal rules.
- **Expression:** mastery comes from timing and composition, not automation.
- **Performance:** movement remains identical at every visual quality tier.
- **Cancelability:** transitions are explicit; presentation never traps gameplay.

## 3. Input Architecture

Current flow is Physical Input → Binding State → Semantic Action → Action Buffer → Movement State → future Technique Detection → Presentation. Actions support primary and secondary bindings. Movement consumes semantic actions rather than hardcoded keys. Double taps and buffered sequences use ordered timestamps. Settings, menus, binding capture, and chat composition suppress gameplay actions safely.

## 4. Timing Philosophy

Timing is expressed in seconds. Input, buffer, cancel, cooldown, and recovery windows are independently configurable. Expert sequences must accept fast intentional input. Animation contact frames communicate outcomes but never decide whether a valid semantic sequence succeeds.

## 5. Movement State Model

The client movement owner models `Grounded`, `JumpRising`, `AirborneFree`, ground/air/return dash, `WallApproach`, vertical and horizontal wall runs, `WallJumpRecovery`, `WallCancelFreedom`, and same-wall rejection. Dash phases remain Entry, Travel, and Exit. `MovementEngine` is the sole client gameplay writer of root velocity during dash and wall movement; sensing and presentation only report or observe state. Death, respawn, menu entry, settings, and character replacement cancel stale state.

## 6. Dash Specification

Directional double taps activate a camera-relative dash. Direction is captured on the accepted second tap and cannot bend during travel. Ground and air dashes have separate distance and cooldown values. One air dash is currently available before landing. Vertical momentum is preserved at activation.

Current provisional values are 14.5 studs ground distance, 13 studs air distance, a 0.25-second double-tap window, 0.24-second ground cooldown, and 0.30-second air cooldown. Entry, travel, and exit last 0.035, 0.115, and 0.085 seconds. These are playtest values, not permanent balance.

The intended result is immediate, explosive, addictive, repeatable, readable, and suitable for future K-style chaining. Animation, effects, and camera impulses remain independent from dash validity.

## 7. Jump and Air Control

Humanoid jump supplies vertical movement with the configured 7.2-stud `JumpHeight`, a 0.12-second landing buffer, and 0.08-second grounded grace. Airborne jump presses do not create an open-air double jump; they may instead be consumed by an eligible wall action. Dash preserves live vertical momentum while airborne. Landing resets the normal air-dash allowance and all wall-return eligibility.

## 8. Camera Relationship

The crosshair remains mathematically centred. Locomotion and dash use the flat camera basis, character yaw follows camera yaw, and accepted dash headings remain fixed. Neutral framing looks toward the horizon without camera latency. Presentation feedback must be subtle and configurable. See `CAMERA_SPEC.md` for camera rules.

## 9. Presentation Rules

Movement presentation may provide authored animation hooks, procedural fallbacks, directional poses, VFX, camera feedback, and audio. Gameplay never waits for assets. Do not fabricate asset IDs or use copyrighted assets. Presentation must clean up on cancellation, death, respawn, and replacement, and must scale through effects quality and Reduced Effects.

Dash streaks are white world-space Beam effects. Their endpoints follow recent root-part displacement,
then live velocity, so airborne streaks match the rising or falling travel tangent; grounded streaks
discard vertical jitter. This visual sampling never writes velocity or controls the dash trajectory.

## 10. K-Style Technique Framework

Butterfly candidate detection is currently implemented as lightweight local telemetry. An airborne slash cancelled into block inside the configured timing creates a candidate; additional valid cancels in the same airborne sequence create chain candidates. Landing, invalid state, input suppression, character replacement, or weapon switching breaks the sequence. Wall jumps continue the airborne sequence and expose provisional Wall Butterfly hooks. No candidate awards score, progression, damage, or tutorial completion.

Double Butterfly, Triple Butterfly, Slash Shot, Reload Shot, Half Step, Reload Half Step, formal Wall Butterfly, Wall Cancel, and later combinations remain planned. Detection uses semantic action order and timestamps rather than animation coincidence.

## 11. Cancellation Model

- A hard cancel ends the source state immediately.
- A soft cancel enters defined recovery or retained momentum.
- A buffered follow-up executes when its eligibility window opens.
- A presentation interruption stops visuals without changing gameplay state.
- A movement interruption transfers velocity ownership through an explicit transition.

The current Training Katana implements buffered slash-to-block presentation cancellation without changing velocity. Future authoritative combat actions must preserve this contract without rewriting dash.

Training Katana cancel timing is owned by the per-weapon profile in `TechniqueConfig`: 0.025 seconds anticipation, 0.115 seconds active swing, 0.160 seconds recovery, a 0.055–0.205-second cancel window, 0.080 seconds early buffering, 0.035 seconds post-cancel block blend, 0.070 seconds landing forgiveness, 0.060 seconds air-action forgiveness, and a 0.045-second repeated-sequence lockout. All values are provisional.

### 11.1 Movement Truth Wall Interaction

Wall contact is sensed by a bounded forward/side spherecast path using authored wall metadata where available and a conservative vertical-geometry fallback. Head-on entry may begin a vertical run; a 15–45 degree approach to the wall plane may begin a horizontal run; other eligible airborne contact produces a standard wall jump. During a run, signed wall-plane distance maintains a rig-relative safety radius using bounded velocity correction rather than position changes. Manual jump exits, missing or changed contact, ceiling obstruction, clearance loss, height caps, and duration caps transfer once to an outward/upward recovery launch.

The input edge that begins a wall run is consumed. Manual exit requires a newer Jump edge after the configured freshness delay. An accepted katana slash during the short wall-jump recovery cancels only that recovery and earns one time-limited return dash; it does not restore the normal air dash. Exit clears active contact, and same-wall reuse requires elapsed time, measured separation, a moved contact point, inward return velocity, a new spherecast contact, and another buffered Jump. See `WALL_INTERACTION.md` for calibration and diagnostics.

## 12. Environment Requirements

Movement environments require measured streets, side-dash visibility, opposing walls, corner transitions, elevated routes, duel space, drop routes, and repeatable loops. District Zero provides natural practice geometry for social and advanced play; it is not a tutorial. A future tutorial map may explicitly teach dash, Flash Step, Light Step, Block Step, Block Launch, Slash Shot, Reload Shot, and Double Butterfly.

## 13. Networking Direction

Current movement is a responsive client-side feel prototype. Future competitive play requires client prediction, server validation, latency tolerance, authoritative combat, and rejection of impossible movement. No full movement protocol is specified yet.

## 14. Performance Requirements

Avoid unnecessary per-frame allocations, leaked connections, duplicate respawn listeners, and unbounded histories. Pool effects when useful. Diagnostics remain disabled by default. Visual quality may change presentation but never movement or collision.

## 15. Testing Standard

Playtests cover activation reliability, four-direction correctness, captured headings, ground and air limits, held inputs, jump momentum, interruption, death, respawn, rebinding, menu/chat/settings suppression, effects tiers, environment clearance, and subjective rhythm. Roblox Studio testing and owner feel approval are mandatory.

## 16. Definition of Done

A movement feature must function reliably, feel intentional, expose tuning through shared config, support appropriate presentation, survive respawn, respect semantic rebinding and interface suppression, run on low-end hardware, integrate with future techniques, pass Studio testing, and receive owner approval before any Git checkpoint description is prepared.
