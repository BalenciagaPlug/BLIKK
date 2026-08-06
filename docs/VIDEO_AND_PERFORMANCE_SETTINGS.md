# Video and Performance Settings

Profile schema 3 adds event-driven BLIKK render preferences while preserving IDs, fighters, bindings, and existing preferences. Missing keys receive defaults through the existing save pipeline.

- Competitive: Low-equivalent lighting, no bloom or local shadows, reduced presentation, essential route lighting retained.
- Balanced: Medium lighting, restrained bloom, and standard presentation. This is the default.
- Cinematic: High lighting, authored shadows, bloom, and full atmosphere.

Persisted fields cover BLIKK-owned shadows, bloom, color correction, atmosphere, dash-presentation density, weapon trails, screen impulse, FPS, and ping. Implemented consumers include District Zero lighting, dash presentation, katana trail visibility, and the FPS/ping display. Damage-effect and character-outline controls are deliberately omitted until those systems have truthful bounded implementations.

BLIKK omits fake AA algorithm, native AO, engine texture-quality, resolution, and true render-distance controls because Roblox does not expose them to ordinary experiences.
