local MusicConfig = {
	DiagnosticsEnabled = false,
	PlaybackSoundName = "BLIKKMusicPlayback",
	SoundGroupName = "BLIKK_Music",
	PlaybackSpeed = 1,
	VolumeMultiplier = 1,
	FadeInSeconds = 0.65,
	FadeOutSeconds = 0.55,
	PreloadBatchAdvanceSeconds = 12,

	RouteContexts = {
		Splash = "Silent",
		Creation = "CharacterSelection",
		Profiles = "CharacterSelection",
		OperationsHub = "MainMenu",
		Multiplayer = "MainMenu",
		Clans = "MainMenu",
	},

	Tracks = {
		CharacterSelection = {
			Key = "CharacterSelection",
			Name = "BLIKK - Intro [Character Selection]",
			SoundId = "rbxassetid://88261433540574",
			Looped = true,
			Enabled = true,
		},
		OperationsHub = {
			Key = "OperationsHub",
			Name = "BLIKK - Theme Rock [Game Lobby]",
			SoundId = "rbxassetid://139646652744306",
			Looped = true,
			Enabled = true,
		},
		DuelPlaylist = {
			{
				Key = "DuelTheme1",
				Name = "BLIKK - The Duel [Duel Theme 1]",
				SoundId = "rbxassetid://132664546255082",
				Looped = false,
				Enabled = true,
			},
			{
				Key = "DuelTheme5",
				Name = "BLIKK - Ryswick Style [Duel Theme 5]",
				SoundId = "rbxassetid://9474594378021",
				Looped = false,
				Enabled = false,
			},
			{
				Key = "DuelTheme8",
				Name = "BLIKK - HardCore [Duel Theme 8]",
				SoundId = "rbxassetid://106872514813617",
				Looped = false,
				Enabled = true,
			},
		},
	},
}

return MusicConfig
