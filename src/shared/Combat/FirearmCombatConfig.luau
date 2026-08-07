local FirearmCombatConfig = {
	DefinitionId = "TrainingShotgun",
	DisplayName = "BLIKK B-8 BREAKSHOT",
	PelletsPerShot = 12,
	DamagePerPellet = 9,
	MaximumRawDamagePerTarget = 108,
	MagazineCapacity = 5,
	StartingReserve = 20,
	FireIntervalSeconds = 1.000,
	SpreadHalfAngleDegrees = 4.5, -- BLIKK prototype tuning; not a historical GunZ value.
	MaximumRangeStuds = 300, -- BLIKK prototype tuning; not a historical GunZ value.
	Aim = {
		MinimumDirectionMagnitude = 0.99,
		MaximumDirectionMagnitude = 1.01,
		MinimumFacingDot = -0.25,
		MaximumRequestsPerSecond = 12,
		MuzzleForwardStuds = 1.4,
		MuzzleUpStuds = 1.1,
	},
	Reload = {
		StartSeconds = 0.18,
		InsertSeconds = 0.32,
		FinishSeconds = 0.18,
	},
}

return FirearmCombatConfig
