local MeleePresentationConfig = require(script.Parent.MeleePresentationConfig)
local MeleeCombatConfig = require(script.Parent.MeleeCombatConfig)

local MeleePoseSampler = {}

local function ease(alpha, easing)
	if easing == "CubicIn" then return alpha * alpha * alpha end
	if easing == "CubicOut" then
		local inverse = 1 - alpha
		return 1 - inverse * inverse * inverse
	end
	if easing == "CubicInOut" then
		return if alpha < 0.5
			then 4 * alpha * alpha * alpha
			else 1 - ((-2 * alpha + 2) ^ 3) / 2
	end
	return alpha
end

local function rotationFromDegrees(degrees)
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

local function sampleKeyframes(keyframes, elapsed)
	local previous = keyframes[1]
	local following = keyframes[#keyframes]
	for index = 2, #keyframes do
		following = keyframes[index]
		if elapsed <= following.TimeSeconds then break end
		previous = following
	end
	local duration = math.max(0.0001, following.TimeSeconds - previous.TimeSeconds)
	local alpha = math.clamp((elapsed - previous.TimeSeconds) / duration, 0, 1)
	alpha = ease(alpha, previous.EaseToNext)
	local poses = {}
	for alias, degrees in previous.Pose do
		local targetDegrees = following.Pose[alias] or degrees
		poses[alias] = rotationFromDegrees(degrees):Lerp(rotationFromDegrees(targetDegrees), alpha)
	end
	return poses
end

function MeleePoseSampler.SampleBlock(elapsed)
	return sampleKeyframes(MeleePresentationConfig.Pose.ProceduralBlock, elapsed)
end

function MeleePoseSampler.SampleAltFire(elapsed)
	return sampleKeyframes(MeleePresentationConfig.Pose.ProceduralAltFire, elapsed)
end

function MeleePoseSampler.SampleSafeFall(elapsed)
	local duration = MeleeCombatConfig.AltFire.SafeFallAnimationDurationSeconds
	local alpha = math.clamp(elapsed / math.max(duration, 0.001), 0, 1)
	local eased = alpha * alpha * (3 - 2 * alpha)
	local tuck = math.sin(math.pi * alpha)
	local brace = math.sin(math.pi * math.clamp(alpha / 0.78, 0, 1))
	-- A full turn cannot be represented by Lerp(identity, -360 degrees); author
	-- the root rotation directly so the recovery reads as a real backflip.
	return {
		Root = CFrame.Angles(math.rad(-360 * eased), 0, 0),
		Waist = CFrame.Angles(math.rad(16 * tuck), 0, 0),
		Neck = CFrame.Angles(math.rad(-13 * tuck), 0, 0),
		RightShoulder = CFrame.Angles(math.rad(-34 * brace), math.rad(8), math.rad(20 * brace)),
		LeftShoulder = CFrame.Angles(math.rad(-34 * brace), math.rad(-8), math.rad(-20 * brace)),
		RightElbow = CFrame.Angles(math.rad(-52 * tuck), 0, 0),
		LeftElbow = CFrame.Angles(math.rad(-52 * tuck), 0, 0),
		RightHip = CFrame.Angles(math.rad(76 * tuck), 0, math.rad(8 * tuck)),
		LeftHip = CFrame.Angles(math.rad(76 * tuck), 0, math.rad(-8 * tuck)),
	}
end

return MeleePoseSampler
