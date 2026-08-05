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
