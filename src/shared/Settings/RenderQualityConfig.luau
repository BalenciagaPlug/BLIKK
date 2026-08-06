local Config = {
	DefaultPreset = "BALANCED",
	Presets = {
		COMPETITIVE = { EffectsQuality = "LOW", LocalLightShadows = false, BloomEnabled = false, ColorCorrectionEnabled = true, AtmosphereEnabled = true, ParticleDensity = 0.35, WeaponTrailsEnabled = true, ScreenShakeScale = 0.35 },
		BALANCED = { EffectsQuality = "MEDIUM", LocalLightShadows = false, BloomEnabled = true, ColorCorrectionEnabled = true, AtmosphereEnabled = true, ParticleDensity = 0.7, WeaponTrailsEnabled = true, ScreenShakeScale = 0.7 },
		CINEMATIC = { EffectsQuality = "HIGH", LocalLightShadows = true, BloomEnabled = true, ColorCorrectionEnabled = true, AtmosphereEnabled = true, ParticleDensity = 1, WeaponTrailsEnabled = true, ScreenShakeScale = 1 },
	},
}

return Config
