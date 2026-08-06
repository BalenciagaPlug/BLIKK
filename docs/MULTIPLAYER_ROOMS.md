# Multiplayer Rooms

## Authority and states

RoomService owns membership, RoomLeader, configuration, ready state, teams, and inactivity. Clients submit bounded operations through RoomRequest; confirmed snapshots arrive through RoomUpdated. Explicit room and player states prevent client UI state from becoming authority.

Only DistrictZero is whitelisted. Training, Deathmatch, Team Deathmatch Extreme, and Elimination are defined by GameModeRegistry. MeleeOnly is the only recognized mutator foundation.

## Validation and lifecycle

Room names are filtered by TextService and limited to 40 characters. Room IDs and private join codes are server-generated. Maps, modes, capacity, readiness, team balance, membership, leadership, and state eligibility are validated server-side. Room Leader migration prefers active lobby players, then lowest measured server ping, earliest join sequence, and lowest UserId.

AFK warning, leader migration, normal kick, and spectator kick occur at 180, 240, 300, and 420 seconds. Server-observed movement supplements rate-limited client activity. Studio kicking is off by default. Empty rooms close.

Remotes are RoomRequest, RoomUpdated, RoomActivity, DirectoryRequest, and MatchUpdated. The combat layer is not yet competitively authoritative.

