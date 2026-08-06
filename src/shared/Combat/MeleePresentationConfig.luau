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
			Handle = Vector3.new(0.30, 1.00, 0.30),
			Grip = Vector3.new(0.36, 0.82, 0.36),
			Blade = Vector3.new(0.16, 3.50, 0.42),
			BladeEdge = Vector3.new(0.045, 3.36, 0.44),
			Guard = Vector3.new(0.90, 0.12, 0.44),
			Pommel = Vector3.new(0.36, 0.15, 0.36),
		},
		Geometry = {
			GripCenterYStuds = -0.02,
			BladeGuardGapStuds = 0.03,
			EdgeOffsetXStuds = -0.105,
			TrailRootBladeFraction = 0.08,
			TrailTipInsetBladeFraction = 0.04,
		},
		EquippedAttachment = {
			PartName = "RightHand",
			Offset = CFrame.new(0, -0.12, 0.02)
				* CFrame.Angles(math.rad(-54), 0, math.rad(190)),
			GripPivot = CFrame.new(0, 0.18, 0),
		},
		HolsteredAttachment = {
			PartName = "UpperTorso",
			Offset = CFrame.new(0.65, 0.45, 0.55)
				* CFrame.Angles(math.rad(10), math.rad(-8), math.rad(135)),
			GripPivot = CFrame.identity,
		},
	},

	Pose = {
		IdleBlendSpeed = 18,
		ActionBlendSpeed = 28,
		AirReadyTorsoDegrees = -7,
		AirReadyHipDegrees = 13,
		EquippedIdle = {
			Waist = Vector3.new(-1, -4, 1),
			RightShoulder = Vector3.new(-15, -5, 8),
			RightElbow = Vector3.new(-30, 0, 0),
			RightWrist = Vector3.new(4, -4, 6),
		},
	},
}

return MeleePresentationConfig
