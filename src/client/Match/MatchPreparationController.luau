local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local MatchPreparationController = {}

MatchPreparationController.GameplayReleased = Instance.new("BindableEvent")
MatchPreparationController.TransitionFailed = Instance.new("BindableEvent")

local REQUIRED_CHARACTER_MARKERS = {
	"BLIKK_ClientFighterReady",
	"BLIKK_ClientCameraReady",
	"BLIKK_ClientMovementReady",
	"BLIKK_ClientWallReady",
	"BLIKK_ClientTechniqueReady",
	"BLIKK_ClientWeaponReady",
	"BLIKK_ClientHudReady",
}

local player = Players.LocalPlayer
local loadingController = nil
local movementLabRemote = nil
local matchReadyRemote = nil
local activeMatch = nil
local activeLoadingKey = nil
local readinessGeneration = 0
local readinessKeyInFlight = nil
local acknowledged = {}
local acknowledgedOrder = {}
local releasedKeys = {}
local releasedKeyOrder = {}
local isInitialised = false

local function identitiesMatch(left, right)
	return type(left) == "table"
		and type(right) == "table"
		and left.Context == right.Context
		and left.RoomId == right.RoomId
		and left.MatchId == right.MatchId
		and left.MatchGeneration == right.MatchGeneration
		and left.Round == right.Round
		and left.SpawnGeneration == right.SpawnGeneration
end

local function identityKey(identity)
	if type(identity) ~= "table" then return tostring(identity) end
	return table.concat({
		identity.Context or "Unknown",
		identity.RoomId or "-",
		identity.MatchId or "-",
		tostring(identity.MatchGeneration or 0),
		tostring(identity.Round or 0),
		tostring(identity.SpawnGeneration or 0),
	}, "|")
end

local function contextForIdentity(identity)
	if not identity then return "Match" end
	if identity.Context == "MovementLab" then return "MovementLab" end
	if identity.Context == "RoundTransition" then return "Round" end
	if identity.Context == "JoinInProgress" then return "Join" end
	if identity.Context == "Respawn" then return "Respawn" end
	return "Match"
end

local function ownStats(snapshot)
	for _, stats in snapshot.Stats or {} do
		if stats.UserId == player.UserId then return stats end
	end
	return nil
end

local function rememberAcknowledgement(key)
	if acknowledged[key] then return false end
	acknowledged[key] = true
	table.insert(acknowledgedOrder, key)
	while #acknowledgedOrder > Config.MaximumPreparationDiagnostics do
		acknowledged[table.remove(acknowledgedOrder, 1)] = nil
	end
	return true
end

local function beginLoading(context, key)
	if activeLoadingKey == key and loadingController:IsVisible() then return key end
	if activeLoadingKey ~= key then
		readinessGeneration += 1
		readinessKeyInFlight = nil
	end
	activeLoadingKey = key
	return loadingController:Begin(context, key)
end

local function failLoading(identity, code, awaitAuthoritativeState)
	readinessGeneration += 1
	readinessKeyInFlight = nil
	local failureContext = identity and identity.Context or "Unknown"
	if failureContext == "Unknown" and type(activeLoadingKey) == "string"
		and activeLoadingKey:match("^MovementLab") then
		failureContext = "MovementLab"
	end
	local key = identity and identityKey(identity) or activeLoadingKey
	if key and loadingController:IsVisible() then
		loadingController:Fail(
			key,
			"PREPARATION FAILED // " .. tostring(code or "UNKNOWN"),
			awaitAuthoritativeState == true
		)
	end
	MatchPreparationController.TransitionFailed:Fire(
		failureContext,
		code or "PREPARATION_FAILED",
		awaitAuthoritativeState == true
	)
end

local function rememberRelease(key)
	if releasedKeys[key] then return false end
	releasedKeys[key] = true
	table.insert(releasedKeyOrder, key)
	while #releasedKeyOrder > Config.MaximumPreparationDiagnostics do
		releasedKeys[table.remove(releasedKeyOrder, 1)] = nil
	end
	return true
end

local function characterIsReady(character, identity)
	if not character or character ~= player.Character or not character.Parent then return false end
	if character:GetAttribute("BLIKK_SpawnGeneration") ~= identity.SpawnGeneration then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return false end
	for _, marker in REQUIRED_CHARACTER_MARKERS do
		if character:GetAttribute(marker) ~= true then return false end
	end
	return Workspace.CurrentCamera ~= nil
end

local function requestStreamingReadiness(character, identity, generation)
	if not Workspace.StreamingEnabled then return true end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false end
	local succeeded = pcall(
		player.RequestStreamAroundAsync,
		player,
		root.Position,
		Config.WorldReadinessTimeoutSeconds
	)
	return succeeded and generation == readinessGeneration
		and player.Character == character
		and character:GetAttribute("BLIKK_SpawnGeneration") == identity.SpawnGeneration
end

local function awaitRequiredReadiness(identity)
	local key = identityKey(identity)
	if acknowledged[key] or readinessKeyInFlight == key then return end
	beginLoading(contextForIdentity(identity), key)
	readinessGeneration += 1
	local generation = readinessGeneration
	readinessKeyInFlight = key
	loadingController:SetStatus(key, "FIGHTER RECEIVED", "BINDING CAMERA / MOVEMENT / HUD //")
	task.spawn(function()
		local deadline = os.clock() + Config.RequiredClientReadinessTimeoutSeconds
		local character = nil
		while generation == readinessGeneration and os.clock() < deadline do
			character = player.Character
			if characterIsReady(character, identity) then break end
			RunService.Heartbeat:Wait()
		end
		if generation ~= readinessGeneration then return end
		if not characterIsReady(character, identity) then
			failLoading(
				identity,
				"CLIENT_DEPENDENCY_TIMEOUT",
				identity.Context ~= "MovementLab"
			)
			return
		end
		loadingController:SetStatus(key, "WORLD CHECK", "VERIFYING SPAWN-AREA READINESS //")
		if not requestStreamingReadiness(character, identity, generation) then
			failLoading(
				identity,
				"WORLD_READINESS_TIMEOUT",
				identity.Context ~= "MovementLab"
			)
			return
		end
		if generation ~= readinessGeneration or not characterIsReady(character, identity)
			or not identitiesMatch(identity, {
			Context = character:GetAttribute("BLIKK_CharacterContext"),
			RoomId = character:GetAttribute("BLIKK_CharacterRoomId"),
			MatchId = character:GetAttribute("BLIKK_CharacterMatchId"),
			MatchGeneration = identity.MatchGeneration,
			Round = identity.Round,
			SpawnGeneration = character:GetAttribute("BLIKK_SpawnGeneration"),
		}) then return end
		if readinessKeyInFlight == key then readinessKeyInFlight = nil end
		if not rememberAcknowledgement(key) then return end
		loadingController:SetStatus(key, "CLIENT READY", "WAITING FOR SERVER RELEASE //")
		matchReadyRemote:FireServer({
			Context = if identity.Context == "MovementLab" then "MovementLab" else "Match",
			Identity = identity,
		})
	end)
end

local function handleLifecycleUpdate(update)
	if type(update) ~= "table" then return end
	local identity = update.Identity
	if update.Status == "Preparing" and type(identity) == "table" then
		beginLoading(contextForIdentity(identity), identityKey(identity))
	elseif update.Status == "Prepared" and type(identity) == "table" then
		awaitRequiredReadiness(identity)
	elseif update.Status == "Failed" or update.Status == "Rejected"
		or update.Status == "Cancelled" then
		failLoading(identity, update.Code or update.Status)
	elseif update.Status == "Died" and identity and identity.Context == "MovementLab" then
		readinessGeneration += 1
		beginLoading("Respawn", "MovementLab:Respawn")
		loadingController:SetStatus("MovementLab:Respawn", "FIGHTER DOWN", "PREPARING A CLEAN RESPAWN //")
	elseif update.Status == "Released" and identity and identity.Context == "MovementLab" then
		local key = identityKey(identity)
		if activeLoadingKey == key then loadingController:Cancel(key) end
		activeLoadingKey = nil
		if rememberRelease(key) then
			MatchPreparationController.GameplayReleased:Fire("MovementLab", identity)
		end
	end
end

function MatchPreparationController:Init(loadingControllerValue)
	if isInitialised then return true end
	loadingController = loadingControllerValue
	local remotes = ReplicatedStorage:WaitForChild("BLIKKRemotes", Config.RemoteLookupTimeoutSeconds)
	local lifecycleUpdated = remotes and remotes:WaitForChild(
		"CharacterLifecycleUpdated",
		Config.RemoteLookupTimeoutSeconds
	)
	movementLabRemote = remotes and remotes:WaitForChild(
		"RequestMovementLabSpawn",
		Config.RemoteLookupTimeoutSeconds
	)
	matchReadyRemote = remotes and remotes:WaitForChild("MatchReady", Config.RemoteLookupTimeoutSeconds)
	if not lifecycleUpdated or not lifecycleUpdated:IsA("RemoteEvent")
		or not movementLabRemote or not movementLabRemote:IsA("RemoteEvent")
		or not matchReadyRemote or not matchReadyRemote:IsA("RemoteEvent") then
		error("[BLIKK PREPARATION] Required lifecycle remotes were unavailable", 0)
	end
	lifecycleUpdated.OnClientEvent:Connect(handleLifecycleUpdate)
	isInitialised = true
	return true
end

function MatchPreparationController:BeginMovementLab()
	if not isInitialised then return false end
	readinessGeneration += 1
	readinessKeyInFlight = nil
	activeMatch = nil
	beginLoading("MovementLab", "MovementLab:Request")
	loadingController:SetStatus("MovementLab:Request", "REQUESTING FIGHTER", "WAITING FOR SERVER SPAWN AUTHORITY //")
	movementLabRemote:FireServer()
	return true
end

function MatchPreparationController:ExitMovementLab()
	if not isInitialised or activeMatch then return false end
	readinessGeneration += 1
	readinessKeyInFlight = nil
	if activeLoadingKey then loadingController:Cancel(activeLoadingKey) end
	activeLoadingKey = nil
	movementLabRemote:FireServer("Exit")
	return true
end

function MatchPreparationController:AdoptMatchSnapshot(snapshot)
	if type(snapshot) ~= "table" then return false end
	if snapshot.Cleared then
		if activeMatch and snapshot.MatchId and snapshot.MatchId ~= activeMatch.MatchId then return false end
		readinessGeneration += 1
		readinessKeyInFlight = nil
		if activeLoadingKey then loadingController:Cancel(activeLoadingKey) end
		activeLoadingKey = nil
		activeMatch = nil
		return true
	end
	if type(snapshot.MatchId) ~= "string" or type(snapshot.Generation) ~= "number" then return false end
	if activeMatch and activeMatch.MatchId == snapshot.MatchId
		and (tonumber(snapshot.Revision) or 0) < (tonumber(activeMatch.Revision) or 0) then return false end
	activeMatch = snapshot
	local stats = ownStats(snapshot)
	if not stats then return false end
	local identity = stats.Identity
	local phase = stats.PreparationPhase
	local key = identity and identityKey(identity)
		or string.format("%s|%d|%d", snapshot.MatchId, snapshot.Generation, snapshot.Round or 0)

	if snapshot.Phase == "Cancelled" then
		failLoading(identity, snapshot.FailureCode or "MATCH_CANCELLED")
	elseif snapshot.Phase == "PostRound" then
		readinessGeneration += 1
		key = string.format("%s|Round|%d", snapshot.MatchId, (snapshot.Round or 0) + 1)
		beginLoading("Round", key)
		loadingController:SetStatus(key, "ROUND COMPLETE", "PREPARING NEXT ROUND //")
	elseif phase == "Failed" or phase == "TimedOut" then
		failLoading(identity, stats.PreparationFailureCode or phase)
	elseif phase == "WaitingForRound" then
		readinessGeneration += 1
		readinessKeyInFlight = nil
		if activeLoadingKey then loadingController:Cancel(activeLoadingKey) end
		activeLoadingKey = nil
	elseif phase == "WaitingForClient" and type(identity) == "table" then
		awaitRequiredReadiness(identity)
	elseif phase == "Registered" or phase == "Preparing" then
		beginLoading(contextForIdentity(identity), key)
	elseif phase == "Armed" then
		beginLoading(contextForIdentity(identity), key)
		local releaseAt = stats.ReleaseAtServerTime
		if type(releaseAt) ~= "number" or releaseAt <= 0 then releaseAt = snapshot.ReleaseAtServerTime end
		loadingController:ArmFight(key, releaseAt)
	elseif phase == "Fighting" and snapshot.Phase == "Fighting" then
		if key and rememberRelease(key) then
			MatchPreparationController.GameplayReleased:Fire("Match", identity, snapshot)
		end
	elseif snapshot.Phase == "PostMatch" then
		readinessGeneration += 1
		readinessKeyInFlight = nil
		if activeLoadingKey then loadingController:Cancel(activeLoadingKey) end
		activeLoadingKey = nil
	end
	return true
end

function MatchPreparationController:GetActiveMatch()
	return activeMatch
end

return MatchPreparationController
