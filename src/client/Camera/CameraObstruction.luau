local Workspace = game:GetService("Workspace")

local CameraObstruction = {}

local trackedParts = {}
local raycastParams = RaycastParams.new()
local resolvedDistance = nil

local function isCharacterPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function restorePart(part, state)
	if part.Parent then
		part.LocalTransparencyModifier = state.OriginalTransparency
	end
	trackedParts[part] = nil
end

function CameraObstruction.Reset()
	for part, state in trackedParts do
		if part.Parent then
			part.LocalTransparencyModifier = state.OriginalTransparency
		end
	end
	table.clear(trackedParts)
	resolvedDistance = nil
end

function CameraObstruction.ResolvePosition(targetPosition, desiredPosition, character, config, deltaTime)
	local offset = desiredPosition - targetPosition
	local desiredDistance = offset.Magnitude
	if desiredDistance <= 0 then
		resolvedDistance = nil
		return desiredPosition
	end

	local direction = offset / desiredDistance
	local allowedDistance = desiredDistance
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = false

	local result = Workspace:Spherecast(
		targetPosition,
		config.CollisionRadiusStuds,
		direction * desiredDistance,
		raycastParams
	)
	if result then
		local collisionDistance = math.max(0, result.Distance - config.CollisionPaddingStuds)
		if result.Distance >= config.MinimumCameraDistanceStuds + config.CollisionPaddingStuds then
			allowedDistance = math.max(config.MinimumCameraDistanceStuds, collisionDistance)
		else
			allowedDistance = collisionDistance
		end
	end

	if resolvedDistance == nil then
		resolvedDistance = allowedDistance
	elseif allowedDistance < resolvedDistance then
		resolvedDistance = allowedDistance
	else
		local restoreAlpha = 1 - math.exp(-config.DistanceRestoreSpeed * deltaTime)
		resolvedDistance += (allowedDistance - resolvedDistance) * restoreAlpha
	end
	resolvedDistance = math.clamp(resolvedDistance, 0, desiredDistance)
	return targetPosition + direction * resolvedDistance
end

function CameraObstruction.UpdateFades(camera, targetPoints, character, config, deltaTime)
	for _, state in trackedParts do
		state.IsTarget = false
	end

	local obstructingParts = camera:GetPartsObscuringTarget(targetPoints, { character })
	for _, part in obstructingParts do
		local state = trackedParts[part]
		if state then state.IsTarget = true end
	end

	local trackedCount = 0
	for _ in trackedParts do trackedCount += 1 end
	for _, part in obstructingParts do
		if trackedCount >= config.MaximumFadedParts then break end
		if part:IsA("BasePart")
			and part.Parent
			and not part:IsDescendantOf(character)
			and not isCharacterPart(part)
			and not trackedParts[part]
		then
			trackedParts[part] = {
				OriginalTransparency = part.LocalTransparencyModifier,
				CurrentTransparency = part.LocalTransparencyModifier,
				IsTarget = true,
			}
			trackedCount += 1
		end
	end

	for part, state in trackedParts do
		if not part.Parent then
			trackedParts[part] = nil
			continue
		end
		local targetTransparency = if state.IsTarget
			then math.max(state.OriginalTransparency, config.FadeLocalTransparency)
			else state.OriginalTransparency
		local speed = if state.IsTarget then config.FadeInSpeed else config.FadeOutSpeed
		local alpha = 1 - math.exp(-speed * deltaTime)
		state.CurrentTransparency += (targetTransparency - state.CurrentTransparency) * alpha
		part.LocalTransparencyModifier = state.CurrentTransparency
		if not state.IsTarget and math.abs(state.CurrentTransparency - state.OriginalTransparency) < 0.01 then
			restorePart(part, state)
		end
	end
end

return CameraObstruction
