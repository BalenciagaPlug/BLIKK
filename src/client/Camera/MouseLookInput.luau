--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before mouse look input")
local CameraConfig = require(Shared.Camera.CameraConfig)

local MouseLookInput = {}

local activeOwner: string? = nil
local accumulatedDeltaX = 0
local accumulatedDeltaY = 0
local baselineDeltaSensitivity = 1
local inputChangedConnection: RBXScriptConnection? = nil
local inputBeganConnection: RBXScriptConnection? = nil
local inputEndedConnection: RBXScriptConnection? = nil
local activeTouch: InputObject? = nil
local isInitialised = false

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function restoreBaselineSensitivity()
	if UserInputService.MouseDeltaSensitivity ~= baselineDeltaSensitivity then
		UserInputService.MouseDeltaSensitivity = baselineDeltaSensitivity
	end
end

function MouseLookInput:Init()
	if isInitialised then return end
	isInitialised = true
	baselineDeltaSensitivity = UserInputService.MouseDeltaSensitivity
	inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if activeOwner == nil or gameProcessed or activeTouch
			or input.UserInputType ~= Enum.UserInputType.Touch then return end
		local camera = workspace.CurrentCamera
		if camera and input.Position.X >= camera.ViewportSize.X * 0.42 then activeTouch = input end
	end)
	inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
		if input == activeTouch then activeTouch = nil end
	end)

	inputChangedConnection = UserInputService.InputChanged:Connect(function(input)
		if activeOwner == nil then return end
		local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
		local isTrackedTouch = input.UserInputType == Enum.UserInputType.Touch and input == activeTouch
		if not isMouse and not isTrackedTouch then return end

		local deltaX = input.Delta.X
		local deltaY = input.Delta.Y
		if not isFinite(deltaX) or not isFinite(deltaY) then return end
		accumulatedDeltaX += deltaX
		accumulatedDeltaY += deltaY
	end)
end

function MouseLookInput:Acquire(owner: string)
	assert(owner ~= "", "Mouse-look owner must be a non-empty string")
	self:Init()
	if activeOwner == nil then
		baselineDeltaSensitivity = UserInputService.MouseDeltaSensitivity
	end
	if activeOwner ~= owner then
		activeOwner = owner
		activeTouch = nil
		accumulatedDeltaX = 0
		accumulatedDeltaY = 0
	end

	local lockedScale = CameraConfig.MouseInput.DeltaSensitivityScale
	if UserInputService.MouseDeltaSensitivity ~= lockedScale then
		UserInputService.MouseDeltaSensitivity = lockedScale
	end
end

function MouseLookInput:Release(owner: string)
	if activeOwner ~= owner then return end
	activeOwner = nil
	activeTouch = nil
	accumulatedDeltaX = 0
	accumulatedDeltaY = 0
	restoreBaselineSensitivity()
end

function MouseLookInput:Flush(owner: string)
	if activeOwner == owner then
		accumulatedDeltaX = 0
		accumulatedDeltaY = 0
	end
end

function MouseLookInput:Consume(owner: string): Vector2
	if activeOwner ~= owner then return Vector2.zero end
	local delta = Vector2.new(accumulatedDeltaX, accumulatedDeltaY)
	accumulatedDeltaX = 0
	accumulatedDeltaY = 0
	return delta
end

function MouseLookInput:Destroy()
	local wasActive = activeOwner ~= nil
	if inputChangedConnection then
		inputChangedConnection:Disconnect()
		inputChangedConnection = nil
	end
	if inputBeganConnection then inputBeganConnection:Disconnect(); inputBeganConnection = nil end
	if inputEndedConnection then inputEndedConnection:Disconnect(); inputEndedConnection = nil end
	activeOwner = nil
	activeTouch = nil
	accumulatedDeltaX = 0
	accumulatedDeltaY = 0
	if wasActive then restoreBaselineSensitivity() end
	isInitialised = false
end

script.Destroying:Connect(function()
	MouseLookInput:Destroy()
end)

return MouseLookInput
