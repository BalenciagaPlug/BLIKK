--!strict

local MouseLookMath = {}

local function normaliseYaw(yawRadians: number): number
	return math.atan2(math.sin(yawRadians), math.cos(yawRadians))
end

function MouseLookMath.ApplyDelta(
	yawRadians: number,
	pitchRadians: number,
	delta: Vector2,
	sensitivityDegreesPerPixel: number,
	invertY: boolean,
	pitchMinimumDegrees: number,
	pitchMaximumDegrees: number
): (number, number)
	if delta == Vector2.zero then
		return yawRadians, pitchRadians
	end

	local gainRadiansPerPixel = math.rad(sensitivityDegreesPerPixel)
	local pitchDirection = if invertY then 1 else -1
	local nextYaw = normaliseYaw(yawRadians - delta.X * gainRadiansPerPixel)
	local nextPitch = pitchRadians + delta.Y * gainRadiansPerPixel * pitchDirection

	return nextYaw, math.clamp(
		nextPitch,
		math.rad(pitchMinimumDegrees),
		math.rad(pitchMaximumDegrees)
	)
end

return MouseLookMath
