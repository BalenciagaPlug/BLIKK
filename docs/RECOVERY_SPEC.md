# BLIKK Recovery Specification

## Evidence boundary

Classic GunZ equips recovery items in two accessory slots. Standard medical and repair kits restore
10 HP or AP, use a 1000 ms delay, and ship in stocks of two to four; stronger variants recover about
twice as much. GunZ kits are dropped into the world and collected by contact. GunZ map spawn files
author HP/AP pickups per map with independent timers, including documented 30- and 45-second examples.

BLIKK deliberately extends the classic two-slot limit to a four-slot recovery belt because Vital
Patch, Aegis Patch, Vital Amp, and Aegis Amp are required as simultaneous default equipment. The
ampoules are the immediate 20-point counterparts; this delivery distinction is BLIKK design, not a
claim about the original client's exact ampoule implementation. District Zero's `+100` cores are
the product requirement and use the conservative documented 45-second map timer.

Research references:

- [StrategyWiki recovery equipment](https://strategywiki.org/wiki/GunZ_The_Duel/Equipment)
- [GameFAQs GunZ FAQ and item statistics](https://gamefaqs.gamespot.com/pc/928753-gunz-the-duel/faqs/50467)
- [GameFAQs guide describing dropped medical/repair pickups](https://gamefaqs.gamespot.com/pc/928753-gunz-the-duel/faqs/39739)
- [Documented GunZ map spawn XML with 30/45-second HP/AP timers](https://forum.ragezone.com/threads/ctf-town-spawn.885750/)
- [GunZ AP map-pickup description](https://gunz.fandom.com/wiki/AP)

## Authority

Keys 4 through 7 select one recovery-belt item; selection alone never consumes or deploys it. The
selected item is used only by a subsequent Primary action, matching the equipment/use separation of
GunZ's item slots. Selecting melee or a firearm clears the recovery selection.

The client sends only item ID, monotonic request sequence, and observed spawn generation. The server
validates the live released character, match or isolated Movement Lab context, exact life generation,
request order, rate, shared one-second delay, remaining stock, and current capacity for the selected
resource. The server alone changes Humanoid
health, armour attributes, counts, world availability, and observer effects. Malformed, reordered,
stale-life, dead, held, menu, and out-of-context requests cannot recover resources.

## Per-life belt

| Item | Resource | Delivery | Amount | Stock |
| --- | --- | --- | --- | --- |
| Vital Patch | HP | 12-second same-context world pickup | 10 | 2 |
| Aegis Patch | AP | 12-second same-context world pickup | 10 | 2 |
| Vital Amp | HP | Immediate self-use | 20 | 2 |
| Aegis Amp | AP | Immediate self-use | 20 | 2 |

Fresh-life preparation resets all four stocks. Movement Lab receives no refill exception and uses
the identical counts and delay as Deathmatch. A patch can be stolen by an opponent in the same
combat context, preserving the positioning risk of GunZ-style medding. Patches and ampoules are
rejected without consuming stock when the owner already has full matching HP or AP; a full owner
cannot deploy a patch merely to create a later world pickup.

## District Zero cores

Market and Generator hold health cores; Station and the Parking Garage roof hold armour cores. A
successful collection adds 100 of the matching resource, clamps at the authoritative maximum, hides
the core, and begins a 45-second respawn. Contact at full resource leaves the core available.

## Presentation

World cores use an explicit HP cross or AP diamond, resource colour, light, and ambient particles.
They have no permanent label. Holding the unobstructed centre crosshair on a queryable active core
for three continuous seconds reveals its amount and respawn time in a panel offset beside the
crosshair; looking away or losing line of sight resets inspection immediately. Successful recovery
gives the collector a short matching screen pulse and text. A
server-created occluded character highlight and particle burst replicate to other clients. These
effects communicate recovery only; they never decide or delay the resource change.
