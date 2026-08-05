local SettingsConfig = {
	AudioDefaults = {
		MasterVolume = 1,
		MusicVolume = 0.7,
		SoundEffectsVolume = 1,
	},

	AudioRanges = {
		MasterVolume = {
			Minimum = 0,
			Maximum = 1,
			Step = 0.05,
		},
		MusicVolume = {
			Minimum = 0,
			Maximum = 1,
			Step = 0.05,
		},
		SoundEffectsVolume = {
			Minimum = 0,
			Maximum = 1,
			Step = 0.05,
		},
	},

	ExtrasDefaults = {
		HudVisible = true,
	},
}

return SettingsConfig
