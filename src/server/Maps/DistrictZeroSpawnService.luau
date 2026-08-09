local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterDependency = require(ReplicatedStorage.Shared.Character.CharacterDependency)
local Config = require(ReplicatedStorage.Shared.Maps.DistrictZero.DistrictZeroConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local SpawnService = {}

local spawnRandom = Random.new()
local recentUseBySpawnId = {}
local historyByPlayer = {}
local reservationsBySpawnId = {}
local spawnProtectionGeneration = {}
local serviceConnections = {}
local mapGeneration = 0
local knownSpawnFolder = nil
local isInitialised = false

local function getSpawnFolder()
	local root = Workspace:FindFirstChild(Config.Identity.WorkspaceRootName)
	local district = root and root:FindFirstChild(Config.Identity.ModelName)
	return district and district:FindFirstChild("SpawnPoints")
end

local function clearSelectionState()
	table.clear(recentUseBySpawnId)
	table.clear(reservationsBySpawnId)
	for player in historyByPlayer do historyByPlayer[player] = nil end
end

local function synchronizeMapGeneration()
	local folder = getSpawnFolder()
	if folder ~= knownSpawnFolder then
		knownSpawnFolder = folder
		mapGeneration += 1
		clearSelectionState()
	end
	return folder
end

local function getLivingRoots(excludedPlayer)
	local roots = {}
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= excludedPlayer and otherPlayer.Character then
			local humanoid = otherPlayer.Character:FindFirstChildOfClass("Humanoid")
			local root = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				table.insert(roots, root)
			end
		end
	end
	return roots
end

local function isVisibleFromPlayer(spawn, playerRoot)
	local origin = playerRoot.Position + Vector3.new(0, 2, 0)
	local target = spawn.Position + Vector3.new(0, 2, 0)
	if (target - origin).Magnitude > Config.SpawnSafety.VisibilityProbeDistanceStuds then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { playerRoot.Parent }
	local hit = Workspace:Raycast(origin, target - origin, params)
	return hit == nil or hit.Instance == spawn
end

local function resolvePool(context, modeId, teamId)
	if context == "MovementLab" or modeId == "Training" then
		return Config.SpawnGroups.Training
	end
	if teamId == "ALPHA" then return Config.SpawnGroups.TeamA end
	if teamId == "OMEGA" then return Config.SpawnGroups.TeamB end
	if modeId == "Duel" then return Config.SpawnGroups.Duel end
	return Config.SpawnGroups.FreeForAll
end

local function resolveAllowedIds(poolDefinition)
	if type(poolDefinition) == "string" then
		poolDefinition = Config.SpawnGroups[poolDefinition]
	end
	if type(poolDefinition) ~= "table" then return nil end
	local ids = {}
	for _, definition in poolDefinition do
		local spawnId = if type(definition) == "table" then definition.Id else definition
		if type(spawnId) == "string" then ids[spawnId] = true end
	end
	return ids
end

local function pruneReservations(now)
	for spawnId, reservation in reservationsBySpawnId do
		if reservation.ExpiresAt <= now or reservation.Player.Parent ~= Players
			or reservation.MapGeneration ~= mapGeneration then
			reservationsBySpawnId[spawnId] = nil
		end
	end
end

local function clearReservation(player, expectedSpawnGeneration)
	for spawnId, reservation in reservationsBySpawnId do
		if reservation.Player == player
			and (expectedSpawnGeneration == nil
				or reservation.SpawnGeneration == expectedSpawnGeneration) then
			reservationsBySpawnId[spawnId] = nil
		end
	end
end

local function isHardOccupied(spawn, roots)
	local radius = Config.SpawnSafety.HardOccupancyRadiusStuds
	for _, root in roots do
		if (spawn.Position - root.Position).Magnitude < radius then return true end
	end
	for _, reservation in reservationsBySpawnId do
		if (spawn.Position - reservation.Position).Magnitude < radius then return true end
	end
	return false
end

local function historyContains(history, spawnId)
	for _, recentSpawnId in history do
		if recentSpawnId == spawnId then return true end
	end
	return false
end

local function rememberSpawn(player, spawnId, now)
	recentUseBySpawnId[spawnId] = now
	local history = historyByPlayer[player]
	if not history then
		history = {}
		historyByPlayer[player] = history
	end
	for index = #history, 1, -1 do
		if history[index] == spawnId then table.remove(history, index) end
	end
	table.insert(history, 1, spawnId)
	while #history > Config.SpawnSafety.RecentHistoryLength do table.remove(history) end
	player:SetAttribute("BLIKK_LastSpawnId", spawnId)
end

local function reserveSpawn(player, spawn, spawnGeneration, now)
	local spawnId = spawn:GetAttribute("BLIKK_SpawnId")
	local reservation = {
		SpawnId = spawnId,
		Player = player,
		Position = spawn.Position,
		ExpiresAt = now + Config.SpawnSafety.ReservationDurationSeconds,
		SpawnGeneration = spawnGeneration,
		MapGeneration = mapGeneration,
	}
	reservationsBySpawnId[spawnId] = reservation
	return reservation
end

local function chooseSpawn(player, context, modeId, spawnGeneration)
	local folder = synchronizeMapGeneration()
	if not folder then return nil, nil end
	local allowedIds = resolveAllowedIds(resolvePool(
		context,
		modeId,
		player:GetAttribute("BLIKK_TeamId")
	))
	local candidates = {}
	for _, child in folder:GetChildren() do
		if child:IsA("SpawnLocation") and child:GetAttribute("BLIKK_SpawnGroup") == "Training"
			and allowedIds and allowedIds[child:GetAttribute("BLIKK_SpawnId")] then
			table.insert(candidates, child)
		end
	end
	table.sort(candidates, function(left, right)
		return (left:GetAttribute("BLIKK_SpawnIndex") or 0)
			< (right:GetAttribute("BLIKK_SpawnIndex") or 0)
	end)
	if #candidates == 0 then return nil, nil end

	local now = os.clock()
	pruneReservations(now)
	clearReservation(player)
	local roots = getLivingRoots(player)
	local hardSafe = {}
	local evaluations = {}
	for _, spawn in candidates do
		if isHardOccupied(spawn, roots) then continue end
		local minimumDistance = math.huge
		local visibleOpponents = 0
		for _, root in roots do
			minimumDistance = math.min(minimumDistance, (spawn.Position - root.Position).Magnitude)
			if isVisibleFromPlayer(spawn, root) then visibleOpponents += 1 end
		end
		if minimumDistance == math.huge then
			minimumDistance = Config.SpawnSafety.PreferredSafeDistanceStuds * 5
		end
		evaluations[spawn] = {
			MinimumDistance = minimumDistance,
			VisibleOpponents = visibleOpponents,
		}
		table.insert(hardSafe, spawn)
	end
	if #hardSafe == 0 then return nil, nil end

	local history = historyByPlayer[player] or {}
	local nonRecent = {}
	for _, spawn in hardSafe do
		if not historyContains(history, spawn:GetAttribute("BLIKK_SpawnId")) then
			table.insert(nonRecent, spawn)
		end
	end
	local eligible = if #nonRecent > 0 then nonRecent else hardSafe
	local bestScore = -math.huge
	local scored = {}
	for _, spawn in eligible do
		local spawnId = spawn:GetAttribute("BLIKK_SpawnId")
		local evaluation = evaluations[spawn]
		local recentAge = now - (recentUseBySpawnId[spawnId] or -math.huge)
		local globalRecentPenalty = if recentAge < Config.SpawnSafety.RecentUsePenaltySeconds
			then 80 * (1 - recentAge / Config.SpawnSafety.RecentUsePenaltySeconds)
			else 0
		local personalPenalty = if historyContains(history, spawnId) then 35 else 0
		local preferredDistance = math.min(
			evaluation.MinimumDistance,
			Config.SpawnSafety.PreferredSafeDistanceStuds * 5
		)
		local score = preferredDistance
			- evaluation.VisibleOpponents * 30
			- globalRecentPenalty
			- personalPenalty
		table.insert(scored, { Spawn = spawn, Score = score })
		bestScore = math.max(bestScore, score)
	end

	local top = {}
	for _, result in scored do
		if result.Score >= bestScore - Config.SpawnSafety.TopScoreTolerance then
			table.insert(top, result.Spawn)
		end
	end
	local selected = top[spawnRandom:NextInteger(1, #top)]
	return selected, reserveSpawn(player, selected, spawnGeneration, now)
end

local function placeCharacter(player, character, deadline, context, modeId, spawnGeneration)
	if not character or character ~= player.Character then return false, "STALE_CHARACTER" end
	local expiresAt = deadline or (os.clock() + MultiplayerConfig.CharacterDependencyTimeoutSeconds)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or CharacterDependency.WaitForChildBefore(character, "Humanoid", expiresAt)
	if character ~= player.Character then return false, "STALE_CHARACTER" end
	local root = CharacterDependency.WaitForChildBefore(character, "HumanoidRootPart", expiresAt)
	if character ~= player.Character then return false, "STALE_CHARACTER" end
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return false, "CHARACTER_INCOMPLETE"
	end
	local spawn, reservation = chooseSpawn(player, context, modeId, spawnGeneration)
	if not spawn or not reservation then return false, "SPAWN_UNAVAILABLE" end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local pivoted, pivotError = pcall(character.PivotTo, character, spawn.CFrame + Vector3.new(0, 3.5, 0))
	if not pivoted or character ~= player.Character then
		clearReservation(player, spawnGeneration)
		return false, if pivoted then "STALE_CHARACTER" else "SPAWN_PLACEMENT_FAILED", pivotError
	end
	local currentReservation = reservationsBySpawnId[reservation.SpawnId]
	if currentReservation ~= reservation or reservation.MapGeneration ~= mapGeneration then
		clearReservation(player, spawnGeneration)
		return false, "SPAWN_UNAVAILABLE"
	end
	reservationsBySpawnId[reservation.SpawnId] = nil
	rememberSpawn(player, reservation.SpawnId, os.clock())
	return true, nil, {
		Humanoid = humanoid,
		RootPart = root,
		Spawn = spawn,
	}
end

function SpawnService:Init()
	if isInitialised then return end
	isInitialised = true
	synchronizeMapGeneration()
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(function(player)
		spawnProtectionGeneration[player] = nil
		historyByPlayer[player] = nil
		clearReservation(player)
	end))
end

function SpawnService:OnMapRebuilt()
	knownSpawnFolder = getSpawnFolder()
	mapGeneration += 1
	clearSelectionState()
end

function SpawnService:PlaceCharacter(player, character, deadline, context, modeId, spawnGeneration)
	return placeCharacter(
		player,
		character or player.Character,
		deadline,
		context,
		modeId,
		spawnGeneration
	)
end

function SpawnService:ClearReservation(player, spawnGeneration)
	clearReservation(player, spawnGeneration)
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

function SpawnService:Destroy()
	for _, connection in serviceConnections do connection:Disconnect() end
	table.clear(serviceConnections)
	clearSelectionState()
	table.clear(spawnProtectionGeneration)
	knownSpawnFolder = nil
	isInitialised = false
end

return SpawnService
