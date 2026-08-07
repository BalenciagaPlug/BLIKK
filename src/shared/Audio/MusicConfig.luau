local MusicConfig = {
	DiagnosticsEnabled = false,

	FrontendSoundtrack = {
		Name = "BLIKKFrontendSoundtrack",
		SoundId = "rbxassetid://78521539571251",
		Looped = true,
		PlaybackSpeed = 1,
		FadeInSeconds = 0.65,
		FadeOutSeconds = 0.55,
		VolumeMultiplier = 1,
		SoundGroupName = "BLIKK_Music",
		AssetObservationSeconds = 8,
		ResumeOnFrontendReturn = true,
	},

	FrontendRoutes = {
		Creation = true,
		Profiles = true,
		OperationsHub = true,
		Multiplayer = true,
		Clans = true,
	},
}

return MusicConfig
