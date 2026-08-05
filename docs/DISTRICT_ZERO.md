# District Zero V1

## Authority

District Zero is built from the approved DZ-001 construction, DZ-002 movement, and DZ-003 height-and-section blueprints. These plans supersede earlier blockouts. The arena is a believable abandoned district first and a movement environment second; movement opportunities arise from architecture rather than floating helpers or tutorial signage.

## Scale

The playable footprint is 500 by 500 studs on a 25-by-25 grid with 20-stud units. Ground level is 0 studs, the canal reaches -24 studs, the station service level reaches -12 studs, and the Clock Tower spire reaches 106 studs. Standard roof heights range from 24 to 50 studs, with Clock Tower play surfaces at 34, 68, and 92 studs.

Street widths follow Movement Standards V1: 40–48 studs for main streets, 32–38 for standard streets, 26–30 for minor streets, 20–24 for service roads, 12–18 for alleys, and 9–11 for opposing-wall channels. Roof gaps range from 5-stud easy jumps through 14.5-stud ground-dash equivalents and 21-stud advanced gaps; 22–28-stud gaps remain future routes.

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

## Safe Spawning

Blueprint spawns A, B, and C are placed at Garage West, Parking Southwest, and Service Southeast. The server ranks them using distance from living players, line-of-sight pressure, recent use, and rotation. Joining, resetting, and every Movement Lab re-entry select a valid spawn and clear linear and angular velocity. Future modes may map these spawn identifiers into team and duel groups.

## Runtime Contract

The deterministic map exists only at `Workspace/BLIKK_MovementLab/DistrictZero`. Rebuilding replaces that exact root. Static geometry is server-owned and anchored. Quality settings change only lighting presentation; collision and route geometry remain invariant.
