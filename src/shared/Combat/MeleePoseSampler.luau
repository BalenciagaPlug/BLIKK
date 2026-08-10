local MeleePresentationConfig = require(script.Parent.MeleePresentationConfig)

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

return MeleePoseSampler
