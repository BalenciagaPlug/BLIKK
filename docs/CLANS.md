# Clans

Clans are persistent social identity, not Clan War. Names are 3–20 characters, tags are 2–5 uppercase characters, descriptions are at most 160 characters, membership caps at 50, pending invites at 20, and invitations expire after seven days. Display text is filtered server-side.

Stores are BLIKKClansV1, BLIKKClanMembershipV1, BLIKKClanInvitesV1, BLIKKClanNameIndexV1, and BLIKKClanTagIndexV1. Shared writes use UpdateAsync. Normalized claims protect uniqueness. A per-user pointer enforces one clan; load verifies it against the roster and repairs stale pointers. Multi-key failures use bounded rollback where safe.

OWNER can transfer, disband, manage roles, invite, and kick. OFFICER can invite and kick lower roles but cannot affect the owner. MEMBER can view and leave. Permissions are revalidated server-side.

BLIKK_ClanPresenceV1 uses a 90-second MemoryStore TTL and 30-second heartbeat. Clan tags are presentation only. Clan War, rankings, currency, perks, and clan chat are excluded.

