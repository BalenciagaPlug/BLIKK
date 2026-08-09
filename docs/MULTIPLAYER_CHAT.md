# Multiplayer and Chat Prototype

## Lobby Browser

The Multiplayer Browser queries the server-owned room directory. Published servers use expiring MemoryStore listings and reserved room servers; Studio uses a local-room fallback for multi-client lifecycle testing. Clients select only public RoomIds or server-generated join codes and never receive reserved access codes.

The Create Room panel exposes only the implemented District Zero whitelist and Training, Deathmatch, Team Deathmatch Extreme, and Elimination registries. Room names are filtered server-side. Configuration, capacity, ready state, teams, leadership, and teleport authorization remain server-owned. Ranked matchmaking, Duel queue, and Clan War are not implemented.

## Chat Safety

BLIKK Chat is a custom presentation layer over Roblox `TextChatService`. It never sends unfiltered RemoteEvent messages and never bypasses Roblox filtering, privacy, parental controls, blocking, or moderation. The default Roblox chat window and input bar are hidden to prevent duplicate visual layers while `TextChatService` remains the messaging authority.

Movement Lab exposes ALL and SYSTEM presentation contexts. A joined room uses one server-created `TextChannel` whose membership is limited to that room. The channel persists across the room lobby and its active match, and its `TextSource` membership is destroyed when a player leaves. The lobby browser and Movement Lab continue to use the filtered general channel because they have no joined-room transport. The client accepts only the active session channel, clears presentation history when that session changes, and therefore does not carry conversation into another room or a later session. Future TEAM, CLAN, and WHISPER contexts remain unavailable until supported by real game state.

Chat visibility, opacity, scale, and timestamps are session settings. Gameplay chat defaults to a compact upper-right recent-message feed rather than a title-only tab. The same scrolling frame retains at most 80 chronological messages in compact and expanded views. Mouse-wheel input over that frame scrolls its history and is withheld from gameplay weapon switching; wheel input elsewhere does not move Chat. New messages follow the bottom only while the reader is already there, so reading older messages is not interrupted. Enter expands and focuses Chat; the next Enter sends non-empty text through the active Roblox text channel and returns to the compact feed, while an empty submission simply returns to the feed. Focusing chat suppresses semantic gameplay input. Chat does not bind Escape, preserving Roblox's menu behavior.

The shared ownership contract is defined in `docs/UI_INPUT_OWNERSHIP.md`.
Focused text entry owns Return and Backspace first, and an active BLIKK menu
suppresses Chat so confirmation input cannot open Chat behind a modal.
