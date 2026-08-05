local MenuCamera = {}

function MenuCamera:Attach(viewportFrame)
	local camera = Instance.new("Camera")
	camera.Name = "MenuCamera"
	camera.FieldOfView = 32
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera
	return camera
end

function MenuCamera:Frame(camera, focus, distance, elapsed)
	local sway = math.sin(elapsed * 0.32) * 0.18
	local position = focus + Vector3.new(sway, 0.25 + math.sin(elapsed * 0.24) * 0.08, distance)
	camera.CFrame = CFrame.lookAt(position, focus)
end

function MenuCamera:GetDistanceForBounds(camera, boundsSize, viewportSize)
	local verticalTangent = math.tan(math.rad(camera.FieldOfView) * 0.5)
	local aspectRatio = viewportSize.X / math.max(viewportSize.Y, 1)
	local verticalDistance = boundsSize.Y * 0.56 / verticalTangent
	local horizontalDistance = boundsSize.X * 0.56 / (verticalTangent * aspectRatio)
	return math.max(verticalDistance, horizontalDistance) + boundsSize.Z * 0.5
end

return MenuCamera
