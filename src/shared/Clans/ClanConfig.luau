local Config = {
	SchemaVersion = 1, NameMinimumLength = 3, NameMaximumLength = 20,
	TagMinimumLength = 2, TagMaximumLength = 5, DescriptionMaximumLength = 160,
	MaximumMembers = 50, MaximumPendingInvites = 20, InviteExpirySeconds = 604800,
	MutationCooldownSeconds = 1, QueryCooldownSeconds = 2, PresenceTtlSeconds = 90,
	PresenceHeartbeatSeconds = 30, DataStoreRetryCount = 3, RetryBaseDelaySeconds = 0.5,
	Stores = {
		Clans = "BLIKKClansV1", Membership = "BLIKKClanMembershipV1",
		Invites = "BLIKKClanInvitesV1", NameIndex = "BLIKKClanNameIndexV1",
		TagIndex = "BLIKKClanTagIndexV1",
	},
	PresenceMapName = "BLIKK_ClanPresenceV1",
	Roles = { OWNER = 3, OFFICER = 2, MEMBER = 1 },
}

return Config
