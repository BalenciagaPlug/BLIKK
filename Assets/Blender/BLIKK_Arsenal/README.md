# BLIKK Block-R15 Arsenal Authoring Library

This folder contains original BLIKK weapon meshes and presentation animations authored against the
official Roblox R15 armature. The review body deliberately uses classic block proportions similar to
the avatars seen in current BLIKK playtests. It is a visual proxy only; player appearance, clothing,
accessories, body colors, and the live character rig remain Roblox-owned at runtime.

The library takes broad silhouette and timing inspiration from fast Y2K arena-action games. It does
not contain extracted GunZ meshes, textures, animation data, scripts, or other third-party content.
All materials are generated in the Blender source and have no external texture dependency.

## Source of truth

- `BLIKK_BlockR15_Arsenal_Master.blend` is the editable master.
- `author_blokk_r15_arsenal.py` deterministically rebuilds the master, exports, and QA renders from
  Roblox's official RoundMale R15 template.
- `Models/*.glb` contains one script-free model export per weapon.
- `Animations/*.fbx` contains one upper-body animation export per action.
- `Previews/*.png` contains authoring QA stills. They do not prove Roblox runtime compatibility.

## Weapon model contract

| Model | Source basis | Intended presentation | Status |
| --- | --- | --- | --- |
| `TrainingKatana_MK2.glb` | local `+Y` from grip to tip | compact one-handed katana | Studio import pending |
| `BLIKK_B8_BREAKSHOT_MK2.glb` | local `-Z` from stock to muzzle; `+Y` up | compact pump shotgun | Studio import pending |
| `BLIKK_V9_SMG.glb` | local `-Z` from stock to muzzle; `+Y` up | short, high-rate SMG | Studio import pending |
| `BLIKK_AR4_RIFLE.glb` | local `-Z` from stock to muzzle; `+Y` up | readable mid-length rifle | Studio import pending |

The source roots carry orientation and attachment metadata. Roblox import can convert scene axes, so
the imported mesh must be normalized once into BLIKK's existing canonical weapon basis before any
live integration. Do not change the approved live Katana grip or B-8 aim pose to compensate for an
unverified import.

## Animation library

| Action | Duration | Intended use |
| --- | ---: | --- |
| `KatanaEquip` | 0.120 s | draw into the approved one-handed ready stance |
| `KatanaSlash1` | 0.300 s | compact grounded right-to-left slash |
| `KatanaBlock` | 0.180 s | enter and hold a central blade guard |
| `KatanaAltLaunch` | 0.420 s | upward launcher presentation |
| `ShotgunEquip` | 0.100 s | raise B-8 into the ready pose |
| `ShotgunFire` | 0.160 s | one-shot shoulder/arm recoil presentation |
| `ShotgunReload` | 0.760 s | whole-magazine reload presentation |
| `SMGEquip` | 0.090 s | compact SMG draw |
| `SMGFire` | 0.090 s | short automatic-fire impulse |
| `SMGReload` | 0.680 s | magazine replacement presentation |
| `RifleEquip` | 0.105 s | rifle draw |
| `RifleFire` | 0.110 s | controlled rifle-fire impulse |
| `RifleReload` | 0.820 s | magazine replacement presentation |

Every source action keys only `UpperTorso`, both upper arms, both lower arms, and `RightHand`.
HumanoidRootPart, root, hips, legs, and feet remain unkeyed. Gameplay timing, damage, ammunition,
movement, cancels, and weapon selection must remain code-owned. These clips are presentation assets,
not gameplay authority.

## Compatibility and import gate

R15 is the production target because it preserves the current blocky look while retaining Roblox's
modern 15-part articulation, avatar-description pipeline, layered clothing support, and future
animation compatibility. R6 is not an integration target for this library.

Before publishing or wiring any asset into runtime:

1. Import one model or animation at a time into a disposable Studio test rig.
2. Use the exact upgraded R15 avatar configuration from BLIKK gameplay.
3. Verify the model axis, scale, grip, muzzle/blade direction, and hand contact from all sides.
4. Test each animation while walking, jumping, dashing, wall interacting, switching, and cancelling.
5. Confirm no root/lower-body tracks were introduced by FBX import and remove any identity tracks.
6. Check common classic/block R15 avatars plus minimum and maximum supported avatar scale values.
7. Check layered shirts, jackets, hair, and bulky accessories for unacceptable clipping.
8. Publish only under the confirmed BLIKK experience owner/group and record the returned IDs in
   `docs/ANIMATION_ASSETS.md`.
9. Integrate one approved asset at a time behind the existing procedural fallback.

No asset in this folder is currently published, runtime-integrated, or gameplay-approved.
