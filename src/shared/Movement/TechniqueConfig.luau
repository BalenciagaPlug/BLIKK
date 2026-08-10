local TechniqueConfig = {
	WeaponTechniqueDiagnosticsEnabled = false,
	SemanticHistoryMaximumEntries = 32,
	CancelProfiles = {
		TrainingKatana = {
			AnticipationSeconds = 0.030,
			ActiveSeconds = 0.110,
			RecoverySeconds = 0.200,
			CancelWindowOpenSeconds = 0.060,
			CancelWindowCloseSeconds = 0.225,
			EarlyInputBufferSeconds = 0.085,
			PostCancelBlockEnterBlendSeconds = 0.040,
			LandingForgivenessSeconds = 0.070,
			AirActionForgivenessSeconds = 0.060,
			RepeatedSequenceLockoutSeconds = 0.050,
			SequenceResetSeconds = 0.65,
			LateBlockPolicy = "AfterRecovery",
		},
	},

	Butterfly = {
		CandidateMaximumSeconds = 0.260,
		JumpChainMaximumSeconds = 0.900,
		ChainMaximumGapSeconds = 0.300,
		MaximumPairsPerJump = 3,
		WallContinuationSeconds = 0.750,
		DiagnosticsEnabled = false,
	},

	WeaponWeave = {
		MovementIntentMaximumRequestsPerSecond = 30,
		AcceptedResultLockoutSeconds = 0.050,
		SlashShot = {
			MaximumSequenceSeconds = 0.550,
			DashBeforeSlashMaximumSeconds = 0.350,
			EquipAfterSlashMaximumSeconds = 0.300,
			FireAfterEquipMaximumSeconds = 0.250,
		},
		HalfStep = {
			MaximumSequenceSeconds = 0.750,
			ContinuationDashAvailabilitySeconds = 0.340,
			DashAfterEquipMaximumSeconds = 0.350,
			FireAfterDashMaximumSeconds = 0.250,
		},
		SwapShot = {
			MaximumShotGapSeconds = 0.550,
			FireAfterEquipMaximumSeconds = 0.250,
		},
		ReloadShot = {
			ReloadAfterFireMaximumSeconds = 0.200,
			EquipAfterReloadMaximumSeconds = 0.250,
			MaximumShotGapSeconds = 0.550,
		},
	},

	Feedback = {
		VisibleSeconds = 0.550,
		FadeSeconds = 0.180,
		TextSizePixels = 18,
		LeftOffsetPixels = 24,
		BottomOffsetPixels = 286,
	},

	Wall = {
		QueryIntervalSeconds = 0.025,
		MinimumCheckDistanceStuds = 3.25,
		VelocityLookAheadSeconds = 0.055,
		QueryPaddingStuds = 1.25,
		SphereRadiusStuds = 0.85,
		OverheadClearanceCheckStuds = 2.5,
		SideCheckAngleDegrees = 42,
		MaximumSurfaceNormalY = 0.20,
		MinimumUsableWidthStuds = 4,
		MinimumUsableHeightStuds = 8,
		DirectionDeadzone = 0.05,
		ContactSideDotThreshold = 0.30,
		ContactGraceSeconds = 0.12,
		JumpInputBufferSeconds = 0.28,
		MinimumFreshExitInputDelaySeconds = 0.08,
		ClearancePaddingStuds = 0.30,
		ContactMaintenanceDistanceStuds = 0.90,
		ClearanceCorrectionGain = 12,
		MaximumClearanceCorrectionSpeedStudsPerSecond = 8,
		AdhesionSpeedStudsPerSecond = 0.30,
		SensorIntoSpeedWeight = 0.35,
		SensorTangentSpeedWeight = 0.65,
		HeadOnMinimumIntoWallRatio = 0.72,
		HeadOnMaximumTangentRatio = 0.45,
		HeadOnMinimumIntoWallSpeedStudsPerSecond = 8,
		-- A wider band accepts deliberate shallow and steep approaches while the
		-- tangent/into-speed gates still prevent passive wall adhesion.
		AngledMinimumDegreesFromWallPlane = 8,
		AngledMaximumDegreesFromWallPlane = 58,
		AngledMinimumTangentRatio = 0.42,
		AngledMinimumIntoWallSpeedStudsPerSecond = 4,
		AngledMinimumTangentSpeedStudsPerSecond = 6,
		VerticalRun = {
			GroundEntryWindowSeconds = 0.16,
			GroundContactToleranceStuds = 0.35,
			DurationSeconds = 0.68,
			InitialUpwardSpeedStudsPerSecond = 30,
			FinalUpwardSpeedStudsPerSecond = 8,
			MaximumHeightCharacterScale = 2.6,
			TangentialRetentionScale = 0.25,
		},
		HorizontalRun = {
			DurationSeconds = 1.05,
			TangentialRetentionScale = 1.0,
			MinimumTangentialSpeedStudsPerSecond = 29,
			TargetTangentialSpeedStudsPerSecond = 34,
			TangentialAccelerationStudsPerSecondSquared = 80,
			InitialUpwardSpeedStudsPerSecond = 14,
			FinalUpwardSpeedStudsPerSecond = -2,
			MaximumHeightCharacterScale = 1.25,
		},
		Post = {
			MaximumHoldSeconds = 0.85,
			DownwardSpeedStudsPerSecond = 2.0,
			TangentialSpeedStudsPerSecond = 8,
			ReleaseOutwardSpeedStudsPerSecond = 6,
		},
		-- Classic wall-jump cancel is the accessible wall-posting profile. It
		-- preserves elevation and creates return space; slash-first Scale below
		-- remains the deliberately faster vertical-climb profile.
		UpwardSpeedStudsPerSecond = 54,
		OutwardSpeedStudsPerSecond = 48,
		DirectionalInfluenceStudsPerSecond = 12,
		RetainedTangentialVelocityScale = 0.65,
		MinimumOutwardRetentionScale = 0.50,
		AutomaticVerticalExit = {
			UpwardSpeedStudsPerSecond = 46,
			OutwardSpeedStudsPerSecond = 42,
			TangentialRetentionScale = 0.60,
		},
		AutomaticHorizontalExit = {
			UpwardSpeedStudsPerSecond = 38,
			OutwardSpeedStudsPerSecond = 37.5,
			TangentialRetentionScale = 0.75,
		},
		RecoveryDurationSeconds = 0.26,
		SlashCancelWindowSeconds = 0.22,
		ReturnDashAvailabilitySeconds = 0.68,
		Scale = {
			-- Supports approach dash -> slash -> jump and wall run -> slash -> jump.
			-- The reverse wall jump -> slash order remains the classic cancel path.
			DashToWallMaximumSeconds = 0.44,
			MinimumDashIntoWallDot = 0.42,
			SlashToJumpMinimumSeconds = 0.000,
			SlashToJumpMaximumSeconds = 0.34,
			UpwardSpeedStudsPerSecond = 66,
			OutwardSpeedStudsPerSecond = 48,
			RetainedTangentialVelocityScale = 0.70,
			ReturnDashAvailabilitySeconds = 0.70,
		},
		SameWallMinimumRecontactSeconds = 0.10,
		SameWallMinimumSeparationStuds = 0.55,
		SameWallMinimumContactPointMovementStuds = 0.35,
		SameWallMinimumReentrySpeedStudsPerSecond = 5,
		SameWallNormalMatchDot = 0.94,
		DiagnosticsEnabled = false,
		AllowUntaggedFallback = true,
		Presentation = {
			UpperBodyCounterRotationScale = 0.28,
			ContactRootPitchDegrees = 3, ContactRootRollDegrees = 8,
			ContactWaistPitchDegrees = -4, ContactWaistYawDegrees = 8, ContactWaistRollDegrees = 5,
			ContactHipForwardDegrees = 20, ContactHipBackDegrees = -12, ContactHipRollDegrees = 8,
			HorizontalStrideDegrees = 32, HorizontalStrideCyclesPerSecond = 2.2,
			VerticalClimbDegrees = 26, VerticalClimbCyclesPerSecond = 2.0,
			PostKneeTuckDegrees = 34,
			ContactShoulderPitchDegrees = -45, ContactShoulderRollDegrees = 38,
			JumpRootPitchDegrees = -12, JumpRootRollDegrees = 14,
			JumpWaistPitchDegrees = 7, JumpHipForwardDegrees = 24, JumpHipBackDegrees = -20,
		},
	},
}

local wall = TechniqueConfig.Wall
assert(
	wall.AngledMinimumDegreesFromWallPlane >= 0
		and wall.AngledMinimumDegreesFromWallPlane < wall.AngledMaximumDegreesFromWallPlane
		and wall.AngledMaximumDegreesFromWallPlane < 90,
	"Wall-run angle band must remain ordered inside the wall-plane hemisphere"
)
assert(
	wall.Scale.SlashToJumpMinimumSeconds >= 0
		and wall.Scale.SlashToJumpMaximumSeconds > wall.Scale.SlashToJumpMinimumSeconds,
	"Wall scale Slash-to-Jump window must be positive and ordered"
)
assert(
	wall.Scale.MinimumDashIntoWallDot > 0 and wall.Scale.MinimumDashIntoWallDot <= 1,
	"Wall scale approach dash must require meaningful inward direction"
)
assert(
	wall.Scale.ReturnDashAvailabilitySeconds >= wall.ReturnDashAvailabilitySeconds,
	"Slash-first wall scale must preserve at least the classic return-dash window"
)
assert(
	wall.SlashCancelWindowSeconds <= wall.RecoveryDurationSeconds,
	"Wall slash-cancel window must remain inside wall-jump recovery"
)
assert(
	wall.UpwardSpeedStudsPerSecond > wall.OutwardSpeedStudsPerSecond,
	"Classic wall cancel must retain enough lift to hold wall-posting elevation"
)
assert(
	wall.Scale.UpwardSpeedStudsPerSecond >= wall.UpwardSpeedStudsPerSecond + 10,
	"Slash-first wall scaling must remain the fastest vertical wall route"
)
assert(
	wall.VerticalRun.GroundEntryWindowSeconds > 0
		and wall.VerticalRun.GroundEntryWindowSeconds <= wall.JumpInputBufferSeconds,
	"Vertical wall run must retain a short ground-origin Jump window"
)
assert(
	wall.VerticalRun.GroundContactToleranceStuds >= 0
		and wall.VerticalRun.GroundContactToleranceStuds <= wall.ContactMaintenanceDistanceStuds,
	"Vertical wall run ground contact tolerance must remain inside maintained contact"
)

return TechniqueConfig
