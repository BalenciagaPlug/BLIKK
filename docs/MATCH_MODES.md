# Match Modes

MatchService owns countdowns, match state, death observation, respawning, spawn protection state, kills, deaths, streaks, scores, team scores, and round wins. Clients receive MatchUpdated snapshots and cannot submit statistics or eliminations.

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

Spawn protection lasts 1.5 seconds and is cleared when the future server combat hook confirms an offensive action. RegisterDamageSource and ClearDamageSource are server-only. Damage sources expire after 12 seconds. Studio debug elimination is disabled by default, requires RunService:IsStudio(), and has no client remote.

The Tab scoreboard sorts server-confirmed score, kills, fewer deaths, and UserId. No leaderstats are trusted.
