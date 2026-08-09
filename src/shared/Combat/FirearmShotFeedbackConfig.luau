local FirearmShotFeedbackConfig = {
	DiagnosticsEnabled = false,
	Payload = {
		EndpointRangeToleranceStuds = 1,
		LocalOriginCacheCapacity = 16,
		LocalOriginCacheLifetimeSeconds = 2,
	},
	PelletVisual = {
		SpeedStudsPerSecond = 2500,
		TrailLengthStuds = 1.5,
		MinimumLifetimeSeconds = 0.025,
		MaximumLifetimeSeconds = 0.12,
		WidthStartStuds = 0.035,
		WidthEndStuds = 0.012,
		PoolShotCapacity = 8,
		MuzzleColor = Color3.fromRGB(255, 232, 156),
		TailColor = Color3.fromRGB(142, 146, 150),
	},
	Muzzle = {
		FlashLifetimeSeconds = 0.045,
		FlashLightBrightness = 4,
		FlashLightRangeStuds = 10,
		SparkCount = 5,
		SmokeCount = 2,
		SmokeLifetimeSeconds = 0.16,
		RemoteFlashSizeStuds = 0.28,
	},
	Recoil = {
		KickSeconds = 0.020,
		HoldSeconds = 0.015,
		ReturnSeconds = 0.110,
		PitchDegrees = 9,
		BackwardTravelStuds = 0.12,
		PumpDelaySeconds = 0.035,
		PumpCycleSeconds = 0.235,
		PumpTravelStuds = 0.30,
	},
	ImpactPresentation = {
		Enabled = false,
		MaximumPerShot = 0,
	},
}

FirearmShotFeedbackConfig.Recoil.TotalDurationSeconds =
	FirearmShotFeedbackConfig.Recoil.KickSeconds
	+ FirearmShotFeedbackConfig.Recoil.HoldSeconds
	+ FirearmShotFeedbackConfig.Recoil.ReturnSeconds

return FirearmShotFeedbackConfig
