# Cross-Server Rooms

Public servers act as browser hubs. Live creation reserves a room server that owns lobby, match, post-match, and subsequent room state.

MemoryStore structures:

- BLIKK_PublicRoomsV1: sorted listings, 90-second TTL.
- BLIKK_RoomSecretsV1: access data, 120-second refreshed TTL.
- BLIKK_PrivateRoomLookupV1: server lookup, 120-second TTL.
- BLIKK_JoinCodesV1: code lookup, 120-second TTL.
- BLIKK_RoomJoinNoncesV1: one-use authorization, 120-second TTL. This covers the bounded
  pre-commit plus indeterminate committed-call window; atomic consumption still prevents replay.

Room servers heartbeat every 25 seconds; listings older than 60 seconds are ignored. Pages contain 25 entries and results are capped at 100. The server emits `BLIKK_RoomDirectoryV1` invalidation messages, but the current subscriber is intentionally a no-op and MemoryStore polling remains the only functional directory reader. Calls are protected and retry at most three times.

Clients supply only public RoomIds. Reserved access codes are applied server-side and never enter
TeleportData or client snapshots. Destinations revalidate protocol, nonce, UserId, RoomId, expiry,
PrivateServerId, capacity, and state. The nonce is atomically changed to a unique consumed tombstone
with `MemoryStoreHashMap:UpdateAsync`; only the caller whose consumption ID is returned may proceed.
Teleports attempt at most three times.

Each source server owns at most one active transport attempt per player. The attempt has a generated
ID in `TeleportData`; `TeleportInitFailed` is accepted only when the returned `TeleportOptions`
contains that exact ID. One 60-second pre-commit deadline starts before text filtering, reservation,
directory writes, nonce creation, or teleport initiation. Guarded retries and every post-yield
continuation must still own the same live attempt. Synchronous failure, correlated asynchronous
failure, pre-commit deadline expiry, and pre-init `PlayerRemoving` all cancel through that owner and
clean any known nonce/secret/private/code records. Once `TeleportAsync` is yielding or has reported
initiation, Roblox exposes no rollback operation: the attempt remains exclusively committed, Back
and retry stay blocked, and `PlayerRemoving` is treated as successful departure. If neither departure
nor `TeleportInitFailed` resolves that indeterminate call, a further 30-second terminal bound removes
the source player with a reconnect message and clears source-local ownership rather than permitting
a competing transport. Because a committed platform call cannot be rolled back safely, its nonce and
room credentials are left to their short TTL unless a synchronous or correlated failure proves that
cleanup is safe.

The destination retains its authoritative room secret in server memory and refreshes the listing,
secret, private-server lookup, and private join-code lookup on each heartbeat. This allows credential
TTL recovery after a transient MemoryStore outage instead of extending a public listing whose
credentials have expired. Private listings remain excluded from public browser results.

Directory records expose both current phase and one fighter-oriented derived joinable flag. Lobby
rooms are joinable. Loading, countdown, active, and round-intermission rooms require the room's
join-in-progress policy; post-match and closing rooms are not advertised as joinable. The
destination still accepts authorized spectators in phases allowed by `RoomService`, but the current
single public `Joinable` flag does not advertise a separate cross-server spectator route. Source
servers reject a stale non-joinable listing, and the destination remains authoritative for final
admission.

Studio uses local-room fallback. MemoryStore and reserved servers require published-client testing.

Directory create and join responses use an explicit transport discriminator:

- `LocalRoom` means the server has already joined the player to a real RoomService session in the
  current Studio server and includes only sanitized room/match snapshots.
- `ReservedServerTeleport` means a production server authorized and initiated a server-owned
  reserved teleport. Only this result may display a teleporting client state.
- `Failure` includes a bounded retryable code and never exposes an access code.

The public source server uses a temporary RoomService record only to validate and reserve a new
room. That record is hidden from `RoomUpdated`, local listings, directory publication, room
mutation, and production `Create`/`JoinLocal` bypasses. Its reservation generation is revalidated
after text filtering and every yielding platform operation; player presence and the transport owner
are part of that check. The source stores the secret and lookups, but deliberately
does not publish a listing. Only the founder can bypass that missing listing for the first
teleport; the destination publishes the room after admitting the founder. This prevents another
joiner from occupying the destination while a source-side founder failure is still able to cancel
the reservation.

After teleport initiation succeeds, the temporary source membership is detached. A successful
`PlayerRemoving` clears only source-local metadata. Synchronous failure, correlated
`TeleportInitFailed`, pre-commit expiry, or a synchronous committed-call failure removes the secret
and lookups. An indeterminate terminal committed call leaves credentials to TTL instead of risking
deletion of a live destination. Because the source
never queues a listing update for the temporary room, those cleanup calls cannot race a stale
source publication that resurrects the room.

When the final destination-room member leaves, the room stops heartbeating and removes its public
listing, room secret, private-server lookup, and private join-code lookup before publishing a
RoomClosed invalidation hint. Local Studio closure removes the RoomService session immediately, so
subsequent local directory reads cannot return a ghost row.

RoomService coalesces destination directory changes through one ordered mutation worker per room.
Close follows any in-flight destination update, and the destination revalidates ownership after
yielded MemoryStore calls; an update that loses ownership removes its partial writes. Temporary
source reservations do not enter this publication queue. Published reserved-server behavior
remains a manual acceptance gate because ordinary Studio play cannot prove TeleportService or
MemoryStore ordering.

Reserved access codes can create more than one runtime with the same `PrivateServerId` when console
cross-play is disabled. The secret therefore records the founder server's
`DataModel.MatchmakingType`; sources reject a different partition before teleport and destinations
reject it before membership. Public records carry the same partition and browser queries omit rows
from other partitions, so an incompatible room is not advertised as joinable. Published tests must
cover the intended Default, Xbox-only, and
PlayStation-only hosting policy before those platforms are declared supported.
