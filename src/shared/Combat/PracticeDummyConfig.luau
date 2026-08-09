local ProfileConfig = require(script.Parent.Parent.Character.ProfileConfig)

local PracticeDummyConfig = {
	DiagnosticsEnabled = false,
	FolderName = "BLIKK_PracticeDummies",
	ModelName = "BLIKK_PracticeDummy_CLOCK",
	AvatarUserId = 7709079953,
	CollectionTag = "BLIKK_PracticeDummy",
	Attributes = {
		IsPracticeDummy = "BLIKK_PracticeDummy",
		AvatarUserId = "AvatarUserId",
		Generation = "DummyGeneration",
		IsActive = "BLIKK_PracticeDummyActive",
	},
	Placement = {
		WallStandOffStuds = 3,
		HorizontalFallbackOffsetsStuds = { 0, -4, 4, -8, 8 },
		GroundOffsetStuds = 0.08,
		GroundProbeHeightStuds = 32,
		GroundProbeDepthStuds = 96,
		MinimumGroundNormalY = 0.72,
		WallProbeTorsoHeightStuds = 3,
		WallProbeExtraStuds = 2,
		ClearanceSizeStuds = Vector3.new(4, 6, 4),
		ClearanceBottomAboveGroundStuds = 0.12,
		FloorSurfaceToleranceStuds = 0.2,
		ClearanceMaximumParts = 32,
	},
	Vitals = {
		ResetAfterInactivitySeconds = 3,
		LethalRecoverySeconds = 1,
	},
	AvatarConstructionTimeoutSeconds = 12,
	Animation = {
		TrustedR15IdleAnimationId = ProfileConfig.PreviewAnimation.TrustedIdleAnimationIds.R15,
		InitialFadeSeconds = ProfileConfig.PreviewAnimation.InitialFadeSeconds,
	},
	Readout = {
		Enabled = true,
		MaximumDistanceStuds = 90,
		SizePixels = Vector2.new(180, 58),
		StudsOffset = Vector3.new(0, 3.6, 0),
		TitleTextSizePixels = 13,
		VitalTextSizePixels = 12,
	},
}

return PracticeDummyConfig
