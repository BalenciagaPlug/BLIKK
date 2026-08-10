local MovementConfig = {
	Dash = {
		DoubleTapWindowSeconds = 0.25,
		FollowupInputBufferSeconds = 0.09,
		GroundDistanceStuds = 18.125,
		AirDistanceStuds = 16.25,
		EntryDurationSeconds = 0.040,
		TravelDurationSeconds = 0.125,
		ExitDurationSeconds = 0.085,
		EntrySpeedMultiplier = 0.62,
		PeakSpeedMultiplier = 1.38,
		TravelEndSpeedMultiplier = 1.05,
		ExitMomentumRetention = 0.24,
		GroundCooldownSeconds = 0.32,
		AirCooldownSeconds = 0.34,
		AirDashLimit = 1,
		VerticalMomentumMode = "PreserveAtActivation",
		MinimumActivationSpeedStudsPerSecond = 0,
		CancelWindows = {
			FutureTechniqueOpenSeconds = 0.05,
			FutureTechniqueCloseSeconds = 0.19,
		},
		Presentation = {
			Enabled = true,
			CharacterLeanDegrees = 11,
			CounterTwistDegrees = 8,
			ArmBraceDegrees = 18,
			LeadShoulderDegrees = 22,
			LeadStepDegrees = 34,
			TrailStepDegrees = 18,
			StepPeakProgress = 0.46,
			StepRecoveryStartProgress = 0.72,
			HipMotionDelayProgress = 0.10,
			-- Air dashes are a separate flight silhouette: both legs remain balanced
			-- instead of borrowing the grounded dash's lead-step animation.
			AirCharacterLeanDegrees = 8,
			AirDirectionYawDegrees = 5,
			AirHipTuckDegrees = 9,
			AirHipSpreadDegrees = 4,
			AirReadyHipTuckDegrees = 5,
			EffectIntensity = 0.8,
			StreakCount = 3,
			StreakHeightsStuds = { 2.15, 0, -2.15 },
			StreakWidthsStuds = { 0.12, 0.16, 0.1 },
			StreakLengthStuds = 8.5,
			StreakMinimumDisplacementStuds = 0.01,
			StreakColor = Color3.fromRGB(255, 255, 255),
			StreakLifetimeSeconds = 0.24,
			StreakTransparency = 0.28,
			MediumLifetimeMultiplier = 0.72,
			MediumWidthMultiplier = 0.8,
			LowStreakCount = 1,
			LowLifetimeMultiplier = 0.5,
			GroundAccentSizeStuds = 2.8,
			GroundAccentLifetimeSeconds = 0.12,
			SoundId = "rbxassetid://9119738974",
			SoundVolume = 0.35,
			AnimationIds = { Forward = "", Backward = "", Left = "", Right = "" },
		},
		Diagnostics = { Enabled = false },
	},

	-- Ranged double-taps deliberately occupy a slower, more readable traversal
	-- role than the katana dash. The half-second commitment follows the original
	-- GunZ tumble cadence; distances are BLIKK/Roblox calibration.
	Tumble = {
		GroundDistanceStuds = 12.5,
		AirDistanceStuds = 11.0,
		EntryDurationSeconds = 0.10,
		TravelDurationSeconds = 0.30,
		ExitDurationSeconds = 0.10,
		EntrySpeedMultiplier = 0.55,
		PeakSpeedMultiplier = 1.15,
		TravelEndSpeedMultiplier = 0.80,
		ExitMomentumRetention = 0.18,
		GroundCooldownSeconds = 0.55,
		AirCooldownSeconds = 0.58,
	},

	Ground = {
		ForwardSpeedStudsPerSecond = 18,
		StrafeSpeedStudsPerSecond = 16,
		BackwardSpeedStudsPerSecond = 13,
	},

	Jump = {
		HeightStuds = 7.5,
		InputBufferSeconds = 0.18,
		GroundedGraceSeconds = 0.10,
	},
}

return MovementConfig
