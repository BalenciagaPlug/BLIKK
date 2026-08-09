# BLIKK KatanaSlash1 authoring package

This package contains BLIKK's original, GunZ-inspired grounded Katana slash. It is an authored presentation asset, not a copy or extraction of a GunZ animation.

## Deliverables

- `BLIKK_KatanaSlash1_Authoring.blend` — editable Blender 4.5 source.
- `BLIKK_KatanaSlash1_R15.fbx` — Roblox Studio import file.
- `author_katana_slash1.py` — deterministic authoring and validation script.
- `preview_final/` — seven review moments from front, three-quarter, side, and rear cameras.

The rig originates from Roblox's official `RoundMale.blend` R15 template:

https://create.roblox.com/docs/art/characters/creating/template-files

## Locked motion contract

- Duration: exactly `0.300` seconds at `120` FPS (`0..36`).
- Authored bones only: `UpperTorso`, both upper arms, both lower arms, and `RightHand`.
- Root, hips, and legs remain unauthored so locomotion and high-APM cancels stay code-owned.
- One-handed compact right-to-left cut across the lower ribs/navel with a slight downward path.
- The first and final authored poses are identical.
- The Katana visible in Blender is review-only and is not included in the FBX. Runtime weapon geometry and grip remain owned by BLIKK.

## Studio import and publication gate

1. Open the exact upgraded R15 gameplay rig in Roblox Studio's Animation Editor.
2. Import `BLIKK_KatanaSlash1_R15.fbx` using **Import > From FBX Animation**.
3. Confirm the imported track list contains motion only for the six approved upper-body bones. Blender's FBX writer may include static/default channels for the rest of the source skeleton; Roblox's keyframe optimizer is expected to discard default-only tracks. If any root or lower-body track contains non-default motion, stop and do not publish.
4. Set the animation to non-looping and Action priority.
5. Preview at normal speed from front, three-quarter, side, and rear views on the exact BLIKK avatar and approved Katana grip.
6. Confirm no torso/arm/weapon intersection, no root displacement, no leg ownership, and an exact return to equipped stance at `0.300` seconds.
7. Publish through the Animation Editor under the BLIKK experience owner/group and copy the returned animation asset ID.
8. Only after visual acceptance, place `rbxassetid://<published-id>` in `WeaponDefinitions.TrainingKatana.AnimationSet.KatanaSlash1` and record the owner/ID/publication state in `docs/ANIMATION_ASSETS.md`.

Publication must remain an authenticated Studio action. Never invent an asset ID or publish under a substitute owner.
