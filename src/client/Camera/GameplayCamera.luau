local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraConfig = require(Shared.Camera.CameraConfig)
local CameraObstruction = require(script.Parent.CameraObstruction)
local CameraSettings = require(script.Parent.CameraSettings)

local GameplayCamera = {}

local player = Players.LocalPlayer
local isInitialised = false
local hasWindowFocus = true
local isMenuOpen = false
local isSettingsOpen = false
local isCursorReleased = false
local yawRadians = 0
local pitchRadians = 0
local character = nil
local humanoid = nil
local rootPart = nil
local crosshairGui = nil
local characterDiedConnection = nil
local dashFovOffsetDegrees = 0
local isGameplayActive = false
local isFreeLookActive = false
local freeLookHoldCount = 0
local freeLookYawRadians = 0
local freeLookPitchRadians = 0
local freeLookDistanceStuds = CameraConfig.DeveloperFreeLook.FallbackDistanceStuds
local activeCamera = nil
local obstructionTargetPoints = {}
local updateMouseCapture

local function createCrosshairLine(name, size, position)
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = position
	line.Size = size
	line.BackgroundColor3 = CameraConfig.Crosshair.Color
	line.BackgroundTransparency = CameraConfig.Crosshair.Transparency
	line.BorderSizePixel = 0
	return line
end

local function createCrosshair()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BLIKKCrosshair")

	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BLIKKCrosshair"
	screenGui.DisplayOrder = CameraConfig.Crosshair.DisplayOrder
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local gap = CameraConfig.Crosshair.GapPixels
	local length = CameraConfig.Crosshair.LineLengthPixels
	local thickness = CameraConfig.Crosshair.ThicknessPixels

	createCrosshairLine(
		"Top",
		UDim2.fromOffset(thickness, length),
		UDim2.new(0.5, 0, 0.5, -(gap + length / 2))
	).Parent = screenGui
	createCrosshairLine(
		"Bottom",
		UDim2.fromOffset(thickness, length),
		UDim2.new(0.5, 0, 0.5, gap + length / 2)
	).Parent = screenGui
	createCrosshairLine(
		"Left",
		UDim2.fromOffset(length, thickness),
		UDim2.new(0.5, -(gap + length / 2), 0.5, 0)
	).Parent = screenGui
	createCrosshairLine(
		"Right",
		UDim2.fromOffset(length, thickness),
		UDim2.new(0.5, gap + length / 2, 0.5, 0)
	).Parent = screenGui

	screenGui.Parent = playerGui
	crosshairGui = screenGui
end

local function isCharacterAlive()
	return character ~= nil
		and character.Parent ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and rootPart ~= nil
		and rootPart.Parent ~= nil
end

local function shouldCaptureMouse()
	return hasWindowFocus
		and isGameplayActive
		and not isMenuOpen
		and not isSettingsOpen
		and not isCursorReleased
		and isCharacterAlive()
end

local function cancelFreeLook()
	freeLookHoldCount = 0
	if not isFreeLookActive then return end
	isFreeLookActive = false
	updateMouseCapture()
end

updateMouseCapture = function()
	local shouldCapture = shouldCaptureMouse()
	local mouseIconEnabled = not shouldCapture
	local mouseBehavior = Enum.MouseBehavior.Default

	if shouldCapture then
		mouseBehavior = Enum.MouseBehavior.LockCenter
	end

	if UserInputService.MouseIconEnabled ~= mouseIconEnabled then
		UserInputService.MouseIconEnabled = mouseIconEnabled
	end

	if UserInputService.MouseBehavior ~= mouseBehavior then
		UserInputService.MouseBehavior = mouseBehavior
	end

	if crosshairGui then
		local crosshairEnabled = isCharacterAlive()
			and isGameplayActive
			and not isMenuOpen
			and not isSettingsOpen
			and not isCursorReleased
			and not isFreeLookActive

		if crosshairGui.Enabled ~= crosshairEnabled then
			crosshairGui.Enabled = crosshairEnabled
		end
	end
end

local function getFlatCameraBasis()
	local yawFrame = CFrame.fromOrientation(0, yawRadians, 0)
	return yawFrame.LookVector, yawFrame.RightVector
end

local function bindCharacter(newCharacter)
	cancelFreeLook()
	CameraObstruction.Reset()
	if characterDiedConnection then
		characterDiedConnection:Disconnect()
		characterDiedConnection = nil
	end

	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	rootPart = newCharacter:WaitForChild("HumanoidRootPart")
	humanoid.AutoRotate = false

	local lookVector = rootPart.CFrame.LookVector
	yawRadians = math.atan2(-lookVector.X, -lookVector.Z)
	pitchRadians = math.rad(CameraConfig.NeutralPitchDegrees)

	characterDiedConnection = humanoid.Died:Connect(function()
		cancelFreeLook()
		CameraObstruction.Reset()
		updateMouseCapture()
	end)

	updateMouseCapture()
end

local function beginFreeLook()
	freeLookHoldCount += 1
	if isFreeLookActive then return end
	if not CameraConfig.DeveloperFreeLook.Enabled
		or not isGameplayActive
		or isSettingsOpen
		or isMenuOpen
		or not isCharacterAlive()
	then
		return
	end

	local currentCamera = Workspace.CurrentCamera
	if not currentCamera then return end
	local targetPosition = rootPart.Position
		+ Vector3.new(0, CameraConfig.DeveloperFreeLook.TargetVerticalOffsetStuds, 0)
	local offset = currentCamera.CFrame.Position - targetPosition
	local distance = offset.Magnitude
	if distance <= 0 then
		distance = CameraConfig.DeveloperFreeLook.FallbackDistanceStuds
		offset = Vector3.new(0, 0, distance)
	end

	freeLookDistanceStuds = math.clamp(
		distance,
		CameraConfig.DeveloperFreeLook.MinimumDistanceStuds,
		CameraConfig.DeveloperFreeLook.MaximumDistanceStuds
	)
	local unitOffset = offset.Unit
	freeLookYawRadians = math.atan2(unitOffset.X, unitOffset.Z)
	freeLookPitchRadians = -math.asin(math.clamp(unitOffset.Y, -1, 1))
	isFreeLookActive = true
	updateMouseCapture()
end

local function getFreeLookCameraFrame(targetPosition)
	local cosine = math.cos(freeLookPitchRadians)
	local offset = Vector3.new(
		math.sin(freeLookYawRadians) * cosine,
		-math.sin(freeLookPitchRadians),
		math.cos(freeLookYawRadians) * cosine
	) * freeLookDistanceStuds
	local position = targetPosition + offset
	return CFrame.lookAt(position, targetPosition)
end

local function updateObstructionTargets()
	table.clear(obstructionTargetPoints)
	for _, offset in CameraConfig.Obstruction.TargetOffsetsStuds do
		table.insert(obstructionTargetPoints, rootPart.Position + offset)
	end
end

local function updateCamera(deltaTime)
	if not isGameplayActive then
		return
	end
	if not isCharacterAlive() then
		return
	end

	local currentCamera = Workspace.CurrentCamera
	if not currentCamera then
		return
	end
	if currentCamera ~= activeCamera then
		CameraObstruction.Reset()
		cancelFreeLook()
		activeCamera = currentCamera
	end

	currentCamera.CameraType = Enum.CameraType.Scriptable
	currentCamera.FieldOfView = CameraSettings:Get("FieldOfViewDegrees") + dashFovOffsetDegrees

	local targetPosition
	local desiredCameraFrame
	if isFreeLookActive then
		targetPosition = rootPart.Position
			+ Vector3.new(0, CameraConfig.DeveloperFreeLook.TargetVerticalOffsetStuds, 0)
		desiredCameraFrame = getFreeLookCameraFrame(targetPosition)
	else
		targetPosition = rootPart.Position
			+ Vector3.new(0, CameraSettings:Get("CameraHeightAboveRootStuds"), 0)
		local yawFrame = CFrame.fromOrientation(0, yawRadians, 0)
		local pitchFrame = CFrame.fromOrientation(pitchRadians, 0, 0)
		desiredCameraFrame = CFrame.new(targetPosition)
			* yawFrame
			* pitchFrame
			* CFrame.new(
				CameraSettings:Get("CameraRightOffsetStuds"),
				0,
				CameraSettings:Get("CameraDistanceStuds")
			)
	end

	local resolvedPosition = CameraObstruction.ResolvePosition(
		targetPosition,
		desiredCameraFrame.Position,
		character,
		CameraConfig.Obstruction,
		deltaTime
	)
	if isFreeLookActive then
		currentCamera.CFrame = CFrame.lookAt(resolvedPosition, targetPosition)
	else
		currentCamera.CFrame = CFrame.new(resolvedPosition) * desiredCameraFrame.Rotation
		local forward = getFlatCameraBasis()
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + forward)
	end

	updateObstructionTargets()
	CameraObstruction.UpdateFades(
		currentCamera,
		obstructionTargetPoints,
		character,
		CameraConfig.Obstruction,
		deltaTime
	)
	updateMouseCapture()
end

function GameplayCamera:GetFlatBasis()
	return getFlatCameraBasis()
end

function GameplayCamera:SetInterfaceOpen(isOpen)
	isSettingsOpen = isOpen
	if isOpen then cancelFreeLook() end
	updateMouseCapture()
end

function GameplayCamera:SetGameplayActive(isActive)
	isGameplayActive = isActive
	if not isActive then
		cancelFreeLook()
		CameraObstruction.Reset()
		dashFovOffsetDegrees = 0
		local currentCamera = Workspace.CurrentCamera
		if currentCamera then currentCamera.CameraType = Enum.CameraType.Custom end
	end
	updateMouseCapture()
end

function GameplayCamera:ResetPitchToNeutral()
	pitchRadians = math.rad(CameraConfig.NeutralPitchDegrees)
end

function GameplayCamera:SetDashFovOffset(offsetDegrees)
	dashFovOffsetDegrees = offsetDegrees
end

function GameplayCamera:Destroy()
	isGameplayActive = false
	cancelFreeLook()
	CameraObstruction.Reset()
	RunService:UnbindFromRenderStep("BLIKKGameplayCamera")
	local currentCamera = Workspace.CurrentCamera
	if currentCamera then currentCamera.CameraType = Enum.CameraType.Custom end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	if crosshairGui then crosshairGui.Enabled = false end
end

function GameplayCamera:Init(inputManager)
	if isInitialised then
		return
	end

	isInitialised = true
	createCrosshair()

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement or not shouldCaptureMouse() then
			return
		end

		if isFreeLookActive then
			local sensitivity = math.rad(CameraSettings:Get("MouseSensitivityDegreesPerPixel"))
			local pitchDirection = if CameraSettings:Get("InvertY") then 1 else -1
			freeLookYawRadians -= input.Delta.X * sensitivity
			freeLookPitchRadians += input.Delta.Y * sensitivity * pitchDirection
			freeLookPitchRadians = math.clamp(
				freeLookPitchRadians,
				math.rad(CameraConfig.DeveloperFreeLook.PitchMinDegrees),
				math.rad(CameraConfig.DeveloperFreeLook.PitchMaxDegrees)
			)
		else
			local sensitivity = math.rad(CameraSettings:Get("MouseSensitivityDegreesPerPixel"))
			local pitchDirection = if CameraSettings:Get("InvertY") then 1 else -1
			yawRadians -= input.Delta.X * sensitivity
			pitchRadians += input.Delta.Y * sensitivity * pitchDirection
			pitchRadians = math.clamp(
				pitchRadians,
				math.rad(CameraConfig.PitchMinDegrees),
				math.rad(CameraConfig.PitchMaxDegrees)
			)
		end
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		hasWindowFocus = false
		cancelFreeLook()
		updateMouseCapture()
	end)

	UserInputService.WindowFocused:Connect(function()
		hasWindowFocus = true
		updateMouseCapture()
	end)

	GuiService.MenuOpened:Connect(function()
		isMenuOpen = true
		cancelFreeLook()
		updateMouseCapture()
	end)

	GuiService.MenuClosed:Connect(function()
		isMenuOpen = false
		updateMouseCapture()
	end)

	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(removingCharacter)
		if removingCharacter == character then
			cancelFreeLook()
			CameraObstruction.Reset()
			character, humanoid, rootPart = nil, nil, nil
		end
	end)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		CameraObstruction.Reset()
		cancelFreeLook()
		activeCamera = Workspace.CurrentCamera
	end)

	if player.Character then
		bindCharacter(player.Character)
	end

	RunService:BindToRenderStep(
		"BLIKKGameplayCamera",
		Enum.RenderPriority.Camera.Value + 1,
		updateCamera
	)

	inputManager.ActionBegan.Event:Connect(function(action)
		if action == "ReleaseCursor" then
			isCursorReleased = true
			updateMouseCapture()
		elseif action == "DeveloperFreeLook" then
			beginFreeLook()
		end
	end)
	inputManager.ActionEnded.Event:Connect(function(action)
		if action == "ReleaseCursor" then
			isCursorReleased = false
			updateMouseCapture()
		elseif action == "DeveloperFreeLook" then
			freeLookHoldCount = math.max(0, freeLookHoldCount - 1)
			if freeLookHoldCount == 0 then cancelFreeLook() end
		end
	end)
	inputManager.SuppressionChanged.Event:Connect(function(suppressed)
		if suppressed then cancelFreeLook() end
	end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		if not enabled then cancelFreeLook() end
	end)
	script.Destroying:Connect(function()
		self:Destroy()
	end)
end

return GameplayCamera
