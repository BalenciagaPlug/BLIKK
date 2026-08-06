# Character Profile Persistence

## Ownership

The server owns one versioned character-profile account per Roblox `UserId`. Clients send bounded
create, update, delete, select, or snapshot-request intent and render only server-confirmed snapshots.
`DataStoreService` is used exclusively by `CharacterProfileService` on the server.

The durable store remains `BLIKKCharacterProfilesV1`; keys use `Player_<UserId>`. Schema version 2
stores up to five fighters, a selected fighter ID, server timestamps, semantic input bindings, and
the camera, sound, UI, chat, and effects preferences exposed by the settings interface. Profile IDs
are server-generated GUID strings. Appearance values remain the named definitions already exposed
by `ProfileConfig`.

Schema-1 records migrate in place during load. The migration preserves fighter records, generated
IDs, selection, levels, appearance, and timestamps while adding validated default bindings and
preferences. Unsupported future schemas are rejected and never overwritten. Binding tokens and
preference values are allowlisted and bounded on the server; protected interface actions retain at
least one access path.

Normalization returns bounded category diagnostics to the server load path. Expected schema-1
migration and default Settings insertion mark the account dirty without producing a malformed-data
warning. Removed character records, duplicate IDs or names, invalid selection, invalid bindings, and
invalid preferences are reported only as category counts; profile contents and setting values are
never written to Output. Fundamentally malformed records and unsupported future schemas remain
unavailable and cannot be replaced by defaults.

Missing supported preferences are forward-compatible additions: their defaults are inserted, the
account is marked dirty, and the normal load remains silent. Invalid stored values and unknown keys
are counted separately and may produce one bounded warning. Canonical numeric defaults are preserved
exactly even when a UI slider's step grid would otherwise reconstruct a slightly different value.

Bindings use the existing primitive string tokens (`KeyCode.<Name>`, supported mouse buttons, and
mouse-wheel directions), with at most primary and secondary slots for each action shown by the
controls UI. Individual and all-binding resets derive from `ActionCatalogue`. Preferences store only
the values already exposed by the camera, sound, and extras pages; shared configuration owns their
types, defaults, numeric ranges, and enum allowlists. Camera reset is one bounded account mutation.

Binding and preference changes use narrow operations on the existing profile request endpoint. The
server returns the confirmed account snapshot, and the client applies it to the existing binding,
camera, and session-setting owners without respawning or rebuilding input connections. Slider motion
previews locally and submits once on release (or once after numeric entry), while persistence still
uses the account save debounce.

Profile transport discovery is independent from account readiness. The client checks the centralized
remote folder immediately, observes it for a bounded eight-second window when necessary, and retries
discovery when the Profiles screen is entered. A late or temporarily failed request cannot erase the
last confirmed snapshot or downgrade a ready account with an older loading response.

Transient interface state, camera orientation, free-look state, character transforms and velocity,
current equipment, chat input, dash state, preview state, and runtime objects are deliberately not
persisted.

## Lifecycle

Joining creates a loading session and performs three bounded load attempts with exponential backoff.
A missing key becomes a new empty account. Unsupported or invalid account schemas become unavailable
and are never overwritten with defaults. Valid records are normalized to known fields and the
five-profile bound.

Confirmed mutations mark the server session dirty. Saves are debounced for three seconds, serialized
per player, retried three times, and also attempted every 60 seconds, on `PlayerRemoving`, and during a
bounded `BindToClose` window. `UpdateAsync` writes a validated server-owned snapshot. A failed save
keeps the session dirty for a later attempt.

## Studio testing

Use a separate published BLIKK persistence test experience, not the live production place. In Studio,
open **Game Settings > Security** and enable **Studio Access to API Services** for that test version.
Test create, selection, deletion, the five-profile limit, binding conflicts and resets, every
settings category, schema-1 migration, rejoin loading, autosave, immediate exit, shutdown, and
multiple clients. Disable Studio API access again after testing if it is no longer needed.

With API access disabled, loading becomes unavailable without crashing. The frontend does not claim
that an empty account loaded or that mutations were permanently saved, and the server does not write
defaults after the failed load.
