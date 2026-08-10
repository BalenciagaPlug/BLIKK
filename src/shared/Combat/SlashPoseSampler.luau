local MeleePresentationConfig = require(script.Parent.MeleePresentationConfig)

local SlashPoseSampler = {}

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

function SlashPoseSampler.Sample(variant, elapsed)
	local variants = MeleePresentationConfig.Pose.ProceduralSlash.Variants
	local keyframes = variants[variant] or variants[1]
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

local function sampleWeaponArc(variant, elapsed)
	local variants = MeleePresentationConfig.Pose.ProceduralSlash.WeaponArcVariants
	local keyframes = variants[variant] or variants[1]
	local previous = keyframes[1]
	local following = keyframes[#keyframes]
	for index = 2, #keyframes do
		following = keyframes[index]
		if elapsed <= following.TimeSeconds then break end
		previous = following
	end
	local duration = math.max(0.0001, following.TimeSeconds - previous.TimeSeconds)
	local alpha = ease(math.clamp((elapsed - previous.TimeSeconds) / duration, 0, 1), previous.EaseToNext)
	local direction = previous.Direction:Lerp(following.Direction, alpha)
	local strength = previous.Strength + (following.Strength - previous.Strength) * alpha
	local edgeRoll = previous.EdgeRollDegrees
		+ (following.EdgeRollDegrees - previous.EdgeRollDegrees) * alpha
	return direction.Unit, strength, edgeRoll
end

function SlashPoseSampler.ApplyWeaponDirection(grip, root, localDirection, edgeRoll, strength)
	if not grip or not grip.Parent or not grip.Part0 or not root or not root.Parent then return false end
	if typeof(localDirection) ~= "Vector3" or localDirection.Magnitude < 0.001 then return false end
	strength = math.clamp(strength or 1, 0, 1)
	edgeRoll = edgeRoll or 0
	if strength <= 0 then
		grip.Transform = CFrame.identity
		return true
	end
	local bladeDirection = root.CFrame:VectorToWorldSpace(localDirection.Unit).Unit
	-- C0 is the approved equipped katana basis and local +Y is grip-to-tip.
	-- Rotate that existing basis by the shortest arc instead of rebuilding an
	-- unrelated world frame; rebuilding discarded the approved roll axis and
	-- could invert the blade through the character's hip during block.
	local basePivot = grip.Part0.CFrame * grip.C0
	local approvedBladeDirection = basePivot.UpVector
	local dot = math.clamp(approvedBladeDirection:Dot(bladeDirection), -1, 1)
	local axisWorld = approvedBladeDirection:Cross(bladeDirection)
	local alignment
	if axisWorld.Magnitude > 0.0001 then
		local axisLocal = basePivot:VectorToObjectSpace(axisWorld.Unit)
		alignment = CFrame.fromAxisAngle(axisLocal, math.acos(dot))
	elseif dot < 0 then
		alignment = CFrame.fromAxisAngle(Vector3.xAxis, math.pi)
	else
		alignment = CFrame.identity
	end
	local actionRotation = alignment * CFrame.Angles(0, math.rad(edgeRoll), 0)
	local desiredPivot = basePivot * actionRotation
	if desiredPivot.UpVector:Dot(bladeDirection) < 0.995 then return false end
	grip.Transform = CFrame.identity:Lerp(actionRotation, strength)
	return true
end

function SlashPoseSampler.ApplyWeaponArc(grip, root, variant, elapsed)
	local localDirection, strength, edgeRoll = sampleWeaponArc(variant, elapsed)
	return SlashPoseSampler.ApplyWeaponDirection(
		grip,
		root,
		localDirection,
		edgeRoll,
		strength
	)
end

function SlashPoseSampler.ResetWeaponArc(grip)
	if grip and grip.Parent then grip.Transform = CFrame.identity end
end

return SlashPoseSampler
