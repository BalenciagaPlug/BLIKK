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
local directoryMutationStates = {}
local limiter = RateLimiter.New()
local joinSequence = 0
local isRunning = false

local function trim(value)
	return if type(value) == "string" then value:match("^%s*(.-)%s*$") else nil
end

local function isFiniteInteger(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
		and value % 1 == 0
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

local function enqueueDirectoryMutation(room, shouldClose)
	local service = directoryService
	if not service or type(room) ~= "table" or type(room.RoomId) ~= "string" then return end
	local roomId = room.RoomId
	local state = directoryMutationStates[roomId]
	if not state then
		state = {
			Desired = nil,
			Running = false,
			WarnedFailure = false,
		}
		directoryMutationStates[roomId] = state
	end
	state.Desired = {
		Service = service,
		Room = room,
		Revision = room.Revision,
		Close = shouldClose == true,
	}
	if state.Running then return end
	state.Running = true
	task.spawn(function()
		while state.Desired do
			local operation = state.Desired
			state.Desired = nil
			local isCurrentService = directoryService == operation.Service
			local shouldRun = operation.Close
				or (rooms[roomId] == operation.Room
					and operation.Room.Revision >= operation.Revision)
			local succeeded, message = true, nil
			if isCurrentService and shouldRun then
				if operation.Close then
					succeeded, message = pcall(
						operation.Service.CloseRoom,
						operation.Service,
						operation.Room
					)
				else
					succeeded, message = pcall(
						operation.Service.UpdateRoom,
						operation.Service,
						operation.Room
					)
				end
			end
			if not succeeded and not state.WarnedFailure then
				state.WarnedFailure = true
				warn("[BLIKK ROOM] Ordered directory mutation failed: " .. tostring(message))
			elseif succeeded then
				state.WarnedFailure = false
			end
		end
		state.Running = false
		if not state.Desired and rooms[roomId] == nil then
			directoryMutationStates[roomId] = nil
		end
	end)
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
	if not room.ClientPublicationSuppressed then
		for player, member in room.Members do
			if player.Parent == Players then updateRemote:FireClient(player, snapshot(room, member.IsRoomLeader)) end
		end
	end
	if not room.DirectoryPublicationSuppressed then enqueueDirectoryMutation(room, false) end
end

local function chooseLeader(room)
	local candidates = {}
	local fallbackCandidates = {}
	for _, member in room.Members do
		table.insert(fallbackCandidates, member)
		if os.clock() - member.LastActivityAt < Config.AfkLeaderMigrationSeconds then
			table.insert(candidates, member)
		end
	end
	if #candidates == 0 then candidates = fallbackCandidates end
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
		enqueueDirectoryMutation(room, true)
		return
	end
	for _, member in room.Members do member.IsRoomLeader = member == nextMember end
	room.RoomLeaderUserId = nextMember.Player.UserId
	publish(room)
end

local function removePlayer(player)
	local room = playerRoom[player]
	if not room then return nil end
	local member = room.Members[player]
	if matchService then matchService:RemovePlayer(player) end
	room.Members[player] = nil
	playerRoom[player] = nil
	local didClose = false
	if not next(room.Members) then
		room.State = "Closing"
		room.Revision += 1
		rooms[room.RoomId] = nil
		if matchService then matchService:StopRoom(room.RoomId) end
		if room.ReservationPending then
			room.ReservationPending = false
			room.ReservationGeneration = (room.ReservationGeneration or 0) + 1
		else
			enqueueDirectoryMutation(room, true)
		end
		didClose = true
	elseif member.IsRoomLeader then
		migrateLeader(room)
	else
		publish(room)
	end
	return {
		RoomId = room.RoomId,
		Revision = room.Revision,
		Closed = didClose,
	}
end

local function validateConfiguration(payload)
	if type(payload) ~= "table" then return nil end
	local map = Maps.Get(payload.MapId)
	local mode = Modes.Get(payload.ModeId)
	if not map or not map.IsMultiplayerEnabled or not mode or not Maps.SupportsMode(map.Id, mode.Id) then return nil end
	local maximumPlayers = payload.MaximumPlayers
	if not isFiniteInteger(maximumPlayers) then return nil end
	maximumPlayers = math.clamp(maximumPlayers, Config.RoomCreationMinimumPlayers,
		math.min(mode.MaximumPlayers, map.MaximumPlayers, Config.MaximumPlayers))
	local mutators = {}
	if type(payload.Mutators) == "table" and payload.Mutators.MeleeOnly == true then mutators.MeleeOnly = true end
	local spectatorSlots = tonumber(payload.SpectatorSlots) or 0
	if not isFiniteInteger(spectatorSlots) then return nil end
	return {
		MapId = map.Id, ModeId = mode.Id, MaximumPlayers = maximumPlayers,
		IsPublic = payload.IsPublic ~= false, Mutators = mutators,
		TeamAssignmentMode = mode.TeamMode and "PLAYER_CHOICE_BALANCED" or "NONE",
		JoinInProgressEnabled = mode.JoinInProgressEnabled
			and payload.JoinInProgressEnabled ~= false and payload.JoinInProgress ~= false,
		SpectatorSlots = math.clamp(spectatorSlots, 0, Config.MaximumSpectatorSlots),
		ReadyRequired = mode.Competitive,
	}
end

local function isJoinable(room, isSpectator)
	if room.State == "Lobby" then return true end
	if room.State == "LoadingMatch" or room.State == "Countdown"
		or room.State == "InProgress" or room.State == "RoundIntermission" then
		return isSpectator or room.Config.JoinInProgressEnabled
	end
	return false
end

local function assignBalancedTeam(room, member)
	local mode = Modes.Get(room.Config.ModeId)
	if not mode.TeamMode or member.IsSpectator then return end
	local counts = { ALPHA = 0, OMEGA = 0 }
	for _, candidate in room.Members do
		if not candidate.IsSpectator and candidate.TeamId then counts[candidate.TeamId] += 1 end
	end
	member.TeamId = if counts.ALPHA <= counts.OMEGA then "ALPHA" else "OMEGA"
end

local function addMember(room, player, isSpectator)
	joinSequence += 1
	local member = {
		Player = player, State = isSpectator and "Spectating" or "InLobby",
		IsReady = false, IsSpectator = isSpectator, TeamId = nil, IsRoomLeader = false,
		JoinSequence = joinSequence, LastActivityAt = os.clock(), WasWarned = false,
		ClanId = player:GetAttribute("BLIKK_ClanId"), ClanTag = player:GetAttribute("BLIKK_ClanTag"),
	}
	room.Members[player] = member
	if room.State ~= "Lobby" then assignBalancedTeam(room, member) end
	playerRoom[player] = room
	if room.State ~= "Lobby" and not isSpectator and matchService then
		if not matchService:AddLatePlayer(room, player, member) then
			room.Members[player] = nil
			playerRoom[player] = nil
			return nil
		end
	end
	return member
end

local function createRoom(player, payload, suppressDirectoryPublication)
	if player.Parent ~= Players then return nil, "PLAYER_UNAVAILABLE" end
	if playerRoom[player] or not profiles:IsReady(player) then return nil, "PROFILE_NOT_READY" end
	if not RateLimiter.Allow(limiter, player, "Create", Config.RoomCreationCooldownSeconds, 1) then return nil, "RATE_LIMITED" end
	local configuration = validateConfiguration(payload)
	local name = configuration and filterText(player, payload.Name, Config.RoomNameMaximumLength)
	if not configuration or not name then return nil, "INVALID_ROOM" end
	if player.Parent ~= Players or playerRoom[player] then return nil, "PLAYER_UNAVAILABLE" end
	joinSequence += 1
	local room = {
		RoomId = HttpService:GenerateGUID(false), Name = name, State = "Lobby",
		RoomLeaderUserId = player.UserId, JoinCode = configuration.IsPublic and nil or makeJoinCode(),
		Config = configuration, Members = {}, Revision = 0, CreatedAtUnix = os.time(),
		DirectoryPublicationSuppressed = suppressDirectoryPublication == true,
		ClientPublicationSuppressed = suppressDirectoryPublication == true,
		ReservationPending = suppressDirectoryPublication == true,
		ReservationGeneration = if suppressDirectoryPublication == true then 1 else 0,
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
	if not room then return nil, "ROOM_UNAVAILABLE" end
	local isSpectator = payload.RequestedRole == "Spectator"
	if not isJoinable(room, isSpectator) then return nil, "ROOM_NOT_JOINABLE" end
	local memberCount, spectatorCount = 0, 0
	for _, member in room.Members do
		if member.IsSpectator then spectatorCount += 1 else memberCount += 1 end
	end
	if (isSpectator and spectatorCount >= room.Config.SpectatorSlots)
		or (not isSpectator and memberCount >= room.Config.MaximumPlayers) then
		return nil, "ROOM_FULL"
	end
	if not room.Config.IsPublic and payload.JoinCode ~= room.JoinCode then return nil, "PRIVATE_ROOM" end
	if not addMember(room, player, isSpectator) then return nil, "MATCH_UNAVAILABLE" end
	publish(room)
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
	if not member then return nil, "NOT_IN_ROOM" end
	if not member.IsRoomLeader then return nil, "NOT_ROOM_LEADER" end
	if room.State ~= "Lobby" then
		if room.State == "Starting" or room.State == "LoadingMatch"
			or room.State == "Countdown" or room.State == "InProgress"
			or room.State == "RoundIntermission" then
			return nil, "MATCH_ALREADY_STARTING"
		end
		return nil, "INVALID_STATE"
	end
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
	if eligible < mode.StartMinimumPlayers then return nil, "NOT_ENOUGH_PLAYERS" end
	room.State = "Starting"; publish(room)
	if not matchService:StartRoom(room) then
		room.State = "Lobby"
		publish(room)
		warn("[BLIKK ROOM] Match entry failed: MATCH_START_FAILED")
		return nil, "MATCH_START_FAILED"
	end
	return snapshot(room, false)
end

local function transfer(player, targetUserId)
	local room = playerRoom[player]; local member = room and room.Members[player]
	if not member or not member.IsRoomLeader or not isFiniteInteger(targetUserId) then return nil, "NOT_ROOM_LEADER" end
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
	if not member or not member.IsRoomLeader or room.State ~= "Lobby"
		or not isFiniteInteger(targetUserId) or targetUserId == player.UserId then
		return nil, "NOT_PERMITTED"
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or playerRoom[target] ~= room then return nil, "INVALID_TARGET" end
	local departure = removePlayer(target)
	updateRemote:FireClient(target, {
		Warning = "REMOVED_FROM_ROOM",
		RoomId = departure and departure.RoomId or room.RoomId,
		Revision = departure and departure.Revision or room.Revision,
		RoomClosed = departure and departure.Closed or false,
	})
	return snapshot(room, true)
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
			local mode = Modes.Get(room.Config.ModeId)
			table.insert(result, { RoomId = room.RoomId, Name = room.Name, LeaderUserId = room.RoomLeaderUserId, ModeId = room.Config.ModeId, MapId = room.Config.MapId, CurrentPlayers = count, MaximumPlayers = room.Config.MaximumPlayers, State = room.State, IsPublic = true, JoinInProgressEnabled = room.Config.JoinInProgressEnabled, Joinable = isJoinable(room, false), LateJoinBehavior = mode.LateJoinBehavior, Revision = room.Revision, UpdatedAtUnix = os.time() })
		end
	end
	return result
end
function RoomService:SetDirectoryService(service) directoryService = service end
function RoomService:CreateForPlayer(player, payload, suppressDirectoryPublication)
	return createRoom(player, payload, suppressDirectoryPublication)
end
function RoomService:JoinForPlayer(player, payload) return joinLocal(player, payload) end
function RoomService:LeavePlayer(player) return removePlayer(player) end
function RoomService:GetMatchSnapshot(player)
	return matchService and matchService:GetSnapshot(player) or nil
end

function RoomService:IsReservationCurrent(player, room, generation)
	return type(room) == "table" and room.ReservationPending == true
		and room.ReservationGeneration == generation
		and player.Parent == Players
		and rooms[room.RoomId] == room
		and playerRoom[player] == room
		and room.Members[player] ~= nil
end

function RoomService:ReleaseForTeleport(player, expectedRoom, generation)
	local room = playerRoom[player]
	if room ~= expectedRoom or not self:IsReservationCurrent(player, room, generation) then return false end
	room.ReservationPending = false
	room.ReservationGeneration += 1
	room.Members[player] = nil
	playerRoom[player] = nil
	rooms[room.RoomId] = nil
	return true
end

function RoomService:AcceptTeleportedPlayer(player, record, requestedRole)
	if type(record) ~= "table" or type(record.RoomId) ~= "string"
		or not isFiniteInteger(record.RoomLeaderUserId) or playerRoom[player] then return false end
	local room = rooms[record.RoomId]
	if not room then
		local configuration = validateConfiguration(record.Config)
		if not configuration or type(record.Name) ~= "string" or #record.Name > Config.RoomNameMaximumLength then return false end
		room = { RoomId = record.RoomId, Name = record.Name, State = "Lobby", RoomLeaderUserId = record.RoomLeaderUserId, JoinCode = record.JoinCode, Config = configuration, Members = {}, Revision = 0, CreatedAtUnix = record.CreatedAtUnix or os.time() }
		rooms[room.RoomId] = room
	end
	local isLeader = player.UserId == room.RoomLeaderUserId
	local isSpectator = requestedRole == "Spectator" and not isLeader
	if not isJoinable(room, isSpectator) then return false end
	local memberCount, spectatorCount = 0, 0
	local hasLeader = false
	for _, member in room.Members do
		if member.IsSpectator then spectatorCount += 1 else memberCount += 1 end
		if member.IsRoomLeader then hasLeader = true end
	end
	local fighterCapacity = room.Config.MaximumPlayers
	if not isLeader and not hasLeader then fighterCapacity = math.max(0, fighterCapacity - 1) end
	if (isSpectator and spectatorCount >= room.Config.SpectatorSlots)
		or (not isSpectator and memberCount >= fighterCapacity) then return false end
	local member = addMember(room, player, isSpectator)
	if not member then return false end
	member.IsRoomLeader = isLeader
	if isLeader then
		room.LeaderArrivalGeneration = (room.LeaderArrivalGeneration or 0) + 1
		for _, candidate in room.Members do candidate.IsRoomLeader = candidate == member end
	elseif not hasLeader and not room.LeaderArrivalScheduled then
		room.LeaderArrivalScheduled = true
		room.LeaderArrivalGeneration = (room.LeaderArrivalGeneration or 0) + 1
		local arrivalGeneration = room.LeaderArrivalGeneration
		task.delay(Config.Directory.FounderArrivalTimeoutSeconds, function()
			if rooms[room.RoomId] ~= room or room.LeaderArrivalGeneration ~= arrivalGeneration then return end
			for _, candidate in room.Members do
				if candidate.IsRoomLeader then return end
			end
			room.LeaderArrivalScheduled = false
			migrateLeader(room)
		end)
	end
	publish(room)
	return true
end

function RoomService:Init(remoteRegistry, profileService)
	isRunning = true
	remote = remoteRegistry.RoomRequest; updateRemote = remoteRegistry.RoomUpdated; activityRemote = remoteRegistry.RoomActivity
	profiles = profileService
	remote.OnServerInvoke = function(player, operation, payload)
		if type(operation) ~= "string" or #operation > 32 then return { Success = false, Code = "INVALID_OPERATION" } end
		local currentRoom = playerRoom[player]
		if currentRoom and currentRoom.ReservationPending then
			return { Success = false, Code = "ROOM_RESERVATION_IN_PROGRESS" }
		end
		if not RunService:IsStudio() and (operation == "Create" or operation == "JoinLocal") then
			return { Success = false, Code = "DIRECTORY_ROUTE_REQUIRED" }
		end
		if operation == "Snapshot" then
			local room = playerRoom[player]
			return {
				Success = true,
				Snapshot = room and snapshot(room, false),
				MatchSnapshot = matchService and matchService:GetSnapshot(player) or nil,
			}
		end
		if operation == "Leave" then
			local departure = removePlayer(player)
			return {
				Success = true,
				LeftRoomId = departure and departure.RoomId or nil,
				Revision = departure and departure.Revision or nil,
				RoomClosed = departure and departure.Closed or false,
			}
		end
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

function RoomService:SetMatchPhase(roomId, state)
	local room = rooms[roomId]
	if not room then return end
	room.State = state
	if state == "LoadingMatch" then
		for _, member in room.Members do
			if not member.IsSpectator then member.State = "Loading" end
		end
	elseif state == "InProgress" then
		for _, member in room.Members do
			if member.State == "Loading" then member.State = "Alive" end
		end
	elseif state == "PostMatch" then
		for _, member in room.Members do
			member.State = member.IsSpectator and "Spectating" or "PostMatch"
		end
	end
	publish(room)
end

function RoomService:SetMemberMatchState(player, state)
	local room = playerRoom[player]
	local member = room and room.Members[player]
	if not member or type(state) ~= "string" then return false end
	member.State = state
	publish(room)
	return true
end

function RoomService:SetMatchMemberStates(roomId, statesByPlayer)
	local room = rooms[roomId]
	if not room or type(statesByPlayer) ~= "table" then return false end
	local changed = false
	for player, state in statesByPlayer do
		local member = room.Members[player]
		if member and type(state) == "string" and member.State ~= state then
			member.State = state
			changed = true
		end
	end
	if changed then publish(room) end
	return true
end

function RoomService:ReturnToLobby(roomId)
	local room = rooms[roomId]
	if not room then return end
	room.State = "Lobby"
	for _, member in room.Members do member.IsReady = false; member.State = member.IsSpectator and "Spectating" or "InLobby" end
	publish(room)
end

return RoomService
