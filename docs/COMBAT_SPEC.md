# BLIKK Combat Specification

# Purpose

Combat exists to reward movement.

Movement creates opportunities.

Weapons capitalize on those opportunities.

Skill always beats statistics.

---

# Combat Philosophy

Combat should feel:

- Fast
- Readable
- Responsive
- Technical
- Fair

Every hit should feel earned.

---

# Combat Pillars

Movement

↓

Position

↓

Timing

↓

Execution

↓

Reward

---

# Weapons

## Current Prototype Foundation

The Training Katana has client-side equip, idle, slash, held-block, slash-to-block cancellation, airborne presentation, authored-animation hooks, and a procedural R15 fallback. This layer is presentation-only: it has no hitbox, damage, guard effect, target detection, or server combat authority.

Primary Action maps to slash and Alternate Action maps to block while the Melee slot is active. Dedicated Slash and Block actions remain aliases. Firearm slots retain their future category-dependent interpretation.

The provisional slash phases are 0.025 seconds anticipation, 0.115 seconds active presentation, and 0.160 seconds recovery. Block may cancel slash from 0.055 through 0.205 seconds after acceptance, with 0.080 seconds of early buffering. Per-weapon cancellation, forgiveness, blend, and lockout values are centralized in `TechniqueConfig` and require feel testing.

## Sprint 025.0 training arsenal

The Training Katana remains presentation-only. The B-8 shotgun has a narrow server-authoritative
pellet-combat vertical slice.
The Training Katana procedurally presents holster, equip/unequip, ground/air idle, alternating ground
slashes, air slash, block enter/hold/exit, slash-to-block cancels, wall readiness, wall slash, and
interruption. The two slash variants share the same 0.300-second code-owned timing and reset to the
first variation after 0.65 seconds of inactivity.

`TrainingShotgun` remains the stable definition ID and displays as **BLIKK B-8 BREAKSHOT**. Primary1
and Primary2 independently own five loaded rounds, twenty reserve rounds, a one-second fire deadline,
reload token, and state. The guaranteed repository-built fallback is an original compact single-
barrel pump-action silhouette. Shared prototype combat tuning is twelve pellets, nine damage per
pellet, a 4.5-degree spread half-angle, and 300-stud maximum range, without falloff or headshots.

The client predicts bounded presentation and sends only slot, monotonic sequence, aim direction, and
diagnostic timestamp. The server owns ammunition, shell commits, cooldowns, deterministic cone rays,
hit resolution, and damage. It derives its muzzle origin and never accepts client targets, hits,
damage, ammunition, cooldown completion, or ray origin. Valid attackers are registered through
`MatchService:RegisterDamageSource` before aggregated pellet damage is applied. The retained shared
spread generator uses one server-owned seed to produce exactly twelve unit directions uniformly over
the circular 4.5-degree cone; there is no guaranteed centre pellet.

Each accepted shot publishes a dedicated bounded presentation payload containing shooter user ID,
spawn generation, sequence, equipped firearm slot, server-derived origin, and exactly twelve finite
server ray endpoints. It is sent only to the shooter and members of the same active room/match. The
shooter may replace the replicated origin with a short-lived cached rendered-muzzle origin for visual
streak alignment, but never changes the authoritative endpoints. Rejected shots publish no authoritative
streak or endpoint presentation.

Confirmed damage remains private to the shooter on the existing `FirearmResult` reconciliation remote;
it is never added to the room-scoped shot-presentation payload. An accepted fire result carries the
server spawn generation and a dense array of at most twelve per-target records. Each record contains
an allowlisted target kind, a bounded stable string ID, one-to-twelve pellet hits, raw/AP/HP/applied
damage no greater than the configured 108-damage shot maximum, one finite average impact position,
and an elimination boolean. The client supplies none of those values and validates all of them before
presentation. Rejected shots, stale generations, malformed results, and world-only impacts produce no
hit feedback.

Movement Lab owns exactly one server-created practice dummy for each District Zero map generation.
Its R15 appearance is fetched asynchronously from configured user `7709079953`; a failed fetch or
avatar construction receives one safe default-description fallback. Construction is generation-gated,
sanitized before entering Workspace, and registered by server-only model identity, attributes, and a
CollectionService tag. Player respawn and Movement Lab re-entry never rebuild it. A map rebuild or
service teardown invalidates all model, reset, readout, animation, Katana, and asynchronous ownership.

The fixed dummy bay is derived from the Clock Tower centre and south-wall footprint. It evaluates the
wall centre, four studs left/right, then eight studs left/right, always at the configured wall stand-off
and facing world `+Z` into the plaza. Every candidate requires collidable level ground, bounded body
clearance, an actual Clock Tower wall behind it at the expected stand-off, and no Clock Tower
intersection. It never falls back to a player spawn. One failure warning reports bounded rejection
totals.

The practice dummy uses the shared Training Katana geometry and canonical right-hand equipped grip,
plus the repository-trusted R15 standing idle. It has exactly one presentation Katana and no Tool,
hitbox, melee controller, attack behavior, score identity, match membership, or persistence identity.
Dummy damage uses the same authoritative AP-first resolver as fighters but never calls player-only
match attribution, awards a kill, or changes match statistics.

Shooter feedback is presentation-only. One aggregated number is projected from each confirmed target's
average pellet impact, and one reusable crosshair hitmarker is refreshed for any applied damage. Both
use bounded pre-created UI ownership. AP feedback is blue, HP feedback is green, mixed damage preserves
both component colors, and elimination may use a red accent. A single reusable confirmed-hit Sound is
retriggered once only when the accepted shot's server result contains positive total applied damage;
it never triggers per pellet, per target, on misses, or from prediction. A second reusable Sound
triggers only from a shooter-private server reload-accepted acknowledgement. Audio never participates
in hit, reload, or damage authority.

Shot streaks are cosmetic Beams from an eight-shot, ninety-six-pellet pool owned by one client effects
controller and updated through one connection. The pool reclaims a complete oldest shot on wrap,
never creates per-shot attachments, and applies no collision or damage. Impact presentation is limited
to endpoints until the server supplies validated normals and hit categories. Local muzzle flash,
light, sparks, and smoke are reusable weapon-owned objects triggered immediately on a locally valid
shot; remote flashes use the accepted server origin.

While a local firearm is equipped and ready, firearm aim is automatic: there is no aim button and no
aim-down-sights mode. The existing centered crosshair ray supplies local presentation intent. A
firearm-owned R15 IK layer aligns the right-hand grip and barrel to that intent and keeps the left hand
on the canonical foregrip. It yields during reload, switching, tumble, input suppression, frontend
ownership, death, and character replacement. This IK is presentation-only; it does not change shot
direction, spread, ammunition, timing, damage, or the server-derived ray origin. Remote-player aim
replication is not part of the current local presentation slice.

The arm solve derives pitch only from the camera direction in character-root space. Shoulder width,
upper-torso height, and arm reach produce a scale-relative neutral receiver position that stays on the
fighter's right/front side without independent aim yaw. A rear stock reference derived from the coded
stock geometry becomes the pitch pivot. Both hand targets are then derived from the same rigid receiver
transform and its canonical trigger-grip and foregrip references. The solve never derives presentation
pitch from an IK-driven hand, receiver, foregrip, or muzzle. Developer free-look stops supplying aim
updates and freezes the last solved pose. Only the selected firearm model is parented to the rendered
character; inactive firearm models retain their slot state outside the DataModel and own no hand grip
or visible effects.

Mechanical recoil owns an explicit shot timestamp rather than a firearm-state timestamp. Its pure
envelope rises for 0.020 seconds, holds for 0.015 seconds, and returns for 0.110 seconds. During that
envelope the complete canonical receiver pitches upward nine degrees around its stock basis and moves
0.12 studs rearward; both IK targets follow the same receiver transform. The pump begins after the
main kick and runs as a separate 0.235-second cycle. Zero recoil remains exactly the approved ready
pose, and recoil never changes crosshair aim, server shot direction, character root, or camera.

The coded B-8 receiver is authored directly in its canonical basis, so `GeometryToCanonical` is the
identity transform: local `-Z` runs from stock to muzzle, local `+Y` runs from the grips toward the
receiver top, and local `+X` is weapon-right. Geometry-derived stock, muzzle, top, and bottom references
must validate the proposed receiver before arm IK is enabled. At runtime the muzzle-to-stock direction
must agree with the intended forward basis, the top-to-bottom direction must agree with its corrected-up
basis, both grips must remain below the barrel line, and the foregrip must remain ahead of the trigger
grip. A disabled-by-default local diagnostic can display those references, both IK targets, both poles,
and the canonical blue-forward, green-up, and red-right axes without affecting gameplay.

`PoseCoordinator` owns legacy `Motor6D` character-joint procedural posing only. Upgraded
`AnimationConstraint` rigs intentionally retain their native animation presentation; finding no
compatible `Motor6D` pose joints on such a rig is an expected capability mode, not a partial-rig
error. Base/idle claims have priority 20, dash and wall priority 30, weapon actions priority 40, and
shotgun tumble priority 50.
The isolated firearm aim rig owns only its local R15 arm IK controls and targets. Weapon hinge and
shell joints remain internal to their presentation model. No pose changes root physics, collision,
velocity, dash timing, camera rotation, or FOV.

Accepted presentation actions publish timestamped semantic events for equip, unequip, fire, reload
start/commit/cancel, slash, block, and tumble start/end. The technique controller retains a bounded
history for future sequence definitions but does not award Slash Shot, Reload Shot, Half Step, or
Reload Half Step.

Weapon selection uses one presentation transaction for `1`, `Q`, `E`, and both wheel directions.
The latest valid request wins, blocks old-weapon fire while pending, and commits the fighter slot,
visible weapon, HUD, input target, and semantic transition together. Each B-8 keeps independent
magazine and reserve state. Delayed firearm work validates character and switch generations, slot identity,
slot token, and model lifetime. Input suppression restores the selected firearm to `Ready` and
non-rendered firearms to `Idle` without changing ammunition, cooldowns, or emitting fabricated actions.

An accepted B-8 reload commits once at the configured opening-plus-insertion point. The server computes
the missing magazine amount, transfers the minimum of that amount and finite reserve, performs one
ammunition mutation, and reconciles the actual transferred count. A switch or other accepted
pre-commit cancellation invalidates the slot token and transfers nothing; a stale task cannot refill a
different slot, character, or spawn generation. The reload initiation cue comes from the private
`ReloadAccepted` response, never from the local key press.

Movement Lab is the only authoritative unlimited-reserve context. Each B-8 still has a five-shell
magazine, firing still consumes it, and reload remains required, but a valid whole-magazine reload
does not decrement reserve. The replicated reconciliation carries a finite reserve plus an explicit
`UnlimitedReserve` boolean, and the HUD renders the reserve as infinity. Multiplayer keeps finite
server-owned reserve and never accepts an unlimited-ammo request from the client.

Butterfly and Wall Butterfly candidates are internal movement/combat telemetry only. They do not imply a hit, successful technique award, guard outcome, or authoritative combat result.

## Melee

Future categories:

- Dagger
- Katana
- Dual Daggers
- Dual Katanas
- Long Sword

Every melee weapon supports:

- Idle
- Equip
- Unequip
- Slash
- Block
- Hit
- Trails

---

## Firearms

Future categories:

- Shotguns
- Pistols
- Heavy Pistols
- SMGs
- Assault Rifles

Every firearm supports:

- Equip
- Idle
- Fire
- Reload
- Empty
- Unequip

Presentation hooks:

- muzzle flash
- shell eject
- smoke
- sound

---

# Equipment

Slots

Equipment 1

Equipment 2

Types

- Med Kit
- Armour Kit
- Med HoT
- Armour HoT

---

# Armour

The current prototype initializes each authoritative fresh fighter life with
the `FighterVitalsConfig` maximum health and armour. Health remains owned by
the server-side Humanoid and armour is replicated through server-written
character attributes for HUD observation. Accepted firearm damage is aggregated by pellet target,
then the server drains current armour before applying the remainder to the Humanoid. Armour is clamped
between zero and the authoritative maximum, and a valid attacker is registered even when armour absorbs
the complete shot. Armour regeneration and equipment-derived maximum changes are not implemented.

Slots

Head

Body

Legs

Feet

Future armour affects:

- HP
- AP
- Appearance

---

# Rings

Two slots.

Future examples:

- HP Ring
- AP Ring
- Movement Ring
- Reload Ring
- Dash Ring

Rings change playstyle.

Not raw power.

---

# Hit Detection

Future implementation:

Server authoritative.

Client prediction.

Clear hit confirmation.

Readable effects.

---

# Techniques

Future combat techniques include:

- Butterfly
- Double Butterfly
- Triple Butterfly
- Slash Shot
- Reload Shot
- Half Step
- Reload Half Step

Detection uses semantic actions.

Never animation coincidence.

---

# Animation Rules

Gameplay first.

Animations communicate.

Animations never block player input unnecessarily.

Future cancels remain configurable.

---

# Effects

Every attack supports:

Animation

↓

Audio

↓

Particles

↓

Camera Feedback

↓

UI Feedback

All scale with graphics settings.

---

# Definition of Done

Combat features are complete when they:

- feel satisfying
- reward skill
- remain readable
- perform well
- survive latency
- integrate with movement
