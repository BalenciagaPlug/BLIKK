local Combat = require(script.Parent.FirearmCombatConfig)

local RIGHT_HAND_GRIP = CFrame.new(0, -0.38, 0.24)
	* CFrame.Angles(math.rad(92), 0, 0)

local FirearmPresentationConfig = {
	DiagnosticsEnabled = false,
	ApprovedCustomModelName = "",
	DefinitionId = Combat.DefinitionId,
	DisplayName = Combat.DisplayName,
	ChamberCapacity = Combat.MagazineCapacity,
	StartingReserve = Combat.StartingReserve,
	EquipDurationSeconds = 0.10,
	UnequipDurationSeconds = 0.08,
	FireAnticipationSeconds = 0.025,
	FireActionSeconds = 0.095,
	FireRecoverySeconds = 0.235,
	SameWeaponFireIntervalSeconds = Combat.FireIntervalSeconds,
	SwitchCancelOpenSeconds = 0.080,
	ReloadOpenSeconds = Combat.Reload.StartSeconds,
	ReloadEjectSeconds = 0.08,
	ReloadInsertSeconds = Combat.Reload.InsertSeconds,
	ReloadCloseSeconds = Combat.Reload.FinishSeconds,
	AimPitchMinimumDegrees = -55,
	AimPitchMaximumDegrees = 55,
	AimBlend = 0.42,
	GeometryToCanonical = CFrame.identity,
	OrientationValidation = {
		MinimumForwardDot = 0.98,
		MinimumUpDot = 0.95,
		PitchSamplesDegrees = { -55, -35, 0, 35, 55 },
	},
	Diagnostics = {
		MarkerSizeStuds = 0.12,
		AxisThicknessStuds = 0.04,
		AxisLengthStuds = 0.75,
	},
	AimIK = {
		Weight = 1,
		SmoothTimeSeconds = 0,
		RightArmPriority = 10,
		LeftArmPriority = 20,
		NeutralReceiverInwardShoulderWidths = 0.18,
		NeutralReceiverDownTorsoHeights = 0.18,
		NeutralReceiverForwardArmReaches = 0.35,
		RightElbowPoleOutwardShoulderWidths = 0.55,
		RightElbowPoleDownTorsoHeights = 0.32,
		RightElbowPoleRearwardArmReaches = 0.08,
		LeftElbowPoleOutwardShoulderWidths = 0.50,
		LeftElbowPoleDownTorsoHeights = 0.42,
		LeftElbowPoleForwardArmReaches = 0.10,
	},
	TumblePriority = 50,
	ActionPriority = 40,
	IdlePriority = 20,
	Colors = {
		Gunmetal = Color3.fromRGB(43, 46, 52),
		Black = Color3.fromRGB(18, 19, 22),
		Accent = Color3.fromRGB(144, 64, 214),
	},
	Geometry = {
		Receiver = Vector3.new(0.58, 0.62, 1.05),
		Barrel = Vector3.new(1.40, 0.24, 0.24),
		Shroud = Vector3.new(0.44, 0.44, 1.00),
		Pump = Vector3.new(0.54, 0.50, 0.72),
		Stock = Vector3.new(0.48, 0.60, 1.08),
		Grip = Vector3.new(0.30, 0.66, 0.34),
		Guard = Vector3.new(0.44, 0.10, 0.48),
		Port = Vector3.new(0.04, 0.22, 0.38),
		Sight = Vector3.new(0.08, 0.10, 0.10),
		Shell = Vector3.new(0.12, 0.12, 0.36),
		MuzzleFlash = Vector3.new(0.30, 0.30, 0.18),
	},
	Offsets = {
		Stock = CFrame.new(0, 0.02, 1.02) * CFrame.Angles(math.rad(-7), 0, 0),
		Grip = CFrame.new(0, -0.52, 0.35) * CFrame.Angles(math.rad(-24), 0, 0),
		Guard = CFrame.new(0, -0.38, -0.08),
		Port = CFrame.new(0.31, 0.08, -0.08),
		Shroud = CFrame.new(0, 0.03, -0.92),
		Barrel = CFrame.new(0, 0.03, -1.78) * CFrame.Angles(0, math.rad(90), 0),
		Sight = CFrame.new(0, 0.31, -2.40),
		Pump = CFrame.new(0, -0.05, -1.25),
		Muzzle = CFrame.new(0, 0.03, -2.52),
	},
	Attachments = {
		RightHandGrip = RIGHT_HAND_GRIP,
	},
}

local rearStockCenter = FirearmPresentationConfig.Offsets.Stock
	* CFrame.new(0, 0, FirearmPresentationConfig.Geometry.Stock.Z * 0.5)
local muzzleTip = FirearmPresentationConfig.Offsets.Muzzle
	* CFrame.new(0, 0, -FirearmPresentationConfig.Geometry.MuzzleFlash.Z * 0.5)
local attachments = FirearmPresentationConfig.Attachments
attachments.MuzzleReference = CFrame.new(muzzleTip.Position)
attachments.Muzzle = attachments.MuzzleReference
attachments.Foregrip = CFrame.new(FirearmPresentationConfig.Offsets.Pump.Position)
attachments.WeaponTopReference = CFrame.new(
	0,
	FirearmPresentationConfig.Geometry.Receiver.Y * 0.5,
	0
)
attachments.WeaponBottomReference = CFrame.new(
	0,
	-FirearmPresentationConfig.Geometry.Receiver.Y * 0.5,
	0
)
FirearmPresentationConfig.Attachments.StockReference = CFrame.new(rearStockCenter.Position)

return FirearmPresentationConfig
