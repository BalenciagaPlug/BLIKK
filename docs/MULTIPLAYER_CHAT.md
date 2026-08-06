# Multiplayer and Chat Prototype

## Lobby Browser

The Multiplayer Browser queries the server-owned room directory. Published servers use expiring MemoryStore listings and reserved room servers; Studio uses a local-room fallback for multi-client lifecycle testing. Clients select only public RoomIds or server-generated join codes and never receive reserved access codes.

The Create Room panel exposes only the implemented District Zero whitelist and Training, Deathmatch, Team Deathmatch Extreme, and Elimination registries. Room names are filtered server-side. Configuration, capacity, ready state, teams, leadership, and teleport authorization remain server-owned. Ranked matchmaking, Duel queue, and Clan War are not implemented.

## Chat Safety

BLIKK Chat is a custom presentation layer over Roblox `TextChatService`. It never sends unfiltered RemoteEvent messages and never bypasses Roblox filtering, privacy, parental controls, blocking, or moderation. The default Roblox chat window and input bar are hidden to prevent duplicate visual layers while `TextChatService` remains the messaging authority.

Movement Lab exposes ALL and SYSTEM presentation contexts. The lobby browser exposes LOBBY and SYSTEM presentation contexts. LOBBY currently uses the filtered general channel because no real lobby transport exists. Future TEAM, CLAN, and WHISPER contexts remain unavailable until supported by real game state.

Chat visibility, opacity, scale, and timestamps are session settings. Gameplay chat defaults to a compact upper-right tab. Enter expands and focuses it; the next Enter sends non-empty text through the Roblox text channel and collapses the panel, while an empty submission simply collapses it. Focusing chat suppresses semantic gameplay input. Chat does not bind Escape, preserving Roblox's menu behavior.
