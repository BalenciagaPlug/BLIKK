local TechniqueConfig = require(script.Parent.Parent.Movement.TechniqueConfig)

local SlashConfig = TechniqueConfig.CancelProfiles.TrainingKatana
local SLASH_ACTIVE_END_SECONDS = SlashConfig.AnticipationSeconds + SlashConfig.ActiveSeconds
local SLASH_RECOVERY_SETTLE_SECONDS = SLASH_ACTIVE_END_SECONDS + SlashConfig.RecoverySeconds * 0.53125
local SLASH_TOTAL_SECONDS = SLASH_ACTIVE_END_SECONDS + SlashConfig.RecoverySeconds
local CHARACTER_FORWARD_AXIS = -Vector3.zAxis
local HARD_LOCKED_EQUIPPED_GRIP_ROTATION = CFrame.Angles(math.rad(-54), 0, math.rad(190))
local HARD_LOCKED_IDLE_RIGHT_SHOULDER = Vector3.new(-15, -5, 8)
local HARD_LOCKED_AIRBORNE_RIGHT_SHOULDER_OFFSET = Vector3.new(-1, 0, -1)
local MINIMUM_BLADE_FORWARD_DOT = 0.55
local MAXIMUM_FRONT_SHOULDER_PITCH_DEGREES = 110

-- These values are the approved melee ready silhouette. Action presentation must
-- animate away from this baseline instead of redefining the equipped hard lock.

local MeleePresentationConfig = {
	Diagnostics = { Enabled = false },

	Slash = SlashConfig,

	Equip = { DurationSeconds = 0.12, UnequipDurationSeconds = 0.09 },
	Block = {
		EnterPresentationSeconds = 0.100,
		ExitPresentationSeconds = 0.060,
		MaximumDurationSeconds = 2.000,
	},
	AltFire = {
		ImpactSeconds = 0.180,
		TotalDurationSeconds = 0.420,
		SoundCueSeconds = 0.080,
		SoundPlaybackSpeed = 0.90,
	},
	Trail = {
		HighLifetimeSeconds = 0.16,
		MediumLifetimeSeconds = 0.09,
		DefaultOpacity = 0.28,
	},
	ContactVFX = {
		LifetimeSeconds = 0.55,
		FadeAtLifetimeFraction = 0.58,
		LengthStuds = 4.6,
		SurfaceOffsetStuds = 0.055,
		CoreWidthStuds = 0.10,
		GlowWidthStuds = 0.30,
		LightEmission = 0.85,
		Colors = {
			Damage = Color3.fromRGB(255, 105, 118),
			Guarded = Color3.fromRGB(116, 205, 255),
			Wall = Color3.fromRGB(184, 97, 255),
		},
	},

	TrainingKatana = {
		FutureMeshId = "",
		FutureSoundHooks = { Equip = "", Unequip = "", Slash = "", AltFire = "", Block = "" },
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
				* HARD_LOCKED_EQUIPPED_GRIP_ROTATION,
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
		WeaponArmPriority = 40,
		IdleBlendSpeed = 18,
		AirborneBlendSpeed = 20,
		ActionBlendSpeed = 28,
		AirReadyTorsoDegrees = -7,
		AirReadyHipDegrees = 13,
		EquippedIdle = {
			Waist = Vector3.new(-1, -4, 1),
			RightShoulder = HARD_LOCKED_IDLE_RIGHT_SHOULDER,
			RightElbow = Vector3.new(-30, 0, 0),
			RightWrist = Vector3.new(4, -4, 6),
		},
		EquippedAirborneOffsets = {
			RightShoulder = HARD_LOCKED_AIRBORNE_RIGHT_SHOULDER_OFFSET,
			RightElbow = Vector3.new(-2, 0, 0),
			RightWrist = Vector3.new(1, 0, 1),
		},
		ProceduralSlash = {
			-- Every active pose is deliberately kept in front of the torso plane. The
			-- compact shoulder arc preserves aim readability and lower-body ownership.
			WeaponArcVariants = {
				{
					{ TimeSeconds = 0.000, EaseToNext = "CubicOut", Direction = Vector3.new(0.62, 0.35, -0.70), Strength = 0.00, EdgeRollDegrees = -8 },
					{ TimeSeconds = SlashConfig.AnticipationSeconds, EaseToNext = "CubicIn", Direction = Vector3.new(0.58, 0.28, -0.76), Strength = 0.92, EdgeRollDegrees = -10 },
					{ TimeSeconds = SlashConfig.AnticipationSeconds + SlashConfig.ActiveSeconds * 0.5, EaseToNext = "Linear", Direction = Vector3.new(-0.62, -0.12, -0.78), Strength = 1.00, EdgeRollDegrees = -14 },
					{ TimeSeconds = SLASH_ACTIVE_END_SECONDS, EaseToNext = "CubicOut", Direction = Vector3.new(-0.78, -0.16, -0.60), Strength = 1.00, EdgeRollDegrees = -12 },
					{ TimeSeconds = SLASH_RECOVERY_SETTLE_SECONDS, EaseToNext = "CubicInOut", Direction = Vector3.new(-0.25, 0.15, -0.96), Strength = 0.42, EdgeRollDegrees = -6 },
					{ TimeSeconds = SLASH_TOTAL_SECONDS, Direction = Vector3.new(0.62, 0.35, -0.70), Strength = 0.00, EdgeRollDegrees = -8 },
				},
				{
					{ TimeSeconds = 0.000, EaseToNext = "CubicOut", Direction = Vector3.new(-0.42, 0.32, -0.85), Strength = 0.00, EdgeRollDegrees = 8 },
					{ TimeSeconds = SlashConfig.AnticipationSeconds, EaseToNext = "CubicIn", Direction = Vector3.new(-0.55, 0.24, -0.80), Strength = 0.92, EdgeRollDegrees = 10 },
					{ TimeSeconds = SlashConfig.AnticipationSeconds + SlashConfig.ActiveSeconds * 0.5, EaseToNext = "Linear", Direction = Vector3.new(0.62, -0.12, -0.78), Strength = 1.00, EdgeRollDegrees = 14 },
					{ TimeSeconds = SLASH_ACTIVE_END_SECONDS, EaseToNext = "CubicOut", Direction = Vector3.new(0.76, -0.16, -0.63), Strength = 1.00, EdgeRollDegrees = 12 },
					{ TimeSeconds = SLASH_RECOVERY_SETTLE_SECONDS, EaseToNext = "CubicInOut", Direction = Vector3.new(0.20, 0.14, -0.97), Strength = 0.42, EdgeRollDegrees = 6 },
					{ TimeSeconds = SLASH_TOTAL_SECONDS, Direction = Vector3.new(-0.42, 0.32, -0.85), Strength = 0.00, EdgeRollDegrees = 8 },
				},
			},
			Variants = {
				{
					{ TimeSeconds = 0.000, EaseToNext = "CubicOut", Pose = {
						Waist = Vector3.new(-1, -4, 1), Neck = Vector3.zero,
						RightShoulder = HARD_LOCKED_IDLE_RIGHT_SHOULDER, RightElbow = Vector3.new(-30, 0, 0), RightWrist = Vector3.new(4, -4, 6),
						LeftShoulder = Vector3.zero, LeftElbow = Vector3.zero, LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SlashConfig.AnticipationSeconds, EaseToNext = "CubicIn", Pose = {
						Waist = Vector3.new(-4, -18, 5), Neck = Vector3.new(1, 4, -2),
						RightShoulder = Vector3.new(82, -10, 18), RightElbow = Vector3.new(-24, 4, -5), RightWrist = Vector3.new(-28, -5, 10),
						LeftShoulder = Vector3.new(18, 5, -8), LeftElbow = Vector3.new(-6, 0, 0), LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SlashConfig.AnticipationSeconds + SlashConfig.ActiveSeconds * 0.5, EaseToNext = "Linear", Pose = {
						Waist = Vector3.new(-4, 2, 1), Neck = Vector3.new(1, -1, 0),
						RightShoulder = Vector3.new(96, -4, -4), RightElbow = Vector3.new(-12, 0, -3), RightWrist = Vector3.new(-32, 3, -7),
						LeftShoulder = Vector3.new(14, 1, -5), LeftElbow = Vector3.new(-4, 0, 0), LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SLASH_ACTIVE_END_SECONDS, EaseToNext = "CubicOut", Pose = {
						Waist = Vector3.new(-4, 20, -5), Neck = Vector3.new(1, -4, 2),
						RightShoulder = Vector3.new(70, 9, -22), RightElbow = Vector3.new(-20, -4, 5), RightWrist = Vector3.new(-42, 7, -10),
						LeftShoulder = Vector3.new(16, -5, 9), LeftElbow = Vector3.new(-4, 0, 0), LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SLASH_RECOVERY_SETTLE_SECONDS, EaseToNext = "CubicInOut", Pose = {
						Waist = Vector3.new(-2, -12, 0), Neck = Vector3.zero,
						RightShoulder = Vector3.new(22, -6, -2), RightElbow = Vector3.new(-28, 0, 2), RightWrist = Vector3.new(1, -2, 2),
						LeftShoulder = Vector3.new(5, 0, 2), LeftElbow = Vector3.zero, LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SLASH_TOTAL_SECONDS, Pose = {
						Waist = Vector3.new(-1, -4, 1), Neck = Vector3.zero,
						RightShoulder = HARD_LOCKED_IDLE_RIGHT_SHOULDER, RightElbow = Vector3.new(-30, 0, 0), RightWrist = Vector3.new(4, -4, 6),
						LeftShoulder = Vector3.zero, LeftElbow = Vector3.zero, LeftWrist = Vector3.zero,
					} },
				},
				{
					{ TimeSeconds = 0.000, EaseToNext = "CubicOut", Pose = {
						Waist = Vector3.new(-1, -4, 1), Neck = Vector3.zero,
						RightShoulder = HARD_LOCKED_IDLE_RIGHT_SHOULDER, RightElbow = Vector3.new(-30, 0, 0), RightWrist = Vector3.new(4, -4, 6),
						LeftShoulder = Vector3.zero, LeftElbow = Vector3.zero, LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SlashConfig.AnticipationSeconds, EaseToNext = "CubicIn", Pose = {
						Waist = Vector3.new(-4, 18, -5), Neck = Vector3.new(1, -4, 2),
						RightShoulder = Vector3.new(70, 9, -22), RightElbow = Vector3.new(-20, -4, 5), RightWrist = Vector3.new(-42, 7, -10),
						LeftShoulder = Vector3.new(16, -5, 9), LeftElbow = Vector3.new(-4, 0, 0), LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SlashConfig.AnticipationSeconds + SlashConfig.ActiveSeconds * 0.5, EaseToNext = "Linear", Pose = {
						Waist = Vector3.new(-4, -2, -1), Neck = Vector3.new(1, 1, 0),
						RightShoulder = Vector3.new(96, -4, 4), RightElbow = Vector3.new(-12, 0, -3), RightWrist = Vector3.new(-32, -3, 7),
						LeftShoulder = Vector3.new(14, -1, 5), LeftElbow = Vector3.new(-4, 0, 0), LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SLASH_ACTIVE_END_SECONDS, EaseToNext = "CubicOut", Pose = {
						Waist = Vector3.new(-4, -20, 5), Neck = Vector3.new(1, 4, -2),
						RightShoulder = Vector3.new(82, -10, 18), RightElbow = Vector3.new(-24, 4, -5), RightWrist = Vector3.new(-34, -5, 10),
						LeftShoulder = Vector3.new(18, 5, -8), LeftElbow = Vector3.new(-6, 0, 0), LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SLASH_RECOVERY_SETTLE_SECONDS, EaseToNext = "CubicInOut", Pose = {
						Waist = Vector3.new(-2, 10, 0), Neck = Vector3.zero,
						RightShoulder = Vector3.new(24, -7, 3), RightElbow = Vector3.new(-29, 0, -1), RightWrist = Vector3.new(3, -3, 4),
						LeftShoulder = Vector3.new(5, 0, -2), LeftElbow = Vector3.zero, LeftWrist = Vector3.zero,
					} },
					{ TimeSeconds = SLASH_TOTAL_SECONDS, Pose = {
						Waist = Vector3.new(-1, -4, 1), Neck = Vector3.zero,
						RightShoulder = HARD_LOCKED_IDLE_RIGHT_SHOULDER, RightElbow = Vector3.new(-30, 0, 0), RightWrist = Vector3.new(4, -4, 6),
						LeftShoulder = Vector3.zero, LeftElbow = Vector3.zero, LeftWrist = Vector3.zero,
					} },
				},
			},
		},
		ProceduralBlock = {
			{ TimeSeconds = 0.000, EaseToNext = "CubicOut", Pose = {
				Waist = Vector3.new(-1, -4, 1), Neck = Vector3.zero,
				RightShoulder = HARD_LOCKED_IDLE_RIGHT_SHOULDER, RightElbow = Vector3.new(-30, 0, 0), RightWrist = Vector3.new(4, -4, 6),
				LeftShoulder = Vector3.zero, LeftElbow = Vector3.zero, LeftWrist = Vector3.zero,
			} },
			{ TimeSeconds = 0.100, Pose = {
				-- Both hands form a compact high guard in front of the sternum. Keep
				-- elbow flexion shallow enough that the weapon hand cannot fold back
				-- through the hip while retaining the approved idle as frame zero.
				Waist = Vector3.new(-3, -5, 1), Neck = Vector3.new(1, 3, -1),
				RightShoulder = Vector3.new(86, -10, 24), RightElbow = Vector3.new(-20, 1, -7), RightWrist = Vector3.new(-12, -7, -14),
				LeftShoulder = Vector3.new(76, 9, -23), LeftElbow = Vector3.new(-24, 0, 8), LeftWrist = Vector3.new(-8, 7, 12),
			} },
		},
		ProceduralBlockWeapon = {
			-- Diagonal guard crosses the chest in the front torso half-space.
			-- The right hand supplies the pivot; this direction keeps the blade
			-- between incoming attacks and the head/upper torso.
			Direction = Vector3.new(-0.48, 0.57, -0.67),
			EdgeRollDegrees = -12,
		},
		ProceduralAltFire = {
			{ TimeSeconds = 0.000, EaseToNext = "CubicOut", Pose = {
				Root = Vector3.zero, Waist = Vector3.new(-1, -4, 1), Neck = Vector3.zero,
				RightShoulder = HARD_LOCKED_IDLE_RIGHT_SHOULDER, RightElbow = Vector3.new(-30, 0, 0), RightWrist = Vector3.new(4, -4, 6),
				LeftShoulder = Vector3.zero, LeftElbow = Vector3.zero, LeftWrist = Vector3.zero,
				LeftHip = Vector3.zero, RightHip = Vector3.zero,
			} },
			{ TimeSeconds = 0.080, EaseToNext = "CubicIn", Pose = {
				Root = Vector3.new(5, 0, 0), Waist = Vector3.new(15, -16, 5), Neck = Vector3.new(-5, 8, -2),
				RightShoulder = Vector3.new(38, -18, 42), RightElbow = Vector3.new(-68, 0, -8), RightWrist = Vector3.new(18, -10, -24),
				LeftShoulder = Vector3.new(25, 10, -20), LeftElbow = Vector3.new(-32, 0, 5), LeftWrist = Vector3.zero,
				LeftHip = Vector3.new(-8, 0, -4), RightHip = Vector3.new(-10, 0, 4),
			} },
			{ TimeSeconds = 0.180, EaseToNext = "CubicOut", Pose = {
				Root = Vector3.new(-8, 0, 0), Waist = Vector3.new(-18, 9, -4), Neck = Vector3.new(7, -5, 2),
				RightShoulder = Vector3.new(104, -7, -18), RightElbow = Vector3.new(-18, 0, 2), RightWrist = Vector3.new(-38, 4, -8),
				LeftShoulder = Vector3.new(66, -8, 22), LeftElbow = Vector3.new(-20, 0, -3), LeftWrist = Vector3.zero,
				LeftHip = Vector3.new(12, 0, -3), RightHip = Vector3.new(7, 0, 3),
			} },
			{ TimeSeconds = 0.285, EaseToNext = "CubicInOut", Pose = {
				Root = Vector3.new(-3, 0, 0), Waist = Vector3.new(-8, 13, -2), Neck = Vector3.new(3, -5, 1),
				RightShoulder = Vector3.new(104, 4, -22), RightElbow = Vector3.new(-25, 0, 4), RightWrist = Vector3.new(-25, 5, -7),
				LeftShoulder = Vector3.new(34, -4, 14), LeftElbow = Vector3.new(-15, 0, 0), LeftWrist = Vector3.zero,
				LeftHip = Vector3.new(5, 0, -2), RightHip = Vector3.new(3, 0, 2),
			} },
			{ TimeSeconds = 0.420, Pose = {
				Root = Vector3.zero, Waist = Vector3.new(-1, -4, 1), Neck = Vector3.zero,
				RightShoulder = HARD_LOCKED_IDLE_RIGHT_SHOULDER, RightElbow = Vector3.new(-30, 0, 0), RightWrist = Vector3.new(4, -4, 6),
				LeftShoulder = Vector3.zero, LeftElbow = Vector3.zero, LeftWrist = Vector3.zero,
				LeftHip = Vector3.zero, RightHip = Vector3.zero,
			} },
		},
	},
}

local function validateActionFrontFacingPose(pose, label)
	for _, alias in { "RightShoulder", "LeftShoulder" } do
		local degrees = pose[alias]
		if degrees then
			assert(
				degrees.X >= 0 and degrees.X <= MAXIMUM_FRONT_SHOULDER_PITCH_DEGREES,
				string.format("%s %s pitch must remain in the front-facing range", label, alias)
			)
		end
	end
end

assert(
	MeleePresentationConfig.Pose.EquippedIdle.RightShoulder == HARD_LOCKED_IDLE_RIGHT_SHOULDER,
	"Training Katana equipped idle must retain the approved hard-locked right shoulder"
)
assert(
	MeleePresentationConfig.Pose.EquippedAirborneOffsets.RightShoulder
		== HARD_LOCKED_AIRBORNE_RIGHT_SHOULDER_OFFSET,
	"Training Katana airborne idle must retain the approved hard-locked shoulder offset"
)

for variantIndex, keyframes in MeleePresentationConfig.Pose.ProceduralSlash.Variants do
	-- First and last frames are the approved ready pose. Only the action frames
	-- are constrained to the procedural forward-facing animation convention.
	for keyframeIndex = 2, #keyframes - 1 do
		local keyframe = keyframes[keyframeIndex]
		validateActionFrontFacingPose(
			keyframe.Pose,
			string.format("Slash variant %d keyframe %d", variantIndex, keyframeIndex)
		)
	end
end

for variantIndex, keyframes in MeleePresentationConfig.Pose.ProceduralSlash.WeaponArcVariants do
	for keyframeIndex, keyframe in keyframes do
		assert(
			keyframe.Direction.Unit:Dot(CHARACTER_FORWARD_AXIS) >= MINIMUM_BLADE_FORWARD_DOT,
			string.format(
				"Slash variant %d weapon keyframe %d must remain in the forward half-space",
				variantIndex,
				keyframeIndex
			)
		)
	end
end

for keyframeIndex = 2, #MeleePresentationConfig.Pose.ProceduralBlock do
	local keyframe = MeleePresentationConfig.Pose.ProceduralBlock[keyframeIndex]
	validateActionFrontFacingPose(keyframe.Pose, string.format("Block keyframe %d", keyframeIndex))
end

assert(
	MeleePresentationConfig.Pose.ProceduralBlockWeapon.Direction.Unit:Dot(CHARACTER_FORWARD_AXIS)
		>= MINIMUM_BLADE_FORWARD_DOT,
	"Block weapon direction must remain in the forward half-space"
)

for keyframeIndex = 2, #MeleePresentationConfig.Pose.ProceduralAltFire - 1 do
	local keyframe = MeleePresentationConfig.Pose.ProceduralAltFire[keyframeIndex]
	validateActionFrontFacingPose(keyframe.Pose, string.format("Alt-fire keyframe %d", keyframeIndex))
end

return MeleePresentationConfig
