local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Maps.DistrictZero.DistrictZeroConfig)

local SpawnService = {}
local recentUse = {}
local rotationIndex = 0
local requestEvent = nil
local lastRequestAt = {}

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

local function chooseSpawn(player)
	local folder = getSpawnFolder()
	if not folder then return nil end
	local candidates = {}
	for _, child in folder:GetChildren() do
		if child:IsA("SpawnLocation") and child:GetAttribute("BLIKK_SpawnGroup") == "Training" then table.insert(candidates, child) end
	end
	table.sort(candidates, function(a, b) return (a:GetAttribute("BLIKK_SpawnIndex") or 0) < (b:GetAttribute("BLIKK_SpawnIndex") or 0) end)
	if #candidates == 0 then return nil end
	local roots = getLivingRoots(player)
	local now = os.clock()
	local bestSpawn = nil
	local bestScore = -math.huge
	for index, spawn in candidates do
		local minimumDistance = math.huge
		local visiblePlayers = 0
		for _, root in roots do
			minimumDistance = math.min(minimumDistance, (spawn.Position - root.Position).Magnitude)
			if isVisibleFromPlayer(spawn, root) then visiblePlayers += 1 end
		end
		if minimumDistance == math.huge then minimumDistance = 200 end
		local recentSeconds = now - (recentUse[spawn] or -math.huge)
		local recentPenalty = if recentSeconds < Config.SpawnSafety.RecentUsePenaltySeconds then 80 else 0
		local safetyPenalty = if minimumDistance < Config.SpawnSafety.MinimumPlayerDistanceStuds then 120 else 0
		local rotationBonus = if index == rotationIndex % #candidates + 1 then 8 else 0
		local score = minimumDistance - visiblePlayers * 30 - recentPenalty - safetyPenalty + rotationBonus
		if score > bestScore then bestScore, bestSpawn = score, spawn end
	end
	rotationIndex += 1
	recentUse[bestSpawn] = now
	return bestSpawn
end

local function placeCharacter(player, character)
	if not character or character ~= player.Character then return false end
	local humanoid = character:WaitForChild("Humanoid", 8)
	local root = character:WaitForChild("HumanoidRootPart", 8)
	local spawn = chooseSpawn(player)
	if not humanoid or not root or not spawn then return false end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(spawn.CFrame + Vector3.new(0, 3.5, 0))
	player.RespawnLocation = spawn
	return true
end

local function bindPlayer(player)
	player.CharacterAdded:Connect(function(character) placeCharacter(player, character) end)
	if player.Character then task.defer(placeCharacter, player, player.Character) end
end

function SpawnService:Init()
	local remotes = ReplicatedStorage:FindFirstChild("BLIKKRemotes") or Instance.new("Folder")
	remotes.Name = "BLIKKRemotes"
	remotes.Parent = ReplicatedStorage
	requestEvent = remotes:FindFirstChild("RequestMovementLabSpawn") or Instance.new("RemoteEvent")
	requestEvent.Name = "RequestMovementLabSpawn"
	requestEvent.Parent = remotes
	requestEvent.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastRequestAt[player] or -math.huge) < Config.SpawnSafety.RequestCooldownSeconds then return end
		lastRequestAt[player] = now
		placeCharacter(player, player.Character)
	end)
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player) lastRequestAt[player] = nil end)
	for _, player in Players:GetPlayers() do bindPlayer(player) end
end

return SpawnService
