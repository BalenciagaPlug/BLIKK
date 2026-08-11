# BLIKK premium UI/HUD v3 import manifest

Import each PNG as an individual Roblox image and preserve the filename. Every source is RGBA,
contains real transparency, and is capped at 1024 pixels on its longest edge so Roblox runtime pixels
match the nine-slice coordinates below.

| File | Runtime key | Source size | Rendering |
| --- | --- | --- | --- |
| `blikk-shell-frame-9slice-v3.png` | `MenuShellDesktop` | 1024x548 | SliceCenter `110, 90, 914, 458`; SliceScale `0.72` |
| `blikk-panel-frame-9slice-v3.png` | `ContentPanelWide` | 1024x478 | SliceCenter `96, 74, 927, 404`; SliceScale `0.55` |
| `blikk-button-idle-9slice-v3.png` | `ButtonIdleWide` | 1024x169 | SliceCenter `98, 39, 926, 130`; SliceScale `0.32` |
| `blikk-button-selected-9slice-v3.png` | `ButtonSelectedPurpleWide` | 1024x217 | SliceCenter `103, 48, 921, 168`; SliceScale `0.28` |
| `blikk-button-confirm-9slice-v3.png` | `ButtonConfirmAcidWide` | 1024x246 | SliceCenter `105, 55, 919, 191`; SliceScale `0.26` |
| `blikk-hud-vitals-frame-v3.png` | `HudVitalsHpAp` | 1024x194 | Fit |
| `blikk-hud-weapon-frame-v3.png` | `HudWeaponPanel` | 1024x265 | SliceCenter `147, 56, 877, 208`; SliceScale `0.38` |
| `blikk-notification-frame-9slice-v3.png` | `NotificationFrame` | 1024x194 | SliceCenter `97, 43, 927, 151`; SliceScale `0.45` |
| `blikk-meter-ap-fill-v3.png` | `HudArmourFill` | 1024x64 | Stretch inside clipped authored rail |
| `blikk-meter-hp-fill-v3.png` | `HudHealthFill` | 1024x64 | Stretch inside clipped authored rail |

After import, copy the ten IDs into `src/shared/UI/UIAssetConfig.luau`. The two fill keys are already
present with empty values so the HUD falls back cleanly while the uploads moderate.

Do not use the old source dimensions for SliceCenter. Those values were the reason only half of a
frame appeared after Roblox resized the uploaded image.
