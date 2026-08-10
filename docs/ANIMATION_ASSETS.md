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

The production fallback is a complete repository-owned, code-authored upper-body clip rather than a
placeholder pose. It samples six poses across the current 0.340-second gameplay window, alternates
two slash directions, and covers anticipation, centreline cut, follow-through, and recovery. It keys
Waist, Neck, shoulders, elbows, and wrists only; Root and lower-body joints remain available to
locomotion. This path needs no uploaded animation ID. A correctly owned published asset remains an
optional visual upgrade, not a requirement for the slash to animate.

The runtime pose coordinator supports both legacy `Motor6D` and Avatar Joint Upgrade
`AnimationConstraint` character graphs. Constraint rigs receive the same fallback as a procedural
layer during `PreSimulation`, after the Animator has evaluated the native locomotion track. Do not
disable the fallback merely because the experience uses upgraded avatar joints. Weapon-owned arm
joints are the deliberate exception to ordinary additive layering: their BLIKK pose replaces the
walk-cycle arm result while the unmasked body continues to animate.

## Block-R15 authoring library

The unpublished source library is in `Assets/Blender/BLIKK_Arsenal`. It uses Roblox's official R15
armature with a classic block-proportioned review shell representative of current BLIKK playtest
avatars. The shell is not a replacement character and is never exported with the action clips.

| Hook candidate | Duration | Publication state | Runtime state |
| --- | ---: | --- | --- |
| `KatanaEquip` | `0.120` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | disabled |
| `KatanaSlash1` | `0.300` s source; retime to `0.340` before publication | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | procedural fallback active |
| `KatanaBlock` | `0.180` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | procedural fallback active |
| `KatanaAltLaunch` | `0.420` s | `UNPUBLISHED / STUDIO_AUDITION_PENDING` | procedural fallback active |
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
grip and idle stance visible. The runtime animation is exactly `0.340` seconds long. It keys only `Waist`,
`RightShoulder`, `RightElbow`, `RightWrist`, `LeftShoulder`, `LeftElbow`, and, only if needed, a
subtle `Neck` counter-rotation no greater than 6 degrees. Do not key the HumanoidRootPart, RootJoint,
root translation or rotation, hips, knees, ankles, world position, or facing.

Treat every target below as an additive local-space offset from the approved equipped stance after
inspecting the live rig's actual joint axes:

| Time | Required pose and blade result |
| --- | --- |
| `0.000` | Exact approved equipped stance; blade beside/rearward of the right leg; no entry snap. |
| `0.030` | Compact coil: waist yaw 14–20 degrees toward the weapon side, pitch -3 to -6, roll no more than +5; right elbow bent 25–40 degrees; right hand stays in front of the shoulder plane; left shoulder subtly forward. |
| `0.060` | Release/cancel-open pose: hand crosses forward, waist rapidly unwinds, right elbow retains at least 15 degrees of bend, and left arm begins counterbalancing. |
| `0.070–0.095` | Fastest near-linear section: waist passes neutral, right hand crosses the forward-right torso plane, elbow stays below shoulder, blade crosses the centerline at navel/lower-rib height without rolling upside down. |
| `0.110–0.140` | Follow-through: waist yaw 18–24 degrees toward the target side, pitch -2 to -6, roll within about -6; hand slightly across center but remains forward of the torso plane; elbow bent 12–25 degrees; tip below chest. |
| `0.225` | Recovery is 40–55 percent complete; blade clear of torso and legs so late block or weapon-switch cancellation does not pop. |
| `0.340` | Exact approved equipped stance with no residual keyed-joint offset, pose pop, or weapon drift. |

The blade makes one compact right-to-left lateral cut at waist-to-lower-rib height with a 10–15
degree downward bias. It starts beside the right shin/ankle, accelerates outward clear of the right
leg, crosses the forward body plane below the neck, finishes forward-left below the chest, and takes
the shortest clean return. It must never intersect the avatar, turn upside down, point vertically
upward, extend behind the fighter during the active strike, or disconnect from the right hand. The
left hand counterbalances and never touches the weapon.

Use a very short smooth ease from `0.000–0.030`, fast acceleration from `0.030–0.060`, near-linear
interpolation through `0.060–0.140`, and a compact smooth recovery through `0.340`. Do not add
elasticity, bounce, overshoot, exaggerated follow-through, or root motion.

The following optional markers are inspection aids only; code remains authoritative for gameplay,
trail, cancel, and recovery timing:

| Marker | Time |
| --- | --- |
| `SlashStart` | `0.030` |
| `DirectionSet` | `0.070` |
| `ContactVisual` | `0.085` |
| `TrailOff` | `0.140` |
| `CancelClose` | `0.225` |
| `Recovered` | `0.340` |

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

`KatanaSlash2`, the air slash, tumble, and all other authored melee animations are separate future
presentation work. Block and upward launch are already complete code-authored fallbacks and do not
depend on publication. Block keys only the upper body; upward launch uses a 0.420-second grounded
full-body pose while gameplay timing and world movement remain code-owned.

The repository fallback is the multiplayer baseline. Its active frames must keep the right hand and
blade in the fighter's forward aim half-space; rear-facing windups and behind-the-back contact arcs are
rejected even if visually dramatic. It uses only Waist, optional Neck counter-rotation, shoulders,
elbows, and wrists, leaving Root and lower-body movement unkeyed. Remote observers receive the same
sampled poses over the disposable melee-presentation channel, while the local fighter stays predicted.
See `docs/K_STYLE_EVIDENCE.md` for the source hierarchy and locked gameplay interpretation.

The approved Training Katana ready silhouette remains a hard lock: the equipped hand attachment uses
the original `190`-degree Z roll, the right-shoulder ready pitch remains `-15` degrees, and its airborne
offset remains `-1` degree. Slash, block, and alt-fire must animate away from that baseline without
rewriting it. Their active frames use an absolute weapon-direction solver and a separate `0`-through-
`110`-degree front-facing shoulder convention. Every slash and block action direction asserts at least
a `0.55` forward dot. Block blends the weapon solver across its `0.100`-second enter phase for both the
local fighter and remote observers, preventing a grip snap while preserving the approved idle pose.

Until an owned authored clip passes Studio review, the procedural fallback also applies a
weapon-joint arc during the 0.340-second slash. It preserves the right-hand pivot, constrains both
blade-direction variants to forward local space during active frames, and returns the grip transform
to identity on recovery, interruption, block cancel, unequip, death, or replacement. This grip layer
is presentation-only and never supplies hit geometry.

## Technique composition contract

Butterfly, Double Butterfly, and Triple Butterfly reuse the approved procedural slash and held-block
poses for every player-entered pair. A successful block cancel may re-enter the slash fallback after
the configured repeat lockout; no animation is sped up, skipped automatically, or allowed to decide
whether the next pair succeeds. Remote observers receive every separately accepted slash and block
transition through the existing disposable presentation channel.

Swap Shot, Reload Shot, Slash Shot, and Half Step are animated compositions of existing owned action
presentation. They use firearm recoil/pump, reload opening, equip/unequip, katana slash cancellation,
directional dash/tumble, and aim IK in the order created by the player's inputs. No public animation
asset, copied GunZ clip, fabricated asset ID, or technique-length master animation is introduced.

## Weapon-limb locomotion mask

While a local firearm or melee pose owns an arm joint, `PoseCoordinator` resolves that shoulder,
elbow, or wrist from the retained BLIKK weapon pose instead of layering it over the Animator's current
walk-cycle transform. Arm priority remains at the weapon-action tier even during ordinary locomotion,
while Root, Waist, Neck, hips, and legs continue to receive locomotion and compatible movement-pose
layers. Remote accepted melee presentation applies the same absolute arm rule, preventing walk swing
from dragging an observed katana without freezing the rest of the remote avatar.

The firearm tumble is split hierarchically: Root and lower-body joints retain the full directional
rotation and leg tuck, while Waist applies the inverse tumble rotation before a small brace pose.
Shoulders and elbows remain under the crosshair-driven firearm claim, and firearm IK continues solving
during Ready, Firing, and Recovering tumble states. This preserves the movement silhouette without
turning the equipped weapon or gameplay aim away from the player's crosshair.
