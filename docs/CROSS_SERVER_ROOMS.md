# Cross-Server Rooms

Public servers act as browser hubs. Live creation reserves a room server that owns lobby, match, post-match, and subsequent room state.

MemoryStore structures:

- BLIKK_PublicRoomsV1: sorted listings, 90-second TTL.
- BLIKK_RoomSecretsV1: access data, 120-second refreshed TTL.
- BLIKK_PrivateRoomLookupV1: server lookup, 120-second TTL.
- BLIKK_JoinCodesV1: code lookup, 120-second TTL.
- BLIKK_RoomJoinNoncesV1: one-use authorization, 60-second TTL.

Room servers heartbeat every 25 seconds; listings older than 60 seconds are ignored. Pages contain 25 entries and results are capped at 100. BLIKK_RoomDirectoryV1 messages are invalidation hints only; MemoryStore remains authoritative. Calls are protected and retry at most three times.

Clients supply only public RoomIds. Reserved access codes are applied server-side and never enter TeleportData or client snapshots. Destinations revalidate protocol, nonce, UserId, RoomId, expiry, PrivateServerId, capacity, and state, then consume the nonce. Teleports attempt at most three times.

Directory records expose both current phase and a derived joinable flag. Lobby and countdown
rooms are joinable; active and round-intermission rooms follow the mode's join-in-progress
policy; post-match and closing rooms are not advertised as joinable. Source servers reject a
stale non-joinable listing, and the destination remains authoritative for final admission.

Studio uses local-room fallback. MemoryStore and reserved servers require published-client testing.
