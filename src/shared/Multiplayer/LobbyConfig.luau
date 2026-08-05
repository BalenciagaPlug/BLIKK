local LobbyConfig = {
	Categories = { "PINNED", "POPULAR", "RECENT" },
	Maps = { "District Zero" },
	Modes = {
		{ Id = "Training", DisplayName = "TRAINING", Available = true },
		{ Id = "Duel", DisplayName = "DUEL // FUTURE", Available = false },
		{ Id = "TeamDeathmatch", DisplayName = "TEAM DEATHMATCH // FUTURE", Available = false },
		{ Id = "FreeForAll", DisplayName = "FREE FOR ALL // FUTURE", Available = false },
	},
	PlayerCapacities = { 2, 4, 8, 12, 16 },
	PrototypeListings = {
		{ Category = "PINNED", Name = "DISTRICT ZERO // PUBLIC LAB", Mode = "TRAINING", Map = "DISTRICT ZERO", Players = "LOCAL", Ping = "--", Password = false, Status = "PROTOTYPE" },
		{ Category = "POPULAR", Name = "MOVEMENT PRACTICE", Mode = "TRAINING", Map = "DISTRICT ZERO", Players = "--/16", Ping = "--", Password = false, Status = "NOT DISCOVERED" },
		{ Category = "RECENT", Name = "YOUR RECENT LOBBIES", Mode = "--", Map = "--", Players = "--", Ping = "--", Password = false, Status = "SESSION ONLY" },
	},
	FutureServices = {
		"MemoryStoreService listings", "MessagingService updates", "Reserved servers",
		"Teleport routing", "Matchmaking", "Server filters",
	},
}

return LobbyConfig
