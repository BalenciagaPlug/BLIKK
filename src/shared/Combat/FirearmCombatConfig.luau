local RELOAD_START_SECONDS = 0.18
local RELOAD_INSERT_SECONDS = 0.32

local FirearmCombatConfig = {
	DefinitionId = "TrainingShotgun",
	DisplayName = "BLIKK B-8 BREAKSHOT",
	PelletsPerShot = 12,
	DamagePerPellet = 9,
	MaximumRawDamagePerTarget = 108,
	MagazineCapacity = 5,
	StartingReserve = 20,
	MovementLabUnlimitedReserve = true,
	FireIntervalSeconds = 1.000,
	Accuracy = {
		AimBasis = "StableRootOriginToCrosshairPoint",
		SpreadModel = "FixedWeaponCone",
		SpreadHalfAngleDegrees = 4.5, -- BLIKK prototype tuning; not a historical GunZ value.
		MovementStateAffectsSpread = false,
		PresentationRecoilAffectsSpread = false,
		RepeatedFireBloomEnabled = false,
		GuaranteedCenterPellets = 1,
	},
	MaximumRangeStuds = 300, -- BLIKK prototype tuning; not a historical GunZ value.
	Aim = {
		MinimumDirectionMagnitude = 0.99,
		MaximumDirectionMagnitude = 1.01,
		MinimumFacingDot = -0.25,
		MaximumRequestsPerSecond = 12,
		MuzzleForwardStuds = 1.4,
		MuzzleUpStuds = 1.1,
		MinimumAimPointDistanceStuds = 1,
		-- The camera's 300-stud miss point can be several studs farther from the
		-- authoritative root muzzle; rays themselves remain clamped to weapon range.
		MaximumAimPointDistanceStuds = 325,
		MinimumAimPointDirectionDot = 0.90,
	},
	Reload = {
		StartSeconds = RELOAD_START_SECONDS,
		InsertSeconds = RELOAD_INSERT_SECONDS,
		FinishSeconds = 0.18,
		CommitSeconds = RELOAD_START_SECONDS + RELOAD_INSERT_SECONDS,
	},
}

assert(
	FirearmCombatConfig.Accuracy.GuaranteedCenterPellets >= 1
		and FirearmCombatConfig.Accuracy.GuaranteedCenterPellets <= FirearmCombatConfig.PelletsPerShot,
	"At least one shotgun pellet must preserve exact crosshair intent"
)
assert(
	FirearmCombatConfig.Aim.MaximumAimPointDistanceStuds <= FirearmCombatConfig.MaximumRangeStuds + 25,
	"Aim-point tolerance must stay tightly bounded around weapon range"
)

return FirearmCombatConfig
