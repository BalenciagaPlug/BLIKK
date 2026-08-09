# Match Loading and Spawn Ownership

This document is the canonical Sprint 024.4 contract for character creation,
spawn placement, client preparation, match loading, and synchronized gameplay
release. The current implementation is split across
`CharacterLifecycleService`, `DistrictZeroSpawnService`, `MatchService`,
`MatchPreparationController`, and `LoadingScreenController`.

The server owns character creation, placement, match membership, preparation,
and release. The client may prepare local systems and acknowledge an exact
generation; it may not create a character, select a trusted spawn, advance a
round, or release itself.

## Ownership boundaries

| Concern | Owner | Contract |
| --- | --- | --- |
| Roblox automatic spawning | `src/server/init.server.luau` | `Players.CharacterAutoLoads` is set to `false` before server modules are required or initialized. |
| Character creation | `CharacterLifecycleService` | This is the only repository callsite for `Player:LoadCharacterAsync()`. All match, round, respawn, join-in-progress, and Movement Lab flows request a character through this service. |
| Match and round eligibility | `MatchService` | Registers participants, selects shared or individual preparation, validates readiness, and chooses release times. It never loads a character directly. |
| Spawn selection and placement | `DistrictZeroSpawnService` | Selects a valid District Zero spawn and pivots the exact character supplied by the lifecycle service. It does not observe `CharacterAdded`, handle a client remote, set `RespawnLocation`, or request a character. |
| Client readiness | `MatchPreparationController` | Waits for the exact character and required local binders, performs the bounded world check, and sends `MatchReady`. |
| Loading presentation and local UI ownership | `LoadingScreenController` | Covers transitions, preloads a finite presentation manifest, and owns named input, camera, and navigation blockers while active. |
| Earliest boot cover | `ReplicatedFirst/LoadingBootstrap.client.luau` | Replaces Roblox's default loading screen only after a safe black fallback exists, then hands the view to the normal client controller. |

`CharacterAdded` consumers may initialize or observe a character. They must
never call a character-load API or perform a second authoritative placement.
Repository searches must continue to show one `LoadCharacterAsync` callsite
and one `PlaceCharacter` owner.

## Character identity and idempotency

Every lifecycle request resolves to an immutable server table with these
fields:

```luau
{
	Context = "MatchEntry" | "RoundTransition" | "JoinInProgress" | "Respawn" | "MovementLab",
	RoomId = string?,
	MatchId = string?,
	MatchGeneration = number,
	Round = number,
	SpawnGeneration = number,
}
```

- `RoomId` and `MatchId` identify the server-owned room and match. They are
  absent for Movement Lab preparation.
- `MatchGeneration` increases whenever shared preparation begins. This
  includes initial entry and every subsequent round preparation.
- `Round` is the current server-owned round number.
- `SpawnGeneration` is strictly monotonic per player and distinguishes every
  accepted character request within a match generation.
- Identity equality compares all six fields. Client-provided table identity
  or timestamps never substitute for server state.

The lifecycle freezes the identity it creates. A repeated request for the
latest live or pending cycle coalesces; an explicit repeated spawn generation
is idempotent. A dead character is not reusable. A generation at or below the
latest allocated spawn generation is stale and is rejected. A newer request
supersedes pending work, and every asynchronous completion rechecks the exact
latest identity and current `Player.Character` before it may commit.

Cancellation invalidates pending work by advancing the player's spawn
generation. A late `LoadCharacterAsync` completion after a timeout is destroyed
instead of becoming current. This rule also applies when a player leaves,
changes context, closes a room, or is superseded by a newer round.

The accepted identity is reflected on the player and character through:

- `BLIKK_SpawnGeneration`
- `BLIKK_CharacterContext`
- `BLIKK_CharacterRoomId`
- `BLIKK_CharacterMatchId`
- `BLIKK_GameplayReleased`

`BLIKK_GameplayReleased` remains `false` throughout loading and holding. It
becomes `true` only when the lifecycle service releases that exact character.

## Character lifecycle

For each player, `CharacterLifecycleService` owns one serialized worker and at
most one pending request. Preparation performs the following sequence:

1. Validate or allocate the immutable identity.
2. Publish `Preparing` to the owning client.
3. Call `LoadCharacterAsync` through the sole load boundary.
4. Reject or destroy a stale completion.
5. Resolve the `Humanoid` and `HumanoidRootPart` within one bounded deadline.
6. Anchor the root, zero linear and angular velocity, and set gameplay released
   false.
7. Ask `DistrictZeroSpawnService` to select and apply one valid placement.
8. Recheck the exact identity and current character.
9. Initialize that fresh character life once with the configured maximum health
   and server-owned armour attributes. The per-character initialized marker
   prevents repeated lifecycle observation or HUD rebinding from refilling it.
10. Register one death observer and publish `Prepared`.
11. Keep the character held until an exact release request succeeds.

Fresh-life vitals are configured in `FighterVitalsConfig`. Health uses the
authoritative `Humanoid` values. Armour uses replicated server-written
`BLIKK_Armour` and `BLIKK_MaximumArmour` character attributes; clients only
observe them for HUD presentation. Every Movement Lab, match entry, round,
join-in-progress, and intended respawn character uses this single lifecycle
path. A new character receives full values, while a rebind of the same
character cannot heal or restore armour.

The current tuning is held in `MultiplayerConfig`:

- At most two character-load attempts.
- `12` seconds per load attempt before terminal timeout handling.
- `0.35` seconds base retry delay with exponential backoff.
- `10` seconds for ordinary character dependency lookup.
- `15` seconds for individual preparation and placement.

A character-load timeout places that player lifecycle into a temporary
terminal state. New requests are rejected with the terminal code until the
late load finishes and is discarded, at which point the client receives a
`Recovered` update with `LATE_LOAD_DISCARDED`. A newer request that was already
queued before the older timeout is preserved and resumes only after that late
platform call has finished, so recovery never starts overlapping character
loads.

### Service API and events

The lifecycle API is:

- `RequestCharacter(player, request)`
- `HoldCharacter(player, identity, reason)`
- `ReleaseCharacter(player, identity, reason)`
- `CancelPlayer(player, reason)`
- `GetState(player)`

Its server bindable events are:

| Event | Arguments | Meaning |
| --- | --- | --- |
| `CharacterPrepared` | `player, identity, character, placementResult` | The exact character is loaded, placed, held, and has one death observer. |
| `CharacterFailed` | `player, identity, code` | The latest request could not complete. Stale identities are ignored by match state. |
| `CharacterDied` | `player, identity, character, humanoid` | The accepted character died. Match policy decides the next action. |

`CharacterLifecycleUpdated` is a reliable `RemoteEvent` sent only to the
owning player. Its payload contains `Status`, `Identity`, `Code`, `Character`,
and `ServerTime`. Implemented statuses include `Preparing`, `Prepared`,
`Held`, `Released`, `Died`, `Failed`, `Rejected`, `Cancelled`, and `Recovered`.

## Placement ownership

`DistrictZeroSpawnService` is a placement service, not a spawn lifecycle.
Given the exact current character, it:

- waits only within the caller's finite deadline;
- filters team spawns when `BLIKK_TeamId` is `ALPHA` or `OMEGA`;
- scores candidate spawns using living-player distance, visibility, recent use,
  and deterministic rotation preference;
- zeros root velocity and pivots the character once, `3.5` studs above the
  selected spawn; and
- returns the resolved humanoid, root, and spawn to the lifecycle authority.

`SPAWN_UNAVAILABLE` may be retried until the lifecycle placement deadline. A
successful placement is committed once for the accepted character generation.
Stale characters, incomplete rigs, or placement exceptions fail instead of
being repositioned later by a second owner.

Spawn protection is separate from placement. `MatchService` enables it only
after successful gameplay release and clears the attacker's protection when a
server combat hook accepts an offensive source.

## Match preparation state machine

The authoritative phase sequence is:

```text
Preparing -> WaitingForClients -> Armed -> Fighting -> PostRound -> Preparing
                                           |              |
                                           +----------> PostMatch
```

`Cancelled` is a terminal failure path from any pre-match or active phase.

| Phase | Server behavior |
| --- | --- |
| `Preparing` | Increment the match generation, register the eligible participant set once, reset preparation records, and issue lifecycle requests in stable `UserId` order. |
| `WaitingForClients` | Wait for both `ServerPrepared` and `ClientReady` for each exact identity. The shared barrier may complete early when no participant remains pending. |
| `Armed` | Freeze the accepted set, assign one future `ReleaseAtServerTime`, publish it, and keep all accepted roots held. |
| `Fighting` | Release exact accepted identities, enable spawn protection, mark participants alive, and begin authoritative match or round timing. |
| `PostRound` | Elimination only: disable competitive resolution, hold live accepted characters, run the intermission, increment `Round`, and begin a new shared generation. |
| `PostMatch` | Hold live accepted characters, publish the winner, end replay capture, and return the room to its lobby after the bounded post-match interval. |

Match snapshots include the match ID, room ID, phase, generation, revision,
round, participant set, preparation timestamps, release timestamp, per-player
preparation records, failure code, and bounded diagnostic counters. Clients
must ignore an older revision for the same match.

## Exact-generation client readiness

`CharacterPrepared` proves server loading and placement only. The owning client
then waits up to `RequiredClientReadinessTimeoutSeconds` (`12` seconds) for the
exact `Player.Character`, matching spawn generation, `Humanoid`,
`HumanoidRootPart`, a live `Workspace.CurrentCamera`, and these per-character
markers:

- `BLIKK_ClientFighterReady`
- `BLIKK_ClientCameraReady`
- `BLIKK_ClientMovementReady`
- `BLIKK_ClientWallReady`
- `BLIKK_ClientTechniqueReady`
- `BLIKK_ClientWeaponReady`
- `BLIKK_ClientHudReady`

Each controller sets its marker only after its character dependencies and
connections are committed for the current character bind generation. Markers
belong to that character instance; they must never be accumulated across
characters.

Client character binders use one cancellable, event-driven dependency observer
for the current character. The initial dependency window emits one diagnostic
if the Humanoid or HumanoidRootPart is still absent, but the observer remains
eligible to commit if those dependencies replicate later while the exact
character and bind generation are still current. Character replacement or
removal cancels that observer. Finite deadline helpers return `nil` when their
budget is exhausted and never pass a zero timeout to `WaitForChild`. The normal
client-readiness and server preparation deadlines remain authoritative; late
dependency arrival cannot release an expired or superseded generation.

Immediately before acknowledgement, the client rechecks character context,
room, match, and spawn generation against the prepared identity. It then sends
one reliable `MatchReady` payload:

```luau
{
	Context = "Match" | "MovementLab",
	Identity = exactPreparedIdentity,
}
```

The server accepts match readiness only from an actual current participant
whose stored identity matches every field. It rejects malformed or stale
generations, rate-limits readiness to eight requests per one-second window,
and treats a duplicate as idempotent. Client readiness alone cannot arm or
release a player; `ServerPrepared` must also be true.

Client acknowledgement history is bounded by
`MaximumPreparationDiagnostics` (`24`) identities.
Release-deduplication history uses the same cap. If a slow bootstrap misses the
earlier `CharacterLifecycleUpdated: Prepared` event, an authoritative match
snapshot whose own preparation phase is `WaitingForClient` restarts this exact
readiness check; duplicate snapshots coalesce on the identity key.

## Finite asset manifest

Loading presentation uses the finite `LoadingScreenConfig.AssetManifest`; it
does not scan or preload the entire `Workspace`, and it does not use
`ContentProvider.RequestQueueSize` as a completion signal. Supported manifest
entries are explicit `Image`, `Sound`, or `Animation` asset IDs in three
categories:

| Category | Current use |
| --- | --- |
| `Required` | Empty. No presentation asset currently blocks readiness. |
| `Preferred` | The approved default loading artwork, `rbxassetid://129609609853716`. Failure falls back to the black loading treatment. |
| `Cosmetic` | Empty. Future disposable polish belongs here. |

`PreloadAsync` has an eight-second budget. Results report timeout, failed IDs,
and the number of failed entries classified as required. Presentation failure
is bounded and degrades independently from character and world readiness.
Because the current required list is empty, `RequiredFailureCount` is not a
readiness gate. If a future feature adds a genuinely required asset, its result
must be explicitly connected to `MatchPreparationController` before the
`Required` label may be treated as a gameplay barrier.

There is no artificial minimum display time and no fake percentage. The
initial `ReplicatedFirst` cover uses bounded replication and handoff waits; if
the shared artwork cannot load, the black fallback remains readable. The
current FIGHT sound field is `LoadingScreenConfig.Fight.SoundAssetId`; it is
empty, so no FIGHT SFX plays until a valid `rbxassetid://<number>` is approved.

## Streaming and world readiness

World readiness is local, bounded, and spawn-area specific:

- If `Workspace.StreamingEnabled` is false, no streaming request is needed.
- If streaming is enabled, the client calls
  `LocalPlayer:RequestStreamAroundAsync(root.Position, 5)` for the exact
  prepared root.
- After the call, the client rechecks its readiness cancellation generation,
  current character, and spawn generation.
- A call failure or timeout produces `WORLD_READINESS_TIMEOUT` and no readiness
  acknowledgement.

This does not prove the entire map is resident and must not evolve into a full
Workspace preload. Any future map-specific critical geometry check must use an
explicit, finite sentinel owned by that map.

## Shared and individual release policies

| Flow | Preparation and timeout | Release policy |
| --- | --- | --- |
| Initial match entry | Shared barrier, `20`-second match preparation budget. | Once all participants resolve or the budget expires, accepted players receive one shared release time `CountdownSeconds` (`3` seconds) in the future. |
| Elimination round transition | `PostRound`, round intermission, then a new shared match generation and fresh characters. | Same shared barrier and timestamp as initial entry. |
| Normal respawn | Modes with respawn enabled wait their configured respawn delay, then use individual preparation with a `15`-second budget. | Exact ready player is armed `1.25` seconds into the future; other active players are unaffected. |
| Join in progress outside Elimination | During `Fighting`, start individual preparation immediately. During shared preparation, mark the player pending and start individual preparation after the shared release. | Individual future release time; never added retroactively to an already armed shared set. |
| Elimination join in progress | Player remains `WaitingForRound` and spectating. | Entry occurs through the next shared round generation. If competitive resolution was inactive and the arriving roster restores a valid distribution, the server starts a fresh round. |
| Elimination death | No mid-round respawn while competitive resolution is active. Death contributes to round resolution. | Winner advances the series or all participants enter `PostRound`. In a non-competitive solo warm-up, the configured one-second fallback uses individual respawn. |
| Movement Lab | Individual lifecycle request with match generation and round `0`; the client marker budget is `12` seconds and the server lifecycle budget is `15` seconds. | Releases immediately after exact readiness. A readiness timeout cancels rather than silently releasing an incomplete fighter. Death requests a clean new Movement Lab spawn generation, and exit cancels the character. |

At a shared timeout, players without both server and client readiness are
cancelled and moved to spectating. A non-competitive match may proceed with at
least one accepted participant. A competitive match cancels if the accepted
set no longer satisfies its minimum or team distribution. No accepted players
cancels the match. An individual timeout cancels only that player generation
and leaves the player spectating.

Death or reset of the exact prepared character before release invalidates both
server and client readiness. During shared preparation the participant fails
the barrier; if the shared set was already armed, the match cancels instead of
showing a false FIGHT. During individual preparation only that participant is
cancelled and moved to spectating. Client readiness also requires a live
Humanoid immediately before acknowledgement.

Player leave, room close, match cancellation, and post-match cleanup invalidate
delayed tasks and cancel lifecycle ownership. A delayed respawn or intermission
callback must recheck the current match object, match generation, task
generation, phase, membership record, and relevant identity before acting. A
death-respawn timer from an earlier membership cannot supersede a leave/rejoin
join-in-progress preparation for the same Player object.

## Synchronized FIGHT

All scheduling uses `Workspace:GetServerTimeNow()` rather than client wall
clock time.

For shared entry, the server publishes one `ReleaseAtServerTime` for every
accepted identity. Each client arms the same value and begins a
`RenderStepped` watch shortly before it. On the closest practical render frame
at or after the timestamp, the loading controller fully removes its artwork
and backdrop and releases only its own local blockers. It then presents FIGHT
on the next render frame as a transparent overlay over the live gameplay
world. At the same server timestamp, `MatchService` requests exact lifecycle
releases. Successful release unanchors the root, zeros velocity, sets
`BLIKK_GameplayReleased = true`, marks the participant alive, and enables spawn
protection.

For individual entry, the server supplies a player-specific timestamp
`IndividualFightLeadSeconds` (`1.25` seconds) in the future. The same client
FIGHT scheduling and exact lifecycle release rules apply without delaying the
rest of the match.

FIGHT presentation is not authority. A delayed render frame may display it
late, but never changes the server timestamp. A client cannot advance the
match or unanchor its root by sending readiness early.

## Gameplay gates

| Gate | Held behavior | Release behavior |
| --- | --- | --- |
| Input | Loading adds the named `LoadingScreen` blocker to `InputManager`, which clears buffered gameplay actions and prevents semantic gameplay dispatch. | Removes only that named blocker at FIGHT or bounded dismissal. Other menu, text, spectator, or settings ownership remains effective. |
| Camera | Loading adds the named `LoadingScreen` blocker to `GameplayCamera`, preventing gameplay camera activation and mouse capture. | Removes only that named blocker. Existing frontend or spectator requests still decide effective camera state. |
| UI navigation | Loading owns a topmost `LoadingScreen` navigation scope. | Deactivates that scope before releasing camera and input blockers, restoring the next valid scope. |
| Character root | Lifecycle anchors the exact root and zeros both assembly velocities. | Only exact-generation `ReleaseCharacter` may unanchor it. Post-round and post-match holding anchors it again when still live. |
| Combat and targetability | Match stats remain unreleased/not alive and `BLIKK_GameplayReleased` is false. Server damage-source registration rejects non-Fighting, unreleased, dead, or attribute-gated participants. | Successful server release sets all required match and lifecycle gates. Spawn protection is applied separately. |

Local input and camera release at the synchronized visual timestamp, while the
server-owned root and combat checks remain the authoritative backstop. Client
presentation controllers must continue to consume the effective input gate and
must not infer authority from the visibility of the loading screen.

## Failure behavior and diagnostics

Failures use stable machine-readable codes and bounded presentation. Important
classes include invalid or stale identity, player unavailable, character load
failure or timeout, missing dependencies, stale character, spawn unavailable,
placement exception, client dependency timeout, world readiness timeout,
readiness timeout, release failure, insufficient ready distribution, and match
cancellation.

- Lifecycle failure destroys an unsafe current character, clears spawn
  protection, keeps gameplay released false, and publishes `CharacterFailed`
  plus `CharacterLifecycleUpdated`.
- Client preparation failure fires `TransitionFailed` and does not send
  readiness. Movement Lab returns through its bounded frontend recovery. A
  match dependency/world timeout retains loading input and camera ownership
  until an authoritative failed, timed-out, or cancelled snapshot arrives;
  spectator state is adopted before the loading blocker dismisses.
- Shared release failure cancels a competitive match. Any participants already
  released in that pass are held again before cancellation. A failed shared
  participant is cancelled even when a non-competitive match continues, so no
  held lifecycle character remains as a ghost.
- A failed or timed-out individual preparation affects only that participant.
- Player and task generations prevent old delayed callbacks from restoring a
  superseded loading screen or releasing a stale character.

Match snapshots expose these bounded counters:

- `ReadyAccepted`
- `ReadyDuplicate`
- `ReadyStaleRejected`
- `ReadyRateLimited`
- `PreFightRejected`
- `CharactersPrepared`
- `CharacterFailures`
- `ReadinessTimeouts`

One-shot warnings identify loading artwork failure, presentation preload
timeout, missing PlayerGui/remotes, lifecycle exceptions, and character-load
timeout without per-frame spam. The server MicroProfiler labels are:

- `BLIKK_CharacterLoad`
- `BLIKK_SpawnPlacement`
- `BLIKK_CharacterPreparation`

These labels measure code sections; they do not replace runtime counters or
Studio acceptance testing.

## Static validation invariants

Before handoff, static validation must include:

- a repository search proving one `LoadCharacterAsync` callsite and no
  deprecated character-load call;
- a search proving placement is called only through the lifecycle boundary;
- remote name, class, and owner checks for `MatchReady`, `MatchUpdated`,
  `CharacterLifecycleUpdated`, and `RequestMovementLabSpawn`;
- require-target, circular-dependency, duplicate-connection, merge-marker, and
  malformed callback-table checks;
- an available Luau analyzer or parser;
- `git diff --check`;
- a full pinned Rojo build and removal of its temporary artifact; and
- final working-tree and staged-file inspection.

A successful Rojo build proves project construction only. It does not prove
Roblox runtime behavior, synchronization, streaming, gameplay feel, or cleanup.

## Manual Roblox Studio acceptance gates

Sprint 024.4 is not runtime-approved until all applicable gates below pass.

### 1. Bootstrap recovery

1. Run Splash -> Character Profiles -> Operations Hub.
2. Open and close Settings with `M`; exercise Chat and text focus.
3. Navigate profile selection with mouse and keyboard.
4. Confirm no module-load, syntax, bootstrap, duplicate GUI, or stuck input
   errors in Output.

Expected: the bootstrap cover hands off once, the approved artwork preserves
aspect ratio when available, the black fallback is readable when unavailable,
and every input owner restores the correct prior state.

### 2. Single-spawn soak

Repeat at least 20 transitions across initial join, solo match start, death
respawn, Roblox reset, round restart, leave/rejoin, Operations Hub return, and
starting again.

Expected for every intended spawn:

- one accepted `SpawnGeneration`;
- one accepted character instance;
- one successful placement;
- one controller bind and death observer;
- no duplicate avatar flash, second pivot, stale late character, or connection
  growth.

Useful Output filters: `BLIKK CHARACTER`, `BLIKK MATCH`, `BLIKK LOADING`,
`CHARACTER_LOAD_TIMEOUT`, `STALE`, and `READINESS`.

### 3. Multiplayer synchronized start

Using two to four Studio clients, create one local room and start at least ten
matches or rounds.

Expected:

- every accepted roster entry and character appears once;
- all accepted clients receive the same generation and shared release time;
- FIGHT appears on the closest practical frame at or after that time;
- nobody moves, attacks, takes damage, or becomes targetable early;
- slow or failed clients follow the documented timeout/spectator policy;
- Room Leader authority and room membership remain server-confirmed.

### 4. Network simulation

Test representative latency, jitter, and packet loss.

Expected: reliable readiness and match snapshots remain bounded, duplicate or
stale readiness cannot release a player, FIGHT stays tied to server time, and
packet delay causes a late presentation rather than an early release.

### 5. High-APM and frame-rate soak

Exercise rapid alternation, simultaneous key presses, dash/attack transitions,
Chat and Settings open/close, low and high render FPS, and reset during held
input.

Expected: no stuck held state, duplicated action, false global cooldown,
cross-generation presentation, or silent loss of legitimate post-release
input. Inputs begun while loading must not execute after release.

### 6. Mode and cleanup matrix

Validate join in progress for every supported mode, Elimination next-round
entry, normal respawn, solo Elimination warm-up respawn, spectator transitions,
scoreboard availability, leave during loading, Room Leader leave, last-member
leave, empty-room cleanup, post-match lobby return, and Movement Lab enter,
death, respawn, and exit.

Expected: policy matches the table in this document; no stale task recreates a
match or character; no loading UI, connection, character, weapon, replay entry,
or input blocker accumulates across rounds.

### 7. Profiling

Capture:

- client MicroProfiler around initial join, shared entry, and individual entry;
- server MicroProfiler around multi-player character preparation, including
  the three named profile labels;
- a network-enabled dump during high-APM play; and
- Developer Console memory, network, and script observations across the soak.

Record measured results and before/after evidence for any confirmed hotspot.
Do not fabricate a baseline.

Published-client reserved-server teleport behavior remains a separate
acceptance gate. Ordinary Studio play cannot fully validate TeleportService or
reserved-server handoff behavior.
