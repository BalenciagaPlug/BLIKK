# Multiplayer and Chat Prototype

## Lobby Browser

The Multiplayer Browser is a local frontend shell, not cross-server discovery. It presents pinned, popular, and recent prototype entries using a data-driven lobby catalogue. Join, refresh, and create actions clearly disclose their local status. Future production work may add MemoryStoreService listings, MessagingService updates, reserved servers, teleport routing, matchmaking, and filters.

The Create Lobby panel validates lobby name, map, mode, capacity, and password requirements. District Zero Training is the only playable selection. Duel, Team Deathmatch, Free For All, team balance, spectators, friendly fire, time limits, and score limits are labelled as future where unavailable.

## Chat Safety

BLIKK Chat is a custom presentation layer over Roblox `TextChatService`. It never sends unfiltered RemoteEvent messages and never bypasses Roblox filtering, privacy, parental controls, blocking, or moderation. The default Roblox chat window and input bar are hidden to prevent duplicate visual layers while `TextChatService` remains the messaging authority.

Movement Lab exposes ALL and SYSTEM presentation contexts. The lobby browser exposes LOBBY and SYSTEM presentation contexts. LOBBY currently uses the filtered general channel because no real lobby transport exists. Future TEAM, CLAN, and WHISPER contexts remain unavailable until supported by real game state.

Chat visibility, opacity, scale, and timestamps are session settings. Gameplay chat defaults to a compact upper-right tab. Enter expands and focuses it; the next Enter sends non-empty text through the Roblox text channel and collapses the panel, while an empty submission simply collapses it. Focusing chat suppresses semantic gameplay input. Chat does not bind Escape, preserving Roblox's menu behavior.
