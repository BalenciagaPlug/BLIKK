local LobbyConfig = {
	Categories = { "PUBLIC" },
	Maps = { "District Zero" },
	Modes = {
		{ Id = "Training", DisplayName = "TRAINING", Available = true },
		{ Id = "Deathmatch", DisplayName = "DEATHMATCH", Available = true },
		{ Id = "TeamDeathmatchExtreme", DisplayName = "TEAM DEATHMATCH EXTREME", Available = true },
		{ Id = "Elimination", DisplayName = "ELIMINATION", Available = true },
	},
	PlayerCapacities = { 2, 4, 8, 12, 16 },
	PrototypeListings = {},
	FutureServices = { "Ranked matchmaking", "Duel queue", "Clan War" },
}

return LobbyConfig
