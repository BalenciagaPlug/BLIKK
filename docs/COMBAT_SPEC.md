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
`MatchService:RegisterDamageSource` before aggregated pellet damage is applied.

All character-body procedural poses flow through `PoseCoordinator`. Base/idle claims have priority
20, dash and wall priority 30, weapon actions priority 40, and shotgun tumble priority 50. Weapon
hinge and shell joints remain internal to their presentation model. No pose changes root physics,
collision, velocity, dash timing, camera rotation, or FOV.

Accepted presentation actions publish timestamped semantic events for equip, unequip, fire, reload
start/commit/cancel, slash, block, and tumble start/end. The technique controller retains a bounded
history for future sequence definitions but does not award Slash Shot, Reload Shot, Half Step, or
Reload Half Step.

Weapon selection uses one presentation transaction for `1`, `Q`, `E`, and both wheel directions.
The latest valid request wins, blocks old-weapon fire while pending, and commits the fighter slot,
visible weapon, HUD, input target, and semantic transition together. Each B-8 keeps independent
magazine and reserve state. Delayed firearm work validates character and switch generations, slot identity,
slot token, and model lifetime. Input suppression restores the selected firearm to `Ready` and
holstered firearms to `Idle` without changing ammunition, cooldowns, or emitting fabricated actions.

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
character attributes for HUD observation. Armour absorption, armour damage,
regeneration, and equipment-derived maximum changes are not implemented by
this initialization foundation.

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
