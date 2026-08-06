# BLIKK Modular Urban Kit

## Purpose

The Modular Urban Kit is BLIKK's deterministic, Roblox-native construction library for dense Y2K urban environments. It provides reusable data-driven pieces rather than storing thousands of prebuilt Instances. Every dimension is expressed in studs and every constructor builds only the Instances requested by a map builder.

## Catalog

The wall catalog contains 12 families, five treatments, seven widths, and six heights. Their cross-product provides 2,520 snapped wall combinations: Brick, Dirty Brick, Concrete, Cracked Concrete, Render, Steel, Garage Roller, Warehouse, Apartment Exterior, Shop Exterior, Alley, and Service walls; Clean, Damaged, Graffiti Ready, Window, and Vent treatments; widths of 4, 8, 12, 16, 20, 24, and 32 studs; and heights of 10, 14, 18, 24, 32, and 40 studs.

Window modules cover Apartment, Warehouse, Shop, Broken, Boarded, Security Bars, Industrial, and Corner forms. Each uses a framed pane, physical thickness, conservative collision, and a playable sill. Any type may request the broken treatment.

Roof modules cover Flat, Parapet, Warehouse, Apartment, Corner, Billboard, and Mechanical roofs. Optional rooftop detail modules cover AC units, generators, vent stacks, fans, solar panels, electrical cabinets, maintenance doors, water towers, cable trays, satellite dishes, roof lights, and billboards.

Vertical movement modules cover two fire-escape profiles, external and industrial stairs, maintenance and roof ladders, broken stairs, catwalks, bridges, pipe walks, scaffolding, and construction platforms. Their dimensions are supplied by the map definition and must conform to the movement specification.

Street furniture includes 21 reusable types: street and traffic lights, power poles and boxes, dumpsters, bins, mailboxes, hydrants, concrete and traffic barriers, five fence or guard forms, bus stops, phone booths, benches, trees, shrubs, and planters. Alley detail includes pallets, crates, oil drums, tyres, garbage bags, cardboard piles, shopping trolleys, wood sheets, construction fencing, scaffolding, utility piping, wall conduits, and electrical meters.

## Movement Metadata

Architectural pieces may expose the following boolean attributes without adding visible helpers:

- `BLIKK_WallJumpSurface`
- `BLIKK_ButterflyChannel`
- `BLIKK_SafeLanding`
- `BLIKK_RecoveryDrop`
- `BLIKK_RoofEdge`
- `BLIKK_PipeWalk`
- `BLIKK_ClimbSurface`
- `BLIKK_Parapet`

Compatible surfaces also retain the established `BLIKK_WallSurface` and `BLIKK_Ledge` CollectionService tags. Metadata describes architectural intent; it does not implement or alter movement mechanics.

## Construction Rules

- Instantiate catalog entries on demand; never prebuild the full combinatorial catalog.
- Keep static map geometry anchored and deterministic.
- Snap wall dimensions to catalog values and supply explicit positions.
- Use concrete, brick, steel, corroded metal, glass, wood, and restrained BLIKK purple accents to create material separation without texture-heavy rendering.
- Prefer a small silhouette-changing detail over dense cosmetic clutter.
- Preserve playable collision, route widths, gaps, and heights when replacing gray-box geometry.
- Use movement metadata instead of arrows, tutorial signs, or invisible route advertising.

## Environment Lighting Contract

Generated environment-light owners carry the `BLIKK_EnvironmentLight` tag and store their
quality tier, purpose, and High-quality shadow permission as attributes. Their child Light
stores immutable base brightness and range attributes. Tagging occurs only after the Light
and attributes exist, allowing the client quality controller to apply the current setting
without a partially constructed owner. Lighting is static and bounded; builders must not
introduce per-frame light updates or exceed their map-specific light and shadow budgets.

## District Zero Proof Pass

District Zero exercises the kit through modular roof families and utilities, apartment fire escapes and ladders, construction scaffolding, alley clutter and conduits, and varied street furniture. This is a proof of reuse rather than an art-complete pass. Major building masses, road slabs, canal walls, Clock Tower geometry, the court, and several connective platforms intentionally remain authored gray-box geometry for later incremental replacement.
