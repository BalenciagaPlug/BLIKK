local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Movement.TechniqueConfig).Wall

local Controller = {}
Controller.StateChanged = Instance.new("BindableEvent")
Controller.WallJumped = Instance.new("BindableEvent")

local player = Players.LocalPlayer
local movementEngine
local cameraController
local character
local humanoid
local rootPart
local raycastParams = RaycastParams.new()
local state = "None"
local stateChangedAt = 0
local contactPart
local contactNormal = Vector3.zero
local contactPoint = Vector3.zero
local contactSide = "Forward"
local lastContactAt = -math.huge
local lastWall
local lastWallPoint = Vector3.zero
local lastWallJumpAt = -math.huge
local bufferedJumpAt = -math.huge
local queryAccumulator = 0
local generation = 0
local gameplayEnabled = true
local inputSuppressed = false
local poseJoints = {}
local ownedJoints = {}
local poseTargets = {}
local characterConnections = {}
local isInitialised = false

local jointNames = {
	RootJoint = "Root", Waist = "Waist", LeftShoulder = "LeftShoulder", RightShoulder = "RightShoulder",
	LeftHip = "LeftHip", RightHip = "RightHip",
}

local function diagnose(message)
	if Config.DiagnosticsEnabled then print("[BLIKK WALL] " .. message) end
end

local function setState(nextState)
	if state == nextState then return end
	state = nextState
	stateChangedAt = os.clock()
	Controller.StateChanged:Fire(nextState, contactSide, contactNormal, contactPart)
	if Config.DiagnosticsEnabled and character then
		character:SetAttribute("BLIKK_WallState", nextState)
		character:SetAttribute("BLIKK_WallSide", contactSide)
		character:SetAttribute("BLIKK_WallNormal", contactNormal)
	end
end

local function resetOwnedPose()
	for alias in ownedJoints do
		local joint = poseJoints[alias]
		if joint and joint.Parent then joint.Transform = CFrame.identity end
	end
	table.clear(ownedJoints)
end

local function resetState(clearSameWall)
	contactPart = nil
	contactNormal = Vector3.zero
	contactPoint = Vector3.zero
	lastContactAt = -math.huge
	bufferedJumpAt = -math.huge
	if clearSameWall then
		lastWall = nil
		lastWallJumpAt = -math.huge
		lastWallPoint = Vector3.zero
	end
	setState("None")
	resetOwnedPose()
end

local function isVerticalSurface(result)
	local part = result.Instance
	if not part:IsA("BasePart") or not part.CanCollide or not part.CanQuery then return false, "not collidable" end
	if part.Transparency >= 0.95 or part.Name:find("Helper") then return false, "helper or transparent" end
	if math.abs(result.Normal.Y) > Config.MaximumSurfaceNormalY then return false, "invalid normal" end
	if part:GetAttribute("BLIKK_WallJumpSurface") == false then return false, "explicitly disabled" end
	local explicit = part:GetAttribute("BLIKK_WallJumpSurface") == true or CollectionService:HasTag(part, "BLIKK_WallSurface")
	if explicit then return true end
	if not Config.AllowUntaggedFallback then return false, "untagged" end
	local horizontalSize = math.max(part.Size.X, part.Size.Z)
	if part.Size.Y < Config.MinimumUsableHeightStuds or horizontalSize < Config.MinimumUsableWidthStuds then return false, "too small" end
	return true
end

local function sideFromNormal(normal)
	local _, right = cameraController:GetFlatBasis()
	local dot = normal:Dot(right)
	if dot > Config.ContactSideDotThreshold then return "Left" elseif dot < -Config.ContactSideDotThreshold then return "Right" end
	return "Forward"
end

local function sameWallLocked(part, point, now)
	if part ~= lastWall then return false end
	if now - lastWallJumpAt >= Config.RecontactLockoutSeconds and (point - lastWallPoint).Magnitude >= Config.SameWallMinimumSeparationStuds then return false end
	return true
end

local function performWallJump(now)
	if not gameplayEnabled or inputSuppressed or not humanoid or humanoid.Health <= 0 or humanoid.FloorMaterial ~= Enum.Material.Air then return false end
	if not contactPart or now - lastContactAt > Config.ContactGraceSeconds then return false end
	if sameWallLocked(contactPart, contactPoint, now) then setState("RecontactLocked"); diagnose("rejected // same wall lock") return false end
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local tangent = horizontal - contactNormal * horizontal:Dot(contactNormal)
	local movement = movementEngine:GetMoveVector()
	local launchHorizontal = contactNormal * Config.OutwardSpeedStudsPerSecond
		+ movement * Config.DirectionalInfluenceStudsPerSecond
		+ tangent * Config.RetainedTangentialVelocityScale
	local minimumOutward = Config.OutwardSpeedStudsPerSecond * Config.MinimumOutwardRetentionScale
	if launchHorizontal:Dot(contactNormal) < minimumOutward then
		launchHorizontal += contactNormal * (minimumOutward - launchHorizontal:Dot(contactNormal))
	end
	rootPart.AssemblyLinearVelocity = Vector3.new(launchHorizontal.X, Config.UpwardSpeedStudsPerSecond, launchHorizontal.Z)
	lastWall, lastWallPoint, lastWallJumpAt = contactPart, contactPoint, now
	bufferedJumpAt = -math.huge
	setState("WallJumping")
	Controller.WallJumped:Fire(now, contactPart, contactNormal, contactSide)
	return true
end

local function acceptContact(result, now)
	if sameWallLocked(result.Instance, result.Position, now) then
		setState("RecontactLocked")
		return
	end
	if lastWall and result.Instance ~= lastWall then lastWall = nil end
	local isNewContact = state == "None" or contactPart ~= result.Instance
	contactPart = result.Instance
	contactNormal = Vector3.new(result.Normal.X, 0, result.Normal.Z).Unit
	contactPoint = result.Position
	contactSide = sideFromNormal(contactNormal)
	lastContactAt = now
	if isNewContact then setState("WallApproach") end
	setState("WallContact")
	if now - bufferedJumpAt <= Config.JumpInputBufferSeconds then performWallJump(now) end
end

local function queryDirection(origin, direction)
	local result = Workspace:Raycast(origin, direction * Config.CheckDistanceStuds, raycastParams)
	if not result then return nil end
	local valid = isVerticalSurface(result)
	return if valid then result else nil
end

local function updateWallQuery(deltaTime)
	if not gameplayEnabled or inputSuppressed or not character or not humanoid or humanoid.Health <= 0 then return end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		if state ~= "None" then resetState(true) end
		return
	end
	queryAccumulator += deltaTime
	if queryAccumulator < Config.QueryIntervalSeconds then return end
	queryAccumulator %= Config.QueryIntervalSeconds
	local now = os.clock()
	if state == "WallJumping" then
		if now - stateChangedAt < Config.RecoveryDurationSeconds then return end
		setState("WallRecovery")
	end
	local movement = movementEngine:GetMoveVector()
	local forward = cameraController:GetFlatBasis()
	local basis = if movement.Magnitude > Config.DirectionDeadzone then movement.Unit else forward
	local sideAxis = Vector3.new(-basis.Z, 0, basis.X)
	local radians = math.rad(Config.SideCheckAngleDegrees)
	local cosine, sine = math.cos(radians), math.sin(radians)
	local origin = rootPart.Position
	local result = queryDirection(origin, basis)
		or queryDirection(origin, basis * cosine - sideAxis * sine)
		or queryDirection(origin, basis * cosine + sideAxis * sine)
	if result then
		acceptContact(result, now)
	elseif now - lastContactAt > Config.ContactGraceSeconds and state ~= "WallJumping" then
		contactPart = nil
		setState(if lastWall and now - lastWallJumpAt < Config.RecontactLockoutSeconds then "RecontactLocked" else "None")
	end
end

local function bindPoseJoints()
	table.clear(poseJoints)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local alias = jointNames[descendant.Name:gsub(" ", "")]
			if alias then poseJoints[alias] = descendant end
		end
	end
end

local function applyWallPose()
	if state ~= "WallContact" and state ~= "WallJumping" and state ~= "WallRecovery" then resetOwnedPose(); return end
	local side = if contactSide == "Left" then -1 elseif contactSide == "Right" then 1 else 0
	local jumping = state == "WallJumping"
	local presentation = Config.Presentation
	table.clear(poseTargets)
	poseTargets.Root = CFrame.Angles(math.rad(if jumping then presentation.JumpRootPitchDegrees else presentation.ContactRootPitchDegrees), 0, math.rad(side * (if jumping then presentation.JumpRootRollDegrees else presentation.ContactRootRollDegrees)))
	poseTargets.Waist = CFrame.Angles(math.rad(if jumping then presentation.JumpWaistPitchDegrees else presentation.ContactWaistPitchDegrees), math.rad(-side * presentation.ContactWaistYawDegrees), math.rad(-side * presentation.ContactWaistRollDegrees))
	poseTargets.LeftHip = CFrame.Angles(math.rad(if jumping then presentation.JumpHipBackDegrees else presentation.ContactHipForwardDegrees), 0, math.rad(-side * presentation.ContactHipRollDegrees))
	poseTargets.RightHip = CFrame.Angles(math.rad(if jumping then presentation.JumpHipForwardDegrees else presentation.ContactHipBackDegrees), 0, math.rad(side * presentation.ContactHipRollDegrees))
	if side <= 0 then poseTargets.LeftShoulder = CFrame.Angles(math.rad(presentation.ContactShoulderPitchDegrees), 0, math.rad(-presentation.ContactShoulderRollDegrees)) end
	if side >= 0 then poseTargets.RightShoulder = CFrame.Angles(math.rad(presentation.ContactShoulderPitchDegrees), 0, math.rad(presentation.ContactShoulderRollDegrees)) end
	resetOwnedPose()
	for alias, pose in poseTargets do
		local joint = poseJoints[alias]
		if joint then joint.Transform = pose; ownedJoints[alias] = true end
	end
end

local function bindCharacter(nextCharacter)
	generation += 1
	for _, connection in characterConnections do connection:Disconnect() end
	table.clear(characterConnections)
	resetState(true)
	character = nextCharacter
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true
	bindPoseJoints()
	table.insert(characterConnections, humanoid.Died:Connect(function() resetState(true) end))
end

function Controller:GetState() return state end
function Controller:GetContact() return contactPart, contactNormal, contactSide end

function Controller:Init(inputManager, movementEngineValue, gameplayCamera)
	if isInitialised then return end
	isInitialised = true
	movementEngine, cameraController = movementEngineValue, gameplayCamera
	inputManager.ActionBegan.Event:Connect(function(action, timestamp)
		if action ~= "Jump" then return end
		bufferedJumpAt = timestamp
		performWallJump(timestamp)
	end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		gameplayEnabled = enabled
		if not enabled then resetState(true) end
	end)
	inputManager.SuppressionChanged.Event:Connect(function(suppressed) inputSuppressed = suppressed; if suppressed then resetState(true) end end)
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(removingCharacter)
		if removingCharacter == character then
			for _, connection in characterConnections do connection:Disconnect() end
			table.clear(characterConnections)
			resetState(true)
			character = nil
			humanoid = nil
			rootPart = nil
		end
	end)
	if player.Character then bindCharacter(player.Character) end
	RunService.Heartbeat:Connect(updateWallQuery)
	RunService:BindToRenderStep("BLIKKWallPresentation", Enum.RenderPriority.Character.Value + 2, applyWallPose)
end

return Controller
