# BLIKK Mobile and Tablet Interface Contract

## Design objective

Touch players receive the complete combat and movement state machine, not reduced mechanics. The interface replaces awkward touch translations such as double-tapping a virtual direction with direct, timing-sensitive controls that still use the desktop cooldowns, buffers, air limits, and server validation.

## Gameplay layout

- Left thumb: a floating movement surface which appears beneath the first touch, supports diagonals, and uses a small engage/release hysteresis so noisy fingers do not rapidly toggle movement.
- Right thumb: a compact fast-tech triangle for attack, jump, and dash. A smaller context row contains swap and only the actions relevant to the equipped weapon.
- Melee context: the attack position becomes slash, with block and alternate launch in the context row.
- Firearm context: the same attack position becomes fire, block/alternate launch disappear, and reload takes their context position.
- The aim surface is the unoccupied right side of the screen. Dragging it feeds the same direct camera pipeline as mouse input.
- The standard Roblox touch controls, PC input diagram, and recovery belt are hidden while BLIKK touch controls own gameplay.
- HP/AP and weapon information use a separate compact touch scale and remain in the upper-left information lane instead of covering the player or crosshair.
- Phone and tablet layouts use shortest-side responsive scales and preserve a minimum practical touch target.

The dedicated dash button selects the player's current movement direction and enters the same dash/tumble path used by keyboard input. This replaces an unreliable directional double-tap on glass, but it does not bypass technique timing, cooldowns, air resources, or server validation. Fast scaling still requires the player to execute jump, dash, slash, jump, and dash in rhythm; the inputs are simply placed in one reachable thumb arc.

## Visibility budget

- Collapsed touch chat shows only the two newest messages in a small, high-transparency panel.
- Opening chat may temporarily expand the panel, but combat controls remain hidden only when normal gameplay suppression owns input.
- Decorative weapon silhouettes and prototype labels are omitted on touch; live health, armour, weapon identity, ammunition, and state remain.
- No combat control may overlap the crosshair lane or the character's normal center-screen silhouette at the reference phone aspect ratios.

## Automation boundary

Automatic fire is disabled by default. A future accessibility option may repeat the normal fire action while held, but it must preserve weapon cadence, reload state, ammunition, server validation, and identical accuracy. It must never aim, select targets, or execute a movement technique for the player.

## Visual language

- Primary atmosphere: near-black industrial glass and scratched gunmetal.
- Identity accent: ultraviolet purple.
- Information and confirmation accent: restrained acid green.
- Text remains live Roblox UI text for localization, scaling, and accessibility; generated art contains no baked labels.
- The UI atlas is optional presentation. Code-native panels remain functional until the uploaded Roblox image asset ID is configured.

## Performance rules

- Prefer one uploaded atlas over many independently fetched decorative textures.
- Avoid persistent PC-only overlays on touch devices.
- Keep gameplay controls code-native and responsive even if decorative art has not loaded.
- Do not allocate UI objects or input tables every rendered frame.
- Test at phone, tablet, 16:9 desktop, and ultrawide aspect ratios before publishing.
