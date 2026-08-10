# BLIKK Movement Truth: Wall Interaction

## Ownership and States

`MovementEngine` owns all dash, wall-run, wall-launch, and recovery state and is the only client gameplay system that writes root velocity. `WallInteractionController` performs bounded sensing and procedural pose presentation; it reports contacts but never decides movement outcomes.

The wall path is `WallApproach` into `VerticalWallRun`, `HorizontalWallRun`, melee `WallPost`, or a standard `WallJumpRecovery`. A manual or automatic run exit also enters `WallJumpRecovery`. An accepted slash during its cancel window enters `WallCancelFreedom` and earns one `WallReturnDash`. Slash-first scaling uses `WallScaleLaunch`: an accepted approach dash into a fresh wall contact, or an active wall run/post, may arm a slash for a following Jump. Landing returns to `Grounded` and clears all wall and air allowances.

## Detection and Classification

While airborne, the sensor checks the velocity or semantic movement heading, two configurable angled headings, and both pure-side headings every 0.025 seconds. Spherecasts expand their reach with horizontal speed, exclude the complete local character assembly, and select the best stable contact using 35-percent inward and 65-percent tangent velocity weighting plus previous-wall stability and distance. Floors, ceilings, slopes beyond the configured normal tolerance, transparent helpers, non-query/collision parts, and undersized fallback geometry are rejected. A run accepts only the original part and a compatible surface normal; a changed normal or wall loss expires through contact grace.

Head-on classification requires at least 72 percent inward motion, no more than 45 percent tangent motion, and meaningful inward speed. A vertical run is only accepted from a ground-origin Jump detected within 0.16 seconds and within 0.35 studs of the rig-relative contact boundary. A character already airborne at a head-on wall performs a standard wall jump when a fresh Jump is pressed. Angled classification accepts an approach 8–58 degrees from the wall plane, at least 42 percent tangent motion, 4 studs/second inward speed, and 6 studs/second tangent speed. The wider angled band preserves advanced multi-wall re-entry without turning parallel contact into passive wall adhesion.

## Clearance and Current Calibration

Minimum wall clearance is the greater horizontal half-size of the active `HumanoidRootPart` and torso plus `0.30` studs. A representative 2-stud root therefore targets `1.30` studs from root centre to wall plane. Below that boundary, inward velocity is removed and outward correction is `(clearance error × 12)`, capped at `8 studs/s`. At or above the boundary, contact uses `0.30 studs/s` adhesion. The run exits if distance exceeds the boundary by `0.90` studs. No root CFrame or Position correction is used.

- Vertical run: 0.68 seconds maximum, upward velocity easing from 30 to 8 studs/s, 2.6 character-height cap.
- Horizontal run: 1.05 seconds maximum, full tangent retention with a 29 studs/s floor, acceleration toward 34 studs/s, upward velocity easing from 14 to -2 studs/s, 1.25 character-height cap.
- Wall post: airborne melee Secondary, 0.85 seconds maximum, 2 studs/s controlled descent, 8 studs/s semantic tangent movement, and 6 studs/s release separation.
- Classic wall-posting exit: 54 studs/s upward, 48 studs/s outward, 65 percent tangent retention.
- Automatic vertical exit: 46 studs/s upward, 42 studs/s outward, 60 percent tangent retention.
- Automatic horizontal exit: 38 studs/s upward, 37.5 studs/s outward, 75 percent tangent retention.
- Fresh manual exit delay: 0.08 seconds after the consumed entry Jump timestamp, with a 0.28-second wall Jump buffer.
- Classic slash cancel: 0.22 seconds inside a 0.26-second recovery; the earned return dash remains available for 0.68 seconds, uses the existing air-dash curve, and bypasses only the ordinary approach-dash cooldown.
- Same-wall return: at least 0.10 seconds, 0.55 studs of outward separation, 0.35 studs of contact-point movement, 5 studs/s back into the wall, a new spherecast hit, and a new buffered Jump.

The two GunZ-inspired orders have deliberately different jobs. Classic wall posting is `wall exit -> slash cancel within 0.22 seconds -> return dash into wall -> fresh Jump`; its lower 54-stud upward launch and broader 0.68-second return preserve elevation and make repeated near-wall positioning accessible. Slash-first scale is the fastest vertical route: `air dash into wall -> slash -> Jump within 0.34 seconds`, or `wall run/post -> slash -> Jump within 0.34 seconds`; it launches at 66 studs/second upward and 48 studs/second outward, then grants one 0.70-second return dash. A hard-lock assertion keeps slash-first launch at least 10 studs/second faster vertically than classic posting. Horizontal multi-run extension uses the same return resource at an angled re-entry. Separation, re-entry direction, contact movement, a fresh spherecast, and a new buffered Jump still prevent sticky automatic reattachment.

All values are provisional and live in `TechniqueConfig.Wall`. Normal dash distances, phase curve, camera-relative direction capture, and Sprint 016 live airborne Y preservation are unchanged.

## Authoring Metadata

Level builders can mark a `BasePart` with the `BLIKK_WallSurface` CollectionService tag and `BLIKK_WallJumpSurface = true`. Setting that attribute to `false` always disables the surface. Untagged, collidable, queryable, sufficiently large vertical geometry remains enabled by the prototype fallback.

District Zero's `Development/WallCalibrationStrip` provides opposing gaps and multiple wall heights for repeatable tuning. It remains outside the normal spawn route.

## Diagnostics and Limitations

`TechniqueConfig.Wall.DiagnosticsEnabled` enables concise transition/rejection output and character attributes for movement state, measured rig clearance, classification, signed distance, normal/tangent velocity, adhesion, entry/exit timing, exit reason/impulse, Jump timestamps, separation and direction evidence, and return-dash eligibility. Diagnostics are off by default and do not run a per-frame print loop.

Movement remains locally simulated and is not competitive authority. Roblox Studio playtesting is required for contact reliability, high-speed corners, ceiling exits, camera headings, repeated chains, frame-rate stability, and final feel.
