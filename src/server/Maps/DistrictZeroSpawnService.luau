local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Maps.DistrictZero.DistrictZeroConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local SpawnService = {}
local recentUse = {}
local rotationByPool = {}
local lastSpawnByPlayer = {}
local spawnProtectionGeneration = {}
local isInitialised = false

local function getSpawnFolder()
	local root = Workspace:FindFirstChild(Config.Identity.WorkspaceRootName)
	local district = root and root:FindFirstChild(Config.Identity.ModelName)
	return district and district:FindFirstChild("SpawnPoints")
end

local function getLivingRoots(excludedPlayer)
	local roots = {}
	for _, player in Players:GetPlayers() do
		if player ~= excludedPlayer and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root then table.insert(roots, root) end
		end
	end
	return roots
end

local function isVisibleFromPlayer(spawn, playerRoot)
	local origin = playerRoot.Position + Vector3.new(0, 2, 0)
	local target = spawn.Position + Vector3.new(0, 2, 0)
	if (target - origin).Magnitude > Config.SpawnSafety.VisibilityProbeDistanceStuds then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { playerRoot.Parent }
	local hit = Workspace:Raycast(origin, target - origin, params)
	return hit == nil or hit.Instance == spawn
end

local function resolvePool(context, modeId, teamId)
	if context == "MovementLab" or modeId == "Training" then return "Training", Config.SpawnGroups.Training end
	if teamId == "ALPHA" then return "TeamA", Config.SpawnGroups.TeamA end
	if teamId == "OMEGA" then return "TeamB", Config.SpawnGroups.TeamB end
	if modeId == "Duel" then return "Duel", Config.SpawnGroups.Duel end
	return "FreeForAll", Config.SpawnGroups.FreeForAll
end

local function resolveAllowedIds(poolDefinition)
	if type(poolDefinition) == "string" then poolDefinition = Config.SpawnGroups[poolDefinition] end
	if type(poolDefinition) ~= "table" then return nil end
	local ids = {}
	for _, definition in poolDefinition do
		local spawnId = if type(definition) == "table" then definition.Id else definition
		if type(spawnId) == "string" then ids[spawnId] = true end
	end
	return ids
end

local function chooseSpawn(player, context, modeId)
	local folder = getSpawnFolder()
	if not folder then return nil end
	local candidates = {}
	local teamId = player:GetAttribute("BLIKK_TeamId")
	local poolId, poolDefinition = resolvePool(context, modeId, teamId)
	local allowedIds = resolveAllowedIds(poolDefinition)
	for _, child in folder:GetChildren() do
		if child:IsA("SpawnLocation") and child:GetAttribute("BLIKK_SpawnGroup") == "Training"
			and allowedIds and allowedIds[child:GetAttribute("BLIKK_SpawnId")] then table.insert(candidates, child) end
	end
	table.sort(candidates, function(a, b) return (a:GetAttribute("BLIKK_SpawnIndex") or 0) < (b:GetAttribute("BLIKK_SpawnIndex") or 0) end)
	if #candidates == 0 then return nil end
	local roots = getLivingRoots(player)
	local now = os.clock()
	local safeCandidates = {}
	local evaluations = {}
	for _, spawn in candidates do
		local minimumDistance = math.huge
		local visiblePlayers = 0
		for _, root in roots do
			minimumDistance = math.min(minimumDistance, (spawn.Position - root.Position).Magnitude)
			if isVisibleFromPlayer(spawn, root) then visiblePlayers += 1 end
		end
		if minimumDistance == math.huge then minimumDistance = 200 end
		evaluations[spawn] = { MinimumDistance = minimumDistance, VisiblePlayers = visiblePlayers }
		if minimumDistance >= Config.SpawnSafety.MinimumPlayerDistanceStuds then
			table.insert(safeCandidates, spawn)
		end
	end
	local eligible = if #safeCandidates > 0 then safeCandidates else candidates
	local previousSpawnId = lastSpawnByPlayer[player]
	local mayExcludePrevious = #safeCandidates >= 2
	local bestSpawn = nil
	local bestScore = -math.huge
	local rotationIndex = rotationByPool[poolId] or 0
	for index, spawn in eligible do
		local spawnId = spawn:GetAttribute("BLIKK_SpawnId")
		if mayExcludePrevious and spawnId == previousSpawnId then continue end
		local evaluation = evaluations[spawn]
		local minimumDistance = evaluation.MinimumDistance
		local visiblePlayers = evaluation.VisiblePlayers
		local recentSeconds = now - (recentUse[spawn] or -math.huge)
		local recentPenalty = if recentSeconds < Config.SpawnSafety.RecentUsePenaltySeconds then 80 else 0
		local safetyPenalty = if minimumDistance < Config.SpawnSafety.MinimumPlayerDistanceStuds then 120 else 0
		local rotationBonus = if index == rotationIndex % #eligible + 1 then 8 else 0
		local score = minimumDistance - visiblePlayers * 30 - recentPenalty - safetyPenalty + rotationBonus
		if score > bestScore then bestScore, bestSpawn = score, spawn end
	end
	if not bestSpawn then bestSpawn = eligible[1] end
	rotationByPool[poolId] = rotationIndex + 1
	recentUse[bestSpawn] = now
	lastSpawnByPlayer[player] = bestSpawn:GetAttribute("BLIKK_SpawnId")
	player:SetAttribute("BLIKK_LastSpawnId", lastSpawnByPlayer[player])
	return bestSpawn
end

local function placeCharacter(player, character, deadline, context, modeId)
	if not character or character ~= player.Character then return false, "STALE_CHARACTER" end
	local expiresAt = deadline or (os.clock() + MultiplayerConfig.CharacterDependencyTimeoutSeconds)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", math.max(0, expiresAt - os.clock()))
	if character ~= player.Character then return false, "STALE_CHARACTER" end
	local root = character:FindFirstChild("HumanoidRootPart")
		or character:WaitForChild("HumanoidRootPart", math.max(0, expiresAt - os.clock()))
	if character ~= player.Character then return false, "STALE_CHARACTER" end
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return false, "CHARACTER_INCOMPLETE"
	end
	local spawn = chooseSpawn(player, context, modeId)
	if not spawn then return false, "SPAWN_UNAVAILABLE" end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(spawn.CFrame + Vector3.new(0, 3.5, 0))
	if character ~= player.Character then return false, "STALE_CHARACTER" end
	return true, nil, {
		Humanoid = humanoid,
		RootPart = root,
		Spawn = spawn,
	}
end

function SpawnService:Init()
	if isInitialised then return end
	isInitialised = true
	Players.PlayerRemoving:Connect(function(player)
		spawnProtectionGeneration[player] = nil
		lastSpawnByPlayer[player] = nil
	end)
end

function SpawnService:PlaceCharacter(player, character, deadline, context, modeId)
	return placeCharacter(player, character or player.Character, deadline, context, modeId)
end

function SpawnService:SetSpawnProtection(player, durationSeconds)
	spawnProtectionGeneration[player] = (spawnProtectionGeneration[player] or 0) + 1
	local generation = spawnProtectionGeneration[player]
	player:SetAttribute("BLIKK_SpawnProtected", true)
	task.delay(durationSeconds, function()
		if spawnProtectionGeneration[player] == generation and player.Parent == Players then
			player:SetAttribute("BLIKK_SpawnProtected", false)
		end
	end)
end

function SpawnService:ClearSpawnProtection(player)
	spawnProtectionGeneration[player] = (spawnProtectionGeneration[player] or 0) + 1
	player:SetAttribute("BLIKK_SpawnProtected", false)
end

return SpawnService
