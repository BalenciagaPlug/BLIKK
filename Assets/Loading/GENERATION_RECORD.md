# BLIKK premium loading asset generation record

Mode: built-in image generation and editing (`imagegen`). Chroma-key removal used the
bundled image-generation transparency helper after generation; Roblox receives true
RGBA PNGs, not keyed backgrounds.

## BLIKK_Loading_AsianWarrior_Background_V1.png

```text
Use case: stylized-concept
Asset type: premium 16:9 Roblox game loading-screen background layer
Input image: the attached BLIKK Asian warrior loading-screen concept is the edit target and visual reference.
Primary request: preserve the exact overall identity, dark Asian-inspired katana fighter on the left, moonlit dystopian District Zero skyline, distant rooftop fighters, black/silver/deep-purple palette, rain haze and cinematic depth. Recompose cleanly to a true 16:9 landscape game background with high-detail premium studio key art.
Composition: keep the warrior mainly in the left third and the purple moon / city in the right third. Leave a controlled darker central area for a separate animated BLIKK logo and a clear lower safe zone for live loading status UI.
Lighting/mood: restrained purple moonlight, wet-city reflections, soft volumetric smoke, atmospheric perspective, subtle sword-edge glints, premium dark sci-fi martial-arts mood.
Constraints: REMOVE all baked logo text, slogans, loading bars, status readouts, borders, HUD panels, coordinates, and interface typography. Preserve only the cinematic environment and character. No guns in the foreground. No thug or streetwear styling; the warrior should read as modern Asian cyber-samurai. No watermark. Keep important subjects within a 10 percent safe margin. Crisp enough for a high-resolution game loading screen.
```

## BLIKK_Loading_Smoke_V1.png

```text
Use case: stylized-concept
Asset type: transparent-ready atmospheric smoke overlay texture for a premium game loading screen
Primary request: create a sparse cinematic layer of soft charcoal-grey and faint violet volumetric smoke wisps, drifting horizontally with large areas of empty space, suitable for very slow parallax movement over dark cyberpunk city key art.
Composition: wide landscape overlay, smoke concentrated along the lower left and upper right edges, center mostly clear. No hard border and no rectangular frame.
Background requirement: perfectly flat solid #FF7A00 chroma-key background for removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation.
Constraints: smoke only; no city, no character, no logo, no text, no sparks, no watermark. Do not use orange or warm colors in the smoke. Soft feathered wisps but clearly separated from the flat key background.
```

Final edit prompt:

```text
Edit the supplied smoke-overlay source. Preserve the exact smoke shapes, placement, softness, and purple/charcoal color. Change only the entire orange background into a perfectly uniform flat solid #00FF00 chroma-key green. No gradient, no lighting variation, no floor, no shadow, no texture. Keep smoke free of green tones. Do not add anything.
```

## BLIKK_Loading_Glare_V1.png

```text
Use case: stylized-concept
Asset type: transparent-ready cinematic sword-glare and lens-streak overlay for a premium 16:9 game loading screen
Primary request: create a very sparse set of elegant silver-white and deep-violet blade-edge glints, thin diagonal light streaks, and two small star-shaped lens flares. The effect should feel like controlled moonlight catching a katana, not a sci-fi laser show.
Composition: wide landscape overlay, one restrained diagonal highlight near the left-center, one faint horizontal glare near the right-center, and large areas completely empty. Keep the center readable for a game logo.
Background requirement: perfectly flat solid #FF7A00 chroma-key background for removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation.
Constraints: effects only; no sword object, no character, no city, no logo, no text, no frame, no smoke, no sparks shower, no watermark. Do not use orange or warm colors in the effects. Premium, crisp, minimal, suitable for a subtle 7-to-10-second animation loop.
```

Final edit prompt:

```text
Edit the supplied cinematic-glare overlay source. Preserve the exact two glare shapes, placement, thinness, silver-white cores, and violet highlights. Change only the entire orange background into a perfectly uniform flat solid #00FF00 chroma-key green. No gradient, no lighting variation, no floor, no shadow, no texture. Keep the glare effects free of green tones. Do not add anything.
```

## BLIKK_Logo_Full_HD_V2.png

```text
Use case: product
Asset type: high-resolution transparent-ready game logo master
Edit the supplied approved BLIKK logo. Preserve its identity and composition exactly: the exact uppercase spelling BLIKK, silver beveled letters, central silver skull with purple eyes, mirrored futuristic guns, black/silver shard frame, and restrained purple energy accents. Clean and sharpen edges, improve material definition, symmetry, and small-detail readability so it remains crisp when displayed large, but do not redesign it and do not change the word.
Remove the dark grey backdrop and all background lighting. Place the complete logo centered with generous safe margins on a perfectly uniform flat solid #00FF00 chroma-key background. No shadows or glow may extend into the green except the logo's restrained purple edge light. No extra text, no slogan, no watermark. Make every letter fully legible and keep the full silhouette inside the canvas.
```

## BLIKK_Logo_Icon_HD_V2.png

```text
Use case: product
Asset type: high-resolution transparent-ready BLIKK emblem master
Edit the supplied approved standalone B emblem. Preserve its identity and composition exactly: the exact angular uppercase B silhouette, silver beveled metal faces, black inset cavities, asymmetric black shard frame, and restrained deep-violet energy highlights. Clean and sharpen every edge, improve material definition and small-detail readability, and keep the silhouette bold enough to remain crisp in a compact Roblox HUD badge. Do not redesign the letter or change its proportions.
Remove the grey backdrop and all background lighting. Place the complete emblem centered with generous safe margins on a perfectly uniform flat solid #00FF00 chroma-key background. No shadows or glow may extend into the green except the emblem's restrained violet edge light. No extra text, no skull, no guns, no slogan, no watermark. Keep the full silhouette inside the canvas.
```
