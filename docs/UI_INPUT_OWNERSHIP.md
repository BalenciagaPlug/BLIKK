# UI Input Ownership

BLIKK client input uses one strict ownership order:

1. A focused `TextBox`
2. The topmost active BLIKK menu or modal
3. Active BLIKK Chat
4. Gameplay
5. Presentation-only systems

`InputManager` remains the physical-input to semantic-action boundary. The
client `UINavigationController` owns fixed UI navigation, active UI scopes,
and `GuiService.SelectedObject`. It reports menu ownership to `InputManager`
so gameplay, Chat, and lower-priority interface actions cannot respond to the
same key press.

## Fixed UI controls

Arrow keys, Return/Enter, keypad Enter, and Backspace are fixed interface
controls while a BLIKK UI scope is active. They are not account bindings and
must not be added to binding defaults or persistence.

- Arrows move through the active scope. Left and Right adjust registered
  sliders and discrete selectors through their existing range or option data.
- Return calls the same registered callback used by `GuiButton.Activated`.
- Backspace calls the top scope's existing close, back, cancel, or safe leave
  callback.
- A focused `TextBox` receives these keys normally and prevents menu, Chat,
  and gameplay handling.

Action controls and inactive tabs use a subtle BLIKK olive-green focus fill.
Mouse hover or press may move that temporary focus, and keyboard input resumes
from the focused object. An active tab keeps its solid domain-owned treatment;
when focus is on that same tab, the translucent fill is suppressed rather than
layered over it.

Selection-list items may opt into `ChooseOnFocus`. Mouse press and keyboard
focus then use one domain-selection callback, while hover alone does not commit
the choice. These rows suppress the global focus fill and render one native
dark-green selected background instead. Stable selection identities restore the
same item after a dynamic rebuild when it still exists; otherwise the owning
screen chooses a valid fallback. Selection graphs are rebuilt only when a scope
opens, visibility changes, or a dynamic list changes. There is no per-frame UI
scan.

## Scope lifecycle

Frontend routes, Settings, nested Settings confirmations, Multiplayer,
Clans, the scoreboard report targets, and spectator controls own explicit
scopes. Opening a nested modal pushes it above its origin. Closing or
destroying a scope removes it and restores the last valid selection in the
scope below. Returning to gameplay clears frontend selection.

Multiplayer Backspace uses the existing server-confirmed room leave callback;
it never clears membership locally. Reporting retains its existing bounded
double-confirm callbacks. The current replay surface is only a list-count
request button, not a replay inspector, so no unimplemented replay controls
are implied by this contract.

## Chat interaction

Chat may open only when no BLIKK menu owns input and no other `TextBox` is
focused. Opening a menu closes active Chat and releases its field. Chat keeps
its existing filtered-send behavior, empty Return close, and empty Backspace
close. A Return that commits a Settings numeric field therefore commits once,
keeps Settings open, and cannot open Chat.

While the pointer is over the retained Chat message frame, that frame owns
mouse-wheel input. It scrolls the bounded Chat history and blocks only semantic
mouse-wheel dispatch, so the same pulse cannot also switch a gameplay weapon.
Leaving or hiding Chat releases that narrow owner without flushing unrelated
held gameplay input.

## Loading-screen transition ownership

The active loading screen is not a passive presentation-only system. It owns a
topmost `UINavigationController` scope named `LoadingScreen` and adds the named
owner `LoadingScreen` to both `InputManager` and `GameplayCamera` through
`SetGameplayBlocked(owner, blocked)`. The visual may cover initial boot, match
entry, round transition, join in progress, respawn, or Movement Lab entry, but
it does not replace the normal input, camera, or navigation owners.

Named blockers preserve the requested gameplay state independently from the
effective state. Loading therefore removes only its own blocker when it ends.
Another active owner, such as spectator control, continues to block gameplay,
and a frontend route that requested gameplay inactive remains inactive. The
loading navigation scope is likewise pushed above existing scopes rather than
destroying them. When it is removed, the next active scope restores its last
valid selection using the normal scope rules. A focused `TextBox` retains the
higher priority defined at the start of this document.

Loading acquires ownership in this order:

1. Add the `LoadingScreen` input blocker.
2. Add the `LoadingScreen` camera blocker.
3. Activate the `LoadingScreen` navigation scope.

Normal cancellation, an authoritative reported failure, and non-FIGHT
dismissal retain that ownership through the bounded fade. Final cleanup
deactivates the navigation scope first, then removes the camera blocker, then
removes the input blocker. A local match dependency or world-readiness timeout
retains loading ownership until the server publishes `Failed`, `TimedOut`, or
`Cancelled`; its 15/20-second preparation budget is the controlling bound.
Spectator snapshot adoption runs before loading dismissal, so an unreleased or
waiting player never passes through an unowned gameplay frame. Movement Lab
failure instead returns through the bounded frontend recovery path.

At an armed FIGHT transition, the client watches synchronized server time and
presents FIGHT on the closest practical `RenderStepped` frame at or after the
server-supplied release timestamp. It removes the same three loading owners on
that frame. This reveals and enables only the state permitted by all remaining
owners; it does not force gameplay active. A newer transition identity cancels
the prior delayed wake-up, render connection, owned tweens, and sound. A newer
FIGHT-arm token for the current identity cancels the prior wake-up and render
watch. Stale callbacks cannot release ownership, and repeated `Begin` or
identical arm messages for the same transition remain idempotent.

Destroying the controller also removes its named blockers and navigation
scope. Loading cleanup must never clear another owner's blocker, close an
underlying scope, or blindly restore a captured global enabled flag.

## High-APM input-state recovery

Physical inputs are tracked by dispatch identity as well as semantic action.
This keeps simultaneous bindings independent: when two physical tokens map to
one action, releasing either token removes only that dispatch, and
`ActionEnded` fires only after the action's last held token ends. Every accepted
dispatch receives a monotonic local sequence. Forced cleanup processes held
dispatches in that stable begin order rather than relying on table iteration.

The following ownership changes clear buffered actions so input accepted in an
earlier context cannot execute in a later one:

- gameplay becoming effectively disabled, including the first named blocker;
- binding capture opening;
- a `TextBox` gaining focus;
- a menu scope acquiring input; and
- the Roblox client window losing focus.

Gameplay disable, binding capture, text focus, menu ownership, and window-focus
loss also flush held dispatches. This synthesizes the matching raw and semantic
end events and prevents movement, free-look, or combat state from remaining
logically held when Roblox cannot deliver the physical release. Menu ownership
then suppresses new gameplay dispatch until its scope releases input. Movement
also cancels any dash, wall approach/run/recovery, or return-dash state owned by
the local movement engine; a blocked heartbeat cannot apply another wall or
dash velocity step.

Mouse-wheel input uses a separate monotonic pulse generation for every wheel
change. Rapid overlapping pulses therefore cannot overwrite one shared token.
Each pulse ends independently after
`InputConfig.MouseWheelPulseDurationSeconds`, while forced cleanup removes its
pending generation and emits its end event at most once.

`ActionBuffer` accepts entries only within `ActionBufferDurationSeconds` and is
capacity-bounded by `ActionBufferMaximumEntries` (currently 64). A push first
removes expired entries using the same supplied timestamp, appends the new
valid semantic action, and evicts the oldest entries if the cap is exceeded.
Consumption still searches newest-first and rejects entries outside the
caller's age window. This bounds memory during sustained high APM without
replacing action-specific gameplay validation or server-owned cooldowns.

## Presentation and server-authority boundary

Loading artwork, loading animation, optional FIGHT sound, and the finite
presentation preload manifest are cosmetic client concerns. Their completion
event is diagnostic only. It must not send `MatchReady`, authorize a spawn,
select a release timestamp, advance a round, or remove a server gameplay gate.
An unavailable image degrades to black, and an unavailable optional sound
remains silent; neither failure can authorize or indefinitely block a match.

The match preparation coordinator may report generation-scoped client
readiness only after its required character and controller checks complete.
The server validates that acknowledgement against current membership and match
generation, decides whether the readiness barrier has been satisfied, and
supplies the authoritative future release timestamp. The loading controller
may schedule presentation against that timestamp, but presentation readiness
never gives the client permission to release itself or another participant.

## Manual regression checks

Run these checks in Roblox Studio after any change to input, navigation,
loading, camera, match preparation, or FIGHT presentation:

1. Complete initial boot through Character Profiles and Operations Hub. Confirm
   one loading GUI, no world flash, no bootstrap error, and normal mouse,
   keyboard, Chat, and Settings behavior after the initial fade.
2. Open a frontend scope, select a non-default control, begin and cancel a
   loading transition, and confirm that the same valid control is restored.
   Repeat with a focused Settings field and confirm no gameplay action leaks.
3. Hold a movement or combat input before loading begins. Confirm loading
   flushes it, gameplay and camera remain inactive while covered, and returning
   to gameplay does not leave the action or mouse lock stuck.
4. Activate another named blocker, then begin and end loading. Confirm removing
   `LoadingScreen` does not remove the other blocker or activate gameplay.
5. Arm FIGHT on two to four clients. Confirm nobody can move, attack, aim, or
   become combat-effective early, and confirm FIGHT and loading ownership end
   on the server-timestamp frame without requiring an extra click.
6. Supersede an armed transition, cancel during its fade, and exercise the
   bounded failure path. Confirm old timers never reveal gameplay, no duplicate
   FIGHT occurs, and the player is not left black-screened or input-locked.
7. Bind two physical tokens to one semantic action. Hold both, release one, and
   confirm the action remains held until the last token releases, with one final
   semantic end transition.
8. Generate rapid overlapping wheel input. Confirm every accepted pulse ends,
   later pulses are not erased by earlier delayed callbacks, and no pulse stays
   active after window-focus loss or a gameplay blocker.
9. While holding several inputs, focus a `TextBox`, enter binding capture, and
   separately move focus away from the Studio client window. Confirm held ends
   occur in begin order, the action buffer clears, and returning focus creates
   no synthetic action begins.
10. Sustain rapid alternating actions beyond 64 buffered entries. Confirm the
    buffer remains capped, expired inputs are not consumed, and the newest
    legitimate actions remain available within their configured window.
11. Repeat loading and FIGHT across multiple rounds, respawns, cancellation,
    and join-in-progress. Confirm there is still one loading GUI, one navigation
    scope, no duplicate input callbacks, and no connection or memory growth.
12. Fail the loading artwork and leave the FIGHT sound field empty. Confirm the
    black fallback and silent FIGHT presentation work, while the server remains
    the only authority that releases the match.
