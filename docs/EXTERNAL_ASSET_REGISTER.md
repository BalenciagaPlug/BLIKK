# External Asset Register

These Creator Store model IDs are research candidates only. They are not approved runtime assets,
not verified animation IDs, and must not be loaded or required by game code.

| Model ID | Candidate | Status |
| --- | --- | --- |
| `9936936245` | Katana Animations | `REFERENCE_ONLY / AUDITION_PENDING / NOT_RUNTIME_APPROVED` |
| `7598646037` | Animations for Katana | `REFERENCE_ONLY / AUDITION_PENDING / NOT_RUNTIME_APPROVED` |
| `14394631962` | ACS Double Barrel | `REFERENCE_ONLY / AUDITION_PENDING / NOT_RUNTIME_APPROVED` |
| `4842215723` | Official Roblox Shotgun | `REFERENCE_ONLY / AUDITION_PENDING / NOT_RUNTIME_APPROVED` |
| `9147549653` | Open-source Shotgun Animations | `REFERENCE_ONLY / AUDITION_PENDING / NOT_RUNTIME_APPROVED` |

No listed ID may be assigned to `Animation.AnimationId`, passed to `InsertService:LoadAsset`, used
with `require`, or imported with third-party scripts. Sprint 025.0 uses repository-owned primitive
weapons and procedural R15 presentation without these assets.
