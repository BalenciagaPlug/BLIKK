local modes = {
	Training = {
		Id = "Training", DisplayName = "TRAINING", TeamMode = false, Competitive = false,
		MinimumPlayers = 1, MaximumPlayers = 16, TimeLimitSeconds = 0, ScoreLimit = 0,
		RespawnEnabled = true, RespawnDelaySeconds = 1, SpawnProtectionSeconds = 1.5,
		JoinInProgress = true, RoundBased = false,
	},
	Deathmatch = {
		Id = "Deathmatch", DisplayName = "DEATHMATCH", TeamMode = false, Competitive = true,
		MinimumPlayers = 2, MaximumPlayers = 16, TimeLimitSeconds = 600, ScoreLimit = 20,
		RespawnEnabled = true, RespawnDelaySeconds = 3, SpawnProtectionSeconds = 1.5,
		JoinInProgress = true, RoundBased = false,
	},
	TeamDeathmatchExtreme = {
		Id = "TeamDeathmatchExtreme", DisplayName = "TEAM DEATHMATCH EXTREME", TeamMode = true,
		Competitive = true, MinimumPlayers = 2, MaximumPlayers = 16, TimeLimitSeconds = 720,
		ScoreLimit = 30, RespawnEnabled = true, RespawnDelaySeconds = 3,
		SpawnProtectionSeconds = 1.5, JoinInProgress = true, RoundBased = false,
	},
	Elimination = {
		Id = "Elimination", DisplayName = "ELIMINATION", TeamMode = true, Competitive = true,
		MinimumPlayers = 2, MaximumPlayers = 16, TimeLimitSeconds = 0, ScoreLimit = 0,
		RespawnEnabled = false, RespawnDelaySeconds = 0, SpawnProtectionSeconds = 1.5,
		JoinInProgress = false, RoundBased = true, BestOfRounds = 7,
		RoundTimeSeconds = 180, RoundIntermissionSeconds = 6,
	},
}

local Registry = { All = modes, TeamIds = { "ALPHA", "OMEGA" }, Mutators = { MeleeOnly = true } }

function Registry.Get(modeId)
	return if type(modeId) == "string" then modes[modeId] else nil
end

return Registry
