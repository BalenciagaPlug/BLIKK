local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MovementConfig = require(script.Parent.MovementConfig)

local MovementEngine = {}

local isInitialised = false
local isDashing = false
local airDashCount = 0
local lastDashTime = 0
local lastDirectionPress = {}
local characterGeneration = 0
local currentHumanoid = nil
local currentRootPart = nil
local stateChangedConnection = nil
local cameraController = nil

local directionCoefficients = {
	Forward = Vector2.new(0, 1),
	Backward = Vector2.new(0, -1),
	Left = Vector2.new(-1, 0),
	Right = Vector2.new(1, 0),
}

local function isAirborne(humanoid)
	return humanoid.FloorMaterial == Enum.Material.Air
end

local function getCameraRelativeDirection(action)
	local coefficient = directionCoefficients[action]

	if not coefficient or not cameraController then
		return nil
	end

	local cameraForward, cameraRight = cameraController:GetFlatBasis()
	local direction = cameraRight * coefficient.X + cameraForward * coefficient.Y

	if direction.Magnitude <= 0 then
		return nil
	end

	return direction.Unit
end

function MovementEngine:Dash(direction, generation)
	if isDashing or generation ~= characterGeneration then
		return
	end

	local now = os.clock()

	if now - lastDashTime < MovementConfig.Dash.Cooldown then
		return
	end

	local humanoid = currentHumanoid
	local rootPart = currentRootPart

	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	local airborne = isAirborne(humanoid)

	if airborne and airDashCount >= MovementConfig.Dash.AirDashLimit then
		return
	end

	if airborne then
		airDashCount += 1
	end

	isDashing = true
	lastDashTime = now

	local startingVerticalVelocity = rootPart.AssemblyLinearVelocity.Y
	local dashDuration = MovementConfig.Dash.Duration
	local dashSpeed = MovementConfig.Dash.Distance / dashDuration
	local elapsed = 0

	while elapsed < dashDuration and generation == characterGeneration do
		local deltaTime = RunService.Heartbeat:Wait()
		elapsed += deltaTime

		if not rootPart.Parent or humanoid.Health <= 0 then
			break
		end

		local verticalVelocity = 0

		if MovementConfig.Dash.PreserveVerticalVelocity then
			verticalVelocity = startingVerticalVelocity
		end

		rootPart.AssemblyLinearVelocity = Vector3.new(
			direction.X * dashSpeed,
			verticalVelocity,
			direction.Z * dashSpeed
		)
	end

	if generation ~= characterGeneration then
		return
	end

	if rootPart.Parent then
		rootPart.AssemblyLinearVelocity = Vector3.new(
			0,
			rootPart.AssemblyLinearVelocity.Y,
			0
		)
	end

	isDashing = false
end

function MovementEngine:HandleAction(action)
	if not directionCoefficients[action] then
		return
	end

	local now = os.clock()
	local previousPress = lastDirectionPress[action]
	lastDirectionPress[action] = now

	if not previousPress or now - previousPress > MovementConfig.Dash.DoubleTapWindow then
		return
	end

	-- Capture the camera frame before yielding so turning during the dash cannot bend its path.
	local direction = getCameraRelativeDirection(action)

	if not direction then
		return
	end

	local generation = characterGeneration
	task.spawn(function()
		self:Dash(direction, generation)
	end)
end

function MovementEngine:BindCharacter(character)
	characterGeneration += 1

	if stateChangedConnection then
		stateChangedConnection:Disconnect()
		stateChangedConnection = nil
	end

	currentHumanoid = character:WaitForChild("Humanoid")
	currentRootPart = character:WaitForChild("HumanoidRootPart")
	airDashCount = 0
	isDashing = false
	lastDashTime = 0
	lastDirectionPress = {}

	stateChangedConnection = currentHumanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.RunningNoPhysics
		then
			airDashCount = 0
		end
	end)
end

function MovementEngine:Init(inputManager, gameplayCamera)
	if isInitialised then
		return
	end

	isInitialised = true
	cameraController = gameplayCamera

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		self:BindCharacter(character)
	end)

	if player.Character then
		self:BindCharacter(player.Character)
	end

	inputManager.ActionBegan.Event:Connect(function(action)
		self:HandleAction(action)
	end)

	inputManager.GameplayEnabledChanged.Event:Connect(function(isEnabled)
		if not isEnabled then
			lastDirectionPress = {}
		end
	end)
end

return MovementEngine
