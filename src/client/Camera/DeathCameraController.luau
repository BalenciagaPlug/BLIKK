local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before the death camera")
local CameraConfig = require(Shared.Camera.CameraConfig)
local CharacterDependency = require(Shared.Character.CharacterDependency)
local MultiplayerConfig = require(Shared.Multiplayer.MultiplayerConfig)
local CameraObstruction = require(script.Parent.CameraObstruction)
local CameraSettings = require(script.Parent.CameraSettings)
local MouseLookInput = require(script.Parent.MouseLookInput)
local MouseLookMath = require(script.Parent.MouseLookMath)

local DeathCameraController = {}

local BLOCKER_OWNER = "DeathCamera"
local MOUSE_LOOK_OWNER = "DeathCamera"
local RENDER_STEP_NAME = "BLIKKDeathCamera"
local player = Players.LocalPlayer
local inputManager = nil
local gameplayCamera = nil
local isInitialised = false
local isActive = false
local hasWindowFocus = true
local isMenuOpen = false
local yawRadians = 0
local pitchRadians = 0
local distanceStuds = CameraConfig.DeathCamera.FallbackDistanceStuds
local deadCharacter = nil
local targetPart = nil
local lastTargetPosition = nil
local deathSpawnGeneration = nil
local characterBindGeneration = 0
local cancelDependencyWatch = nil
local characterDiedConnection = nil
local releasedAttributeConnection = nil
local activeCamera = nil
local obstructionTargetPoints = {}

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function updateMouseCapture()
	local shouldCapture = isActive and hasWindowFocus and not isMenuOpen
	UserInputService.MouseBehavior = if shouldCapture
		then Enum.MouseBehavior.LockCenter
		else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not shouldCapture
	if shouldCapture then
		MouseLookInput:Acquire(MOUSE_LOOK_OWNER)
	else
		MouseLookInput:Release(MOUSE_LOOK_OWNER)
	end
end

local function identityFromCharacter(character)
	return {
		Context = character:GetAttribute("BLIKK_CharacterContext"),
		RoomId = character:GetAttribute("BLIKK_CharacterRoomId"),
		MatchId = character:GetAttribute("BLIKK_CharacterMatchId"),
		SpawnGeneration = character:GetAttribute("BLIKK_SpawnGeneration"),
	}
end

local function isPlayableIdentity(identity)
	return type(identity) == "table"
		and type(identity.Context) == "string"
		and identity.Context ~= ""
		and finiteNumber(identity.SpawnGeneration)
end

local function findTargetPart(character)
	if not character or not character.Parent then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then return torso end
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function setInitialOrbit(camera, targetPosition)
	local offset = camera.CFrame.Position - targetPosition
	local distance = offset.Magnitude
	if distance <= 0.001 then
		distance = CameraConfig.DeathCamera.FallbackDistanceStuds
		offset = Vector3.new(0, 0, distance)
	end
	distanceStuds = math.clamp(
		distance,
		CameraConfig.DeathCamera.MinimumDistanceStuds,
		CameraConfig.DeathCamera.MaximumDistanceStuds
	)
	local unitOffset = offset.Unit
	yawRadians = math.atan2(unitOffset.X, unitOffset.Z)
	pitchRadians = -math.asin(math.clamp(unitOffset.Y, -1, 1))
	pitchRadians = math.clamp(
		pitchRadians,
		math.rad(CameraConfig.DeathCamera.PitchMinDegrees),
		math.rad(CameraConfig.DeathCamera.PitchMaxDegrees)
	)
end

local function clearDeathState()
	deadCharacter = nil
	targetPart = nil
	lastTargetPosition = nil
	deathSpawnGeneration = nil
	activeCamera = nil
end

local function endDeathCamera(releasedIdentity, force)
	if not isActive then return false end
	if not force and type(releasedIdentity) == "table" then
		local releasedGeneration = releasedIdentity.SpawnGeneration
		if finiteNumber(deathSpawnGeneration) and finiteNumber(releasedGeneration)
			and releasedGeneration <= deathSpawnGeneration then return false end
	end

	isActive = false
	MouseLookInput:Release(MOUSE_LOOK_OWNER)
	CameraObstruction.Reset()
	clearDeathState()
	gameplayCamera:SetGameplayBlocked(BLOCKER_OWNER, false)
	inputManager:SetGameplayBlocked(BLOCKER_OWNER, false)
	if not gameplayCamera:IsGameplayActive() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	return true
end

local function beginDeathCamera(identity, character)
	if not isInitialised or not isPlayableIdentity(identity) then return false end
	character = character or player.Character
	if not character then return false end
	local spawnGeneration = identity.SpawnGeneration
	if isActive then
		if spawnGeneration == deathSpawnGeneration then
			deadCharacter = character
			targetPart = findTargetPart(character) or targetPart
			return true
		end
		endDeathCamera(nil, true)
	end

	local camera = Workspace.CurrentCamera
	local initialTargetPart = findTargetPart(character)
	if not camera or not initialTargetPart then return false end

	deadCharacter = character
	targetPart = initialTargetPart
	deathSpawnGeneration = spawnGeneration
	lastTargetPosition = initialTargetPart.Position
		+ Vector3.new(0, CameraConfig.DeathCamera.TargetVerticalOffsetStuds, 0)
	setInitialOrbit(camera, lastTargetPosition)
	activeCamera = camera
	isActive = true
	inputManager:SetGameplayBlocked(BLOCKER_OWNER, true)
	gameplayCamera:SetGameplayBlocked(BLOCKER_OWNER, true)
	updateMouseCapture()
	return true
end

local function releasedCharacterCanEnd(character)
	if not isActive or not character or character ~= player.Character then return false end
	if character:GetAttribute("BLIKK_GameplayReleased") ~= true then return false end
	local releasedGeneration = character:GetAttribute("BLIKK_SpawnGeneration")
	return finiteNumber(releasedGeneration)
		and finiteNumber(deathSpawnGeneration)
		and releasedGeneration > deathSpawnGeneration
end

local function tryEndForReleasedCharacter(character)
	if not releasedCharacterCanEnd(character) then return end
	endDeathCamera(identityFromCharacter(character), false)
end

local function bindCharacter(character)
	characterBindGeneration += 1
	local bindGeneration = characterBindGeneration
	if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
	if characterDiedConnection then characterDiedConnection:Disconnect(); characterDiedConnection = nil end
	if releasedAttributeConnection then
		releasedAttributeConnection:Disconnect()
		releasedAttributeConnection = nil
	end

	cancelDependencyWatch = CharacterDependency.ObserveHumanoidAndRoot(
		character,
		MultiplayerConfig.CharacterDependencyTimeoutSeconds,
		function(humanoid)
			if bindGeneration ~= characterBindGeneration
				or character ~= player.Character
				or not character.Parent then return end
			local wasGameplayReleased = character:GetAttribute("BLIKK_GameplayReleased") == true
			releasedAttributeConnection = character:GetAttributeChangedSignal(
				"BLIKK_GameplayReleased"
			):Connect(function()
				if character:GetAttribute("BLIKK_GameplayReleased") == true then
					wasGameplayReleased = true
					tryEndForReleasedCharacter(character)
				end
			end)
			characterDiedConnection = humanoid.Died:Connect(function()
				if bindGeneration ~= characterBindGeneration or not wasGameplayReleased then return end
				beginDeathCamera(identityFromCharacter(character), character)
			end)
			tryEndForReleasedCharacter(character)
		end,
		function()
			if bindGeneration == characterBindGeneration and character == player.Character then
				warn("[BLIKK DEATH CAMERA] Character dependencies did not become ready in time")
			end
		end
	)
end

local function updateCamera(deltaTime)
	if not isActive or not lastTargetPosition then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end
	if camera ~= activeCamera then
		CameraObstruction.Reset()
		MouseLookInput:Flush(MOUSE_LOOK_OWNER)
		activeCamera = camera
	end

	if targetPart and targetPart.Parent then
		lastTargetPosition = targetPart.Position
			+ Vector3.new(0, CameraConfig.DeathCamera.TargetVerticalOffsetStuds, 0)
	else
		targetPart = findTargetPart(deadCharacter)
		if targetPart then
			lastTargetPosition = targetPart.Position
				+ Vector3.new(0, CameraConfig.DeathCamera.TargetVerticalOffsetStuds, 0)
		end
	end

	yawRadians, pitchRadians = MouseLookMath.ApplyDelta(
		yawRadians,
		pitchRadians,
		MouseLookInput:Consume(MOUSE_LOOK_OWNER),
		CameraSettings:Get("MouseSensitivityDegreesPerPixel"),
		CameraSettings:Get("InvertY"),
		CameraConfig.DeathCamera.PitchMinDegrees,
		CameraConfig.DeathCamera.PitchMaxDegrees
	)

	local cosine = math.cos(pitchRadians)
	local offset = Vector3.new(
		math.sin(yawRadians) * cosine,
		-math.sin(pitchRadians),
		math.cos(yawRadians) * cosine
	) * distanceStuds
	local desiredPosition = lastTargetPosition + offset
	local resolvedPosition = CameraObstruction.ResolvePosition(
		lastTargetPosition,
		desiredPosition,
		deadCharacter,
		CameraConfig.Obstruction,
		deltaTime
	)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CameraSettings:Get("FieldOfViewDegrees")
	camera.CFrame = CFrame.lookAt(resolvedPosition, lastTargetPosition)
	obstructionTargetPoints[1] = lastTargetPosition
	CameraObstruction.UpdateFades(
		camera,
		obstructionTargetPoints,
		deadCharacter,
		CameraConfig.Obstruction,
		deltaTime
	)
	updateMouseCapture()
end

function DeathCameraController:Init(gameplayInputManager, gameplayCameraController)
	if isInitialised then return true end
	inputManager = gameplayInputManager
	gameplayCamera = gameplayCameraController
	isInitialised = true
	MouseLookInput:Init()

	UserInputService.InputChanged:Connect(function(input)
		if not isActive then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			distanceStuds = math.clamp(
				distanceStuds - input.Position.Z * CameraConfig.DeathCamera.ZoomStepStuds,
				CameraConfig.DeathCamera.MinimumDistanceStuds,
				CameraConfig.DeathCamera.MaximumDistanceStuds
			)
		end
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
	player.CharacterRemoving:Connect(function(character)
		if character == deadCharacter then
			targetPart = nil
		end
	end)
	if player.Character then bindCharacter(player.Character) end

	RunService:BindToRenderStep(
		RENDER_STEP_NAME,
		Enum.RenderPriority.Camera.Value + 2,
		updateCamera
	)
	script.Destroying:Connect(function()
		characterBindGeneration += 1
		if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
		if characterDiedConnection then characterDiedConnection:Disconnect() end
		if releasedAttributeConnection then releasedAttributeConnection:Disconnect() end
		endDeathCamera(nil, true)
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	end)
	return true
end

function DeathCameraController:Begin(identity, character)
	return beginDeathCamera(identity, character)
end

function DeathCameraController:End(releasedIdentity)
	return endDeathCamera(releasedIdentity, false)
end

function DeathCameraController:Cancel()
	return endDeathCamera(nil, true)
end

function DeathCameraController:IsActive()
	return isActive
end

return DeathCameraController
