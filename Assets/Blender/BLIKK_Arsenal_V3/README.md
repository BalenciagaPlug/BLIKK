# BLIKK Arsenal V3 — Weapon Proof Library

This isolated library contains the B-8 V3 art-direction proofs: an original BLIKK pump shotgun
designed for an early-2000s PC action-game silhouette while remaining readable and performant on a
block-proportioned Roblox R15 avatar.

It also contains the Training Katana V3.1 proof: a slim, curved, one-handed blade with a modelled
cross-section, fullers, restrained guard, wrapped handle, explicit trail endpoints, and no oversized
fantasy geometry.

It does not contain extracted GunZ meshes, textures, animations, or code. GunZ is used only as a
broad reference for compact K-style weapon readability and period presentation.

## Contents

- `BLIKK_B8_BREAKSHOT_V3_Master.blend` — preserved first V3 proof.
- `BLIKK_B8_BREAKSHOT_V3_1_Master.blend` — slimmer current V3.1 source.
- `author_b8_v3.py` — deterministic model, texture, export, and review-render builder.
- `validate_b8_v3.py` — axis, pivot, UV, topology, budget, and artifact validation.
- `Models/BLIKK_B8_BREAKSHOT_V3_1.glb` — current script-free model proof for later Studio import.
- `Textures/B8_V3_1_BaseColor.png` — current original 1024-pixel period-styled texture atlas.
- `Previews/` — side, front three-quarter, rear three-quarter, and block-R15 scale reviews.
- `BLIKK_TRAINING_KATANA_V3_1_Master.blend` — current Katana source.
- `Models/BLIKK_TRAINING_KATANA_V3_1.glb` — script-free Katana proof.
- `Textures/TrainingKatana_V3_1_BaseColor.png` — original Katana texture atlas.
- `author_katana_v3_1.py` / `validate_katana_v3_1.py` — deterministic Katana build and validation.

## Contract

- Local `-Z`: stock to muzzle.
- Local `+Y`: weapon up.
- Local `+X`: weapon right.
- One deliberate model root.
- Explicit `GripAttachment`, `ForegripAttachment`, `MuzzleAttachment`, and `StockPivot` references.
- Target evaluated triangle range: 4,000–8,000.
- V3.1 target length: 3.22 studs; target maximum width: 0.45 studs.
- No scripts, armature, animations, gameplay code, runtime integration, or published Roblox ID.

V2 remains intact. Do not replace the live B-8 geometry or alter the approved firearm pose to fit this
proof. The V3 model must first pass visual approval, disposable Studio import, exact R15 hand fit,
camera readability, and performance checks.

The same gate applies to the Katana. Its local `+Y` axis runs from grip to tip, `+X` is the blade-face
axis, and `-Z` identifies the cutting-edge side. Do not alter the approved live Katana grip or pose to
compensate for an unverified import.
