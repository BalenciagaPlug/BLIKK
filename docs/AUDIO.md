# BLIKK Audio Assets

BLIKK runtime audio must be original, commissioned for BLIKK, obtained from the Roblox Creator Store under an appropriate licence, or otherwise licensed for this project. Local reference music is creative reference material only and must never be imported, uploaded, converted, renamed, embedded, or referenced as a runtime asset.

Music IDs belong in `src/shared/Audio/MusicConfig.luau`; sound-effect IDs and per-cue mix values belong
in `src/shared/Audio/SoundEffectsConfig.luau`. Identifiers describe their BLIKK purpose rather than
referencing another game or soundtrack. Current music contexts are Splash, Character Selection,
Operations Hub, Movement Lab, Competitive Match, and Results.

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

## Competitive sound-effect ownership

`SoundEffectsController` is the reusable non-authoritative presentation owner for combat and UI
sounds. It creates one reusable listener-local `Sound` per enabled configured cue under
`SoundService/BLIKKSoundEffects`. Combat cues route through `BLIKK_SoundEffects`; semantic menu cues
route through the independently adjustable `BLIKK_UI` group. A cue is playable only after its bounded
preload status is `Success`. Invalid, disabled, or failed assets remain silent, and a runtime playback
failure disables that cue for the client session.

The accepted local B-8 fire event plays its report immediately. Remote reports use one positional
`Sound` in each existing bounded shot-effect pool group and play only after the replicated payload and
shooter generation pass validation. The local shooter's replicated payload never replays the report.
An equipped, ready, empty B-8 produces the rate-limited dry-fire semantic event only while gameplay
camera ownership is active.

An accepted Katana slash schedules its air cut for the existing anticipation/active-window boundary.
The pending cue is generation-gated and cancelled by block, unequip, holster, interruption, weapon
switch, dash, or teardown before that boundary. The two existing slash variants use only a narrow
configured pitch difference. `MeleeHitConfirm` is requested only from a validated shooter-private
melee result with positive server-applied damage. Local presentation, overlap, input, and trails
cannot produce a fake hit cue.

Server-confirmed Katana contact additionally drives `KatanaImpact` at the accepted world position.
Wall and guard contacts play for every recipient; fighter contact plays for remote observers while
the local attacker keeps the private `MeleeHitConfirm` without a doubled recording. The cue uses an
8-to-90-stud positional rolloff and cannot be triggered by the animated blade or a client-authored hit.

`CombatFeedbackController` requests `FirearmHitConfirm` once per accepted shot only when the validated
server result reports positive total applied damage. It requests `ReloadInitiated` only from the
shooter-private authoritative reload-accepted response. Neither sound participates in authority.
Successful weapon-slot commits, rather than requested switches, drive `WeaponSwitch`.

Every replicated player character receives one generation-scoped `Humanoid.Died` observer. A death in
the `MovementLab` context or any server match identity creates one short positional `PlayerDeath`
sound on the accepted character root, with a 10-to-100-stud rolloff and bounded cleanup. Frontend
previews, stale characters, non-player humanoids, and teardown cannot emit the cue.

An eliminated practice dummy uses the same catalog recording through the separately calibrated
`PracticeDummyDeath` semantic key. Its shooter-private validated result creates one transient at the
confirmed impact position with volume `1.45`, an 18-stud full-level radius, and a 130-stud maximum
rolloff distance. This keeps the solo-training death cue prominent without raising every player death.

`UINavigationController` emits semantic navigation, activation, confirmation, back, denied, and
slider-step events to the same owner. Arrow keys and W/A/S/D use the same explicit focus graph, and
an externally changed valid selection also emits one de-duplicated navigation event. Automatic initial
selection is silent. Hover navigation emits only when focus changes; disabled, hidden, and inactive controls are silent. A registered control may
select `Activate`, `Confirm`, `Back`, `Denied`, or `Silent`; sliders use the dedicated throttled role.
The shared layer de-duplicates keyboard/controller activation from Roblox `Activated` delivery. Room
create/join confirmation is deferred until a successful transport result; genuine rejection emits the
denied role, while an in-progress request remains silent.

### Sound-effect asset manifest

Roblox Creator Store metadata for the configured IDs was checked on August 10, 2026. Newly selected
entries were listed as Audio / Sound Effect assets and exposed Roblox's `Get Audio` action. They are
enabled for the target-place Studio audition; the preload controller keeps any entry silent if Roblox
does not grant the experience access or the asset cannot load. Creator Store availability does not
grant permission to redistribute an asset outside Roblox or outside the terms attached to that entry.

| Semantic key | BLIKK purpose | Creator/owner | Roblox asset ID | Permission state | Audition state | Runtime enabled |
| --- | --- | --- | --- | --- | --- | --- |
| `B8Shot` | Accepted local report and validated positional remote report | `ToxicBanditT`, asset name `Shotgun Sound Effect` | `rbxassetid://8287951336` | Creator Store / Get Audio; target-place preload pending | Catalog-selected; Studio combat-mix pass required | Yes |
| `B8DryFire` | Equipped, ready, empty trigger click | `TheNikolas24`, asset name `Dry Fire Gun-Sound` | `rbxassetid://484110242` | Creator Store / Get Audio; target-place preload pending | Catalog-selected; Studio combat-mix pass required | Yes |
| `KatanaSlash` | Active-window blade-air cut | `GleonoffG`, asset name `Katana Slash Wind 2` | `rbxassetid://140180249061198` | Creator Store / Get Audio; target-place preload pending | Catalog-selected; slash-timing pass required | Yes |
| `FirearmHitConfirm` | Shooter-private positive authoritative firearm damage tick | `NeoDoesStuff`, asset name `hitmarker_2` | `rbxassetid://125235091454234` | Creator Store / Get Audio; target-place preload pending | Catalog-selected replacement; authoritative damage and mix pass required | Yes |
| `MeleeHitConfirm` | Shooter-private positive authoritative melee damage | `ProSoundEffects`, asset name `Sword Hit 4 (SFX)` | `rbxassetid://9119746751` | Roblox licensed catalog entry; target-place preload pending | Catalog-selected; authoritative damage and mix pass required | Yes |
| `KatanaImpact` | Positional validated wall, guard, and remote fighter contact | `ProSoundEffects`, asset name `Sword Hit 4 (SFX)` | `rbxassetid://9119746751` | Roblox licensed catalog entry; target-place preload pending | Reused at lower pitch/level; spatial contact pass required | Yes |
| `ReloadInitiated` | Shooter-private authoritative reload acceptance | `WackyWafflerz` (`581230884`), asset name `Gun Reload` | `rbxassetid://8145744063` | Baseline-approved in target experience | Identity approved; level re-audition required | Yes |
| `WeaponSwitch` | Successful local slot commit | `Spellwright`, asset name `Weapon equip` | `rbxassetid://5508953366` | Creator Store / Get Audio; target-place preload pending | Catalog-selected; Studio mix pass required | Yes |
| `PlayerDeath` | Positional player-character death cry | `ProSoundEffects`, asset name `Male Scream Short Yelling Bursts Death Cries (SFX)` | `rbxassetid://9125653559` | Roblox licensed catalog entry / Get Audio; target-place preload pending | Catalog-selected; spatial mix and rapid-respawn pass required | Yes |
| `PracticeDummyDeath` | Prominent positional practice-dummy death cry | `ProSoundEffects`, asset name `Male Scream Short Yelling Bursts Death Cries (SFX)` | `rbxassetid://9125653559` | Roblox licensed catalog entry / Get Audio; target-place preload pending | Dedicated 18-to-130-stud solo-training mix; Studio distance pass required | Yes |
| `UINavigate` | Explicit valid focus move | `Roblox`, asset name `Roblox_UI_Small_Click` | `rbxassetid://15675032796` | Official Roblox Creator Store entry; target-place preload pending | Catalog-selected; reused with restrained pitch/level treatment | Yes |
| `UIActivate` | Valid default control activation | `Roblox`, asset name `Roblox_UI_Bright_Click` | `rbxassetid://15675059323` | Official Roblox Creator Store entry; target-place preload pending | Catalog-selected; Studio UI pass required | Yes |
| `UIConfirm` | Committed character, room, or settings choice | `mike1122434exe`, asset name `ui_menu_button_confirm_16` | `rbxassetid://85240253037283` | Creator Store / Get Audio; target-place preload pending | Catalog-selected; Studio UI pass required | Yes |
| `UIBack` | Successful back/cancel action | `Roblox`, asset name `Roblox_UI_Small_Click` | `rbxassetid://15675032796` | Official Roblox Creator Store entry; target-place preload pending | Lower-pitched reuse; Studio UI pass required | Yes |
| `UIDenied` | Genuinely rejected action | `AmbientSorcery`, asset name `ui-simple-negative-error` | `rbxassetid://87519554692663` | Creator Store / Get Audio; target-place preload pending | Catalog-selected; Studio UI pass required | Yes |
| `UISliderStep` | Discrete settings value change | `Roblox`, asset name `Roblox_UI_Small_Click` | `rbxassetid://15675032796` | Official Roblox Creator Store entry; target-place preload pending | Higher-pitched throttled reuse; Studio UI pass required | Yes |
| `FightStart` | Voiced FIGHT reveal transient | `XxxgexxX`, asset name `melty_blood_announcer_fight` | `rbxassetid://120370970484379` | Creator Store / Get Audio; target-place preload pending | Catalog-selected; exact-word, timing, and mix pass required | Yes |
| `Dash` | Existing dash movement report; identity unchanged | `ProSoundEffects` (`7462895450`), asset name `Swoosh Pack High End Multiple Variations 17 (SFX)` | `rbxassetid://9119738974` | Baseline-approved in target experience | Retained; mix audit required | Yes |

Disabled rows are still registered with the preload controller as configuration-disabled, so no asset
request or playback occurs. Enabled Creator Store candidates remain fail-silent until preload succeeds.
The final acceptance gate is a target-place Studio pass covering availability, timing, loudness, and
rapid-retrigger behavior; any failed candidate must be disabled or replaced before release.

## Account-persistent sound settings

The Sound tab's `MasterVolume`, `MusicVolume`, `SoundEffectsVolume`, `UISoundVolume`, and `MusicMuted`
preferences are persisted per Roblox account through the existing versioned account settings path.
The server validates each narrow `SetPreference` mutation, marks the account session dirty, and uses
the existing debounced, autosave, `PlayerRemoving`, and shutdown save behavior. On join, schema
normalization supplies the current defaults for missing or invalid legacy values, and the confirmed
account snapshot is applied to `SessionSettings`.

`AudioController` keeps all BLIKK-owned sound groups silent until that first confirmed preference
snapshot has been applied. It then owns the user-volume layer: `BLIKK_Music` uses
`MasterVolume * MusicVolume * 10^(-8/20)` (or zero while `MusicMuted` is true), while
`BLIKK_SoundEffects` uses `MasterVolume * SoundEffectsVolume * 10^(-2/20)`. `BLIKK_UI` uses
`MasterVolume * SoundEffectsVolume * UISoundVolume * 10^(-1/20)`, so the main effects slider still
acts as the global effects mute while menu feedback has its own relative trim. Menu music and every
enabled Duel playlist track route through `BLIKK_Music`; combat and movement effects remain on their
existing BLIKK effects groups.

Every user-facing audio slider defaults to `1.0`, is capped at `1.0` (`100%`), and changes in `0.05`
steps. Values persisted during the temporary `0`-to-`2.0` effects range are recognized as legacy
values, clamped to `1.0`, and saved through the normal migration path without being reported as corrupt
preferences; valid values at or below `1.0` persist unchanged. Music mute behavior is unchanged.

The fixed category offsets make `100%` the calibrated BLIKK reference mix rather than an overdrive
multiplier: music has `-8 dB` headroom, combat/movement effects have `-2 dB`, and semantic UI feedback
has `-1 dB`. Per-cue values retain the approved identity and relative hierarchy, keeping reload,
firearm reports, hit confirmation, death, and FIGHT above the music bed without forcing every source
asset to the same loudness. These offsets are amplitude multipliers, not claims about an individual
asset's measured LUFS.

Runtime acceptance targets the ITU-T H.872 safe-listening recommendation for video gameplay: a
representative 30-minute output window no higher than `-23 LUFS`, with `±2 LU` tolerance. That target
applies to the combined gameplay output, not each isolated asset. Final compliance therefore requires
an external loudness-meter capture of representative play plus peak, intelligibility, near/far,
headphone, speaker, and rapid-overlap auditions; Roblox volume properties alone cannot prove it.

`MusicController` separately owns track choice, context, playback, shuffle, and per-track transition
fades. Applying a volume or mute preference changes only the sound-group volume, so it does not
recreate a Sound, seek or restart playback, advance a playlist, or rebuild a shuffle bag. Current
track, playback position, Duel shuffle order, previous track, context, and fade state remain local to
the experience session and are never persisted. No non-audio preference is changed by this contract.
