# BLIKK Animation Asset Register

Production animation IDs must be directly loadable Roblox `Animation` assets owned by the same
BLIKK account or group that owns the experience. Public catalog and free-model animations are never
production dependencies. Reference-only candidates remain governed by
`docs/EXTERNAL_ASSET_REGISTER.md`.

| Hook | Owner | Asset ID | Purpose | Approval state | Runtime field |
| --- | --- | --- | --- | --- | --- |
| `KatanaSlash1` | Pending confirmation: BLIKK experience owner/group | `PENDING_PUBLICATION` | Original block-R15 one-handed grounded Training Katana slash | `AUTHORING_CREATED / STUDIO_AUDITION_PENDING / RUNTIME_DISABLED` | `WeaponDefinitions.TrainingKatana.AnimationSet.KatanaSlash1` |

An empty runtime field is intentional until the asset is authored, reviewed, published by the
correct owner, and approved. The procedural grounded slash remains the production fallback. Never
replace the empty field with a catalog reference or an invented ID.

## Block-R15 authoring library

The unpublished source library is in `Assets/Blender/BLIKK_Arsenal`. It uses Roblox's official R15
armature with a classic block-proportioned review shell representative of current BLIKK playtest
avatars. The shell is not a replacement character and is never exported with the action clips.

| Hook candidate | Duration | Publication state | Runtime state |
| --- | ---: | --- | --- |
| `KatanaEquip` | `0.120` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `KatanaSlash1` | `0.300` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | procedural fallback active |
| `KatanaBlock` | `0.180` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `KatanaAltLaunch` | `0.420` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `ShotgunEquip` | `0.100` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `ShotgunFire` | `0.160` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `ShotgunReload` | `0.760` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `SMGEquip` | `0.090` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `SMGFire` | `0.090` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `SMGReload` | `0.680` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `RifleEquip` | `0.105` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `RifleFire` | `0.110` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `RifleReload` | `0.820` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |

Every source action keys only `UpperTorso`, `RightUpperArm`, `RightLowerArm`, `RightHand`,
`LeftUpperArm`, and `LeftLowerArm`. Root and lower-body motion remain deliberately absent so BLIKK's
movement and cancel systems retain ownership. FBX import can produce redundant identity tracks, so
Studio must verify and remove any root or lower-body tracks before publication.

## KatanaSlash1 Studio authoring contract

Author on the exact upgraded R15 avatar used by BLIKK gameplay, with the approved equipped Katana
grip and idle stance visible. The animation is exactly `0.300` seconds long. It keys only `Waist`,
`RightShoulder`, `RightElbow`, `RightWrist`, `LeftShoulder`, `LeftElbow`, and, only if needed, a
subtle `Neck` counter-rotation no greater than 6 degrees. Do not key the HumanoidRootPart, RootJoint,
root translation or rotation, hips, knees, ankles, world position, or facing.

Treat every target below as an additive local-space offset from the approved equipped stance after
inspecting the live rig's actual joint axes:

| Time | Required pose and blade result |
| --- | --- |
| `0.000` | Exact approved equipped stance; blade beside/rearward of the right leg; no entry snap. |
| `0.025` | Compact coil: waist yaw 14–20 degrees toward the weapon side, pitch -3 to -6, roll no more than +5; right elbow bent 25–40 degrees; right hand below shoulder; left shoulder subtly forward. |
| `0.055` | Release/cancel-open pose: hand begins crossing forward, waist rapidly unwinds, right elbow retains at least 15 degrees of bend, and left arm begins counterbalancing rearward. |
| `0.075–0.090` | Fastest near-linear section: waist passes neutral, right hand crosses the forward-right torso plane, elbow stays below shoulder, blade crosses the centerline at navel/lower-rib height without rolling upside down. |
| `0.115–0.140` | Follow-through: waist yaw -24 to -34 degrees left, pitch -2 to -6, roll within about -6; hand slightly left of center but inside the torso silhouette; elbow bent 12–25 degrees; tip below chest. |
| `0.205` | Recovery is 45–60 percent complete; blade clear of torso and legs so late block or weapon-switch cancellation does not pop. |
| `0.300` | Exact approved equipped stance with no residual keyed-joint offset, pose pop, or weapon drift. |

The blade makes one compact right-to-left lateral cut at waist-to-lower-rib height with a 10–15
degree downward bias. It starts beside the right shin/ankle, accelerates outward clear of the right
leg, crosses the forward body plane below the neck, finishes forward-left below the chest, and takes
the shortest clean return. It must never intersect the avatar, turn upside down, point vertically
upward, extend behind the fighter during the active strike, or disconnect from the right hand. The
left hand counterbalances and never touches the weapon.

Use a very short smooth ease from `0.000–0.025`, fast acceleration from `0.025–0.055`, near-linear
interpolation through `0.055–0.140`, and a compact smooth recovery through `0.300`. Do not add
elasticity, bounce, overshoot, exaggerated follow-through, or root motion.

The following optional markers are inspection aids only; code remains authoritative for gameplay,
trail, cancel, and recovery timing:

| Marker | Time |
| --- | --- |
| `SlashStart` | `0.025` |
| `DirectionSet` | `0.075` |
| `ContactVisual` | `0.090` |
| `TrailOff` | `0.140` |
| `CancelClose` | `0.205` |
| `Recovered` | `0.300` |

## Publication and integration gate

1. In Studio, open the exact BLIKK upgraded R15 gameplay rig and verify the approved Katana grip and
   equipped stance before keying.
2. Author and preview the motion at normal `1.0` speed from front, both three-quarter angles, side,
   and rear views. Confirm locomotion can continue on every unkeyed lower-body joint.
3. Export/publish the animation under the confirmed BLIKK experience owner or owning group—not a
   personal or third-party owner that the experience cannot load.
4. Copy the resulting directly loadable animation asset ID and verify ownership/access in the target
   experience.
5. Record the confirmed owner, ID, and review status in the register row above.
6. Only after approval, assign `rbxassetid://<published-id>` to
   `WeaponDefinitions.TrainingKatana.AnimationSet.KatanaSlash1` and complete the Studio acceptance
   pass. Both existing grounded visual variants intentionally use this one hook in this vertical
   slice.

`KatanaSlash2`, the air slash, upward-launch alternate, block, tumble, and all other authored melee
animations are separate future presentation work.
