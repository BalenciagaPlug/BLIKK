# BLIKK Audio Assets

BLIKK runtime audio must be original, commissioned for BLIKK, obtained from the Roblox Creator Store under an appropriate licence, or otherwise licensed for this project. Local reference music is creative reference material only and must never be imported, uploaded, converted, renamed, embedded, or referenced as a runtime asset.

Future Roblox audio IDs belong in `src/shared/Audio/MusicConfig.luau`. Track identifiers describe their BLIKK purpose rather than referencing another game or soundtrack. Current semantic contexts are Splash, Character Selection, Operations Hub, Movement Lab, Competitive Match, and Results.

## Context-owned soundtrack

`MusicController` owns one persistent `BLIKKMusicPlayback` Sound under `SoundService`. Every music
track routes through `BLIKK_Music`; only the Sound's per-track fade multiplier is changed by the
music state machine. `AudioController` remains the sole owner of saved master/music volume and mute.
Graphics, reduced effects, and `SoundEffectsVolume` do not affect music.

The approved tracks were created by `Vnknownxo`, supplied as user-owned BLIKK uploads, and approved
for this experience on August 9, 2026:

| Semantic key | Track | Roblox asset ID | Runtime context | Playback | Enabled |
| --- | --- | --- | --- | --- | --- |
| `CharacterSelection` | BLIKK - Intro [Character Selection] | `rbxassetid://88261433540574` | Profiles and Character Creation | Looped; shared timeline within the context | Yes |
| `OperationsHub` | BLIKK - Theme Rock [Game Lobby] | `rbxassetid://139646652744306` | Operations Hub, Multiplayer frontend, Clans, and Hub submenus | Looped; shared timeline within the context | Yes |
| `DuelTheme1` | BLIKK - The Duel [Duel Theme 1] | `rbxassetid://132664546255082` | Movement Lab and active multiplayer gameplay | Non-looping shuffled playlist entry | Yes |
| `DuelTheme5` | BLIKK - Ryswick Style [Duel Theme 5] | `rbxassetid://9474594378021` | Movement Lab and active multiplayer gameplay | Retained semantic record; excluded from runtime requests | No—asset unavailable |
| `DuelTheme8` | BLIKK - HardCore [Duel Theme 8] | `rbxassetid://106872514813617` | Movement Lab and active multiplayer gameplay | Non-looping shuffled playlist entry | Yes |

Splash is silent. Profiles and Character Creation map to `CharacterSelection`; Operations Hub,
Multiplayer browser/room-selection UI, and Clans map to `MainMenu`. Entering Movement Lab or active
match gameplay explicitly starts a new `Gameplay` playlist session. A context change fades the
current Sound to zero, stops and resets it, assigns the next configured asset, and fades it in.
Navigation inside one frontend context does not restart or seek the track.

Each gameplay session builds a client-local Fisher-Yates shuffle bag with one owned `Random`. All
enabled entries play once before rebuilding, and a rebuilt bag cannot begin with the track that ended
the previous bag. `DuelTheme5` remains disabled until a future direct Studio test proves that Roblox
can load it; it is never preloaded, assigned, or played. Leaving gameplay invalidates that playlist generation; re-entry starts a fresh
bag rather than resuming track or shuffle state. No playlist choice is networked or authoritative.

`AudioPreloadController` begins only after the BLIKK SoundGroups exist and confirmed account Sound
preferences have been applied. It requests each unique enabled configured SoundId at most once per
client session through prioritized, silent temporary `Sound` proxies: current frontend music, other
frontend music, enabled Duel music, then combat SFX. A batch may advance after 12 seconds so one slow
asset cannot prevent later priorities from starting, but the owned request remains `Fetching` and may
still resolve successfully. Each configured batch destroys its temporary folder and proxies after all
of its requests resolve. Navigation, character preparation, room entry, and gameplay release never
wait for it.

Readiness is tracked as not requested, fetching, success, failure, or configuration-disabled. A slow
fetch is not reclassified as unavailable merely because the priority batch advanced. Music assigns an
asset to the single audible playback Sound only after preload success. A generation-gated continuation may
start the requested current context after readiness; stale completions cannot start an older context.
Unavailable Duel entries are skipped within the enabled bag and attempts remain bounded to that bag.
Playlist lookahead observes the next already-requested shuffled entry without consuming or reordering
it. Each failed asset produces at most one client-session diagnostic.

## Combat confirmation cues

`CombatFeedbackController` owns one `BLIKKConfirmedHitSound` and one
`BLIKKReloadInitiatedSound` below `SoundService/BLIKKCombatFeedback`. Both route exclusively through
`BLIKK_SoundEffects`. The confirmed-hit cue (`rbxassetid://1044630916`) plays once per accepted shot
only when the server-reported sum of applied damage is positive. The reload cue
(`rbxassetid://8145744063`) plays once only for the shooter-private authoritative reload-accepted
acknowledgement. Neither cue is created per event, and rapid retriggers restart its reusable Sound.

## Account-persistent sound settings

The Sound tab's `MasterVolume`, `MusicVolume`, `SoundEffectsVolume`, and `MusicMuted`
preferences are persisted per Roblox account through the existing versioned account settings path.
The server validates each narrow `SetPreference` mutation, marks the account session dirty, and uses
the existing debounced, autosave, `PlayerRemoving`, and shutdown save behavior. On join, schema
normalization supplies the current defaults for missing or invalid legacy values, and the confirmed
account snapshot is applied to `SessionSettings`.

`AudioController` keeps all BLIKK-owned sound groups silent until that first confirmed preference
snapshot has been applied. It then owns the user-volume layer: `BLIKK_Music` uses
`MasterVolume * MusicVolume` (or zero while `MusicMuted` is true), while `BLIKK_SoundEffects` uses
`MasterVolume * SoundEffectsVolume`. Menu music and every enabled Duel playlist track route through
`BLIKK_Music`; sound effects route through `BLIKK_SoundEffects` or a BLIKK effects subgroup governed
by the same effective effects volume.

`MusicController` separately owns track choice, context, playback, shuffle, and per-track transition
fades. Applying a volume or mute preference changes only the sound-group volume, so it does not
recreate a Sound, seek or restart playback, advance a playlist, or rebuild a shuffle bag. Current
track, playback position, Duel shuffle order, previous track, context, and fade state remain local to
the experience session and are never persisted. No non-audio preference is changed by this contract.
