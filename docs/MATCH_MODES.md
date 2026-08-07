# Match Modes

MatchService owns match/round generations, preparation barriers, release timestamps, death outcomes,
spawn-protection state, kills, deaths, streaks, scores, team scores, and round wins. The server
`CharacterLifecycleService` is the only owner allowed to request or replace a character; MatchService
requests lifecycle work and never loads a character directly. Clients receive `MatchUpdated`
snapshots and cannot submit statistics, eliminations, spawn choices, or release decisions.

Match snapshots carry a monotonic revision plus `MatchId`, match generation, round, phase,
participant set, preparation deadline, and server-time release. `Preparing`, `WaitingForClients`,
`Armed`, `Fighting`, `PostRound`, and `PostMatch` are the lifecycle phases; the legacy state field
remains a compatibility presentation summary. A server-confirmed Countdown, Active, or Intermission
snapshot transfers the joined client from room frontend ownership to gameplay ownership. The
frontend, camera, mouse, and gameplay input are restored through one frontend transition owner;
clicking START MATCH alone is never sufficient. During `Armed`, every accepted participant remains
server-held and sees a countdown derived from the same `ReleaseAtServerTime`. FIGHT presentation and
legal gameplay both use that timestamp. After PostMatch, the authoritative room return to
Lobby restores the joined room lobby without discarding membership or Room Leader.

| Mode | Limit | Respawn | Join in progress |
| --- | --- | --- | --- |
| Training | No winner | 1 second | Yes |
| Deathmatch | 10 minutes or 20 kills | 3 seconds | Yes |
| Team Deathmatch Extreme | 12 minutes or 30 team kills | 3 seconds | Yes |
| Elimination | Best of 7, 3-minute rounds | Next round only | Yes, spectate until next round |

All modes may start with one player. Competitive scoring can accumulate during the session,
but winner and round resolution remains disabled until Deathmatch has two participants or a
team mode has both teams represented. Solo Elimination deaths respawn as warm-up deaths and
do not award rounds. When the missing team arrives, both sides enter through a fresh round.

Spawn protection lasts 1.5 seconds and is cleared when the future server combat hook confirms an
offensive action. `RegisterDamageSource` and `ClearDamageSource` are server-only, and damage-source
registration rejects participants who are not in `Fighting`, released, and alive. This is a
pre-FIGHT trust-boundary hook, not a claim that the current prototype already has complete
server-authoritative movement and combat. Damage sources expire after 12 seconds. Studio debug
elimination is disabled by default, requires `RunService:IsStudio()`, and has no client remote.

Readiness is exact-generation and idempotent. A shared barrier excludes or fails timed-out players
before arming; a competitive shared release aborts if any accepted participant cannot be released.
Respawns and safe join-in-progress entries use an individual preparation plus a short future release
timestamp. Elimination late joiners remain spectators until the next round boundary.

The Tab scoreboard sorts server-confirmed score, kills, fewer deaths, and UserId. No leaderstats are trusted.

Removing a room member also removes the participant from MatchService, clears the team attribute,
disconnects death observation, stops replay participation, and sends a bounded match-clear update.
Closing the final member's room stops the remaining match lifecycle so delayed countdown,
respawn, or post-match tasks cannot recreate active state.
