local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MovementConfig = require(script.Parent.MovementConfig)

local MovementEngine = {}
MovementEngine.DashStarted = Instance.new("BindableEvent")
MovementEngine.DashUpdated = Instance.new("BindableEvent")
MovementEngine.DashEnded = Instance.new("BindableEvent")

local config = MovementConfig.Dash
local isInitialised = false
local airDashCount = 0
local lastDashTime = -math.huge
local lastDirectionPress = {}
local generation = 0
local humanoid = nil
local rootPart = nil
local stateConnection = nil
local cameraController = nil
local heldDirections = {}
local dashState = nil

local function diagnose(message)
	if config.Diagnostics.Enabled then print("[BLIKK DASH] " .. message) end
end

local directions = {
	Forward = Vector2.new(0, 1), Backward = Vector2.new(0, -1),
	Left = Vector2.new(-1, 0), Right = Vector2.new(1, 0),
}

local function flatDirection(action)
	local coefficient = directions[action]
	if not coefficient or not cameraController then return nil end
	local forward, right = cameraController:GetFlatBasis()
	local direction = right * coefficient.X + forward * coefficient.Y
	return if direction.Magnitude > 0 then direction.Unit else nil
end

local function updateWalking()
	if not humanoid or humanoid.Health <= 0 or not cameraController then return end
	if dashState then
		humanoid:Move(Vector3.zero, false)
		return
	end
	local forward, right = cameraController:GetFlatBasis()
	local movement = Vector3.zero
	for action in heldDirections do
		local coefficient = directions[action]
		movement += right * coefficient.X + forward * coefficient.Y
	end
	if movement.Magnitude > 1 then movement = movement.Unit end
	humanoid:Move(movement, false)
end

local function phaseAt(elapsed)
	local entryEnd = config.EntryDurationSeconds
	local travelEnd = entryEnd + config.TravelDurationSeconds
	if elapsed < entryEnd then
		return "Entry", elapsed / entryEnd, config.EntrySpeedMultiplier, config.PeakSpeedMultiplier
	elseif elapsed < travelEnd then
		return "Travel", (elapsed - entryEnd) / config.TravelDurationSeconds,
			config.PeakSpeedMultiplier, config.TravelEndSpeedMultiplier
	end
	return "Exit", (elapsed - travelEnd) / config.ExitDurationSeconds,
		config.TravelEndSpeedMultiplier, config.ExitMomentumRetention
end

local function curveArea()
	return config.EntryDurationSeconds * (config.EntrySpeedMultiplier + config.PeakSpeedMultiplier) / 2
		+ config.TravelDurationSeconds * (config.PeakSpeedMultiplier + config.TravelEndSpeedMultiplier) / 2
		+ config.ExitDurationSeconds * (config.TravelEndSpeedMultiplier + config.ExitMomentumRetention) / 2
end

local function finishDash(interrupted)
	local state = dashState
	if not state then return end
	dashState = nil
	if rootPart and state.StartPosition then
		diagnose(string.format("%s end interrupted=%s displacement=%.2f duration=%.3f peak=%.2f", state.Action, tostring(interrupted), (rootPart.Position - state.StartPosition).Magnitude, state.Elapsed, state.PeakSpeed))
	end
	MovementEngine.DashEnded:Fire(state.Action, interrupted, state.Grounded)
end

local function stepDash(deltaTime)
	local state = dashState
	if not state then return end
	if state.Generation ~= generation or not rootPart or not rootPart.Parent or not humanoid or humanoid.Health <= 0 then
		finishDash(true)
		return
	end

	state.Elapsed += deltaTime
	local total = config.EntryDurationSeconds + config.TravelDurationSeconds + config.ExitDurationSeconds
	local phase, alpha, fromMultiplier, toMultiplier = phaseAt(math.min(state.Elapsed, total))
	local multiplier = fromMultiplier + (toMultiplier - fromMultiplier) * math.clamp(alpha, 0, 1)
	local speed = state.BaseSpeed * multiplier
	state.PeakSpeed = math.max(state.PeakSpeed, speed)
	local vertical = rootPart.AssemblyLinearVelocity.Y
	if config.VerticalMomentumMode == "PreserveAtActivation" then vertical = state.VerticalVelocity end
	rootPart.AssemblyLinearVelocity = Vector3.new(state.Direction.X * speed, vertical, state.Direction.Z * speed)
	MovementEngine.DashUpdated:Fire(state.Action, phase, math.clamp(state.Elapsed / total, 0, 1))
	if state.Elapsed >= total then finishDash(false) end
end

local function tryDash(action, direction)
	if dashState or not humanoid or not rootPart or humanoid.Health <= 0 then diagnose("rejected // unavailable or already dashing") return end
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local cooldown = if grounded then config.GroundCooldownSeconds else config.AirCooldownSeconds
	if os.clock() - lastDashTime < cooldown then diagnose("rejected // cooldown") return end
	if not grounded and airDashCount >= config.AirDashLimit then diagnose("rejected // air limit") return end
	if not grounded then airDashCount += 1 end
	lastDashTime = os.clock()
	local distance = if grounded then config.GroundDistanceStuds else config.AirDistanceStuds
	dashState = {
		Action = action, Direction = direction, Grounded = grounded, Elapsed = 0,
		BaseSpeed = distance / curveArea(), VerticalVelocity = rootPart.AssemblyLinearVelocity.Y,
		Generation = generation,
		StartPosition = rootPart.Position,
		PeakSpeed = 0,
	}
	diagnose(string.format("%s start grounded=%s", action, tostring(grounded)))
	MovementEngine.DashStarted:Fire(action, direction, grounded)
end

function MovementEngine:HandleAction(action)
	if action == "Jump" then if humanoid and humanoid.Health > 0 then humanoid.Jump = true end return end
	if not directions[action] then return end
	heldDirections[action] = true
	local now = os.clock()
	local previous = lastDirectionPress[action]
	lastDirectionPress[action] = now
	if previous and now - previous <= config.DoubleTapWindowSeconds then
		local direction = flatDirection(action)
		if direction then tryDash(action, direction) end
	end
end

function MovementEngine:HandleActionEnded(action)
	if directions[action] then heldDirections[action] = nil end
end

function MovementEngine:BindCharacter(character)
	generation += 1
	finishDash(true)
	if stateConnection then stateConnection:Disconnect() end
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	airDashCount, lastDashTime, lastDirectionPress, heldDirections = 0, -math.huge, {}, {}
	stateConnection = humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then airDashCount = 0 end
	end)
end

function MovementEngine:Init(inputManager, gameplayCamera)
	if isInitialised then return end
	isInitialised, cameraController = true, gameplayCamera
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character) self:BindCharacter(character) end)
	if player.Character then self:BindCharacter(player.Character) end
	inputManager.ActionBegan.Event:Connect(function(action) self:HandleAction(action) end)
	inputManager.ActionEnded.Event:Connect(function(action) self:HandleActionEnded(action) end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		if not enabled then heldDirections, lastDirectionPress = {}, {}; finishDash(true) end
	end)
	RunService.Heartbeat:Connect(stepDash)
	RunService:BindToRenderStep("BLIKKSemanticWalking", Enum.RenderPriority.Input.Value + 1, updateWalking)
end

return MovementEngine
