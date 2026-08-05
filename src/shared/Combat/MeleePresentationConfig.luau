local TechniqueConfig = require(script.Parent.Parent.Movement.TechniqueConfig)

local MeleePresentationConfig = {
	Diagnostics = { Enabled = false },

	Slash = TechniqueConfig.CancelProfiles.TrainingKatana,

	Equip = { DurationSeconds = 0.12, UnequipDurationSeconds = 0.09 },
	Block = { ExitPresentationSeconds = 0.06 },
	Trail = {
		HighLifetimeSeconds = 0.16,
		MediumLifetimeSeconds = 0.09,
		DefaultOpacity = 0.28,
	},

	TrainingKatana = {
		FutureMeshId = "",
		FutureSoundHooks = { Equip = "", Unequip = "", Slash = "", Block = "" },
		Dimensions = {
			Handle = Vector3.new(0.52, 3.4, 0.52),
			Blade = Vector3.new(0.32, 5.8, 0.72),
			BladeEdge = Vector3.new(0.09, 5.65, 0.76),
			Guard = Vector3.new(2.25, 0.25, 0.55),
			Pommel = Vector3.new(0.7, 0.55, 0.7),
		},
		EquippedAttachment = { PartName = "RightHand", Offset = CFrame.new(0, -1.25, -0.15) * CFrame.Angles(0, 0, math.rad(8)) },
		HolsteredAttachment = { PartName = "UpperTorso", Offset = CFrame.new(-0.75, -0.2, 0.65) * CFrame.Angles(math.rad(8), 0, math.rad(142)) },
		BladeTrail = { StartY = 1.7, EndY = 7.25 },
	},

	Pose = {
		IdleBlendSpeed = 18,
		ActionBlendSpeed = 28,
		AirReadyTorsoDegrees = -7,
		AirReadyHipDegrees = 13,
	},
}

return MeleePresentationConfig
