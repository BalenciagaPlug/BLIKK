local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before the gameplay camera")
local CameraConfig = require(Shared.Camera.CameraConfig)
local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local CharacterDependency = require(Shared.Character.CharacterDependency)
local MultiplayerConfig = require(Shared.Multiplayer.MultiplayerConfig)
local CameraObstruction = require(script.Parent.CameraObstruction)
local CameraSettings = require(script.Parent.CameraSettings)
local MouseLookInput = require(script.Parent.MouseLookInput)
local MouseLookMath = require(script.Parent.MouseLookMath)

local GameplayCamera = {}

local CAMERA_READY_ATTRIBUTE = "BLIKK_ClientCameraReady"
local MOUSE_LOOK_OWNER = "GameplayCamera"
local player = Players.LocalPlayer
local isInitialised = false
local hasWindowFocus = true
local isMenuOpen = false
local isSettingsOpen = false
local isCursorReleased = false
local yawRadians = 0
local pitchRadians = 0
local character = nil
local characterBindingTarget = nil
local characterBindGeneration = 0
local humanoid = nil
local rootPart = nil
local cancelDependencyWatch = nil
local crosshairGui = nil
local characterDiedConnection = nil
local isGameplayRequestedActive = false
local isGameplayActive = false
local gameplayBlockers = {}
local isFreeLookActive = false
local freeLookYawRadians = 0
local freeLookPitchRadians = 0
local freeLookDistanceStuds = CameraConfig.DeveloperFreeLook.FallbackDistanceStuds
local activeCamera = nil
local obstructionTargetPoints = {}
local stableAimOrigin = nil
local stableAimDirection = nil
local stableAimCamera = nil
local updateMouseCapture

local function clearStableAim()
	stableAimOrigin = nil
	stableAimDirection = nil
	stableAimCamera = nil
end

local function crosshairNumber(key, fallback)
	local value = SessionSettings:Get(key)
	return if type(value) == "number" then value else fallback
end

local function createCrosshairLine(parent, name, size, offset, rotation, opacity)
	local shadow = Instance.new("Frame")
	shadow.Name = name .. "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = math.clamp(0.18 + (1 - opacity), 0.18, 0.82)
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	shadow.Rotation = rotation or 0
	shadow.Size = UDim2.fromOffset(size.X + 2, size.Y + 2)
	shadow.ZIndex = 1
	shadow.Parent = parent

	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = CameraConfig.Crosshair.Color
	line.BackgroundTransparency = math.clamp(1 - opacity, 0, 0.75)
	line.BorderSizePixel = 0
	line.Position = shadow.Position
	line.Rotation = shadow.Rotation
	line.Size = UDim2.fromOffset(size.X, size.Y)
	line.ZIndex = 2
	line.Parent = parent
end

local function createCrosshair()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then error("[BLIKK CAMERA] PlayerGui was unavailable after bootstrap", 0) end
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
	local style = SessionSettings:Get("CrosshairStyle") or "PRECISION"
	local gap = crosshairNumber("CrosshairGap", CameraConfig.Crosshair.GapPixels)
	local length = crosshairNumber("CrosshairLength", CameraConfig.Crosshair.LineLengthPixels)
	local thickness = crosshairNumber("CrosshairThickness", CameraConfig.Crosshair.ThicknessPixels)
	local dotSize = math.clamp(math.round(crosshairNumber("CrosshairDotSize", CameraConfig.Crosshair.DotSizePixels)), 1, 10)
	local opacity = crosshairNumber("CrosshairOpacity", CameraConfig.Crosshair.Opacity)

	if style == "SHOTGUN" then
		-- Four complete brackets keep the centre readable while giving spread
		-- weapons a stronger peripheral reference.
		for _, definition in {
			{ "TLH", Vector2.new(length, thickness), Vector2.new(-(gap + length / 2), -gap), 0 },
			{ "TLV", Vector2.new(thickness, length), Vector2.new(-gap, -(gap + length / 2)), 0 },
			{ "TRH", Vector2.new(length, thickness), Vector2.new(gap + length / 2, -gap), 0 },
			{ "TRV", Vector2.new(thickness, length), Vector2.new(gap, -(gap + length / 2)), 0 },
			{ "BLH", Vector2.new(length, thickness), Vector2.new(-(gap + length / 2), gap), 0 },
			{ "BLV", Vector2.new(thickness, length), Vector2.new(-gap, gap + length / 2), 0 },
			{ "BRH", Vector2.new(length, thickness), Vector2.new(gap + length / 2, gap), 0 },
			{ "BRV", Vector2.new(thickness, length), Vector2.new(gap, gap + length / 2), 0 },
		} do
			createCrosshairLine(screenGui, definition[1], definition[2], definition[3], definition[4], opacity)
		end
	elseif style == "MELEE" then
		local radius = gap + length * 0.58
		createCrosshairLine(screenGui, "LeftUpper", Vector2.new(length, thickness), Vector2.new(-radius, -gap * 0.45), 28, opacity)
		createCrosshairLine(screenGui, "LeftLower", Vector2.new(length, thickness), Vector2.new(-radius, gap * 0.45), -28, opacity)
		createCrosshairLine(screenGui, "RightUpper", Vector2.new(length, thickness), Vector2.new(radius, -gap * 0.45), -28, opacity)
		createCrosshairLine(screenGui, "RightLower", Vector2.new(length, thickness), Vector2.new(radius, gap * 0.45), 28, opacity)
	else
		createCrosshairLine(screenGui, "Top", Vector2.new(thickness, length), Vector2.new(0, -(gap + length / 2)), 0, opacity)
		createCrosshairLine(screenGui, "Bottom", Vector2.new(thickness, length), Vector2.new(0, gap + length / 2), 0, opacity)
		createCrosshairLine(screenGui, "Left", Vector2.new(length, thickness), Vector2.new(-(gap + length / 2), 0), 0, opacity)
		createCrosshairLine(screenGui, "Right", Vector2.new(length, thickness), Vector2.new(gap + length / 2, 0), 0, opacity)
	end

	if SessionSettings:Get("CrosshairCenterDot") ~= false then
		-- This is deliberately independent from line thickness. The common
		-- centre anchor keeps every odd or even pixel size exactly on reticle centre.
		createCrosshairLine(screenGui, "CenterDot", Vector2.new(dotSize, dotSize), Vector2.zero, 0, opacity)
	end

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
	if not isFreeLookActive then return end
	isFreeLookActive = false
	MouseLookInput:Flush(MOUSE_LOOK_OWNER)
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

	if shouldCapture then
		MouseLookInput:Acquire(MOUSE_LOOK_OWNER)
	else
		MouseLookInput:Release(MOUSE_LOOK_OWNER)
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
	characterBindGeneration += 1
	local bindGeneration = characterBindGeneration
	characterBindingTarget = newCharacter
	clearStableAim()
	if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
	newCharacter:SetAttribute(CAMERA_READY_ATTRIBUTE, nil)
	cancelFreeLook()
	CameraObstruction.Reset()
	if characterDiedConnection then
		characterDiedConnection:Disconnect()
		characterDiedConnection = nil
	end

	character, humanoid, rootPart = nil, nil, nil
	updateMouseCapture()
	cancelDependencyWatch = CharacterDependency.ObserveHumanoidAndRoot(
		newCharacter,
		MultiplayerConfig.CharacterDependencyTimeoutSeconds,
		function(newHumanoid, newRootPart)
			if bindGeneration ~= characterBindGeneration
				or characterBindingTarget ~= newCharacter
				or player.Character ~= newCharacter
				or not newCharacter.Parent then return end
			character = newCharacter
			humanoid = newHumanoid
			rootPart = newRootPart
			humanoid.AutoRotate = false

			local lookVector = rootPart.CFrame.LookVector
			yawRadians = math.atan2(-lookVector.X, -lookVector.Z)
			pitchRadians = math.rad(CameraConfig.NeutralPitchDegrees)

			characterDiedConnection = humanoid.Died:Connect(function()
				cancelFreeLook()
				CameraObstruction.Reset()
				updateMouseCapture()
			end)
			newCharacter:SetAttribute(CAMERA_READY_ATTRIBUTE, true)
			updateMouseCapture()
		end,
		function()
			if bindGeneration == characterBindGeneration and player.Character == newCharacter then
				warn("[BLIKK CAMERA] Character dependencies remain incomplete; continuing to observe the current character")
			end
		end
	)
end

local function beginFreeLook()
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
	MouseLookInput:Flush(MOUSE_LOOK_OWNER)
	updateMouseCapture()
end

local function applyMouseLookDelta()
	local delta = MouseLookInput:Consume(MOUSE_LOOK_OWNER)
	local sensitivity = CameraSettings:Get("MouseSensitivityDegreesPerPixel")
	local invertY = CameraSettings:Get("InvertY")

	if isFreeLookActive then
		freeLookYawRadians, freeLookPitchRadians = MouseLookMath.ApplyDelta(
			freeLookYawRadians,
			freeLookPitchRadians,
			delta,
			sensitivity,
			invertY,
			CameraConfig.DeveloperFreeLook.PitchMinDegrees,
			CameraConfig.DeveloperFreeLook.PitchMaxDegrees
		)
	else
		yawRadians, pitchRadians = MouseLookMath.ApplyDelta(
			yawRadians,
			pitchRadians,
			delta,
			sensitivity,
			invertY,
			CameraConfig.PitchMinDegrees,
			CameraConfig.PitchMaxDegrees
		)
	end
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
		clearStableAim()
		activeCamera = currentCamera
	end

	currentCamera.CameraType = Enum.CameraType.Scriptable
	currentCamera.FieldOfView = CameraSettings:Get("FieldOfViewDegrees")
	applyMouseLookDelta()

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
		-- Gameplay aim is owned by the controller's input-integrated yaw/pitch,
		-- never by rendered character poses or a later presentation camera write.
		stableAimOrigin = resolvedPosition
		stableAimDirection = desiredCameraFrame.LookVector.Unit
		stableAimCamera = currentCamera
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

local function refreshGameplayActive()
	local nextGameplayActive = isGameplayRequestedActive and next(gameplayBlockers) == nil
	if isGameplayActive == nextGameplayActive then
		return
	end

	isGameplayActive = nextGameplayActive
	if not nextGameplayActive then
		cancelFreeLook()
		CameraObstruction.Reset()
		clearStableAim()
		local currentCamera = Workspace.CurrentCamera
		if currentCamera then currentCamera.CameraType = Enum.CameraType.Custom end
	end
	updateMouseCapture()
end

function GameplayCamera:GetFlatBasis()
	return getFlatCameraBasis()
end

function GameplayCamera:GetCrosshairAim(maximumRangeStuds, additionalExclusions)
	local currentCamera = Workspace.CurrentCamera
	if not currentCamera or currentCamera ~= stableAimCamera
		or not stableAimOrigin or not stableAimDirection
		or not isGameplayActive or isFreeLookActive then return nil end
	local exclusions = { character }
	for _, instance in additionalExclusions or {} do table.insert(exclusions, instance) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions
	params.IgnoreWater = true
	local range = math.max(1, maximumRangeStuds)
	local result = Workspace:Raycast(stableAimOrigin, stableAimDirection * range, params)
	local aimPoint = result and result.Position or stableAimOrigin + stableAimDirection * range
	return {
		Origin = stableAimOrigin,
		Direction = stableAimDirection,
		AimPoint = aimPoint,
		MaximumRangeStuds = range,
	}
end

function GameplayCamera:IsGameplayActive()
	return isGameplayActive and not isFreeLookActive
end

function GameplayCamera:SetInterfaceOpen(isOpen)
	isSettingsOpen = isOpen
	if isOpen then cancelFreeLook() end
	updateMouseCapture()
end

function GameplayCamera:SetGameplayActive(isActive)
	local nextRequestedActive = isActive == true
	if isGameplayRequestedActive == nextRequestedActive then
		return
	end

	isGameplayRequestedActive = nextRequestedActive
	refreshGameplayActive()
end

function GameplayCamera:SetGameplayBlocked(owner, blocked)
	assert(type(owner) == "string" and owner ~= "", "Gameplay blocker owner must be a non-empty string")
	local isBlocked = gameplayBlockers[owner] == true
	local shouldBlock = blocked == true
	if isBlocked == shouldBlock then
		return
	end

	if shouldBlock then
		gameplayBlockers[owner] = true
	else
		gameplayBlockers[owner] = nil
	end
	refreshGameplayActive()
end

function GameplayCamera:ResetPitchToNeutral()
	pitchRadians = math.rad(CameraConfig.NeutralPitchDegrees)
end

function GameplayCamera:Destroy()
	isGameplayRequestedActive = false
	isGameplayActive = false
	table.clear(gameplayBlockers)
	characterBindGeneration += 1
	characterBindingTarget = nil
	if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
	if character and character.Parent then character:SetAttribute(CAMERA_READY_ATTRIBUTE, nil) end
	cancelFreeLook()
	CameraObstruction.Reset()
	clearStableAim()
	RunService:UnbindFromRenderStep("BLIKKGameplayCamera")
	local currentCamera = Workspace.CurrentCamera
	if currentCamera then currentCamera.CameraType = Enum.CameraType.Custom end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	MouseLookInput:Release(MOUSE_LOOK_OWNER)
	if crosshairGui then crosshairGui.Enabled = false end
end

function GameplayCamera:Init(inputManager)
	if isInitialised then
		return
	end

	isInitialised = true
	MouseLookInput:Init()
	createCrosshair()
	SessionSettings.Changed.Event:Connect(function(key)
		if table.find({
			"CrosshairStyle", "CrosshairLength", "CrosshairThickness", "CrosshairDotSize",
			"CrosshairGap", "CrosshairOpacity", "CrosshairCenterDot",
		}, key) then
			createCrosshair()
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
		if removingCharacter == characterBindingTarget then
			characterBindGeneration += 1
			characterBindingTarget = nil
			if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
			removingCharacter:SetAttribute(CAMERA_READY_ATTRIBUTE, nil)
		end
		if removingCharacter == character then
			cancelFreeLook()
			CameraObstruction.Reset()
			clearStableAim()
			character, humanoid, rootPart = nil, nil, nil
			updateMouseCapture()
		end
	end)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		CameraObstruction.Reset()
		cancelFreeLook()
		clearStableAim()
		MouseLookInput:Flush(MOUSE_LOOK_OWNER)
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
			cancelFreeLook()
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
