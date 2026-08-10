local FirearmCombatConfig = require(script.Parent.FirearmCombatConfig)
local MeleeCombatConfig = require(script.Parent.MeleeCombatConfig)

local CombatFeedbackConfig = {
	DiagnosticsEnabled = false,
	Payload = {
		MaximumResultsPerShot = FirearmCombatConfig.PelletsPerShot,
		MaximumPelletHitsPerTarget = FirearmCombatConfig.PelletsPerShot,
		MaximumDamagePerTarget = FirearmCombatConfig.MaximumRawDamagePerTarget,
		MaximumMeleeResultsPerSwing = MeleeCombatConfig.MaximumTargetsPerSwing,
		MaximumMeleeDamagePerTarget = MeleeCombatConfig.DamagePerTarget,
		MaximumTargetIdLength = 64,
		MaximumWorldCoordinateMagnitude = 100000,
		DamageEqualityTolerance = 0.001,
	},
	Colors = {
		Armour = Color3.fromRGB(31, 142, 221),
		Health = Color3.fromRGB(151, 217, 74),
		Mixed = Color3.fromRGB(235, 232, 218),
		Elimination = Color3.fromRGB(183, 45, 48),
		Shadow = Color3.fromRGB(7, 8, 8),
	},
	DamageNumber = {
		LifetimeSeconds = 0.52,
		RiseDistancePixels = 28,
		PoolSize = 10,
		SizePixels = Vector2.new(150, 48),
		InitialOffsetPixels = Vector2.new(28, -18),
		CrosshairClearancePixels = 24,
		OffscreenMarginPixels = 8,
		TotalTextSizePixels = 21,
		BreakdownTextSizePixels = 11,
	},
	Hitmarker = {
		VisibleDurationSeconds = 0.12,
		FadeDurationSeconds = 0.08,
		LineLengthPixels = 9,
		LineThicknessPixels = 2,
		CenterGapPixels = 6,
	},
	ScreenGui = {
		Name = "BLIKKCombatFeedback",
		DisplayOrder = 11,
	},
}

return CombatFeedbackConfig
