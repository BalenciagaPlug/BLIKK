# BLIKK K-Style Movement and Katana Evidence Lock

## Purpose

This document freezes the evidence and BLIKK-specific decisions used for the current movement and
katana foundation. It prevents later tuning from being described as authentic GunZ behavior without
support, while leaving owner playtesting authoritative for BLIKK feel.

## Source hierarchy

1. Original or current official GunZ material establishes design intent and named mechanics.
2. Historical player-facing references may bound timing or control behavior when official material
   does not publish implementation details; those values are triangulation, not engine truth.
3. The community-maintained Open-GunZ source fork supplies inspectable implementation evidence, but
   is not treated as proof that every retail GunZ build used identical constants or compile flags.
4. Roblox documentation establishes supported animation and networking behavior.

Sources reviewed on 2026-08-10:

- MAIET's historical GunZ International weapon guide, preserved at
  `https://gunz.gg/gunz/weapon.php`, describes melee weapons as central to close combat and rates
  the katana with medium delay, above-medium damage, and good control.
- The official GunZ Steam page at
  `https://store.steampowered.com/app/3139440/GunZ_The_Duel/` identifies fluid movement,
  environment use, dashes, acrobatic air combat, and close/long-range weapon transitions as the
  classic play language.
- The official Korean GunZ site at `https://gunz.net/` identifies dash, wall jump, tumbling, wall
  movement, multi-jump, and sword/gun air combinations as core actions.
- The archival Open-GunZ `ZMyCharacter.cpp` mirror defines a `0.5`-second tumble delay, a `0.3`-
  second jump queue, five-percent airborne movement acceleration, and separate vertical, outward,
  and side wall-exit impulses. Its wall-run checks require meaningful incoming speed and preserve
  wall-tangent travel rather than replacing it with a slow wall slide.
- The archival `ZCharacter.h` mirror distinguishes `630` forward run speed from `450` movement in
  other directions and exposes melee, primary, secondary, item-one, and item-two equipment slots.
  These original-unit values establish ratios and action roles only; they are not converted directly
  into Roblox studs.
- The GunZ community Wall Run reference at `https://gunz.fandom.com/wiki/Wall_Run` distinguishes
  head-on vertical entry from roughly 45-degree horizontal entry. The community technique guide at
  `https://gunz.gitbook.io/gunz-guide/how-to-play-gunz/combat-guide/d-style` describes Wall Cancel as
  wall exit Jump plus slash/stab cancellation followed by a dash back into the wall, and Multi Wall
  Running as horizontal run, Jump/slash, angled return dash, then a fresh Jump. These sources lock the
  input/state rhythm, not proprietary engine constants.
- Historical GameFAQs equipment tables at
  `https://gamefaqs.gamespot.com/pc/928753-gunz-the-duel/faqs/37344` list representative sword
  delays from 329 through 359 and damage from 15 through 24. These are secondary, player-facing
  numbers and do not prove hidden simulation or animation code.
- Roblox `AnimationConstraint` documentation at
  `https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint` supports procedural
  transform layers evaluated around `PreSimulation` on upgraded avatar joints.
- Roblox remote-event documentation at `https://create.roblox.com/docs/scripting/events/remote`
  supports reliable remotes for gameplay results and unreliable remotes for disposable presentation.
- MAIET's historical GunZ International controls at `https://gunz.gg/gunz/play.php` establish
  mouse-button shoot/slash, player-adjustable key layout, weapon cycling, chat, and menu controls.
- The historical GunZ configuration reference at `https://w.atwiki.jp/gunzwiki/pages/30.html`
  records a default mouse sensitivity value of `0.400000`, editable values beyond the normal menu
  limit, Y inversion, and crosshair selection. It is a secondary configuration record, not evidence
  of physical DPI, degrees-per-count, Windows pointer behavior, or an engine response curve.
- Roblox `UserInputService` documentation at
  `https://create.roblox.com/docs/reference/engine/classes/UserInputService` establishes centred
  mouse locking, mouse-delta input events, per-render mouse displacement, focus events, and the local
  `MouseDeltaSensitivity` scale available to a custom camera.
- Open-GunZ `ZActionDef.h` and `ZMyCharacter.cpp` at
  `https://github.com/open-gunz/ogz-source` keep defence separate from weapon secondary, limit katana
  secondary to grounded state, schedule its uppercut work at `0.18` seconds, and cap held guard at
  `2.0` seconds. The guard-start compile flag varies, so this source does not prove one universal
  retail guard-entry invulnerability duration.
- Open-GunZ `ZGameAction.cpp` resolves uppercut in the forward half-space and calls the target blast
  reaction without normal weapon damage. `ZGame.cpp` accepts firearm guard only when the incoming
  direction opposes the defender's facing by more than 90 degrees. Original engine distance and blast
  units are not converted into Roblox studs or velocities.
- StrategyWiki's historical GunZ controls/equipment pages at
  `https://strategywiki.org/wiki/GunZ:_The_Duel/Controls` and
  `https://strategywiki.org/wiki/GunZ:_The_Duel/Equipment` describe Shift guard, right-click sword
  uppercut, and the upward launch result. These are secondary player-facing corroboration.
- GameFAQs' historical K-style guide at
  `https://gamefaqs.gamespot.com/pc/928753-gunz-the-duel/faqs/39739` records the player-entered
  Butterfly order as Jump, Dash, Slash, Block. It supports action order, not an exact hidden timing
  window.
- GameFAQs' historical move-cancel and K-style reference at
  `https://gamefaqs.gamespot.com/pc/928753-gunz-the-duel/faqs/50467` records Slash-to-Block,
  Gunshot-to-Reload, and Reload-to-Weapon-Switch cancellation; Butterfly as Jump, Dash, Slash,
  Block; Double Butterfly as two Slash-to-Block pairs in one jump; Reload Shot as Fire, Reload,
  switch, Fire; Slash Shot as Jump, Dash, Slash, switch, Fire; and Half Step as the Slash Shot
  sequence with a gun dash before the shot. It publishes order and relationships, not frame timing.
- StrategyWiki's historical advanced-technique page at
  `https://strategywiki.org/wiki/GunZ_The_Duel/Korean-Style_and_Advanced_Techniques` distinguishes
  static Butterfly, Double Butterfly, Triple Butterfly, Swap Shot, Reload Shot, Slash Shot, and Half
  Step variants. It corroborates player vocabulary but is not treated as engine source.
- GunZ Academy's 2024 comprehensive guide at `https://www.youtube.com/watch?v=FxlyAiZUvzY`
  separately demonstrates Butterfly, Slash Shot, Half Step, Swap Shot, Reload Shot, Double
  Butterfly, and Triple Butterfly. Video demonstration supports visible action order and rhythm,
  not a universal server-side timing constant.

## Locked interpretation

- K-style flow is ordered execution with short commitments and explicit cancels. It is not unrestricted
  repeated activation from overlapping input edges.
- A directional dash consumes two fresh presses. The second press cannot also become the first press
  of the next dash.
- A bounded follow-up buffer may preserve a deliberately entered pair near recovery. It may never
  synthesize missing inputs or automate a technique.
- Dash distance, direction capture, air-dash limit, live gravity, wall rules, and camera-relative basis
  remain BLIKK contracts; research does not authorize changing them implicitly.
- The Training Katana uses an original BLIKK value of 18 AP-first damage and a 0.340-second slash beat.
  Those values sit inside the historical reference band but are not claimed as a copied GunZ weapon.
- The damage contact is a server-owned forward arc. A player cannot hit behind their torso, through a
  wall, twice on the same target in one swing, or by supplying a client target. The client may supply
  only a unit crosshair direction; the server validates facing and pitch, derives the query from the
  authoritative root, and independently resolves eligible targets.
- The visible slash is a compact one-handed cut through forward aim space. Root and lower-body joints
  stay unkeyed. Large rear windups, full spins, and presentation that hides the contact frame are out
  of contract for the Training Katana.
- The historical GunZ value `0.400000` must never be copied into BLIKK or described as equivalent
  sensitivity without evidence for the original game's physical conversion. BLIKK exposes its own
  auditable degrees-per-input-pixel scale instead.
- Mouse rotation is a direct linear mapping with equal horizontal and vertical gain. There is no
  BLIKK-added acceleration, smoothing, deadzone, movement-state modifier, weapon-state modifier,
  aim-down-sights modifier, or FOV modifier.
- Every mouse delta is accumulated and integrated exactly once at render time without a `deltaTime`
  multiplier. Gameplay, developer free-look, and death-camera orbit share this implementation.
- Opening a menu, losing window focus, switching camera ownership, entering free-look, dying, or
  respawning flushes unapplied movement so reacquisition cannot snap the camera.
- Melee guard and Alternate Action remain separate semantic actions. BLIKK defaults Block to Left
  Shift and Alternate Action to right mouse for new/default binding sets; saved custom bindings are
  preserved.
- The katana alternate is ground-only, presents contact at `0.180` seconds, launches eligible targets,
  and deals no normal weapon damage. Its Roblox reach and launch velocities are original BLIKK values.
- Guard is server-owned, lasts at most `2.000` seconds, and protects only the forward half-space. A
  successful melee guard ends the guard; ranged impacts may continue against a held guard.
- Butterfly's invariant is one player-entered airborne Slash-to-Block pair inside one jump. Dash is
  part of the canonical moving Butterfly, while documented static variants remain valid. Double and
  Triple Butterfly are two and three unique pairs inside the same jump; no input is automated.
- Reviewed sources hardlock technique order and cancellation relationships but do not establish one
  universal retail frame window. All second-based BLIKK recognition windows below are original,
  auditable calibration and require owner playtesting.
- Swap Shot is accepted Fire A, switch, Fire B. Reload Shot inserts accepted Reload after Fire A and
  before the switch. Slash Shot is Jump, Dash, Slash, firearm switch, Fire. Half Step inserts one
  post-switch air dash before Fire. More specific recognition wins, so Half Step is not also reported
  as Slash Shot and Reload Shot is not also reported as Swap Shot.
- Technique recognition never creates damage, reload completion, ammunition, movement, or an input.
  Existing authoritative action services perform those outcomes independently.
- GunZ's official material establishes tumbling and wall hanging as core movement vocabulary. The
  archival source hardlocks a half-second tumble delay but not a portable Roblox animation curve.
  BLIKK therefore uses an original 360-degree procedural roll with a restrained mid-rotation float,
  inverse-waist aim stabilisation, and a distinct slower traversal profile.
- BLIKK wall posting uses airborne melee Secondary while a valid wall is under the wall sensor. It
  is an original semantic adaptation of GunZ wall hanging: hold is capped, release drops away, and
  a fresh Jump performs the normal validated wall launch. It does not synthesize a slash or dash.

## Current BLIKK calibration

- Slash phases: `0.030` anticipation, `0.110` active, `0.200` recovery; `0.340` total.
- Slash contact query: `0.085` seconds after server acceptance, at the active-window midpoint.
- Slash damage: `18`, AP first and then HP.
- Slash volume: `3.2 x 3.8 x 6.0` studs, centered `3.0` studs along the validated crosshair direction
  from an authoritative root origin `0.65` studs up.
- Slash arc: maximum `6.5` studs, `24`-degree half-angle, `3.5`-stud vertical tolerance, at most three
  eligible targets per swing.
- Slash aim validation: unit-vector magnitude `0.90` to `1.10`, flat facing dot at least `0.65`, and
  pitch from `-55` through `55` degrees.
- Dash phases: `0.040` entry, `0.125` travel, `0.085` exit; `0.250` total.
- Dash pair window: `0.250`; follow-up buffer: `0.090`.
- Dash cooldowns from activation: `0.320` ground and `0.340` air.
- Dash distances remain `18.125` ground and `16.25` air.
- Firearm tumble phases are `0.100` entry, `0.300` travel, and `0.100` exit; distances are `12.5`
  ground and `11.0` air, with `0.550`/`0.580`-second ground/air cooldowns. These are BLIKK values
  chosen to preserve the archival half-second role while remaining distinct from katana dash.
- Ground locomotion is `18` forward, `16` strafe, and `13` backward studs/second. Jump height is
  `7.5` studs, landing/wall buffers are `0.180` seconds, and grounded grace is `0.100` seconds.
- Vertical wall runs last at most `0.680` seconds, ease from `30` to `8` studs/second upward, and cap
  at `2.6` character heights. Horizontal runs retain full accepted tangent speed, accelerate toward
  `34` studs/second with a `29`-stud/second floor, last at most `1.050` seconds, and use a `14` to `-2`
  studs/second vertical arc. Wall posting lasts at most `0.850` seconds. The wall-cancel return dash
  has a `0.480`-second spend window and bypasses only ordinary dash cooldown. All numeric values are
  Roblox-scaled BLIKK calibration rather than claimed GunZ constants.
- Mouse sensitivity default: `0.030` degrees per input pixel, logarithmic settings range `0.003` to
  `0.500`, typed numeric entry supported, and account persistence retained.
- Roblox mouse-delta scale while captured: neutral `1.0`; restored to its previous value on release.
- Guard maximum hold: `2.000`; frontal threshold: defender-to-attacker facing dot greater than `0`.
- Katana alternate: `0.180` contact, `0.420` total, `6.75`-stud reach, `52` studs/second upward and
  `16` studs/second forward launch; the reach and velocities are BLIKK-original calibration.
- Butterfly chain: `0.900` seconds maximum from accepted jump, `0.300` seconds maximum between
  accepted pairs, three pairs maximum, and `0.050` seconds repeated-slash lockout after each accepted
  airborne cancel. Normal uncancelled slash cadence remains `0.340` seconds.
- Slash Shot: pre-slash dash age at most `0.350`, equip within `0.300` after slash, fire within `0.250`
  after equip, and `0.550` total recognition window.
- Half Step: `0.750` total recognition window, one continuation dash available for `0.340` after
  firearm equip, dash within `0.350` after equip, and fire within `0.250` after that dash.
- Swap Shot: second accepted shot within `0.550` of the first and `0.250` of the committed switch.
- Reload Shot: reload within `0.200` after the first shot, switch within `0.250` after reload, and the
  second accepted shot within `0.550` of the first.

All calibration remains subject to Roblox Studio feel testing. Changing a value requires updating its
domain config and this document when the evidence interpretation or locked contract changes.
