# BLIKK Wall Interaction Foundation

## Current Prototype

Wall interaction is a responsive client-side movement prototype. One controller owns detection, contact state, wall-jump velocity, same-wall protection, and procedural wall presentation. It does not implement wall running, climbing, ledge grabbing, combat outcomes, or server validation.

The states are `None`, `WallApproach`, `WallContact`, `WallJumping`, `WallRecovery`, and `RecontactLocked`. Slash and block presentation have higher pose priority than wall presentation, so melee rhythm remains readable without changing wall-jump velocity.

## Detection

While airborne, the controller checks forward and two configurable side angles at a bounded interval. Raycasts exclude the local character and its attached weapon. Floors, ceilings, near-horizontal slopes, transparent helpers, non-query parts, non-colliding parts, and geometry below the configured usable dimensions are rejected.

Explicit metadata takes priority. Untagged vertical collidable geometry may use the configured prototype fallback. This fallback is provisional and should become stricter as authored maps mature.

## Wall-Jump Physics

Wall launch combines the detected outward normal, camera-relative held movement, and retained tangential velocity. The current provisional values are 50 studs per second upward, 34 studs per second outward, 12 studs per second directional influence, and 65 percent tangential retention. These values are isolated in `TechniqueConfig.Wall`; normal jump and dash configuration is unchanged.

The exact wall is locked for 0.280 seconds and must be left by at least 5 studs before direct reuse. Contact with another valid wall clears same-wall identity immediately. Landing clears all wall state.

## Authoring Metadata

Level builders can mark a Studio `BasePart` using CollectionService tags and boolean attributes:

- Wall-jump valid: add `BLIKK_WallSurface` and set `BLIKK_WallJumpSurface = true`.
- Wall-jump invalid: set `BLIKK_WallJumpSurface = false`; this overrides fallback detection.
- Ledge: add `BLIKK_Ledge` and optionally set `BLIKK_RoofEdge = true`.
- Butterfly channel: set `BLIKK_ButterflyChannel = true` on both opposing walls.
- Recovery platform: set `BLIKK_SafeLanding = true` and `BLIKK_RecoveryDrop = true` as appropriate.

Valid walls must remain collidable, queryable, sufficiently tall and wide, and close to vertical. Decorative rails and clutter should be non-queryable or explicitly wall-jump invalid.

## Calibration Strip

District Zero contains `Development/WallCalibrationStrip`, a development-only chamber below the live district. It has five bays using 9-, 11-, and 13-stud opposing-wall gaps, wall heights of 10, 14, 18, 24, and 32 studs, a safe floor, and a non-colliding spawn marker. It is not part of the normal route or spawn system and can be disabled through District Zero configuration.

## Prototype Limitations

Wall movement is locally simulated and not secure for competitive play. Detection uses raycasts rather than full-body shapecasts, authored wall animations are empty, untagged fallback geometry is permissive, and all launch/cancel values require Roblox Studio feel testing.
