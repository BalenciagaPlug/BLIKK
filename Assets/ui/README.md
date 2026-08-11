# BLIKK production UI assets

The composite `BLIKK_UI_ATLAS_V1` upload is intentionally disabled. Runtime testing showed sprite
bleeding, scaling distortion, and excessive mobile HUD density. Do not re-enable the atlas.

Upload every PNG in `production/` to Roblox as an individual image, preserving its filename as the
Roblox asset name. Each file has a real RGBA alpha channel and transparent corners; no chroma-key
color remains in the production output.

## Desktop and shared UI

- `menu-shell-desktop.png`
- `content-panel-wide.png`
- `button-idle-wide.png`
- `button-selected-purple-wide.png`
- `button-confirm-acid-wide.png`
- `hud-vitals-hp-ap.png`
- `hud-weapon-panel.png`
- `notification-frame.png`

Use `ScaleType = Slice` for the wide frames and buttons. Pick a slice center inside the empty inset,
away from the metal border. Keep all text, meter fills, weapon silhouettes, and numbers as live Roblox
UI layered above the image.

## Competitive crosshairs

- `crosshair-precision-dot.png`
- `crosshair-shotgun-brackets.png`
- `crosshair-melee-chevrons.png`

Use `ScaleType = Fit`, keep the image square, and anchor it exactly at screen center. The white dot or
diamond is the aim point. Crosshair size should be configurable without changing weapon accuracy.

## Mobile controls

- `mobile-movement-ring.png`
- `mobile-dash-button.png`
- `mobile-fire-button.png`
- `mobile-jump-button.png`
- `mobile-slash-button.png`
- `mobile-block-button.png`
- `mobile-alt-fire-button.png`
- `mobile-swap-button.png`

Use `ScaleType = Fit` and preserve a square aspect ratio. These are visual surfaces only; labels and
input behavior remain code-driven. Do not show every combat action simultaneously when it is not
relevant to the currently equipped weapon.

All 19 uploaded Roblox image IDs are mapped in `src/shared/UI/UIAssetConfig.luau`. The old composite
atlas remains disabled; native Roblox frames remain the safe fallback if an individual image is still
moderating or temporarily unavailable. Verify desktop, phone, and tablet before publishing.
