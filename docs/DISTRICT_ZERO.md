# District Zero V1

## Authority

District Zero is built from the approved DZ-001 construction, DZ-002 movement, and DZ-003 height-and-section blueprints. These plans supersede earlier blockouts. The arena is a believable abandoned district first and a movement environment second; movement opportunities arise from architecture rather than floating helpers or tutorial signage.

## Scale

The playable footprint is 500 by 500 studs on a 25-by-25 grid with 20-stud units. Ground level is 0 studs, the canal reaches -24 studs, the station service level reaches -12 studs, and the Clock Tower spire reaches 142 studs. Standard occupied-building roof heights range from 34 to 68 studs, with Clock Tower play surfaces at 52, 94, and 122 studs. The vertical-combat pass adds 18 studs to every standard building while preserving each footprint and route relationship; the landmark receives a larger tiered extension so it remains the district's navigation anchor.

Street widths follow Movement Standards V1: 40–48 studs for main streets, 32–38 for standard streets, 26–30 for minor streets, 20–24 for service roads, 12–18 for alleys, and 9–11 for opposing-wall channels. Roof gaps range from 5-stud easy jumps through 18.125-stud ground-dash equivalents and 21-stud advanced gaps; 22–28-stud gaps remain future routes.

## District Structure

The Clock Tower is the primary landmark. Construction and Parking Garage occupy the northwest; Apartments A and B form the northern roof line; Market and Garage define the west; Generator, Billboard, and Transit define the east; Court anchors the centre-south; Apartments C and D form the southern midline; Parking Lot, Canal/Drain, and Service Yard close the south.

Natural callouts are Clock, Market, Court, Station, Generator, Garage, Canal, Billboard, Construction, Parking, Service Yard, and Apartments A–D.

## Architecture Kit

District Zero uses the reusable `ModularUrbanKit` described in `MODULAR_URBAN_KIT.md`. The current proof pass applies modular roof families and rooftop utilities, apartment fire escapes and ladders, construction scaffolding, alley clutter and conduits, and varied street furniture. New maps may reuse the same catalog while supplying their own deterministic layout configuration.

This pass is deliberately incomplete. Building masses, roads, canal walls, the Clock Tower, court markings, and several route connections remain gray-box geometry until a future art pass can replace them without changing the approved movement dimensions.

## Movement Routes

- The Master Rooftop Highway follows the outer roof network and architectural catwalks.
- The Skyline Route joins high Generator and Billboard geometry.
- Market Run connects Market, Garage, Apartments, and Clock approaches.
- Generator Loop connects Generator, Apartments B, Billboard, and Transit.
- Canal Express uses canal walls, access stairs, bridge, and southern links.
- Apartment Chain crosses Apartments A–D through roofs, fire escapes, ladders, and catwalks.
- Court Climb provides a current-mechanics route from street to the Court roof.
- Alley Connectors use real 12–18-stud passages, including 9–11-stud future Butterfly channels.

Route metadata marks difficulty, future-only techniques, recovery drops, combat pockets, roof height, and movement surfaces without placing public arrows or training platforms.

Every generated `RoofLadder` contains an invisible, collidable `TrussPart` climb volume aligned to
its visible rails and rungs. Roblox's default Humanoid climbing state owns ascent and animation; the
volume is explicitly excluded from BLIKK wall-tech sensing. Every standard roof, the Court, and all
three Clock Tower play surfaces now have a ground or tier-to-tier ladder route. Their rails, rungs,
and climb volumes derive from the new roof heights. Procedural facade windows continue their 11-stud
vertical cadence through the added floors. These beginner routes do not change dash, wall-run,
wall-jump, or K-style timing.

## Recovery control points

District Zero authors four server-owned recovery cores. Market and Generator provide `+100 HP`;
Station and the Parking Garage roof provide `+100 AP`. Collection clamps to the fighter maximum,
does not despawn a core when the corresponding resource is already full, and starts a 45-second
respawn only after a successful recovery. Health and armour use distinct BLIKK colours, glyphs,
labels, light, and particles. The collector receives a brief screen confirmation while the server
replicates a short character highlight and particle burst to nearby observers.

## Safe Spawning

District Zero authors eight ground spawns against the current building footprints and arena boundary:

| ID | Position | Facing | District and clearance rationale |
| --- | --- | --- | --- |
| `SPAWN_A` | `(-238, 3, -150)` | `(1, 0, 0.25)` | Northwest boundary lane, west of Construction/Garage and south of the north wall. |
| `SPAWN_B` | `(-236, 3, 221)` | `(1, 0, -0.2)` | Southwest boundary lane, west of the Parking Lot footprint. |
| `SPAWN_C` | `(232, 3, 221)` | `(-1, 0, -0.2)` | Southeast boundary lane, east of Service Yard. |
| `SPAWN_D` | `(220, 3, -170)` | `(-1, 0, 0.25)` | Northeast lane, east of Apartments B and north of Billboard. |
| `SPAWN_E` | `(-235, 3, 20)` | `(1, 0, 0)` | West-central lane, west of Market and Apartment C. |
| `SPAWN_F` | `(225, 3, 35)` | `(-1, 0, 0)` | East-central lane, east of Transit and south of Billboard. |
| `SPAWN_G` | `(-18, 3, -240)` | `(0, 0, 1)` | North-central boundary lane between the northern apartment footprints. |
| `SPAWN_H` | `(0, 3, 135)` | `(0, 0, -1)` | South-central open route between Court and the Canal opening. |

Training and free-for-all use all eight. ALPHA uses A, B, E, and G; OMEGA uses C, D, F, and H.
Duel has six separated alternatives. `DistrictZeroSpawnService` hard-excludes any candidate within
14 studs of a living player or active three-second reservation. If no hard-safe spawn exists it
returns `SPAWN_UNAVAILABLE`; the lifecycle may retry at most six times within its existing bounded
placement deadline and never falls back to an occupied point.

Selection reserves the chosen ID before placement and clears that bounded reservation on commit,
failure, cancellation, player removal, map rebuild, or teardown. Among hard-safe candidates, scoring
uses opponent distance, line-of-sight pressure, global recent use, and a three-ID personal history.
A server-owned `Random` chooses among near-equal top scores. The committed ID remains visible through
`BLIKK_LastSpawnId`. The service still does not watch `CharacterAdded`, set `RespawnLocation`, or
request a character; all character creation remains in `CharacterLifecycleService`.

## Shared Clock dummy bay

One map-generation-owned `BLIKK_PracticeDummy_CLOCK` stands at the Clock Tower south wall, derived
from `ClockTower.Center`, `ClockTower.Size`, and a configured three-stud stand-off. It faces world
`+Z` beneath the `CLOCK // DISTRICT ZERO` sign. Bounded fallbacks move four or eight studs along the
same wall only. Ground, slope, body clearance, actual wall contact distance, and Clock Tower
intersection are validated before the avatar enters Workspace. Player spawn, death, re-entry, and
room membership do not rebuild it.

## Runtime Contract

The deterministic map exists only at `Workspace/BLIKK_MovementLab/DistrictZero`. Rebuilding replaces that exact root. Static geometry is server-owned and anchored. Quality settings change only lighting presentation; collision and route geometry remain invariant.

## Night Visibility

District Zero remains a night map at 19.15 ClockTime. A restrained cool global fill keeps
routes and character silhouettes readable without flattening the dark sky, while nine warm
street practicals and the purple Generator accent retain the district's colour identity.

Twenty-two invisible, deterministic route-fill anchors cover the three spawns, major
intersections, wall channels, Station sublevel, Canal approaches, and principal roof routes.
Together with the ten visible practicals, the map has a hard limit of 32 local lights. Only
four authored street practicals cast shadows on High quality; Medium and Low use no
light-cast shadows. Quality changes scale brightness and range from immutable base
attributes, so repeated setting changes do not compound values or alter collision.
