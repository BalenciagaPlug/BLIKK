local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MovementConfig = require(script.Parent.MovementConfig)

local MovementEngine = {}

local isInitialised = false
local isDashing = false
local airDashCount = 0
local lastDashTime = 0
local lastDirectionPress = {}

local directionVectors = {
	Forward = Vector3.new(0, 0, -1),
	Backward = Vector3.new(0, 0, 1),
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
}

local function getCharacterParts()
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()

	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")

	return character, humanoid, rootPart
end

local function isAirborne(humanoid)
	return humanoid.FloorMaterial == Enum.Material.Air
end

local function getWorldDirection(rootPart, action)
	local localDirection = directionVectors[action]

	if not localDirection then
		return nil
	end

	local worldDirection = rootPart.CFrame:VectorToWorldSpace(localDirection)
	local flatDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z)

	if flatDirection.Magnitude <= 0 then
		return nil
	end

	return flatDirection.Unit
end

function MovementEngine:Dash(action)
	if isDashing then
		return
	end

	local now = os.clock()

	if now - lastDashTime < MovementConfig.Dash.Cooldown then
		return
	end

	local _, humanoid, rootPart = getCharacterParts()

	if humanoid.Health <= 0 then
		return
	end

	local airborne = isAirborne(humanoid)

	if airborne and airDashCount >= MovementConfig.Dash.AirDashLimit then
		print("[BLIKK] Air dash unavailable")
		return
	end

	local direction = getWorldDirection(rootPart, action)

	if not direction then
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

	while elapsed < dashDuration do
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

	if rootPart.Parent then
		rootPart.AssemblyLinearVelocity = Vector3.new(
			0,
			rootPart.AssemblyLinearVelocity.Y,
			0
		)
	end

	isDashing = false

	print("[BLIKK] Dash complete:", action, airborne and "Air" or "Ground")
end

function MovementEngine:HandleAction(action)
	if not directionVectors[action] then
		return
	end

	local now = os.clock()
	local previousPress = lastDirectionPress[action]

	lastDirectionPress[action] = now

	if previousPress
		and now - previousPress <= MovementConfig.Dash.DoubleTapWindow then
		task.spawn(function()
			self:Dash(action)
		end)
	end
end

function MovementEngine:BindCharacter()
	local _, humanoid = getCharacterParts()

	airDashCount = 0
	isDashing = false

	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.RunningNoPhysics then
			airDashCount = 0
		end
	end)
end

function MovementEngine:Init(inputManager)
	if isInitialised then
		return
	end

	isInitialised = true

	local player = Players.LocalPlayer

	self:BindCharacter()

	player.CharacterAdded:Connect(function()
		self:BindCharacter()
	end)

	inputManager.ActionBegan.Event:Connect(function(action)
		self:HandleAction(action)
	end)

	print("[BLIKK] Movement Engine Initialised")
end

return MovementEngine