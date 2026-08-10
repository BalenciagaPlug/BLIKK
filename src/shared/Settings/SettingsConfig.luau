local SettingsConfig = {
	KeyboardSliderCommitDelaySeconds = 0.18,
	Chat = {
		MaximumStoredMessages = 80,
		CollapsedVisibleMessages = 4,
		MessagePaddingPixels = 3,
		AutoFollowThresholdPixels = 6,
		CollapsedWidthPixels = 350,
		CollapsedHeightPixels = 118,
		ExpandedWidthPixels = 430,
		ExpandedHeightPixels = 245,
	},

	AudioDefaults = {
		MasterVolume = 1,
		MusicVolume = 1,
		MusicMuted = false,
		SoundEffectsVolume = 1,
		UISoundVolume = 1,
	},
	AudioMix = {
		RepresentativeIntegratedTargetLUFS = -23,
		RepresentativeIntegratedToleranceLU = 2,
		MusicGainDecibels = -8,
		SoundEffectsGainDecibels = -2,
		UISoundGainDecibels = -1,
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
		UISoundVolume = {
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
		RenderPreset = "BALANCED",
		LocalLightShadows = false,
		BloomEnabled = true,
		ColorCorrectionEnabled = true,
		AtmosphereEnabled = true,
		ParticleDensity = 0.7,
		WeaponTrailsEnabled = true,
		ScreenShakeScale = 0.7,
		ShowFPS = false,
		ShowPing = false,
		BladeTrailVisible = true,
		BladeTrailOpacity = 0.28,
		ChatVisible = true,
		ChatOpacity = 0.42,
		ChatScale = 1,
		ChatTimestamps = true,
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
		ChatOpacity = { Minimum = 0.15, Maximum = 0.85, Step = 0.05 },
		ChatScale = { Minimum = 0.75, Maximum = 1.25, Step = 0.05 },
		BladeTrailOpacity = { Minimum = 0.05, Maximum = 0.8, Step = 0.05 },
		ParticleDensity = { Minimum = 0, Maximum = 1, Step = 0.1 },
		ScreenShakeScale = { Minimum = 0, Maximum = 1, Step = 0.1 },
	},
}

return SettingsConfig
