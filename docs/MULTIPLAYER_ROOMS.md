# Multiplayer Rooms

## Authority and states

RoomService owns membership, RoomLeader, configuration, ready state, teams, and inactivity. Clients submit bounded operations through RoomRequest; confirmed snapshots arrive through RoomUpdated. Explicit room and player states prevent client UI state from becoming authority.

Room snapshots carry a monotonic room revision. The client keeps directory selection, transport,
request, joined-room, frontend, and match state separate. Directory rows never establish room
membership. The joined room is adopted only from a server response or RoomUpdated event, and an
older revision cannot replace a newer snapshot.

`LoadingMatch` means MatchService is preparing an exact match generation; `Countdown` means the
readiness barrier is armed against one future server-time release; `InProgress` means the release
has completed. Room state never creates or places a fighter. Explicit member states such as
`Loading`, `Alive`, `Dead`, and `Spectating` are applied from the match lifecycle so a late room
phase update cannot overwrite a readiness failure or waiting-for-round policy.

Only DistrictZero is whitelisted. Training, Deathmatch, Team Deathmatch Extreme, and Elimination are defined by GameModeRegistry. MeleeOnly is the only recognized mutator foundation.

Room creation and match start both require one player in every mode. Competitive winner
resolution is separate: Deathmatch requires two participants, while team modes require at
least one Alpha and one Omega player. A solo room therefore remains playable without
awarding a competitive result.

## Validation and lifecycle

Room names are filtered by TextService and limited to 40 characters. Room IDs and private join codes are server-generated. Maps, modes, capacity, readiness, team balance, membership, leadership, and state eligibility are validated server-side. Room Leader migration prefers active lobby players, then lowest measured server ping, earliest join sequence, and lowest UserId.

Reserved-room creation is not publicly discoverable until the recorded founder reaches the
destination. As defense in depth, the destination reserves the final fighter slot for that founder,
forces the founder into the fighter role, and refuses to infer leadership from arrival order. If a
non-founder nevertheless arrives first, founder authority remains reserved for 60 seconds. After
that bounded interval, an active admitted member is selected through the normal deterministic
leader-migration policy so the room cannot remain leaderless forever.

AFK warning, leader migration, normal kick, and spectator kick occur at 180, 240, 300, and 420 seconds. Server-observed movement supplements rate-limited client activity. Studio kicking is off by default. Empty rooms close.

Leaving is server-confirmed. It removes the player from the match and room, clears team state,
stops replay participation, migrates Room Leader when members remain, and closes the room when the
last member leaves. Both LEAVE ROOM and RETURN TO HUB use this same bounded lifecycle; local screen
navigation alone does not preserve invisible membership.

Studio is both the browser hub and the authoritative local room server. Create and join return a
`LocalRoom` transport result with a sanitized joined-room snapshot, so no teleport state is entered.
Production create and join return `ReservedServerTeleport` only after the server authorizes and
initiates the teleport. Failures return the `Failure` transport result and a bounded code.
The client cannot navigate Back to another frontend page while a create/join transport is committed;
the server's pre-commit deadline or correlated failure first returns the transport owner to a
retryable state. An indeterminate in-flight `TeleportAsync` remains non-retryable and ends through
successful departure, correlated failure, or the bounded reconnect policy.

Remotes are RoomRequest, RoomUpdated, RoomActivity, DirectoryRequest, and MatchUpdated. The combat layer is not yet competitively authoritative.

Character readiness uses the reliable `MatchReady` event and `CharacterLifecycleUpdated` status
stream. It is generation-scoped, rate-limited, and server-validated. These contracts carry intent
and state only; the client cannot use them to start a match or unanchor its fighter.

Training, Deathmatch, and Team Deathmatch Extreme admit players during countdown and active
play. Elimination admits them during an active round as spectators and includes them at the
next round boundary. Late team players are assigned to the currently smaller team, with
Alpha winning a tied assignment deterministically.

The client fans every live or recovered match snapshot through spectator ownership before match
loading ownership. This includes the bounded room-membership snapshot used when an initial
`MatchUpdated` event was emitted before client bootstrap, so an Elimination late join adopts
`WaitingForRound` and its spectator input/camera blocker before gameplay UI can become active.
