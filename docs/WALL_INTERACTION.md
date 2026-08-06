# BLIKK Movement Truth: Wall Interaction

## Ownership and States

`MovementEngine` owns all dash, wall-run, wall-launch, and recovery state and is the only client gameplay system that writes root velocity. `WallInteractionController` performs bounded sensing and procedural pose presentation; it reports contacts but never decides movement outcomes.

The wall path is `WallApproach` into `VerticalWallRun`, `HorizontalWallRun`, or a standard `WallJumpRecovery`. A manual or automatic run exit also enters `WallJumpRecovery`. An accepted slash during its cancel window enters `WallCancelFreedom` and earns one `WallReturnDash`. Landing returns to `Grounded` and clears all wall and air allowances.

## Detection and Classification

While airborne, the sensor checks the velocity or semantic movement heading plus two configurable side headings every 0.025 seconds. Spherecasts expand their reach with horizontal speed, exclude the complete local character assembly, and select the best stable contact by inward velocity, previous-wall stability, and distance. Floors, ceilings, slopes beyond the configured normal tolerance, transparent helpers, non-query/collision parts, and undersized fallback geometry are rejected. A run accepts only the original part and a compatible surface normal; a changed normal or wall loss expires through contact grace.

Head-on classification requires at least 72 percent inward motion, no more than 45 percent tangent motion, and meaningful inward speed. Angled classification requires an approach 15–45 degrees from the wall plane, at least 55 percent tangent motion, and meaningful inward and tangent speed. Contacts outside those bands remain eligible for the distinct standard wall jump rather than being forced into a wall run.

## Clearance and Current Calibration

Minimum wall clearance is the greater horizontal half-size of the active `HumanoidRootPart` and torso plus `0.30` studs. A representative 2-stud root therefore targets `1.30` studs from root centre to wall plane. Below that boundary, inward velocity is removed and outward correction is `(clearance error × 12)`, capped at `8 studs/s`. At or above the boundary, contact uses `0.75 studs/s` adhesion. The run exits if distance exceeds the boundary by `0.90` studs. No root CFrame or Position correction is used.

- Vertical run: 0.55 seconds maximum, upward velocity easing from 28 to 6 studs/s, 2.0 character-height cap.
- Horizontal run: 0.82 seconds maximum, 92 percent tangent retention with a 10 studs/s floor, upward velocity easing from 12 to 0 studs/s, 1.0 character-height cap.
- Standard/manual exit: 50 studs/s upward, 32 studs/s outward, 65 percent tangent retention.
- Automatic vertical exit: 38 studs/s upward, 28 studs/s outward, 60 percent tangent retention.
- Automatic horizontal exit: 33 studs/s upward, 25 studs/s outward, 75 percent tangent retention.
- Fresh manual exit delay: 0.08 seconds after the consumed entry Jump timestamp.
- Slash cancel: 0.16 seconds after recovery begins; earned return dash remains available for 0.42 seconds and uses the existing air-dash curve.
- Same-wall return: at least 0.13 seconds, 0.8 studs of outward separation, 0.5 studs of contact-point movement, 6 studs/s back into the wall, a new spherecast hit, and a new buffered Jump.

All values are provisional and live in `TechniqueConfig.Wall`. Normal dash distances, phase curve, camera-relative direction capture, and Sprint 016 live airborne Y preservation are unchanged.

## Authoring Metadata

Level builders can mark a `BasePart` with the `BLIKK_WallSurface` CollectionService tag and `BLIKK_WallJumpSurface = true`. Setting that attribute to `false` always disables the surface. Untagged, collidable, queryable, sufficiently large vertical geometry remains enabled by the prototype fallback.

District Zero's `Development/WallCalibrationStrip` provides opposing gaps and multiple wall heights for repeatable tuning. It remains outside the normal spawn route.

## Diagnostics and Limitations

`TechniqueConfig.Wall.DiagnosticsEnabled` enables concise transition/rejection output and character attributes for movement state, measured rig clearance, classification, signed distance, normal/tangent velocity, adhesion, entry/exit timing, exit reason/impulse, Jump timestamps, separation and direction evidence, and return-dash eligibility. Diagnostics are off by default and do not run a per-frame print loop.

Movement remains locally simulated and is not competitive authority. Roblox Studio playtesting is required for contact reliability, high-speed corners, ceiling exits, camera headings, repeated chains, frame-rate stability, and final feel.
