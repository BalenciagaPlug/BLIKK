local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Modes = require(ReplicatedStorage.Shared.Multiplayer.GameModeRegistry)
local Maps = require(ReplicatedStorage.Shared.Multiplayer.MapRegistry)
local Config = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)
local RateLimiter = require(script.Parent.Parent.Networking.RateLimiter)

local RoomService = {}
local rooms = {}
local playerRoom = {}
local remote = nil
local updateRemote = nil
local activityRemote = nil
local profiles = nil
local matchService = nil
local directoryService = nil
local limiter = RateLimiter.New()
local joinSequence = 0
local isRunning = false

local function trim(value)
	return if type(value) == "string" then value:match("^%s*(.-)%s*$") else nil
end

local function filterText(player, value, maximumLength)
	local text = trim(value)
	if not text or #text < 1 or #text > maximumLength then return nil end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(filtered) == "string" and filtered ~= "" then filtered else nil
end

local function makeJoinCode()
	return HttpService:GenerateGUID(false):gsub("%-", ""):sub(1, Config.JoinCodeLength):upper()
end

local function memberSnapshot(member)
	return {
		UserId = member.Player.UserId, DisplayName = member.Player.DisplayName,
		State = member.State, IsReady = member.IsReady, IsSpectator = member.IsSpectator,
		TeamId = member.TeamId, IsRoomLeader = member.IsRoomLeader,
		PingMilliseconds = math.floor(member.Player:GetNetworkPing() * 2000 + 0.5),
		ClanId = member.Player:GetAttribute("BLIKK_ClanId"),
		ClanTag = member.Player:GetAttribute("BLIKK_ClanTag"),
	}
end

local function snapshot(room, includePrivate)
	local members = {}
	for _, member in room.Members do table.insert(members, memberSnapshot(member)) end
	table.sort(members, function(a, b) return a.UserId < b.UserId end)
	local result = {
		RoomId = room.RoomId, Name = room.Name, State = room.State,
		RoomLeaderUserId = room.RoomLeaderUserId, Config = table.clone(room.Config),
		Members = members, Revision = room.Revision,
	}
	if includePrivate then result.JoinCode = room.JoinCode end
	return result
end

local function publish(room)
	room.Revision += 1
	for player, member in room.Members do
		if player.Parent == Players then updateRemote:FireClient(player, snapshot(room, member.IsRoomLeader)) end
	end
	if directoryService then directoryService:UpdateRoom(room) end
end

local function chooseLeader(room)
	local candidates = {}
	for _, member in room.Members do
		if os.clock() - member.LastActivityAt < Config.AfkLeaderMigrationSeconds then
			table.insert(candidates, member)
		end
	end
	table.sort(candidates, function(a, b)
		if a.IsSpectator ~= b.IsSpectator then return not a.IsSpectator end
		local aPing, bPing = a.Player:GetNetworkPing(), b.Player:GetNetworkPing()
		if aPing ~= bPing then return aPing < bPing end
		if a.JoinSequence ~= b.JoinSequence then return a.JoinSequence < b.JoinSequence end
		return a.Player.UserId < b.Player.UserId
	end)
	return candidates[1]
end

local function migrateLeader(room, selected)
	local nextMember = selected or chooseLeader(room)
	if not nextMember then
		room.State = "Closing"
		rooms[room.RoomId] = nil
		if directoryService then directoryService:CloseRoom(room.RoomId) end
		return
	end
	for _, member in room.Members do member.IsRoomLeader = member == nextMember end
	room.RoomLeaderUserId = nextMember.Player.UserId
	publish(room)
end

local function removePlayer(player)
	local room = playerRoom[player]
	if not room then return end
	local member = room.Members[player]
	room.Members[player] = nil; playerRoom[player] = nil
	if not next(room.Members) then
		room.State = "Closing"; rooms[room.RoomId] = nil
		if directoryService then directoryService:CloseRoom(room.RoomId) end
	elseif member.IsRoomLeader then
		migrateLeader(room)
	else
		publish(room)
	end
end

local function validateConfiguration(payload)
	if type(payload) ~= "table" then return nil end
	local map = Maps.Get(payload.MapId)
	local mode = Modes.Get(payload.ModeId)
	if not map or not map.IsMultiplayerEnabled or not mode or not Maps.SupportsMode(map.Id, mode.Id) then return nil end
	local maximumPlayers = payload.MaximumPlayers
	if type(maximumPlayers) ~= "number" or maximumPlayers % 1 ~= 0 then return nil end
	maximumPlayers = math.clamp(maximumPlayers, mode.MinimumPlayers, math.min(mode.MaximumPlayers, map.MaximumPlayers, Config.MaximumPlayers))
	local mutators = {}
	if type(payload.Mutators) == "table" and payload.Mutators.MeleeOnly == true then mutators.MeleeOnly = true end
	return {
		MapId = map.Id, ModeId = mode.Id, MaximumPlayers = maximumPlayers,
		IsPublic = payload.IsPublic ~= false, Mutators = mutators,
		TeamAssignmentMode = mode.TeamMode and "PLAYER_CHOICE_BALANCED" or "NONE",
		JoinInProgress = mode.JoinInProgress and payload.JoinInProgress ~= false,
		SpectatorSlots = math.clamp(tonumber(payload.SpectatorSlots) or 0, 0, Config.MaximumSpectatorSlots),
		ReadyRequired = mode.Competitive,
	}
end

local function createRoom(player, payload)
	if playerRoom[player] or not profiles:IsReady(player) then return nil, "PROFILE_NOT_READY" end
	if not RateLimiter.Allow(limiter, player, "Create", Config.RoomCreationCooldownSeconds, 1) then return nil, "RATE_LIMITED" end
	local configuration = validateConfiguration(payload)
	local name = configuration and filterText(player, payload.Name, Config.RoomNameMaximumLength)
	if not configuration or not name then return nil, "INVALID_ROOM" end
	joinSequence += 1
	local room = {
		RoomId = HttpService:GenerateGUID(false), Name = name, State = "Lobby",
		RoomLeaderUserId = player.UserId, JoinCode = configuration.IsPublic and nil or makeJoinCode(),
		Config = configuration, Members = {}, Revision = 0, CreatedAtUnix = os.time(),
	}
	room.Members[player] = {
		Player = player, State = "InLobby", IsReady = false, IsSpectator = false,
		TeamId = nil, IsRoomLeader = true, JoinSequence = joinSequence,
		LastActivityAt = os.clock(), WasWarned = false, ClanId = player:GetAttribute("BLIKK_ClanId"), ClanTag = player:GetAttribute("BLIKK_ClanTag"),
	}
	rooms[room.RoomId] = room; playerRoom[player] = room
	publish(room)
	return snapshot(room, true)
end

local function joinLocal(player, payload)
	if playerRoom[player] or type(payload) ~= "table" or type(payload.RoomId) ~= "string" then return nil, "INVALID_JOIN" end
	local room = rooms[payload.RoomId]
	if not room or room.State ~= "Lobby" then return nil, "ROOM_UNAVAILABLE" end
	local count = 0; for _ in room.Members do count += 1 end
	if count >= room.Config.MaximumPlayers then return nil, "ROOM_FULL" end
	if not room.Config.IsPublic and payload.JoinCode ~= room.JoinCode then return nil, "PRIVATE_ROOM" end
	joinSequence += 1
	room.Members[player] = { Player = player, State = "InLobby", IsReady = false, IsSpectator = false, TeamId = nil, IsRoomLeader = false, JoinSequence = joinSequence, LastActivityAt = os.clock(), WasWarned = false, ClanId = player:GetAttribute("BLIKK_ClanId"), ClanTag = player:GetAttribute("BLIKK_ClanTag") }
	playerRoom[player] = room; publish(room)
	return snapshot(room, false)
end

local function setReady(player, payload)
	local room = playerRoom[player]; local member = room and room.Members[player]
	if not member or room.State ~= "Lobby" or type(payload) ~= "boolean" or member.IsSpectator then return nil, "INVALID_STATE" end
	member.IsReady = payload; member.State = if payload then "Ready" else "InLobby"; member.LastActivityAt = os.clock(); publish(room)
	return snapshot(room, false)
end

local function setTeam(player, teamId)
	local room = playerRoom[player]; local member = room and room.Members[player]
	local mode = room and Modes.Get(room.Config.ModeId)
	if not member or room.State ~= "Lobby" or not mode.TeamMode or not table.find(Modes.TeamIds, teamId) then return nil, "INVALID_TEAM" end
	local requested, other = 0, 0
	for _, candidate in room.Members do if candidate.TeamId == teamId then requested += 1 elseif candidate.TeamId then other += 1 end end
	if requested > other then return nil, "TEAM_IMBALANCE" end
	member.TeamId = teamId; member.IsReady = false; member.State = "InLobby"; member.LastActivityAt = os.clock(); publish(room)
	return snapshot(room, false)
end

local function startMatch(player)
	local room = playerRoom[player]; local member = room and room.Members[player]
	if not member or not member.IsRoomLeader or room.State ~= "Lobby" then return nil, "NOT_ROOM_LEADER" end
	local mode = Modes.Get(room.Config.ModeId); local eligible = 0
	local teamCounts = { ALPHA = 0, OMEGA = 0 }
	for _, candidate in room.Members do if candidate.TeamId then teamCounts[candidate.TeamId] += 1 end end
	for _, candidate in room.Members do
		if not candidate.IsSpectator then
			eligible += 1
			if room.Config.ReadyRequired and not candidate.IsReady and candidate ~= member then return nil, "PLAYERS_NOT_READY" end
			if mode.TeamMode and not candidate.TeamId then
				candidate.TeamId = if teamCounts.ALPHA <= teamCounts.OMEGA then "ALPHA" else "OMEGA"
				teamCounts[candidate.TeamId] += 1
			end
		end
	end
	if eligible < mode.MinimumPlayers then return nil, "NOT_ENOUGH_PLAYERS" end
	room.State = "Starting"; publish(room)
	if not matchService:StartRoom(room) then room.State = "Lobby"; publish(room); return nil, "MATCH_START_FAILED" end
	room.State = "InProgress"; publish(room)
	return snapshot(room, false)
end

local function transfer(player, targetUserId)
	local room = playerRoom[player]; local member = room and room.Members[player]
	if not member or not member.IsRoomLeader or type(targetUserId) ~= "number" then return nil, "NOT_ROOM_LEADER" end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or not room.Members[target] then return nil, "INVALID_TARGET" end
	migrateLeader(room, room.Members[target]); return snapshot(room, false)
end

local function updateConfiguration(player, payload)
	local room = playerRoom[player]; local member = room and room.Members[player]
	if not member or not member.IsRoomLeader or room.State ~= "Lobby" then return nil, "NOT_ROOM_LEADER" end
	local configuration = validateConfiguration(payload)
	if not configuration then return nil, "INVALID_CONFIGURATION" end
	room.Config = configuration
	for _, candidate in room.Members do candidate.IsReady = false; candidate.State = candidate.IsSpectator and "Spectating" or "InLobby"; if not Modes.Get(configuration.ModeId).TeamMode then candidate.TeamId = nil end end
	publish(room); return snapshot(room, true)
end

local function kickMember(player, targetUserId)
	local room = playerRoom[player]; local member = room and room.Members[player]
	if not member or not member.IsRoomLeader or room.State ~= "Lobby" or type(targetUserId) ~= "number" or targetUserId == player.UserId then return nil, "NOT_PERMITTED" end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or playerRoom[target] ~= room then return nil, "INVALID_TARGET" end
	removePlayer(target); updateRemote:FireClient(target, { Warning = "REMOVED_FROM_ROOM" }); return snapshot(room, true)
end

local operations = { Create = createRoom, JoinLocal = joinLocal, SetReady = setReady, SetTeam = setTeam, Start = startMatch, TransferLeader = transfer, UpdateConfig = updateConfiguration, Kick = kickMember }

function RoomService:GetRoom(player) return playerRoom[player] end
function RoomService:GetRoomById(roomId) return rooms[roomId] end
function RoomService:GetPublicSnapshot(room) return snapshot(room, false) end
function RoomService:GetLocalListings()
	local result = {}
	for _, room in rooms do
		if room.Config.IsPublic and room.State ~= "Closing" then
			local count = 0; for _ in room.Members do count += 1 end
			table.insert(result, { RoomId = room.RoomId, Name = room.Name, LeaderUserId = room.RoomLeaderUserId, ModeId = room.Config.ModeId, MapId = room.Config.MapId, CurrentPlayers = count, MaximumPlayers = room.Config.MaximumPlayers, State = room.State, IsPublic = true, JoinInProgress = room.Config.JoinInProgress, UpdatedAtUnix = os.time() })
		end
	end
	return result
end
function RoomService:SetDirectoryService(service) directoryService = service end
function RoomService:CreateForPlayer(player, payload) return createRoom(player, payload) end
function RoomService:JoinForPlayer(player, payload) return joinLocal(player, payload) end

function RoomService:AcceptTeleportedPlayer(player, record, requestedRole)
	if type(record) ~= "table" or type(record.RoomId) ~= "string" or playerRoom[player] then return false end
	local room = rooms[record.RoomId]
	if not room then
		local configuration = validateConfiguration(record.Config)
		if not configuration or type(record.Name) ~= "string" or #record.Name > Config.RoomNameMaximumLength then return false end
		room = { RoomId = record.RoomId, Name = record.Name, State = "Lobby", RoomLeaderUserId = record.RoomLeaderUserId, JoinCode = record.JoinCode, Config = configuration, Members = {}, Revision = 0, CreatedAtUnix = record.CreatedAtUnix or os.time() }
		rooms[room.RoomId] = room
	end
	if room.State ~= "Lobby" and not room.Config.JoinInProgress then return false end
	local memberCount, spectatorCount = 0, 0; for _, member in room.Members do if member.IsSpectator then spectatorCount += 1 else memberCount += 1 end end
	local isSpectator = requestedRole == "Spectator"
	if (isSpectator and spectatorCount >= room.Config.SpectatorSlots) or (not isSpectator and memberCount >= room.Config.MaximumPlayers) then return false end
	joinSequence += 1
	local isLeader = player.UserId == room.RoomLeaderUserId or not next(room.Members)
	room.Members[player] = { Player = player, State = isSpectator and "Spectating" or "InLobby", IsReady = false, IsSpectator = isSpectator, TeamId = nil, IsRoomLeader = isLeader, JoinSequence = joinSequence, LastActivityAt = os.clock(), WasWarned = false, ClanId = player:GetAttribute("BLIKK_ClanId"), ClanTag = player:GetAttribute("BLIKK_ClanTag") }
	if isLeader then room.RoomLeaderUserId = player.UserId end
	playerRoom[player] = room; publish(room)
	return true
end

function RoomService:Init(remoteRegistry, profileService)
	isRunning = true
	remote = remoteRegistry.RoomRequest; updateRemote = remoteRegistry.RoomUpdated; activityRemote = remoteRegistry.RoomActivity
	profiles = profileService
	remote.OnServerInvoke = function(player, operation, payload)
		if type(operation) ~= "string" or #operation > 32 then return { Success = false, Code = "INVALID_OPERATION" } end
		if operation == "Snapshot" then local room = playerRoom[player]; return { Success = true, Snapshot = room and snapshot(room, false) } end
		if operation == "Leave" then removePlayer(player); return { Success = true } end
		if not RateLimiter.Allow(limiter, player, "Mutation", Config.RoomMutationCooldownSeconds, 2) then return { Success = false, Code = "RATE_LIMITED" } end
		local handler = operations[operation]
		if not handler then return { Success = false, Code = "UNKNOWN_OPERATION" } end
		local result, code = handler(player, payload)
		return { Success = result ~= nil, Code = code or "OK", Snapshot = result }
	end
	activityRemote.OnServerEvent:Connect(function(player)
		if not RateLimiter.Allow(limiter, player, "Activity", Config.ActivityPingMinimumIntervalSeconds, 1) then return end
		local room = playerRoom[player]; local member = room and room.Members[player]
		if member then member.LastActivityAt = os.clock(); member.WasWarned = false end
	end)
	Players.PlayerRemoving:Connect(function(player) removePlayer(player); RateLimiter.Clear(limiter, player) end)
	task.spawn(function()
		while isRunning do
			task.wait(Config.PositionObservationIntervalSeconds)
			local now = os.clock()
			for _, room in rooms do
				for player, member in room.Members do
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.MoveDirection.Magnitude > 0 then member.LastActivityAt = now; member.WasWarned = false end
					local inactive = now - member.LastActivityAt
					if inactive >= Config.AfkWarningSeconds and not member.WasWarned then member.WasWarned = true; updateRemote:FireClient(player, { Warning = "AFK_WARNING" }) end
					if member.IsRoomLeader and inactive >= Config.AfkLeaderMigrationSeconds then migrateLeader(room) end
					local kickAt = if member.IsSpectator then Config.AfkSpectatorKickSeconds else Config.AfkKickSeconds
					if inactive >= kickAt and (not RunService:IsStudio() or Config.AfkKickEnabledInStudio or Config.StudioAfkTestOverride) then player:Kick("Removed from the room for inactivity") end
				end
			end
		end
	end)
	game:BindToClose(function() isRunning = false end)
end

function RoomService:SetMatchService(service) matchService = service end

function RoomService:ReturnToLobby(roomId)
	local room = rooms[roomId]
	if not room then return end
	room.State = "Lobby"
	for _, member in room.Members do member.IsReady = false; member.State = member.IsSpectator and "Spectating" or "InLobby" end
	publish(room)
end

return RoomService
