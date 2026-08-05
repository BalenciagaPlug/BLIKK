Create and directly write a comprehensive movement design specification into:

docs/MOVEMENT_SPEC.md

Read:
- AGENTS.md
- docs/BLIKK_LORE.md
- the complete current movement, input, camera, settings and dash implementation
- all relevant config modules

Do not modify gameplay code in this task.
Do not commit or push anything.

PURPOSE

MOVEMENT_SPEC.md must become the authoritative design and technical source of truth for all BLIKK movement systems.

BLIKK is a Roblox movement-combat game inspired by the skill expression and responsiveness of GunZ: The Duel, but it must remain original and Roblox-native.

The document must preserve the project’s current philosophy:

- Movement is the game.
- Responsiveness beats realism.
- Player expression beats automation.
- Animations and effects must communicate movement without delaying input.
- Mechanics should combine into a high-skill K-style-inspired system.
- BLIKK Movement Lab is the dedicated training environment.
- Future competitive content belongs to BLIKK: The Duels.

DOCUMENT REQUIREMENTS

Include these sections:

# BLIKK Movement Specification

## 1. Purpose
Explain what the document controls and how Codex or developers must use it.

## 2. Movement Pillars
Define:
- responsiveness,
- flow,
- commitment,
- readability,
- consistency,
- expression,
- performance,
- cancelability.

Clarify where commitment is desirable and where control must be preserved.

## 3. Input Architecture
Document the current intended flow:

Physical Input
→ Binding State
→ Semantic Action
→ Action Buffer
→ Movement State
→ Technique Detection
→ Presentation

Explain:
- two binding slots,
- rebinding,
- double-tap detection,
- input buffering,
- settings suppression,
- scoreboard/menu safety,
- why mechanics must use semantic actions rather than hardcoded keys.

## 4. Timing Philosophy
Define timing in seconds rather than vague frame counts.

Cover:
- input windows,
- buffer windows,
- cancel windows,
- cooldowns,
- recovery,
- early/late tolerance,
- why high-level techniques must remain fast enough for expert input,
- why animation contact frames must not determine whether a valid input sequence succeeds.

## 5. Movement State Model
Define the expected state system, including:

- Idle
- Grounded Locomotion
- Jumping
- Falling
- Ground Dash
- Air Dash
- Landing
- Future Wall Interaction
- Future Slash
- Future Block
- Future Weapon Action
- Future Technique State

Explain:
- which states may overlap,
- which are exclusive,
- interruption rules,
- cleanup,
- respawn reset,
- settings/menu interruption.

## 6. Dash Specification
Document the current dash foundation and intended feel.

Include:
- double-tap directional activation,
- camera-relative direction capture,
- fixed travel direction,
- ground and air dash differences,
- one current air dash before landing,
- entry/travel/exit phases,
- momentum-retaining exit,
- no run-in-place animation,
- future cancel hooks,
- effects and presentation independence.

Record the current provisional starting values from MovementConfig, but clearly label them tunable rather than permanent.

Also describe the target subjective feeling:
- immediate,
- explosive,
- addictive,
- repeatable,
- readable,
- suitable for chaining into K-style techniques.

## 7. Jump and Air Control
Define:
- jump responsibility,
- vertical momentum preservation,
- air control expectations,
- landing reset,
- future wall-jump compatibility,
- why dash must not destroy jump timing.

## 8. Camera Relationship
Document:
- centred crosshair,
- camera-relative movement,
- character yaw,
- captured dash heading,
- no mid-dash bending,
- neutral horizon-facing framing,
- no camera latency,
- subtle configurable feedback only.

Reference CAMERA_SPEC.md as the future detailed source without inventing content that is not written yet.

## 9. Presentation Rules
For every movement mechanic, require relevant:

- authored animation slots,
- procedural fallback,
- directional poses,
- VFX,
- camera feedback,
- audio hooks,
- effects-quality scaling,
- Reduced Effects behaviour.

Clarify:
- gameplay may never depend on presentation assets loading,
- no fabricated animation or sound IDs,
- no copyrighted GunZ assets,
- cleanup on interruption/death/respawn,
- presentation must respond instantly to cancellation.

## 10. K-Style Technique Framework
Define each future technique conceptually without implementing it:

- Butterfly
- Double Butterfly
- Triple Butterfly
- Slash Shot
- Reload Shot
- Half Step
- Reload Half Step
- Wall Cancel
- Future advanced combinations

For each technique, describe:
- semantic action sequence,
- purpose,
- required underlying primitives,
- why timing must be configurable,
- detection should come from action order and timing rather than animation coincidence.

Do not invent final timing values yet.
Mark them as playtest-driven.

## 11. Cancellation Model
Define:
- hard cancel,
- soft cancel,
- buffered follow-up,
- presentation-only interruption,
- movement-state interruption.

Explain how future slash, block, reload and weapon-swap actions should integrate without rewriting dash.

## 12. Environment Requirements
Explain how Movement Lab geometry must support:

- dash lanes,
- side-dash readability,
- wall-jump practice,
- wall-cancel corners,
- Butterfly spacing,
- Triple Butterfly rhythm,
- shotgun swap lanes,
- elevated routes,
- open duel space,
- repeatable movement loops.

Clarify that the environment must be measured against real character scale and movement distances.

## 13. Networking Direction
State that current work is a client-side feel prototype.

Document future goals:
- responsive client prediction,
- server validation,
- anti-cheat considerations,
- authoritative combat,
- tolerance for latency,
- preserving feel without trusting impossible movement.

Do not design the full networking protocol yet.

## 14. Performance Requirements
Include:
- no unnecessary per-frame allocations,
- no leaking connections,
- no duplicate respawn listeners,
- pooled effects where useful,
- potato-PC support,
- quality tiers,
- movement identical across visual-quality settings,
- diagnostics disabled by default.

## 15. Testing Standard
Create a repeatable movement playtest checklist covering:

- activation reliability,
- direction correctness,
- ground/air behaviour,
- held-input behaviour,
- interruption,
- respawn,
- rebinding,
- settings suppression,
- effects quality,
- subjective feel.

## 16. Definition of Done
A movement feature is not complete merely because it executes.

It must:
- function reliably,
- feel intentional,
- have relevant animation/presentation,
- expose config,
- survive respawn,
- respect rebinding and menus,
- scale to low-end hardware,
- support future techniques,
- pass Roblox Studio playtesting,
- receive user approval before Git checkpoint.

STYLE REQUIREMENTS

- Professional Markdown.
- Clear and authoritative.
- Detailed enough for long-term development.
- Avoid generic enterprise filler.
- Match BLIKK’s current rapid-prototype stage.
- Distinguish current implemented behaviour from future design intent.
- Do not claim systems exist when they do not.
- Preserve the project’s terminology.
- Keep gameplay feel central.

At completion, report:
1. Sections written.
2. Existing code/config inspected.
3. Current behaviour documented.
4. Future behaviour marked as planned.
5. Any inconsistencies or design questions discovered.