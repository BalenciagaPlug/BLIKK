local TechniqueConfig = require(script.Parent.Parent.Movement.TechniqueConfig)
local MeleePresentationConfig = require(script.Parent.MeleePresentationConfig)

local Slash = TechniqueConfig.CancelProfiles.TrainingKatana
local KatanaDimensions = MeleePresentationConfig.TrainingKatana.Dimensions
local KatanaGeometry = MeleePresentationConfig.TrainingKatana.Geometry
local KATANA_TIP_REACH_FROM_GRIP_STUDS = KatanaDimensions.Handle.Y * 0.5
	+ KatanaDimensions.Guard.Y
	+ KatanaGeometry.BladeGuardGapStuds
	+ KatanaDimensions.Blade.Y

local MeleeCombatConfig = {
	DefinitionId = "TrainingKatana",
	Slash = Slash,
	DamagePerTarget = 18,
	MinimumSlashIntervalSeconds = Slash.AnticipationSeconds + Slash.ActiveSeconds + Slash.RecoverySeconds,
	MaximumRequestsPerSecond = 12,
	MaximumTargetsPerSwing = 1,
	ImpactDelaySeconds = Slash.AnticipationSeconds + Slash.ActiveSeconds * 0.5,
	AuthoritativeCancelGraceSeconds = 0.060,
	AimValidation = {
		MinimumDirectionMagnitude = 0.90,
		MaximumDirectionMagnitude = 1.10,
		MinimumFacingDot = 0.65,
		MinimumPitchDegrees = -55,
		MaximumPitchDegrees = 55,
		MaximumOriginDistanceFromRootStuds = 24,
	},
	HitVolume = {
		KatanaTipReachFromGripStuds = KATANA_TIP_REACH_FROM_GRIP_STUDS,
		MinimumWeaponArmReachStuds = 1.80,
		MaximumWeaponArmReachStuds = 3.25,
		MinimumShoulderSpanStuds = 1.50,
		MaximumShoulderSpanStuds = 3.25,
		ShoulderWidthScale = 1.00,
		PointBlankRearToleranceStuds = 0.35,
		BroadPhasePaddingStuds = 0.20,
	},
	WallContact = {
		MaximumRayDistanceStuds = 32,
		MaximumSurfaceNormalY = 0.55,
		MaximumSurfaceTransparency = 0.95,
		MaximumSkippedParts = 8,
	},
	Guard = {
		AttributeName = "BLIKK_MeleeGuarding",
		SequenceAttributeName = "BLIKK_MeleeGuardSequence",
		StartedAtAttributeName = "BLIKK_MeleeGuardStartedAt",
		MaximumDurationSeconds = 2.000,
		MinimumFacingDot = 0,
	},
	AltFire = {
		ImpactDelaySeconds = 0.180,
		TotalDurationSeconds = 0.420,
		MinimumIntervalSeconds = 0.420,
		MaximumTargets = 8,
		LaunchUpSpeedStudsPerSecond = 52,
		LaunchForwardSpeedStudsPerSecond = 16,
		HitVolume = {
			SizeStuds = Vector3.new(6.5, 5.5, 6.0),
			ForwardOffsetStuds = 3.0,
			UpOffsetStuds = 0.65,
			MaximumRangeStuds = 6.75,
			MaximumVerticalDifferenceStuds = 4.75,
			HalfAngleDegrees = 90,
		},
	},
	DiagnosticsEnabled = false,
}

assert(
	MeleeCombatConfig.HitVolume.KatanaTipReachFromGripStuds > 0,
	"Training Katana combat reach must remain derived from the presentation model geometry"
)
assert(
	MeleeCombatConfig.HitVolume.MinimumWeaponArmReachStuds
		<= MeleeCombatConfig.HitVolume.MaximumWeaponArmReachStuds
		and MeleeCombatConfig.HitVolume.MinimumShoulderSpanStuds
			<= MeleeCombatConfig.HitVolume.MaximumShoulderSpanStuds,
	"Training Katana avatar-scale combat bounds must remain ordered"
)

return MeleeCombatConfig
