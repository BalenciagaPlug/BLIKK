local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraConfig = require(Shared.Camera.CameraConfig)
local CameraSettings = require(script.Parent.CameraSettings)

local GameplayCamera = {}

local player = Players.LocalPlayer
local isInitialised = false
local hasWindowFocus = true
local isMenuOpen = false
local isSettingsOpen = false
local yawRadians = 0
local pitchRadians = 0
local character = nil
local humanoid = nil
local rootPart = nil
local crosshairGui = nil
local characterDiedConnection = nil

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
	return hasWindowFocus and not isMenuOpen and not isSettingsOpen and isCharacterAlive()
end

local function updateMouseCapture()
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
			and not isMenuOpen
			and not isSettingsOpen

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
		updateMouseCapture()
	end)

	updateMouseCapture()
end

local function updateCamera()
	if not isCharacterAlive() then
		return
	end

	updateMouseCapture()

	local currentCamera = Workspace.CurrentCamera
	if not currentCamera then
		return
	end

	currentCamera.CameraType = Enum.CameraType.Scriptable
	currentCamera.FieldOfView = CameraSettings:Get("FieldOfViewDegrees")

	local focusPosition = rootPart.Position
		+ Vector3.new(0, CameraSettings:Get("CameraHeightAboveRootStuds"), 0)
	local yawFrame = CFrame.fromOrientation(0, yawRadians, 0)
	local pitchFrame = CFrame.fromOrientation(pitchRadians, 0, 0)
	local cameraFrame = CFrame.new(focusPosition)
		* yawFrame
		* pitchFrame
		* CFrame.new(
			CameraSettings:Get("CameraRightOffsetStuds"),
			0,
			CameraSettings:Get("CameraDistanceStuds")
		)

	currentCamera.CFrame = cameraFrame

	local forward = getFlatCameraBasis()
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + forward)
end

function GameplayCamera:GetFlatBasis()
	return getFlatCameraBasis()
end

function GameplayCamera:SetInterfaceOpen(isOpen)
	isSettingsOpen = isOpen
	updateMouseCapture()
end

function GameplayCamera:ResetPitchToNeutral()
	pitchRadians = math.rad(CameraConfig.NeutralPitchDegrees)
end

function GameplayCamera:Init()
	if isInitialised then
		return
	end

	isInitialised = true
	createCrosshair()

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement or not shouldCaptureMouse() then
			return
		end

		local sensitivity = math.rad(CameraSettings:Get("MouseSensitivityDegreesPerPixel"))
		local pitchDirection = if CameraSettings:Get("InvertY") then 1 else -1
		yawRadians -= input.Delta.X * sensitivity
		pitchRadians += input.Delta.Y * sensitivity * pitchDirection
		pitchRadians = math.clamp(
			pitchRadians,
			math.rad(CameraConfig.PitchMinDegrees),
			math.rad(CameraConfig.PitchMaxDegrees)
		)
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		hasWindowFocus = false
		updateMouseCapture()
	end)

	UserInputService.WindowFocused:Connect(function()
		hasWindowFocus = true
		updateMouseCapture()
	end)

	GuiService.MenuOpened:Connect(function()
		isMenuOpen = true
		updateMouseCapture()
	end)

	GuiService.MenuClosed:Connect(function()
		isMenuOpen = false
		updateMouseCapture()
	end)

	player.CharacterAdded:Connect(bindCharacter)

	if player.Character then
		bindCharacter(player.Character)
	end

	RunService.RenderStepped:Connect(updateCamera)
end

return GameplayCamera
