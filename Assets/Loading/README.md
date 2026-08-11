# BLIKK premium loading package

These files are deliberately separate. Do not combine them into an atlas and do not
chroma-key them in Roblox; the overlay PNGs already contain real alpha transparency.

Upload each PNG as an image using the exact filename, then paste its Roblox asset ID
into `src/shared/UI/LoadingScreenConfig.luau`:

- `BLIKK_Loading_AsianWarrior_Background_V1.png` -> `Layers.Background.ImageAssetId`
- `BLIKK_Loading_Smoke_V1.png` -> `Layers.Smoke.ImageAssetId`
- `BLIKK_Loading_Glare_V1.png` -> `Layers.Glare.ImageAssetId`
- `BLIKK_Logo_Full_HD_V2.png` -> `Layers.Logo.ImageAssetId` and
  `Branding.Assets.FullLogoImage`
- `BLIKK_Logo_Icon_HD_V2.png` -> `Branding.Assets.IconLogoImage`

Published August 11, 2026:

- background: `rbxassetid://98241025184666`
- smoke: `rbxassetid://94830671214826`
- glare: `rbxassetid://89832524304874`
- full logo: `rbxassetid://77188572994526`
- icon logo: `rbxassetid://107670090696780`

The game keeps the currently published loading art and logo as safe fallbacks while
the new IDs are empty. The live code supplies status text, the loading panel, smoke
parallax, sword glints, logo breathing, and logo shimmer, so none of those elements
should be baked into the background image.

Quality notes:

- Keep the background at its native 16:9 size.
- Do not resize the transparent layers before upload.
- The background uses crop scaling with safe composition for desktop, tablet and phone.
- The full and icon logo masters are intended to replace the current lower-resolution
  uploads without changing the approved BLIKK identity.
