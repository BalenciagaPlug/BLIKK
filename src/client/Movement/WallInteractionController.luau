local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Movement.TechniqueConfig).Wall
local PoseCoordinator = require(script.Parent.Parent.Character.PoseCoordinator)
local CharacterDependency = require(ReplicatedStorage.Shared.Character.CharacterDependency)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

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
local stateStartedAt = 0
local contactPart
local contactNormal = Vector3.zero
local contactSide = "Forward"
local queryAccumulator = 0
local gameplayEnabled = true
local inputSuppressed = false
local poseTargets = {}
local characterConnections = {}
local isInitialised = false
local characterGeneration = 0
local characterBindingTarget = nil
local cancelDependencyWatch = nil

local function diagnose(message)
	if Config.DiagnosticsEnabled then print("[BLIKK WALL SENSOR] " .. message) end
end

local function resetOwnedPose()
	PoseCoordinator:Release("Wall")
end

local function clearContact()
	contactPart = nil
	contactNormal = Vector3.zero
	contactSide = "Forward"
	if movementEngine then movementEngine:ClearWallContact() end
end

local function clearPresentationState()
	local changed = state ~= "None"
	state = "None"
	clearContact()
	resetOwnedPose()
	if changed then
		Controller.StateChanged:Fire("None", "Forward", Vector3.zero, nil)
	end
end

local function isVerticalSurface(result)
	local part = result.Instance
	if not part:IsA("BasePart") or not part.CanCollide or not part.CanQuery then return false end
	if part.Transparency >= 0.95 or part.Name:find("Helper") then return false end
	if math.abs(result.Normal.Y) > Config.MaximumSurfaceNormalY then return false end
	if part:GetAttribute("BLIKK_WallJumpSurface") == false then return false end
	local explicit = part:GetAttribute("BLIKK_WallJumpSurface") == true
		or CollectionService:HasTag(part, "BLIKK_WallSurface")
	if explicit then return true end
	if not Config.AllowUntaggedFallback then return false end
	local horizontalSize = math.max(part.Size.X, part.Size.Z)
	return part.Size.Y >= Config.MinimumUsableHeightStuds
		and horizontalSize >= Config.MinimumUsableWidthStuds
end

local function sideFromNormal(normal)
	local _, right = cameraController:GetFlatBasis()
	local dot = normal:Dot(right)
	if dot > Config.ContactSideDotThreshold then return "Left" end
	if dot < -Config.ContactSideDotThreshold then return "Right" end
	return "Forward"
end

local function queryDirection(origin, direction, distance)
	local result = Workspace:Spherecast(origin, Config.SphereRadiusStuds, direction * distance, raycastParams)
	if not result or not isVerticalSurface(result) then return nil end
	return result
end

local function chooseContact(candidates, velocity)
	local bestResult
	local bestScore = -math.huge
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	for _, result in candidates do
		if not result then continue end
		local normal = Vector3.new(result.Normal.X, 0, result.Normal.Z)
		if normal.Magnitude == 0 then continue end
		normal = normal.Unit
		local intoSpeed = math.max(0, -horizontalVelocity:Dot(normal))
		local tangent = horizontalVelocity - normal * horizontalVelocity:Dot(normal)
		local stabilityBonus = if result.Instance == contactPart then 2 else 0
		local score = intoSpeed * Config.SensorIntoSpeedWeight
			+ tangent.Magnitude * Config.SensorTangentSpeedWeight
			+ stabilityBonus - result.Distance * 0.05
		if score > bestScore then bestScore, bestResult = score, result end
	end
	return bestResult
end

local function updateWallQuery(deltaTime)
	if not gameplayEnabled or inputSuppressed or not character or not humanoid or humanoid.Health <= 0 then return end
	if humanoid.FloorMaterial ~= Enum.Material.Air then clearContact(); return end
	queryAccumulator += deltaTime
	if queryAccumulator < Config.QueryIntervalSeconds then return end
	queryAccumulator %= Config.QueryIntervalSeconds

	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local movement = movementEngine:GetMoveVector()
	local forward = cameraController:GetFlatBasis()
	local basis = if horizontalVelocity.Magnitude > Config.DirectionDeadzone
		then horizontalVelocity.Unit
		elseif movement.Magnitude > Config.DirectionDeadzone then movement.Unit else forward
	local sideAxis = Vector3.new(-basis.Z, 0, basis.X)
	local radians = math.rad(Config.SideCheckAngleDegrees)
	local cosine, sine = math.cos(radians), math.sin(radians)
	local distance = math.max(
		Config.MinimumCheckDistanceStuds,
		horizontalVelocity.Magnitude * Config.VelocityLookAheadSeconds + Config.QueryPaddingStuds
	)
	local origin = rootPart.Position
	local result = chooseContact({
		queryDirection(origin, basis, distance),
		queryDirection(origin, basis * cosine - sideAxis * sine, distance),
		queryDirection(origin, basis * cosine + sideAxis * sine, distance),
		-- Pure side probes retain a wall while velocity is already parallel to it;
		-- angled-only probes caused the old slow slide/stuck-wall behaviour.
		queryDirection(origin, -sideAxis, Config.MinimumCheckDistanceStuds),
		queryDirection(origin, sideAxis, Config.MinimumCheckDistanceStuds),
	}, velocity)
	if not result then clearContact(); return end

	contactPart = result.Instance
	contactNormal = Vector3.new(result.Normal.X, 0, result.Normal.Z).Unit
	contactSide = sideFromNormal(contactNormal)
	local overhead = Workspace:Spherecast(
		origin,
		Config.SphereRadiusStuds,
		Vector3.yAxis * Config.OverheadClearanceCheckStuds,
		raycastParams
	)
	movementEngine:ReportWallContact({
		Part = contactPart,
		Normal = contactNormal,
		Position = result.Position,
		Side = contactSide,
		HasOverheadClearance = overhead == nil,
	})
end

local function applyWallPose()
	local isRun = state == "VerticalWallRun" or state == "HorizontalWallRun" or state == "WallPost"
	local isJump = state == "WallJumpRecovery"
	if not isRun and not isJump and state ~= "WallApproach" then resetOwnedPose(); return end
	local side = if contactSide == "Left" then -1 elseif contactSide == "Right" then 1 else 0
	local presentation = Config.Presentation
	local elapsed = os.clock() - stateStartedAt
	local stride = 0
	if state == "HorizontalWallRun" then
		stride = math.sin(elapsed * presentation.HorizontalStrideCyclesPerSecond * math.pi * 2)
			* presentation.HorizontalStrideDegrees
	elseif state == "VerticalWallRun" then
		stride = math.sin(elapsed * presentation.VerticalClimbCyclesPerSecond * math.pi * 2)
			* presentation.VerticalClimbDegrees
	end
	table.clear(poseTargets)
	local rootPose = CFrame.Angles(
		math.rad(if isJump then presentation.JumpRootPitchDegrees else presentation.ContactRootPitchDegrees),
		0,
		math.rad(side * (if isJump then presentation.JumpRootRollDegrees else presentation.ContactRootRollDegrees))
	)
	local waistAccent = CFrame.Angles(
		math.rad(if isJump then presentation.JumpWaistPitchDegrees else presentation.ContactWaistPitchDegrees),
		math.rad(-side * presentation.ContactWaistYawDegrees),
		math.rad(-side * presentation.ContactWaistRollDegrees)
	)
	poseTargets.Root = rootPose
	-- Retain enough whole-body contact lean to read as a wall action while only
	-- partially countering it at the waist. Weapon-arm owners keep higher pose
	-- priority, so this never redirects the camera or authoritative shot ray.
	local counterRotation = CFrame.identity:Lerp(
		rootPose.Rotation:Inverse(),
		presentation.UpperBodyCounterRotationScale
	)
	poseTargets.Waist = counterRotation * waistAccent
	local leftHipPitch = if isJump then presentation.JumpHipBackDegrees
		elseif state == "WallPost" then presentation.PostKneeTuckDegrees
		else presentation.ContactHipForwardDegrees + stride
	local rightHipPitch = if isJump then presentation.JumpHipForwardDegrees
		elseif state == "WallPost" then presentation.PostKneeTuckDegrees
		else presentation.ContactHipBackDegrees - stride
	poseTargets.LeftHip = CFrame.Angles(
		math.rad(leftHipPitch),
		0,
		math.rad(-side * presentation.ContactHipRollDegrees)
	)
	poseTargets.RightHip = CFrame.Angles(
		math.rad(rightHipPitch),
		0,
		math.rad(side * presentation.ContactHipRollDegrees)
	)
	PoseCoordinator:Submit("Wall", 30, poseTargets)
end

local function bindCharacter(nextCharacter)
	characterGeneration += 1
	local bindGeneration = characterGeneration
	characterBindingTarget = nextCharacter
	if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
	for _, connection in characterConnections do connection:Disconnect() end
	table.clear(characterConnections)
	clearPresentationState()
	raycastParams.FilterDescendantsInstances = {}
	character, humanoid, rootPart = nil, nil, nil
	cancelDependencyWatch = CharacterDependency.ObserveHumanoidAndRoot(
		nextCharacter,
		MultiplayerConfig.CharacterDependencyTimeoutSeconds,
		function(nextHumanoid, nextRootPart)
			if bindGeneration ~= characterGeneration or characterBindingTarget ~= nextCharacter
				or player.Character ~= nextCharacter then return end
			character, humanoid, rootPart = nextCharacter, nextHumanoid, nextRootPart
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = { character }
			raycastParams.IgnoreWater = true
			character:SetAttribute("BLIKK_ClientWallReady", true)
			table.insert(characterConnections, humanoid.Died:Connect(function()
				if bindGeneration == characterGeneration then clearPresentationState() end
			end))
		end,
		function()
			if bindGeneration == characterGeneration and player.Character == nextCharacter then
				warn("[BLIKK WALL] Character dependencies remain incomplete; continuing to observe the current character.")
			end
		end
	)
end

function Controller:GetState()
	return state
end

function Controller:GetContact()
	return contactPart, contactNormal, contactSide
end

function Controller:Init(inputManager, movementEngineValue, gameplayCamera)
	if isInitialised then return end
	isInitialised = true
	movementEngine, cameraController = movementEngineValue, gameplayCamera
	movementEngine.WallStateChanged.Event:Connect(function(nextState, nextSide, nextNormal, nextPart)
		if state ~= nextState then stateStartedAt = os.clock() end
		local isWallState = nextState == "WallApproach"
			or nextState == "VerticalWallRun"
			or nextState == "HorizontalWallRun"
			or nextState == "WallPost"
			or nextState == "WallJumpRecovery"
			or nextState == "WallCancelFreedom"
			or nextState == "RecontactLocked"
		state = if isWallState then nextState else "None"
		contactSide = nextSide or contactSide
		contactNormal = nextNormal or contactNormal
		contactPart = nextPart or contactPart
		Controller.StateChanged:Fire(state, contactSide, contactNormal, contactPart)
	end)
	movementEngine.WallJumped.Event:Connect(function(...)
		Controller.WallJumped:Fire(...)
	end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		gameplayEnabled = enabled
		if not enabled then clearPresentationState() end
	end)
	inputManager.SuppressionChanged.Event:Connect(function(suppressed)
		inputSuppressed = suppressed
		if suppressed then clearPresentationState() end
	end)
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(removingCharacter)
		if removingCharacter ~= characterBindingTarget then return end
		characterGeneration += 1
		characterBindingTarget = nil
		if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
		for _, connection in characterConnections do connection:Disconnect() end
		table.clear(characterConnections)
		clearPresentationState()
		raycastParams.FilterDescendantsInstances = {}
		character, humanoid, rootPart = nil, nil, nil
	end)
	if player.Character then bindCharacter(player.Character) end
	RunService.Heartbeat:Connect(updateWallQuery)
	RunService:BindToRenderStep("BLIKKWallPresentation", Enum.RenderPriority.Character.Value + 2, applyWallPose)
	diagnose("initialised")
end

return Controller
