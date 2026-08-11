# BLIKK Movement Specification

## 1. Purpose

This document is the movement source of truth for BLIKK. Gameplay feel is authoritative: responsiveness, predictable direction, and player expression take priority over realism or visual polish. Current behaviour is distinguished from provisional tuning and planned systems.

Ordinary airborne movement retains full gravity outside a narrow `+16` through `-48` studs/second
window. Inside it, gravity eases to `0.58` at the apex and progressively returns to `0.88` before
normal fall acceleration resumes. This adds a restrained trick-shot beat without increasing configured
jump height, changing weapon accuracy, or creating a low-gravity map.

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

The client movement owner models `Grounded`, `JumpRising`, `AirborneFree`, ground/air/return dash, ranged tumble, `WallApproach`, vertical and horizontal wall runs, `WallPost`, `WallJumpRecovery`, `WallCancelFreedom`, and same-wall rejection. Mobility phases remain Entry, Travel, and Exit. `MovementEngine` is the sole client gameplay writer of root velocity during dash, tumble, and wall movement; sensing and presentation only report or observe state. Death, respawn, menu entry, settings, and character replacement cancel stale state.

## 6. Dash Specification

Directional double taps activate a camera-relative dash. Direction is captured on the accepted second tap and cannot bend during travel. Ground and air dashes have separate distance and cooldown values. One air dash is currently available before landing. Vertical momentum is preserved at activation.

Current provisional values are 18.125 studs ground distance, 16.25 studs air distance, a 0.25-second double-tap window, 0.32-second ground cooldown, and 0.34-second air cooldown. Entry, travel, and exit are 0.040, 0.125, and 0.085 seconds. Each accepted dash consumes one complete two-press pair; a 0.090-second single-capacity follow-up buffer preserves a deliberate pair entered near recovery without synthesizing input. Phase interpolation uses smooth-step easing while its area preserves the configured travel distance. These are playtest values, not permanent balance.

The intended result is immediate, explosive, addictive, repeatable, readable, and suitable for future K-style chaining. Animation, effects, and audio remain independent from dash validity. Dash does not modify the configured camera FOV.

## 7. Jump and Air Control

Ground movement uses an 18-stud/second forward speed, 16-stud strafe speed, and 13-stud backward speed. Humanoid jump supplies vertical movement with the configured 7.5-stud `JumpHeight`, a 0.18-second landing buffer, and 0.10-second grounded grace. Airborne jump presses do not create an open-air double jump; they may instead be consumed by an eligible wall action. Dash and tumble preserve live vertical momentum while airborne. Landing resets the normal air-mobility allowance and all wall-return eligibility.

## 8. Camera Relationship

The crosshair remains mathematically centred. Locomotion and dash use the flat camera basis, character yaw follows camera yaw, and accepted dash headings remain fixed. Neutral framing looks toward the horizon without camera latency. Presentation feedback must be subtle and configurable. See `CAMERA_SPEC.md` for camera rules.

## 9. Presentation Rules

Movement presentation may provide authored animation hooks, procedural fallbacks, directional poses, VFX, camera feedback, and audio. Gameplay never waits for assets. Do not fabricate asset IDs or use copyrighted assets. Presentation must clean up on cancellation, death, respawn, and replacement, and must scale through effects quality and Reduced Effects.

The procedural dash silhouette is phase-driven rather than a fixed lean. Shoulder intent appears
before delayed hip motion, then a direction-specific lead foot clears into the travel phase and
recovers before the dash ends. Firearm-equipped directional double taps use a distinct 0.500-second,
direction-aware 360-degree tumble with a readable mid-rotation float, compact limb tuck, and
inverse-waist aim stabilisation. Its half-second commitment is unchanged: the initial dive eases into
a slower inversion, recovery rotation accelerates, and the avatar reaches upright by 88 percent so
the final segment settles cleanly before presentation release. It travels 12.5 studs grounded or 11 studs airborne and cannot
match the katana dash's burst speed. Presentation does not alter the authored movement curve,
captured direction, or air allowance.

Dash streaks are white world-space Beam effects. Their endpoints follow recent root-part displacement,
then live velocity, so airborne streaks match the rising or falling travel tangent; grounded streaks
discard vertical jitter. This visual sampling never writes velocity or controls the dash trajectory.

## 10. K-Style Technique Framework

Butterfly recognition counts manually entered Slash-to-Block pairs inside one accepted jump. One,
two, and three valid airborne pairs produce Butterfly, Double Butterfly, and Triple Butterfly. Dash
is recorded as moving-variant context but is not required for documented static variants. The server
validates the live airborne fighter, equipped katana, monotonic melee requests, jump generation,
unique slash sequence, cancel interval, chain age, and inter-pair gap. No action is synthesized.

Swap Shot, Reload Shot, Slash Shot, and Half Step are recognized from accepted server actions rather
than raw key presses. Slash Shot is Jump, Dash, Slash, firearm switch, Fire. Half Step inserts one
earned continuation dash after the firearm switch and before Fire. Swap Shot is an accepted shot,
switch to the other firearm, then another accepted shot. Reload Shot adds an accepted reload cancel
between those shots. Existing slash, block, dash, equip, reload, recoil, and fire presentations form
the visible technique animation; recognition never waits for a bespoke clip. Reload Half Step,
Double Half Step, formal Wall Butterfly, Wall Cancel, and later combinations remain planned.

## 11. Cancellation Model

- A hard cancel ends the source state immediately.
- A soft cancel enters defined recovery or retained momentum.
- A buffered follow-up executes when its eligibility window opens.
- A presentation interruption stops visuals without changing gameplay state.
- A movement interruption transfers velocity ownership through an explicit transition.

The current Training Katana implements buffered slash-to-guard cancellation without changing
velocity. The server preserves the already accepted active-frame contact while validating the guard,
which makes a correctly executed single Butterfly both offensive and defensive without rewriting dash.

Normal slashes retain the complete 0.340-second commitment. Only a server-eligible airborne
slash-to-block cancel predicts a 0.050-second repeated-pair lockout locally and shortens that
player's authoritative next-slash deadline after the server accepts the Butterfly pair. This narrow
exception makes two or three manual pairs possible within one jump without increasing grounded
slash speed.

Half Step does not change the normal one-air-dash limit. An airborne pre-dash slash followed by a
firearm equip may earn one 0.340-second continuation opportunity. It is consumed by the next valid
air dash, expires independently, and is cleared by landing, suppression, death, or replacement.

Training Katana cancel timing is owned by the per-weapon profile in `TechniqueConfig`: 0.030 seconds anticipation, 0.110 seconds active swing, 0.200 seconds recovery, a 0.060–0.225-second cancel window, 0.085 seconds early buffering, 0.040 seconds post-cancel block blend, 0.070 seconds landing forgiveness, 0.060 seconds air-action forgiveness, and a 0.050-second repeated-sequence lockout. All values are provisional. Evidence and BLIKK-specific interpretations are frozen in `docs/K_STYLE_EVIDENCE.md`.

### 11.1 Movement Truth Wall Interaction

Wall contact is sensed by bounded forward, angled, and pure-side spherecasts using authored wall metadata where available and a conservative vertical-geometry fallback. Contact scoring values tangent travel as well as inward approach, so an established side run is not replaced by an adhesion crawl. Only a ground-origin Jump made while running head-on into close wall contact may begin a vertical run; the same head-on Jump pressed after the character is already airborne produces a standard wall jump. An 8–58 degree approach to the wall plane may begin BLIKK's horizontal multi-run path. Horizontal runs retain accepted tangent momentum, accelerate toward their authored traversal speed, and follow a short vertical arc. During a run, signed wall-plane distance maintains a rig-relative safety radius using bounded velocity correction rather than position changes. Manual jump exits, missing or changed contact, ceiling obstruction, clearance loss, height caps, and duration caps transfer once to an outward/upward recovery launch.

With melee equipped, holding airborne Secondary on accepted contact enters a capped `WallPost` rather
than the grounded katana alternate. Releasing drops the player away; a fresh Jump uses the normal
wall launch. Posting never grants an extra dash and respects same-wall separation evidence.

The input edge that begins a wall run is consumed. Manual exit requires a newer Jump edge after the configured freshness delay. Classic posting launches at 68 studs/second upward and 32 outward, then uses 65 percent gravity for 0.14 seconds; Slash earns a return dash after a 0.12-second breathing beat, with 0.22 seconds of early-input buffering. Slash-first scaling remains fastest: Jump is accepted 0.075-0.38 seconds after Slash, launches at 82 upward and 30 outward, uses 60 percent gravity for 0.16 seconds, and unlocks its return dash after 0.14 seconds. Same-wall reuse requires 0.28 seconds, 0.45 studs of separation, 0.25 studs of contact movement, inward velocity, a new spherecast contact, and another buffered Jump. See `WALL_INTERACTION.md` for the paired-recording calibration.

A fresh exit Jump entered just before the minimum run/post exit delay is retained for at most `0.180`
seconds and executes when that delay opens. This preserves a deliberate high-APM rhythm without
synthesizing another input edge.

## 12. Environment Requirements

Movement environments require measured streets, side-dash visibility, opposing walls, corner transitions, elevated routes, duel space, drop routes, and repeatable loops. District Zero provides natural practice geometry for social and advanced play; it is not a tutorial. A future tutorial map may explicitly teach dash, Flash Step, Light Step, Block Step, Block Launch, Slash Shot, Reload Shot, and Double Butterfly.

Authored ladders are an accessibility route, not a scored movement technique. Their invisible
TrussPart volumes use Roblox's default climbing state and are marked ineligible for wall-tech
contact. Ladder climbing must not grant, consume, or reset dash, wall-return, or technique state.

## 13. Networking Direction

Current movement is a responsive client-side feel prototype. Future competitive play requires client prediction, server validation, latency tolerance, authoritative combat, and rejection of impossible movement. No full movement protocol is specified yet.

## 14. Performance Requirements

Avoid unnecessary per-frame allocations, leaked connections, duplicate respawn listeners, and unbounded histories. Pool effects when useful. Diagnostics remain disabled by default. Visual quality may change presentation but never movement or collision.

## 15. Testing Standard

Playtests cover activation reliability, four-direction correctness, captured headings, ground and air limits, held inputs, jump momentum, interruption, death, respawn, rebinding, menu/chat/settings suppression, effects tiers, environment clearance, and subjective rhythm. Roblox Studio testing and owner feel approval are mandatory.

## 16. Definition of Done

A movement feature must function reliably, feel intentional, expose tuning through shared config, support appropriate presentation, survive respawn, respect semantic rebinding and interface suppression, run on low-end hardware, integrate with future techniques, pass Studio testing, and receive owner approval before any Git checkpoint description is prepared.
