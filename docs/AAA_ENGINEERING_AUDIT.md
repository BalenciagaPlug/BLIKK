# AAA Engineering Audit — Sprint 024.4

Audit date: 2026-08-07

Status: Sprint 024.4 is implemented in the current working tree at the static-code level. Roblox Studio acceptance, published-server integration testing, performance measurement, and owner feel/visual approval remain mandatory. This document does not claim those runtime gates have passed.

The audit basis is the uncommitted Sprint 024.2–024.4 working tree. Function and contract names are the durable evidence; line numbers are included only where they materially help and may move during review.

## Severity and disposition

- **P0** — data loss, security, match fairness, crash, duplicate spawn, or broken lifecycle.
- **P1** — likely production instability or a material hot-path, networking, or scalability risk.
- **P2** — bounded maintainability, observability, validation, or future-scaling work.
- **P3** — optional cleanup, tooling, or presentation follow-up.

“Implemented” below means the current source contains a reviewable correction. “Deferred” means the risk remains and is assigned to a follow-up sprint with an explicit dependency. Deferred findings are not silently accepted as production-ready.

## Sprint 024.4 corrections present in the working tree

| Closed item | Current evidence | Remaining runtime gate |
| --- | --- | --- |
| Single character-load authority | `src/server/init.server.luau` sets `Players.CharacterAutoLoads = false` before service loading. The Sprint diff removes the five direct `LoadCharacterAsync` paths formerly in `MatchService` (match start, round restart, normal respawn, solo-Elimination respawn, and late join). A repository search now finds the active load API only in `CharacterLifecycleService.prepareRequest`. `DistrictZeroSpawnService` only places a character passed by that authority. | Twenty-cycle single-spawn soak covering join, match entry, death, reset, round restart, late join, Movement Lab, leave, and re-entry. Count one accepted spawn generation and one placement per intended spawn. |
| Generation-scoped lifecycle | `CharacterLifecycleService.RequestCharacter` owns monotonic spawn identities, coalesces the same cycle, rejects stale generations, serializes pending work, binds one death observer to the accepted character, and cancels superseded state. A newer queued request survives an older terminal load timeout but cannot run until the late platform call returns and is discarded. `HoldCharacter` and `ReleaseCharacter` revalidate the exact live character, humanoid, root, and identity. | Failure injection for character removal, load timeout, reset during preparation, rapid repeated requests, and disconnect/rejoin. |
| Server preparation barrier and synchronized release | `MatchService.beginSharedPreparation`, `armSharedBarrier`, and `releaseSharedBarrier` own participant registration, server-prepared/client-ready state, one future `Workspace:GetServerTimeNow()` release timestamp, timeout policy, and competitive-distribution checks. `MatchReady` is participant-, identity-, generation-, and rate-validated. A competitive partial-release failure aborts the match. | Two-to-four-client Studio tests under latency/jitter/packet-loss simulation. Verify no released movement or targetability before the common timestamp. |
| Loading and FIGHT presentation | `default.project.json` maps `src/replicatedFirst`; `LoadingBootstrap.client.luau` creates or adopts one early black-backed view with bounded handoff; `LoadingScreenController` uses a finite manifest and cancellation ownership; `LoadingScreenConfig.Default.ImageAssetId` is exactly `rbxassetid://129609609853716`. `Fight.SoundAssetId` remains intentionally empty. | Validate artwork ownership/moderation, aspect treatment, black fallback, no world flash, FIGHT frame alignment, and failure recovery in Studio and a published client. |
| Client readiness contract | `MatchPreparationController` waits for the exact fighter, camera, movement, wall, technique, weapon, and HUD markers, verifies the spawn generation, performs bounded streaming readiness when enabled, acknowledges the exact identity once, and schedules FIGHT against server time. | Exercise missing-marker, streaming timeout, optional-asset failure, slow client, and stale snapshot paths. |
| Input ownership and high-APM edge preservation | `InputManager.SetGameplayBlocked(owner, blocked)` composes loading, spectator, menu, and other owners. Held physical tokens are tracked per semantic action, suppression/focus loss flushes state and cancels active dash/wall ownership, overlapping wheel pulses have distinct generations, and `ActionBuffer` has a configurable 64-entry hard bound. | Sustained alternating/simultaneous input at low and high rendering FPS, including focus loss, chat/settings transitions, held input during reset, and loading/spectator release. |
| Room/match correctness connected to entry | Room state updates preserve per-member timeout/spectator results; reserved arrival protects the recorded founder's fighter slot and authority through a bounded fallback; join nonces are consumed atomically with a unique consumer token; room secret TTL is refreshed from reserved metadata; Elimination and team-deathmatch scoring paths are separated; player departure and late Elimination distribution are reevaluated. | Repeated START presses, leader departure, leave during loading, empty-room cleanup, join in progress for every mode, founder timeout, and reserved-room arrival. |
| Replay late-join association | `ReplayService.AddPlayer` now records `playerMatchIds[player]`, allowing a legitimate late participant to request the current retained recording. | Late-join replay list/get tests plus removal and post-match retention tests. |
| Early remote availability | `RemoteRegistry.Init` runs immediately after the manual-spawn policy and creates `MatchReady` and `CharacterLifecycleUpdated` before service initialization. | Inject optional-service startup failures and confirm the intended critical/optional behavior; broader failure isolation remains P1-06. |
| Ordered room-directory publication | `RoomService` coalesces destination mutations through one ordered worker per room. Temporary source reservations are hidden from client/local/directory publication and generation-revalidated after every yielded store call. The destination revalidates ownership after yielded MemoryStore calls, removes partial stale writes after closure, and schedules a current-revision repair if an older write finishes late. | Published-server latency, retry, outage, source cancellation, and close/update race testing remains required. |
| Transport ownership and reserved-server partitioning | `CrossServerRoomService` serializes one transport attempt per player, starts a 60-second pre-commit deadline before filtering/reservation/store work, revalidates the live attempt through every yielded retry, and correlates `TeleportInitFailed` through an exact ID in returned `TeleportOptions`. An in-flight `TeleportAsync` cannot be rolled back, so it keeps exclusive UI/server ownership and has a further 30-second terminal reconnect bound; successful `PlayerRemoving` never triggers source deletion of live destination records. Indeterminate committed credentials expire by short TTL unless failure is proven, and safe cleanup is generation-coalesced. Browser Back is blocked while transport is committed. Public records are filtered by the founder's `DataModel.MatchmakingType`, and the source listing remains gated until founder admission. | Published Default/Xbox-only/PlayStation-only creation, join, disconnect-during-yield, committed-call stall, failure, deadline, TTL, cleanup, and retry tests remain mandatory because Studio cannot exercise these APIs. |
| Slow-bootstrap readiness and spectator recovery | `MatchPreparationController` can recover readiness from an authoritative `WaitingForClient` snapshot when the earlier lifecycle event was missed. Recovered snapshots are fanned to `SpectatorReplayController` first, so `WaitingForRound`, failure, and timeout ownership exist before loading dismisses. Both acknowledgement and release-deduplication histories are capped by `MaximumPreparationDiagnostics`. | Delayed-client, Elimination late-join, missing-event, local readiness failure, and long-running round/respawn soak tests remain required. |
| Persistence documentation drift | `docs/CHARACTER_PERSISTENCE.md` now matches `CharacterPersistenceConfig.SchemaVersion = 3` and records schema-1/schema-2 migration. No stored data was mutated. | Schema migration fixtures still require published persistence testing. |

## Deferred P0 findings

### P0-01 — Clan membership pointer acquisition is not atomic with roster membership

**Disposition:** Deliberately deferred from Sprint 024.4. This is the highest-priority follow-up. A safe correction needs a persistence conflict and repair protocol, which is outside the sprint’s authorized match-loading scope and its prohibition on unrelated persistence migrations.

**Evidence:**

- `ClanService.createClan` calls `membershipStore:UpdateAsync` with `return previous or pointer`, but `pointerSaved` records only whether the DataStore call completed. It does not record whether this clan actually acquired the pointer. The function then installs the new pointer in the live session even if a different persisted clan pointer won the update.
- `ClanService.acceptInvite` has the same pattern after first inserting the user into the destination clan roster. A conflicting existing membership pointer is preserved, but the destination roster and live session proceed as if the join succeeded.
- `ClanService.loadPlayer` ignores the success boolean from membership and clan `GetAsync` retries (`local _, pointer = ...`). A storage outage can be interpreted as “no membership” instead of “membership unavailable.”
- `ClanService.createClan` claims the normalized name and tag before writing the clan record. If the clan-record write fails, the function returns without conditionally releasing those two claims, so a name/tag can remain orphaned even though no usable clan exists.
- Leave, role, ownership-transfer, disband, invite cleanup, and repair writes use several best-effort `pcall` operations across independent stores. Those operations have no idempotent transaction record or reconciliation worker.

**Impact:** Concurrent clan create/join operations or partial DataStore failures can represent one user in multiple clan rosters, leave the authoritative membership pointer disagreeing with live state, corrupt owner/role invariants, or erase the distinction between “not a member” and “membership could not be loaded.” Subsequent cleanup can then remove the wrong side of the relationship. This is durable player-data integrity risk.

**Recommendation:** Make pointer acquisition return and verify an explicit accepted result inside `UpdateAsync`; never install live membership after a conflict. Treat failed reads as an unavailable session, not an empty one. Introduce an idempotent membership operation/repair record with expected clan, user, role, operation ID, and revision; make rollback conditional on values created by that operation; add reconciliation and operator-visible repair diagnostics. Do not repair by blindly deleting whichever record is easiest to reach.

**Dependency:** Clan schema and migration decision, conflict/rollback policy, repair tooling, published DataStore failure testing, and a decision on whether the membership pointer or clan roster is canonical during reconciliation.

**Suggested sprint:** **Sprint 025.1 — Clan Membership Atomicity & Repair**.

## Deferred P1 findings

### P1-01 — Character-profile saves have no cross-server session lease or persisted compare-and-swap revision

**Evidence:** `CharacterProfileService.saveSession` captures a server-owned snapshot and writes it through `UpdateAsync`, rejecting only unsupported future schema versions. `session.Revision` is process-local and is used to decide whether the local dirty flag can clear; it is not stored and compared as an ownership/version precondition. `loadPlayer` uses an ordinary `GetAsync` and does not acquire a session token.

**Impact:** Overlapping server sessions during teleport, reconnect, or platform edge cases can both load the same revision and later overwrite one another. A stale session can successfully replace changes saved by the newer session, causing profile, binding, preference, or selected-fighter data loss.

**Recommendation:** Add a persisted account revision plus either a bounded session lease or an explicit compare-and-swap conflict policy. Every save should prove it owns the active lease or is updating the expected persisted revision. Define crash expiry, teleport handoff, conflict recovery, and a read-only/unavailable client state before migrating records.

**Dependency:** Profile schema migration, lease-duration and teleport-handoff policy, published DataStore testing, and recovery UX.

**Suggested sprint:** **Sprint 025.2 — Profile Session Leases & Conflict Recovery**.

### P1-02 — Competitive movement and combat do not yet have a full authoritative command protocol

**Evidence:** `docs/MOVEMENT_SPEC.md` section 13 explicitly describes movement as a responsive client-side feel prototype with no complete network protocol. `docs/COMBAT_SPEC.md` describes the Training Katana as presentation-only with no hitbox, damage, guard result, target detection, or server combat authority. `MatchService.RegisterDamageSource` correctly rejects unreleased participants, but it is an internal guard, not a complete server-owned action, hit, ammunition, cooldown, or movement-validation pipeline.

**Impact:** Sprint 024.4 can prevent legitimate clients from being released early, but the current prototype is not a production competitive trust boundary after release. Future damage or firearm work built directly on client-reported positions, timestamps, cooldowns, hits, or outcomes would be exploitable and could also drop legitimate high-APM action edges if it used an unsuitable shared debounce or RemoteFunction round trip.

**Recommendation:** Design a reliable ordered semantic-command protocol with per-action sequence handling, bounded payloads, action-specific rate budgets, stale/duplicate rejection, server-owned cooldowns and outcomes, client prediction/reconciliation, and aggregate diagnostics for accepted, stale, rate-limited, and pre-FIGHT commands. Do not network presentation every frame and do not change accepted movement feel without measured reconciliation tests.

**Dependency:** Approved movement/combat timing contracts, actual hit/damage/ammunition systems, latency targets, and multiplayer feel testing.

**Suggested sprint:** **Sprint 026 — Combat & Movement Network Authority**.

### P1-03 — `LoadCharacterAsync` timeout is fail-closed but the underlying platform yield cannot be cancelled

**Evidence:** `CharacterLifecycleService.prepareRequest` invokes `player.LoadCharacterAsync` in a spawned task and enforces `CharacterLoadTimeoutSeconds` in the lifecycle worker. On timeout it sets `TerminalCode = "CHARACTER_LOAD_TIMEOUT"`, rejects new requests, and destroys a character if the original call later completes. There is no Roblox API used here that cancels the in-flight `LoadCharacterAsync` call itself.

**Impact:** The mitigation prevents a timed-out call from silently winning a newer generation, which protects spawn correctness. If the platform call never returns, however, the player remains terminal until reconnect and the orphaned task remains resident. Repeated platform stalls across players can create availability and resource-pressure risk even though concurrent replacement loads are blocked.

**Recommendation:** Keep the fail-closed generation rule; add published-server duration/timeout counters, bounded per-player admission, explicit player-facing reconnect/return recovery, and failure-injection coverage. Confirm Roblox’s real late-completion behavior before considering any retry after a timeout; never start an overlapping load merely to clear the terminal state.

**Dependency:** Published-server observation of `LoadCharacterAsync` stalls and a product decision for terminal recovery.

**Suggested sprint:** **Sprint 024.5 — Lifecycle Recovery & Failure Injection**.

### P1-05 — Room spectators are not members of the match observation contract

**Evidence:** `RoomService.addMember` calls `MatchService.AddLatePlayer` only for non-spectators. `MatchService.StartRoom` likewise registers only non-spectator members, publishes snapshots only to `match.Players`, and resolves `GetMatch` through `playerMatch`. `SpectatorService.allowedTargets` begins with `matchService:GetMatch(player)`, so a spectator-slot user who was never a fighter receives no match and no legal targets.

**Impact:** Dedicated room spectators can be admitted and shown as spectating in the room while remaining unable to observe the active match, receive its snapshots, or use the target contract. This makes spectator slots behaviorally incomplete and can produce confusing UI state during join-in-progress and post-round transitions.

**Recommendation:** Model observers separately from fighters in `MatchService`; publish a sanitized match view to authorized observers; give `SpectatorService` a room/match observer lookup; preserve team-visibility rules; remove observers cleanly without adding them to the preparation barrier, scoring, spawn, or replay-fighter sets.

**Dependency:** Spectator information-visibility policy and room observer UX.

**Suggested sprint:** **Sprint 025.3 — Spectator Membership & Match Observation**.

### P1-06 — Server startup still has a single unprotected require/init chain

**Evidence:** `src/server/init.server.luau` creates remotes early, but then requires every service and initializes `CharacterProfileService` through `CrossServerRoomService` in one direct sequence. Only `DistrictZeroBuilder.Build` is protected with `xpcall`. A require-time or initialization exception in an optional service can prevent unrelated handlers from being attached.

**Impact:** One runtime startup defect can leave all centralized remotes present but unhandled and can prevent otherwise independent character, match, room, reporting, clan, or teleport services from becoming available. This complicates diagnosis because clients see the expected remote names while requests stall or fail later.

**Recommendation:** Define a small explicit startup dependency order. Fail closed and visibly for critical lifecycle/match dependencies, but initialize independent optional services through bounded protected stages with one-shot diagnostics. Do not swallow errors or build a general dependency-injection framework.

**Dependency:** A documented classification of critical versus optional services and desired client degradation behavior.

**Suggested sprint:** **Sprint 024.5 — Bootstrap Failure Isolation**.

## Deferred P2 findings

### P2-01 — Spawn selection and world state are not isolated by arena or room

**Evidence:** `DistrictZeroSpawnService.getSpawnFolder` resolves one Workspace District Zero spawn folder. `getLivingRoots` scans every server player, while `recentUse` and `rotationIndex` are global to the service. `MatchService` can hold matches by multiple room IDs, even though the current reserved-server service keeps one `ownedRoom` in the normal published topology.

**Impact:** The present one-room reserved-server assumption limits exposure. If multiple active rooms ever share one server, their players influence each other’s spawn safety and contend for the same map, recent-use history, and spawn rotation. Studio multi-room tests can also exercise behavior that is not arena-isolated.

**Recommendation:** First make the one-room-per-server hosting invariant explicit and validated. If co-resident matches become a product goal, introduce an arena instance/context passed into placement, replay, visibility, and match state rather than filtering the current global map ad hoc.

**Dependency:** Production hosting topology and the decision between one reserved server per room versus server consolidation.

**Suggested sprint:** **Sprint 027 — Match Instance & Arena Isolation**.

### P2-02 — Important render/simulation hot paths have no measured budget yet

**Evidence:** Camera obstruction performs a spherecast plus `GetPartsObscuringTarget` work during camera updates; wall sensing can run several spherecasts every `QueryIntervalSeconds` (currently 0.025 seconds); dash presentation creates Parts, Attachments, and Beams per dash while reusing one character-bound Sound; character preview performs bounded avatar/bounds work and owns one active render callback. These are bounded by current configuration, but no MicroProfiler baseline in the repository proves their aggregate cost under high APM and repeated rounds.

**Impact:** Allocation churn, physics queries, and hierarchy callbacks may produce client frame spikes on modest hardware during the exact movement/combat sequences BLIKK prioritizes. Optimizing without measurements could also damage accepted presentation or movement feel.

**Recommendation:** Capture client/server MicroProfiler traces at low and high effects settings, with 2–4 clients and sustained dash/wall/combat input. Record p50/p95 frame observations and instance/connection growth. Pool or reduce only the paths that the trace identifies, preserving gameplay state across quality tiers.

**Dependency:** Representative Studio hardware, MicroProfiler captures, effects-quality cases, and owner-approved feel baselines.

**Suggested sprint:** **Sprint 025.4 — MicroProfiler & Hot-Path Budget**.

### P2-03 — Published platform integrations remain unverified acceptance gates

**Evidence:** `CrossServerRoomService` intentionally bypasses several directory/teleport paths in Studio and depends on TeleportService, MemoryStoreService, MessagingService, correlated `TeleportOptions`, and server-only `DataModel.MatchmakingType`. Profile/clan persistence depends on DataStoreService. The loading image depends on published asset permission/moderation. A Rojo build cannot exercise those behaviors.

**Impact:** Local Studio success cannot prove reserved-room authorization, nonce consumption, TTL recovery, messaging behavior, teleport failure recovery, DataStore conflict behavior, or loading artwork availability to a real client. Shipping without this gate can produce invisible rooms, rejected arrivals, lost persistence, or black-fallback presentation.

**Recommendation:** Use a separate published private test experience. Test creation/join by code, founder-gated discoverability, reserved arrival, nonce replay, TTL refresh, leader handoff, correlated teleport failure/timeout/retry, Default and cross-play-disabled console partition rejection, DataStore disabled/outage behavior, rejoin, asset moderation fallback, and multi-client release. Capture bounded Developer Console evidence; do not use live player data.

**Dependency:** Published test place, API-service access policy, owned image availability, and multiple test accounts/clients.

**Suggested sprint:** **Sprint 024.5 — Published Match Pipeline Validation**.

### P2-04 — Menu navigation and gameplay input do not yet have a complete gamepad/touch contract

**Evidence:** `UINavigationController` binds keyboard arrows, Return/KeypadEnter, and Backspace. Pointer activation supports mouse and touch, but repository search finds no gamepad action mapping or preferred-input transition logic. Current gameplay bindings likewise have no complete touch control surface.

**Impact:** Keyboard/mouse ownership and focus can pass while controller users cannot reliably enter, navigate, activate, back out, or recover selection, and touch users have no demonstrated gameplay-equivalent path. This is an acceptance gap, not evidence that keyboard navigation is broken.

**Recommendation:** Define semantic Navigate/Accept/Back actions across keyboard and gamepad, preserve selected-object synchronization when the preferred device changes, and design touch controls separately for gameplay. Validate focus recovery, binding capture, chat/settings, loading release, and spectator controls on each device class.

**Dependency:** Supported-device product decision, controller binding vocabulary, and touch HUD/control design.

**Suggested sprint:** **Sprint 025.5 — Controller & Input Accessibility**.

### P2-05 — Replay retention is bounded per match but not across all retained matches

**Evidence:** `ReplayConfig` bounds rolling snapshots, events, clips, and serialized clip bytes per match and retains completed recordings for 600 seconds. `ReplayService.recordings` has no global retained-match or byte budget. Snapshot and clip eviction use `table.remove(..., 1)`, which shifts arrays.

**Impact:** The current one-room topology keeps this modest, but repeated/co-resident matches or unexpectedly large player snapshots can increase server memory and periodic copy cost. Future multi-arena work would multiply the five-Hz capture loop over every active recording.

**Recommendation:** Measure retained bytes and capture cost first. Then add a global recording/byte budget, oldest-expiry policy, and ring-buffer indexing if traces justify it. Preserve evidence required by reporting policy when choosing eviction order.

**Dependency:** Measured replay payload sizes, reporting retention requirements, and the arena-hosting decision.

**Suggested sprint:** **Sprint 025.4 — MicroProfiler & Replay Memory Budget**.

### P2-06 — Remote query and UI request budgets are inconsistent

**Evidence:** Replay, report, clan, directory, readiness, room mutation, and room activity paths have explicit rate limits. `SpectatorRequest` has no rate limit and scans match state for every call. Character-profile `Request` and room `Snapshot` are unrate-limited. Some client controllers call `RemoteFunction:InvokeServer` directly inside activation callbacks (`ClanController` and `SpectatorReplayController`). The multiplayer browser rejects stale UI responses; its transport owner has bounded pre-commit and terminal policies, although Roblox does not expose cancellation of the underlying invoke or teleport call itself.

**Impact:** A malicious or broken client can create avoidable server query work. During a server stall, direct UI request threads can remain outstanding and repeated activation can create confusing late responses. These are not current high-frequency gameplay commands, so they should not be solved with one blunt global debounce.

**Recommendation:** Assign cheap query-specific token budgets, add client request generations and stale-response rejection, disable/re-enable the exact initiating control, and expose bounded retry UX. Keep gameplay commands on reliable event protocols rather than RemoteFunction round trips.

**Dependency:** Per-interface UX policy and measured normal query frequency.

**Suggested sprint:** **Sprint 025.6 — Remote Request Budgets & UI Recovery**.

### P2-07 — A client-only movement owner resides under the replicated `shared` boundary

**Evidence:** `src/shared/Movement/MovementEngine.luau` accesses `Players.LocalPlayer` and binds `RunService.Heartbeat`. Its location makes it visible to both runtimes even though its contract is client-only. Current server modules do not require it, so this is a boundary hazard rather than a current server crash.

**Impact:** Future networking work can mistakenly treat the module as runtime-neutral or authoritative because it is under `Shared`, increasing the chance of circular ownership or accidental server require failures.

**Recommendation:** Document it explicitly as a replicated client module now. When the authoritative movement protocol is introduced, separate pure shared calculations/configuration from the client simulation owner; relocate only when callers and Rojo mappings can be updated in one focused change.

**Dependency:** Sprint 026 movement networking design and an inventory of current requires.

**Suggested sprint:** **Sprint 026 — Combat & Movement Network Authority**.

### P2-09 — Required client-readiness markers are duplicated string contracts

**Evidence:** `MatchPreparationController.REQUIRED_CHARACTER_MARKERS` lists seven literal attribute names. Each producer repeats its own literal in `FighterController`, `GameplayCamera`, `MovementEngine`, `WallInteractionController`, `TechniqueRhythmController`, `MeleePresentationController`, or `HUDController`. There is no shared marker registry or static assertion that every required marker has one producer and cleanup path.

**Impact:** A rename or new required subsystem can produce only a generic client-dependency timeout at runtime. The barrier safely refuses release, but the coupling is harder to review and diagnose than an explicit shared contract.

**Recommendation:** Centralize marker constants and diagnostic labels in a small client-readable contract, preserve per-character generation checks, and report the bounded set of missing marker names in development diagnostics. Do not let the marker registry become a service framework.

**Dependency:** Stable readiness subsystem list and desired development-only diagnostics.

**Suggested sprint:** **Sprint 024.5 — Lifecycle Recovery & Failure Injection**.

## Deferred P3 findings

### P3-01 — `SpectatorService` owns an empty `PlayerRemoving` connection

**Evidence:** `SpectatorService.Init` connects `Players.PlayerRemoving` to `function() end` and stores no spectator-owned per-player state that requires cleanup.

**Impact:** The connection is harmless but misleading during lifecycle audits and implies cleanup that does not exist.

**Recommendation:** Remove it when spectator membership is reworked, or replace it only if the service begins owning state that must be cleared.

**Dependency:** P1-05 spectator observer design.

**Suggested sprint:** **Sprint 025.3 — Spectator Membership & Match Observation**.

### P3-02 — The room-directory MessagingService subscription has an empty callback

**Evidence:** `CrossServerRoomService.Init` subscribes to the directory topic with `function() end`, retains/disconnects the subscription, and otherwise relies on MemoryStore queries and heartbeat writes. Published messages therefore trigger no cache invalidation or client update.

**Impact:** The server consumes a subscription and creates the impression of event-driven directory refresh without receiving any functional benefit.

**Recommendation:** Either remove the subscription until it has a consumer, or use validated versioned messages to invalidate a bounded directory cache. Do not trust message payloads as the room authority.

**Dependency:** Decision on polling versus event-assisted directory refresh.

**Suggested sprint:** **Sprint 024.5 — Published Match Pipeline Validation**.

### P3-03 — FIGHT audio remains an explicit asset dependency

**Evidence:** `LoadingScreenConfig.Fight.SoundAssetId` is the empty string. No verified owned BLIKK FIGHT sound was found or invented during this sprint.

**Impact:** FIGHT remains visually synchronized but has no configured entry SFX. This is intentional degraded presentation, not a gameplay blocker.

**Recommendation:** Supply an owned, permission-compatible Roblox audio asset ID, then validate latency, volume, and reduced-effects/sound preferences. Keep the field empty until ownership is confirmed.

**Dependency:** User-approved audio asset and publication permission.

**Suggested sprint:** **A future approved audio/presentation pass after Sprint 024.4 acceptance**.

### P3-04 — The pinned toolchain has no automated Luau analyzer or test runner

**Evidence:** `rokit.toml` pins Rojo 7.7.0 only, and the repository currently has no committed Luau analyzer/linter or automated test suite. Rojo construction and targeted static searches catch important classes of failure but do not validate types or state-machine invariants.

**Impact:** Syntax/bootstrap, stale-generation, persistence-conflict, and transition regressions rely heavily on manual review and Studio testing.

**Recommendation:** In a dedicated tooling sprint, evaluate a minimal analyzer and focused pure tests for identity matching, barrier transitions, schema normalization, and room validation. Do not block current playable iteration on a broad CI/framework rollout.

**Dependency:** Team tooling preference and a decision on local versus hosted automation.

**Suggested sprint:** **Sprint 028 — Focused Luau Analysis & State-Machine Tests**.

## Acceptance gates that remain open

1. **Bootstrap recovery:** Splash → Character Profiles → Operations Hub, Settings through M, chat focus recovery, mouse/keyboard profile selection, and no required-module errors.
2. **Single-spawn soak:** At least 20 cycles across join, solo match, death, reset, round restart, room leave/rejoin, Operations Hub return, Movement Lab, and late join.
3. **Synchronized multiplayer release:** Two-to-four clients, at least ten match/round starts, shared release timestamp, no early movement/targetability, one roster entry and character per player, and controlled slow-client policy.
4. **Network simulation:** Representative latency, jitter, and packet loss with stale/duplicate readiness, leave during preparation, and generation supersession.
5. **High-APM resilience:** Sustained simultaneous and alternating movement/combat input, held input through reset/focus loss, chat/settings open-close, and low/high rendering FPS.
6. **Lifecycle cleanup:** Join in progress for every supported mode, Elimination waiting policy, spectator transitions, leader/last-member departure, empty-room cleanup, and repeated-round connection/UI/memory observation.
7. **Performance:** Client and server MicroProfiler captures, Developer Console memory/network/script observations, and before/after evidence before any optimization claim.
8. **Published services:** Reserved-server TeleportService, MemoryStore/Messaging TTL and nonce behavior, DataStore persistence/conflicts, and image authorization/moderation in a separate published test experience.
9. **Device coverage:** Gamepad navigation and focus recovery remain deferred under P2-04; touch gameplay requires an explicit product/control pass.

## Static confidence boundary

The repository search at this audit point found one active character-load API site, owned by `CharacterLifecycleService`, and no deprecated character-load variants. The pinned Rojo build and static require/remote checks can prove project construction and contract presence only. They cannot prove gameplay feel, exact FIGHT frame alignment, streaming readiness, platform-service behavior, network resilience, or absence of runtime connection/memory growth. Those claims remain gated by the tests above.
