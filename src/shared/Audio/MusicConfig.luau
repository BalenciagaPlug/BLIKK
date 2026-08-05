local MusicConfig = {
	CrossfadeDurationSeconds = 0.75,
	DiagnosticsEnabled = false,

	Tracks = {
		CharacterTheme01 = { SoundId = "" },
		HubTheme01 = { SoundId = "" },
		CombatTheme01 = { SoundId = "" },
		CombatTheme02 = { SoundId = "" },
		CombatTheme03 = { SoundId = "" },
		ResultsTheme01 = { SoundId = "" },
	},

	Contexts = {
		Splash = { Playlist = {}, PlaybackOrder = "Sequential" },
		CharacterSelection = { Playlist = { "CharacterTheme01" }, PlaybackOrder = "Sequential" },
		OperationsHub = { Playlist = { "HubTheme01" }, PlaybackOrder = "Sequential" },
		MovementLab = {
			Playlist = { "CombatTheme01", "CombatTheme02", "CombatTheme03" },
			PlaybackOrder = "Shuffle",
		},
		CompetitiveMatch = {
			Playlist = { "CombatTheme01", "CombatTheme02", "CombatTheme03" },
			PlaybackOrder = "Shuffle",
		},
		Results = { Playlist = { "ResultsTheme01" }, PlaybackOrder = "Sequential" },
	},

	RouteContexts = {
		Splash = "Splash",
		Creation = "CharacterSelection",
		Profiles = "CharacterSelection",
		OperationsHub = "OperationsHub",
		MovementLab = "MovementLab",
		CompetitiveMatch = "CompetitiveMatch",
		Results = "Results",
	},
}

return MusicConfig
