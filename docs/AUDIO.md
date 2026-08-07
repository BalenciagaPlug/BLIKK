# BLIKK Audio Assets

BLIKK runtime audio must be original, commissioned for BLIKK, obtained from the Roblox Creator Store under an appropriate licence, or otherwise licensed for this project. Local reference music is creative reference material only and must never be imported, uploaded, converted, renamed, embedded, or referenced as a runtime asset.

Future Roblox audio IDs belong in `src/shared/Audio/MusicConfig.luau`. Track identifiers describe their BLIKK purpose rather than referencing another game or soundtrack. Current semantic contexts are Splash, Character Selection, Operations Hub, Movement Lab, Competitive Match, and Results.

## Persistent frontend soundtrack

`MusicController` owns one `BLIKKFrontendSoundtrack` under `SoundService` for the lifetime of the
client session. It uses `rbxassetid://78521539571251`, loops at normal playback speed, and routes
through the existing `BLIKK_Music` sound group. Profiles, character creation, Operations Hub,
Multiplayer, and Clans share the same playback timeline. Navigation among those routes does not
recreate, replay, or seek the Sound.

Entering Movement Lab or match gameplay fades the soundtrack out and pauses it. Returning to the
frontend resumes the same session `TimePosition` and fades back in. Initial loading and Splash do
not start the soundtrack. `AudioController` remains the sole volume owner: the music sound group
reacts immediately to saved `MasterVolume`, `MusicVolume`, and `MusicMuted` session settings.
Graphics and reduced-effects settings do not affect audio.

The configured asset-readiness observation is bounded and diagnostic only. A delayed or unavailable
track never blocks frontend bootstrap, navigation, loading, or gameplay.

Each supplied track must have an ownership record containing its creator, source, licence or contract, permitted uses, Roblox asset ID, and acquisition date. Keep those records with project production documentation before enabling the asset in configuration.
