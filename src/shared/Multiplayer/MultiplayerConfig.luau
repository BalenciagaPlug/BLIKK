local Config = {
	ProtocolVersion = 1,
	RoomStates = { "Creating", "Lobby", "Starting", "Teleporting", "LoadingMatch", "Countdown", "InProgress", "RoundIntermission", "PostMatch", "ReturningToLobby", "Closing" },
	PlayerStates = { "NotInRoom", "Joining", "InLobby", "Ready", "Loading", "Alive", "Dead", "Spectating", "PostMatch" },
	RoomNameMinimumLength = 1, RoomNameMaximumLength = 40, JoinCodeLength = 7,
	MaximumPlayers = 16, MaximumSpectatorSlots = 4, RoomCreationCooldownSeconds = 8,
	RoomCreationMinimumPlayers = 1,
	BrowserQueryCooldownSeconds = 2, RoomMutationCooldownSeconds = 0.2,
	TeamRequestCooldownSeconds = 0.5, ActivityPingMinimumIntervalSeconds = 2,
	AfkWarningSeconds = 180, AfkLeaderMigrationSeconds = 240, AfkKickSeconds = 300,
	AfkSpectatorKickSeconds = 420, PositionObservationIntervalSeconds = 2,
	AfkKickEnabledInStudio = false, StudioAfkTestOverride = false,
	CountdownSeconds = 3, PostMatchSeconds = 10, DamageAttributionWindowSeconds = 12,
	SoloEliminationRespawnDelaySeconds = 1,
	Directory = {
		ListingMapName = "BLIKK_PublicRoomsV1", SecretMapName = "BLIKK_RoomSecretsV1",
		PrivateServerLookupName = "BLIKK_PrivateRoomLookupV1", JoinCodeLookupName = "BLIKK_JoinCodesV1",
		JoinNonceMapName = "BLIKK_RoomJoinNoncesV1", MessagingTopic = "BLIKK_RoomDirectoryV1",
		ListingTtlSeconds = 90, HeartbeatSeconds = 25, SecretTtlSeconds = 120,
		StaleSeconds = 60, BrowserRefreshSeconds = 7, QueryPageSize = 25,
		MaximumBrowserResults = 100, JoinNonceTtlSeconds = 60,
		RetryCount = 3, RetryBaseDelaySeconds = 1, TeleportRetryCount = 3,
	},
	StudioDebugEliminationsEnabled = false,
}

return Config
