local SettingsConfig = {
	AudioDefaults = {
		MasterVolume = 1,
		MusicVolume = 0.7,
		MusicMuted = false,
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
		InputOverlayVisible = true,
		InputOverlayOpacity = 0.38,
		UIScale = 1,
		HudScale = 1,
		InputOverlayScale = 1,
		ReducedEffects = false,
		EffectsQuality = "HIGH",
	},

	ExtrasRanges = {
		InputOverlayOpacity = {
			Minimum = 0.1,
			Maximum = 0.8,
			Step = 0.05,
		},
		UIScale = { Minimum = 0.75, Maximum = 1.25, Step = 0.05 },
		HudScale = { Minimum = 0.75, Maximum = 1.25, Step = 0.05 },
		InputOverlayScale = { Minimum = 0.75, Maximum = 1.4, Step = 0.05 },
	},
}

return SettingsConfig
