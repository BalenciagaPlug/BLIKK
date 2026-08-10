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

The Training Katana has client-predicted equip, idle, slash, held guard, slash-to-guard
cancellation, grounded alternate launch, airborne presentation, authored-animation hooks, and
repository-owned procedural R15 fallbacks. Slash damage, frontal guard outcomes, alternate launch,
and single-Butterfly acceptance are server-authoritative.

Primary Action maps to slash and Alternate Action maps to the grounded upward-launch attack while
the Melee slot is active. The dedicated Block action defaults to Left Shift and remains rebindable;
the dedicated Slash action remains an alias. Existing saved bindings are not rewritten. Firearm
slots retain their category-dependent interpretation.

The provisional slash phases are 0.030 seconds anticipation, 0.110 seconds active presentation, and 0.200 seconds recovery. Block may cancel slash from 0.060 through 0.225 seconds after acceptance, with 0.085 seconds of early buffering. Per-weapon cancellation, forgiveness, blend, and lockout values are centralized in `TechniqueConfig` and require feel testing.

Guard intent is predicted locally and validated by the server against the live character, spawn,
equipped melee slot, request order, action state, and maximum two-second hold. It rejects firearm and
melee contact only while the attacker is inside the defender's forward 180-degree half-space. A
successful melee guard ends that guard; ranged contact may continue to be held. Guard never changes
movement velocity, and its procedural fallback keys only upper-body joints so ground and air
locomotion continue underneath it.

Katana Alternate Action is a ground-only 0.420-second upward cut. Its server-owned contact occurs at
0.180 seconds, selects bounded visible targets in front, deals no normal weapon damage, and applies
an original Roblox-scale 52-stud-per-second upward plus 16-stud-per-second forward launch. Those
launch values and the 6.75-stud reach are BLIKK calibration, not converted GunZ engine units. The
procedural fallback uses the complete body for readable coil, forward rise, and recovery without
moving the character root in world space.

`KatanaSlash1` is the first approved authored-ground-slash integration point. Its original BLIKK
motion is a compact one-handed right-to-left lateral cut at waist-to-lower-rib height, authored for
the exact upgraded R15 gameplay rig. It may key only Waist, both shoulders, both elbows, RightWrist,
and an optional Neck counter-rotation no greater than 6 degrees. Root and lower-body joints remain
unkeyed so locomotion, jump, dash, and wall systems retain ownership. The complete authoring,
publication, and asset-registration contract is in `docs/ANIMATION_ASSETS.md`.

Gameplay code—not animation length or markers—continues to own slash acceptance, the exact
0.030/0.110/0.200-second phases, the 0.060–0.225 cancel window, the 0.085-second input buffer, and
the 0.030–0.140 trail window. A valid slash track runs at Action priority and 1.0 speed with its
slash-specific fades. While it plays, the melee controller releases its competing procedural ground
slash claim; movement and unkeyed lower-body animation continue. If the asset is absent, rejected,
or fails to load/play, the repository-owned procedural slash resumes immediately without affecting timing.
Block, switching, unequip, death, replacement, room exit, stronger presentation, and controller
teardown stop and release the authored track. The existing two-variant gameplay alternation is
preserved; both grounded variants may use `KatanaSlash1` until a separately approved
`KatanaSlash2` exists.

## Sprint 025.0 training arsenal

The Training Katana and B-8 shotgun both have narrow server-authoritative damage slices.
The Training Katana procedurally presents holster, equip/unequip, ground/air idle, alternating ground
slashes, air slash, block enter/hold/exit, slash-to-block cancels, wall readiness, wall slash, and
interruption. The two slash variants share the same 0.340-second code-owned timing and reset to the
first variation after 0.65 seconds of inactivity.

The guaranteed slash fallback is a six-pose code-authored upper-body clip with explicit anticipation,
centreline cut, follow-through, and recovery. It alternates right-to-left and left-to-right variants,
uses cubic easing around a near-linear active cut, and keys only Waist, optional Neck counter-rotation,
shoulders, elbows, and wrists. Root and lower-body joints remain unkeyed during the slash so grounded,
airborne, dash, and wall locomotion retain presentation ownership. No animation upload or public
catalog dependency is required; an experience-owner-published `KatanaSlash1` can still replace the
fallback later without changing gameplay timing.

Both procedural variants now combine compact diagonal shoulder arcs with an action-only katana grip
arc. The grip sampler keeps the handle attached to the right hand while explicitly steering the blade
axis through the fighter's forward half-space, then restores the approved idle grip at recovery. The
same sampler runs for remote observers. The server accepts only monotonic equipped-melee
intent, enforces the 0.340-second cadence, and resolves one query at the 0.085-second active-window
midpoint. Each slash sends the current camera origin and unit crosshair direction. The server rejects
non-finite values, origins more than 24 studs from the authoritative root, invalid pitch, and aim that
disagrees with character facing. The accepted root-relative camera offset follows authoritative fighter
translation to the active frame while the input-time aim direction remains fixed. The authoritative
strike begins at the live right-shoulder joint and converges on the server raycast point under the
crosshair. Reach is derived from the equipped model: the half-handle, guard, blade gap, and blade total
`4.15` studs from grip origin to tip, added to the live weapon-arm length. A default R15 arm contributes
`2.55` studs for a `6.70`-stud shoulder-to-tip reach; server clamps keep valid avatar variation between
`5.95` and `7.40` studs. The full corridor width is the live left-to-right shoulder span, clamped from
`1.50` through `3.25` studs. A direct body surface under the crosshair is valid inside that reach;
fallback candidates must place their upper-torso centre inside the same shoulder-width corridor and
pass line of sight from both camera intent and weapon shoulder. Only the closest target can be selected.
Wall contact uses the identical shoulder origin, direction, and maximum reach. This removes third-person
origin parallax without allowing blade animation, client targets, or client hit claims to steer combat.
It applies 18 damage
AP first, then HP, to eligible players or the registered practice dummy. Client-supplied targets,
positions, damage, and hit claims are never accepted.

The equipped melee ready pose is independently hard-locked to the previously approved silhouette:
`-15` degrees of right-shoulder pitch, a `-1`-degree airborne right-shoulder offset, and the original
`190`-degree equipped attachment roll. Slash and block begin from that exact baseline, apply only their
action-specific forward arm/blade solve, and return to it at recovery. Block interpolates its blade
direction over the existing `0.100`-second enter presentation rather than snapping the grip.

Melee intent and private hit results are reliable. Accepted slash presentation is a bounded
`UnreliableRemoteEvent`; remote clients construct a temporary clean Training Katana and apply the same
repository-owned upper-body clip to the observed fighter. The local attacker remains predicted.
Damage numbers, hitmarkers, the dedicated melee hit-confirm sound, dummy death recovery, match death,
and Movement Lab death/respawn reuse the existing authoritative paths. Evidence and interpretation are
locked in `docs/K_STYLE_EVIDENCE.md`.

A confirmed fighter, guard, or collidable vertical-wall contact publishes a bounded presentation
record with the server-owned world position and normal. Every observing client draws the same
0.55-second, 4.6-stud slash mark at that contact. Wall and guard contacts play one positional impact
cue; remote observers also hear fighter contact, while the local attacker retains the sharper private
damage-confirm cue and does not double-play it. Floor and ceiling normals are excluded from wall marks.

`TrainingShotgun` remains the stable definition ID and displays as **BLIKK B-8 BREAKSHOT**. Primary1
and Primary2 independently own five loaded rounds, twenty reserve rounds, a one-second fire deadline,
reload token, and state. The guaranteed repository-built fallback is an original compact single-
barrel pump-action silhouette. Shared prototype combat tuning is twelve pellets, nine damage per
pellet, a 4.5-degree spread half-angle, and 300-stud maximum range, without falloff or headshots.

Firearm accuracy uses a fixed weapon-cone model. A stable root-relative origin converges on the
centered crosshair ray's world aim point for every accepted shot; rendered muzzle position,
locomotion pose, jumping, dashing, wall presentation, mechanical recoil, and repeated fire never add
spread or steer that basis. The B-8's intrinsic 4.5-degree half-angle remains identical in every
movement state. Its visible muzzle still owns local flash and streak alignment, but never becomes
client-authoritative shot geometry.

The client predicts bounded presentation and sends only slot, monotonic sequence, aim direction, and
diagnostic timestamp. The server owns ammunition, shell commits, cooldowns, deterministic cone rays,
hit resolution, and damage. It derives its muzzle origin and never accepts client targets, hits,
damage, ammunition, cooldown completion, or ray origin. Valid attackers are registered through
`MatchService:RegisterDamageSource` before aggregated pellet damage is applied. The retained shared
spread generator uses one server-owned seed to produce exactly twelve unit directions uniformly over
the circular 4.5-degree cone; there is no guaranteed centre pellet.

The same registration API has a separate Movement Lab branch. It accepts player-versus-player damage
only when both characters are current, released Movement Lab identities, neither player belongs to a
room or match, and the victim is not spawn protected. It never creates match score, winner, replay,
or progression attribution. A lethal result uses the normal character-death event, waits the
Deathmatch `3`-second respawn delay, prepares a fresh `100 AP / 100 HP` life, and applies the same
`1.5`-second spawn protection on release. Firing a damaging shot clears the attacker's protection.

Each accepted shot publishes a dedicated bounded presentation payload containing shooter user ID,
spawn generation, sequence, equipped firearm slot, server-derived origin, and exactly twelve finite
server ray endpoints. It is sent only to the shooter and members of the same active room/match, or to
the currently released roomless Movement Lab cohort for a Movement Lab shot. The
shooter may replace the replicated origin with a short-lived cached rendered-muzzle origin for visual
streak alignment, but never changes the authoritative endpoints. Rejected shots publish no authoritative
streak or endpoint presentation.

Fire intent and the private hit/miss result use reliable remotes. The server resolves all twelve
pellets, applies AP/HP, and sends the shooter result before publishing presentation. The separate
`FirearmShot` endpoint/muzzle channel is an `UnreliableRemoteEvent`: a late cosmetic packet may be
dropped instead of queueing ahead of authoritative combat state. Victim health and armour remain
server-owned replicated state; neither client authors hit, miss, damage, or elimination.

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

The dummy begins each cycle at exactly `100 AP / 100 HP`. A server-confirmed lethal result immediately
marks that generation inactive, leaves the anchored R15 rig upright with `BreakJointsOnDeath` and the
Dead state disabled, stops its idle presentation, and changes the readout to `RECOVERING`. The shooter uses
the already-validated result position to play one dedicated spatial `PracticeDummyDeath` cue through
the local effects mix. The server starts three compact green/cyan segmented scan rings that expand and
rise through the upright target; after `1.35` seconds it atomically restores `100 AP / 100 HP`,
re-enables the target, clears the recovering state, and resumes the trusted idle. All scan geometry is
destroyed by `1.25` seconds or earlier on map/service teardown. Nonlethal AP/HP damage remains exactly
where the authoritative resolver left it, regardless of inactivity, until a later shot completes the
lethal cycle. No ragdoll, kill award, match elimination, player death observer, or persistent object
is created.

Shooter feedback is presentation-only. One aggregated number is projected from each confirmed target's
average pellet impact, and one reusable crosshair hitmarker is refreshed for any applied damage. Both
use bounded pre-created UI ownership. AP feedback is blue, HP feedback is green, mixed damage preserves
both component colors, and elimination may use a red accent. The shared sound-effect owner retriggers
one non-positional firearm confirmation only when the accepted shot's server result contains positive
total applied damage; it never triggers per pellet, per target, on misses, or from prediction. The
approved reload cue triggers only from a shooter-private server reload-accepted acknowledgement.
An eliminated practice-dummy record additionally triggers one louder 18-to-130-stud spatial death cue
at its validated average impact position. Audio never participates in hit, reload, dummy recovery, or
damage authority.

Shot streaks are cosmetic Beams from an eight-shot, ninety-six-pellet pool owned by one client effects
controller and updated through one connection. The pool reclaims a complete oldest shot on wrap,
never creates per-shot attachments, and applies no collision or damage. Impact presentation is limited
to endpoints until the server supplies validated normals and hit categories. Local muzzle flash,
light, sparks, and smoke are reusable weapon-owned objects triggered immediately on a locally valid
shot; remote flashes use the accepted server origin. The same pool owns one positional remote-shot
Sound per shot group. Local accepted fire plays once through the reusable non-spatial owner; the
local shooter's replicated payload is explicitly excluded from remote audio. Rejected and malformed
payloads produce no remote report. Empty-fire feedback is limited to an equipped, ready B-8 under
active gameplay camera ownership and is rate-limited independently of fire authority.

While a local firearm is equipped and ready, firearm aim is automatic: there is no aim button and no
aim-down-sights mode. The existing centered crosshair ray supplies local presentation intent. A
firearm-owned R15 IK layer aligns the right-hand grip and barrel to that intent and keeps the left hand
on the canonical foregrip. It yields during reload, switching, tumble, input suppression, frontend
ownership, death, and character replacement. This IK is presentation-only; it does not change shot
direction, spread, ammunition, timing, damage, or the server-derived ray origin. Remote-player aim
replication is not part of the current local presentation slice.

Equip, interrupted, focus-loss, and IK-unavailable frames use a front-facing procedural carry rather
than inheriting the retired rear-half-space shoulder convention. Its right and left shoulder pitches
are `72` and `62` degrees respectively and are asserted inside the `0`-to-`110`-degree front-facing
range. The existing hand attachment, canonical receiver basis, ready IK solution, and reload pose are
unchanged.

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

`PoseCoordinator` supports both legacy `Motor6D` and Avatar Joint Upgrade `AnimationConstraint`
character graphs. Legacy transforms retain their direct procedural ownership. Constraint transforms
are resolved after Animator evaluation during `PreSimulation`. Ordinary claims remain additive so
locomotion and retargeting survive beneath the selected BLIKK pose. A weapon claim masks only the arm
joints it owns, replacing walk-cycle shoulder, elbow, and wrist motion without freezing Root, Waist,
Neck, hips, or legs. Base/idle claims have priority 20, dash and wall priority 30, weapon arms and
actions priority 40, and shotgun tumble priority 50.
The isolated firearm aim rig owns only its local R15 arm IK controls and targets. Weapon hinge and
shell joints remain internal to their presentation model. No pose changes root physics, collision,
velocity, dash timing, camera rotation, or FOV.

Every accepted directional double tap while a firearm slot is active presents a distinct tumble on
ground or in air. Its 0.500-second movement commitment, 0.42-stud base presentation lift, additional
0.20-stud mid-flip hangtime lift, compact weapon carry, and mid-rotation float keep it slower and
more readable than katana dash. Rotation slows through the inverted Matrix beat, accelerates through
recovery, reaches upright at 88 percent progress, and holds the remaining action as landing settle. The lower
body owns the full roll while inverse-waist stabilisation preserves the crosshair-driven weapon
platform. This is original BLIKK calibration informed by GunZ's documented tumble vocabulary and
archival half-second delay; it is not a copied retail animation.

Accepted presentation actions publish timestamped semantic events for equip, unequip, fire, reload
start/commit/cancel, slash, block, and tumble start/end. The technique controller retains a bounded
history for diagnostics and presentation rhythm. The server awards Butterfly through Triple
Butterfly, Swap Shot, Reload Shot, Slash Shot, and Half Step only after their component gameplay
actions have been accepted. Reload Half Step remains outside this slice.

An accepted Katana slash may schedule a presentation-only air cut at the configured active-window
boundary. Generation and state checks cancel it if the slash is superseded before that point; this
does not alter melee timing or cancel eligibility. The separate melee confirmation semantic key has
no caller until a future authoritative melee result exists. Slash input, animation overlap, trails,
and local raycasts must never synthesize that outcome.

Weapon selection uses one presentation transaction for `1`, `Q`, `E`, and both wheel directions.
The latest valid request wins, blocks old-weapon fire while pending, and commits the fighter slot,
visible weapon, HUD, input target, and semantic transition together. Each B-8 keeps independent
magazine and reserve state. Delayed firearm work validates character and switch generations, slot identity,
slot token, and model lifetime. Input suppression restores the selected firearm to `Ready` and
non-rendered firearms to `Idle` without changing ammunition, cooldowns, or emitting fabricated actions.
The handling cue follows the committed `ActiveWeaponSlot` change, never the speculative request.

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

A single Butterfly is accepted only when an accepted jump is followed by one airborne slash and a
valid guard cancel. Double and Triple Butterfly require two and three unique accepted slash/guard
pairs inside that same jump. The server validates live airborne state, katana equipment, jump serial,
slash sequence, cancel timing, a 0.900-second jump-chain cap, and a 0.300-second maximum gap between
pairs. Static and moving variants are both recognized; dash context is reported but never fabricated.
Each slash keeps its scheduled authoritative contact after presentation cancellation. Only an
accepted airborne pair shortens the next slash deadline to the 0.050-second repeat lockout.

Weapon-weave recognition runs after authoritative equip, reload, and fire acceptance. Swap Shot is
Fire A, switch, Fire B. Reload Shot is Fire A, Reload, switch, Fire B; switching before the existing
reload commit still invalidates the token and transfers no ammunition. Slash Shot is an airborne
Jump/Dash/Slash followed by firearm equip and Fire. Half Step uses the same opening plus one earned
post-equip continuation dash before Fire. The existing action poses are the technique animations:
katana slash/cancel, guard, weapon unequip/equip, reload opening, firearm tumble, aim solve, recoil,
pump, muzzle effects, and audio remain individually owned. No combo button, held-input automation,
client-authored shot, or animation marker creates acceptance.

Accepted technique names return on a reliable private result channel and drive one reusable HUD
label. They award no score, progression, damage, ammunition, cooldown relief, or aim assistance.
Reload Half Step, Double Half Step, and formal Wall Butterfly remain future slices.

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

Every fresh life receives the same four-slot BLIKK recovery belt in Movement Lab and match play:

| Key | Item | Delivery | Recovery | Stock per life |
| --- | --- | --- | --- | --- |
| `4` | Vital Patch | Deployable HP pickup | 10 HP | 2 |
| `5` | Aegis Patch | Deployable AP pickup | 10 AP | 2 |
| `6` | Vital Amp | Immediate self-use | 20 HP | 2 |
| `7` | Aegis Amp | Immediate self-use | 20 AP | 2 |

All four share a one-second use delay. Patch deployment is rejected before inventory consumption or
pickup creation when the owner already has full matching HP or AP. Otherwise it consumes stock and creates a bounded
12-second pickup that any eligible fighter in the same combat context may claim. Ampoules are
rejected without consuming stock when their resource is already full. Counts, use timing,
pickup collection, HP, and AP are server-owned and reset only through the fresh-life lifecycle.
See `RECOVERY_SPEC.md`.

---

# Armour

The current prototype initializes each authoritative fresh fighter life with
the `FighterVitalsConfig` maximum health and armour. Health remains owned by
the server-side Humanoid and armour is replicated through server-written
character attributes for HUD observation. Accepted firearm damage is aggregated by pellet target,
then the server drains current armour before applying the remainder to the Humanoid. Armour is clamped
between zero and the authoritative maximum, and a valid attacker is registered even when armour absorbs
the complete shot. Recovery is available only through server-approved pickups and per-life equipment;
passive armour or health regeneration and equipment-derived maximum changes are not implemented.

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

Implemented server-recognized combat techniques:

- Butterfly
- Double Butterfly
- Triple Butterfly
- Slash Shot
- Reload Shot
- Half Step

Future combat techniques include:

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
