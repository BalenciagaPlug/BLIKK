local TechniqueConfig = {
	CancelProfiles = {
		TrainingKatana = {
			AnticipationSeconds = 0.025,
			ActiveSeconds = 0.115,
			RecoverySeconds = 0.160,
			CancelWindowOpenSeconds = 0.055,
			CancelWindowCloseSeconds = 0.205,
			EarlyInputBufferSeconds = 0.080,
			PostCancelBlockEnterBlendSeconds = 0.035,
			LandingForgivenessSeconds = 0.070,
			AirActionForgivenessSeconds = 0.060,
			RepeatedSequenceLockoutSeconds = 0.045,
			LateBlockPolicy = "AfterRecovery",
		},
	},

	Butterfly = {
		CandidateMaximumSeconds = 0.260,
		ChainMaximumGapSeconds = 0.600,
		WallContinuationSeconds = 0.750,
		DiagnosticsEnabled = false,
	},

	Wall = {
		QueryIntervalSeconds = 0.025,
		CheckDistanceStuds = 4.5,
		SideCheckAngleDegrees = 42,
		MaximumSurfaceNormalY = 0.25,
		MinimumUsableWidthStuds = 4,
		MinimumUsableHeightStuds = 8,
		DirectionDeadzone = 0.05,
		ContactSideDotThreshold = 0.30,
		ContactGraceSeconds = 0.120,
		JumpInputBufferSeconds = 0.100,
		RecontactLockoutSeconds = 0.280,
		SameWallMinimumSeparationStuds = 5,
		UpwardSpeedStudsPerSecond = 50,
		OutwardSpeedStudsPerSecond = 34,
		DirectionalInfluenceStudsPerSecond = 12,
		RetainedTangentialVelocityScale = 0.65,
		MinimumOutwardRetentionScale = 0.50,
		RecoveryDurationSeconds = 0.180,
		DiagnosticsEnabled = false,
		AllowUntaggedFallback = true,
		Presentation = {
			ContactRootPitchDegrees = 3, ContactRootRollDegrees = 8,
			ContactWaistPitchDegrees = -4, ContactWaistYawDegrees = 8, ContactWaistRollDegrees = 5,
			ContactHipForwardDegrees = 20, ContactHipBackDegrees = -12, ContactHipRollDegrees = 8,
			ContactShoulderPitchDegrees = -45, ContactShoulderRollDegrees = 38,
			JumpRootPitchDegrees = -12, JumpRootRollDegrees = 14,
			JumpWaistPitchDegrees = 7, JumpHipForwardDegrees = 24, JumpHipBackDegrees = -20,
		},
	},
}

return TechniqueConfig
