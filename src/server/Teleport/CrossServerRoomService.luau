local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)
local RateLimiter = require(script.Parent.Parent.Networking.RateLimiter)

local Directory = {}
local directoryConfig = Config.Directory
local listingMap = MemoryStoreService:GetSortedMap(directoryConfig.ListingMapName)
local secretMap = MemoryStoreService:GetHashMap(directoryConfig.SecretMapName)
local privateLookup = MemoryStoreService:GetHashMap(directoryConfig.PrivateServerLookupName)
local codeLookup = MemoryStoreService:GetHashMap(directoryConfig.JoinCodeLookupName)
local nonceMap = MemoryStoreService:GetHashMap(directoryConfig.JoinNonceMapName)
local limiter = RateLimiter.New()
local roomService = nil
local subscription = nil
local ownedRoom = nil
local heartbeatGeneration = 0

local function retry(callback)
	local lastError = nil
	for attempt = 1, directoryConfig.RetryCount do
		local ok, result, extra = pcall(callback)
		if ok then return true, result, extra end
		lastError = result
		if attempt < directoryConfig.RetryCount then task.wait(directoryConfig.RetryBaseDelaySeconds * 2 ^ (attempt - 1)) end
	end
	return false, lastError
end

local function publishInvalidation(kind, roomId)
	pcall(MessagingService.PublishAsync, MessagingService, directoryConfig.MessagingTopic, { Kind = kind, RoomId = roomId, At = os.time() })
end

local function publicRecord(room)
	local count = 0; for _ in room.Members do count += 1 end
	local leader = Players:GetPlayerByUserId(room.RoomLeaderUserId)
	return { DirectoryVersion = 1, RoomId = room.RoomId, Name = room.Name, LeaderUserId = room.RoomLeaderUserId, LeaderDisplayName = leader and leader.DisplayName or "", LeaderClanTag = leader and leader:GetAttribute("BLIKK_ClanTag") or nil, ModeId = room.Config.ModeId, MapId = room.Config.MapId, Mutators = table.clone(room.Config.Mutators), CurrentPlayers = count, MaximumPlayers = room.Config.MaximumPlayers, State = room.State, IsPublic = room.Config.IsPublic, JoinInProgress = room.Config.JoinInProgress, UpdatedAtUnix = os.time() }
end

function Directory:UpdateRoom(room)
	if RunService:IsStudio() or not room.Config.IsPublic then return end
	local record = publicRecord(room)
	local ok = retry(function() return listingMap:SetAsync(room.RoomId, record, directoryConfig.ListingTtlSeconds, record.UpdatedAtUnix) end)
	if not ok then warn("[BLIKK ROOMS] Directory heartbeat temporarily unavailable") end
end

function Directory:CloseRoom(roomId)
	if RunService:IsStudio() then return end
	pcall(listingMap.RemoveAsync, listingMap, roomId)
	pcall(secretMap.RemoveAsync, secretMap, roomId)
	publishInvalidation("RoomClosed", roomId)
end

local function listRooms()
	if RunService:IsStudio() then return roomService:GetLocalListings() end
	local ok, page = retry(function() return listingMap:GetRangeAsync(Enum.SortDirection.Descending, directoryConfig.QueryPageSize) end)
	if not ok then return nil, "DIRECTORY_UNAVAILABLE" end
	local results = {}
	for _, item in page do
		local record = item.value
		if type(record) == "table" and os.time() - (record.UpdatedAtUnix or 0) <= directoryConfig.StaleSeconds and #results < directoryConfig.MaximumBrowserResults then
			table.insert(results, record)
		end
	end
	return results
end

local function reserveRoom(player, payload)
	if RunService:IsStudio() then return nil, "PUBLISHED_CLIENT_REQUIRED" end
	local roomSnapshot, code = roomService:CreateForPlayer(player, payload)
	if not roomSnapshot then return nil, code end
	local ok, accessCode, privateServerId = retry(function() return TeleportService:ReserveServerAsync(game.PlaceId) end)
	if not ok then return nil, "RESERVE_FAILED" end
	local room = roomService:GetRoom(player)
	local secret = { RoomId = room.RoomId, Name = room.Name, Config = room.Config, RoomLeaderUserId = player.UserId, JoinCode = room.JoinCode, AccessCode = accessCode, PrivateServerId = privateServerId, CreatedAtUnix = room.CreatedAtUnix }
	local stored = retry(function()
		secretMap:SetAsync(room.RoomId, secret, directoryConfig.SecretTtlSeconds)
		privateLookup:SetAsync(privateServerId, room.RoomId, directoryConfig.SecretTtlSeconds)
		if room.JoinCode then codeLookup:SetAsync(room.JoinCode, room.RoomId, directoryConfig.SecretTtlSeconds) end
		listingMap:SetAsync(room.RoomId, publicRecord(room), directoryConfig.ListingTtlSeconds, os.time())
	end)
	if not stored then return nil, "DIRECTORY_WRITE_FAILED" end
	publishInvalidation("RoomCreated", room.RoomId)
	return secret
end

local function teleportToRoom(player, roomId, requestedRole)
	local ok, secret = retry(function() return secretMap:GetAsync(roomId) end)
	if not ok or type(secret) ~= "table" or type(secret.AccessCode) ~= "string" then return false, "ROOM_UNAVAILABLE" end
	local nonce = game:GetService("HttpService"):GenerateGUID(false)
	local nonceStored = retry(function() nonceMap:SetAsync(nonce, { UserId = player.UserId, RoomId = roomId, PrivateServerId = secret.PrivateServerId, ExpiresAtUnix = os.time() + directoryConfig.JoinNonceTtlSeconds }, directoryConfig.JoinNonceTtlSeconds) end)
	if not nonceStored then return false, "JOIN_AUTH_FAILED" end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = secret.AccessCode
	options:SetTeleportData({ ProtocolVersion = Config.ProtocolVersion, RoomId = roomId, JoinNonce = nonce, RequestedRole = requestedRole == "Spectator" and "Spectator" or "Player", SourceServerJobId = game.JobId })
	for attempt = 1, directoryConfig.TeleportRetryCount do
		local teleported = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
		if teleported then return true end
		if attempt < directoryConfig.TeleportRetryCount then task.wait(directoryConfig.RetryBaseDelaySeconds * attempt) end
	end
	return false, "TELEPORT_FAILED"
end

local function validateArrival(player)
	if game.PrivateServerId == "" then return end
	local joinData = player:GetJoinData(); local data = joinData and joinData.TeleportData
	if type(data) ~= "table" or data.ProtocolVersion ~= Config.ProtocolVersion or type(data.RoomId) ~= "string" or type(data.JoinNonce) ~= "string" then player:Kick("Room authorization failed"); return end
	local ok, nonce = retry(function() return nonceMap:GetAsync(data.JoinNonce) end)
	if not ok or type(nonce) ~= "table" or nonce.UserId ~= player.UserId or nonce.RoomId ~= data.RoomId or nonce.PrivateServerId ~= game.PrivateServerId or (nonce.ExpiresAtUnix or 0) < os.time() then player:Kick("Room authorization expired"); return end
	pcall(nonceMap.RemoveAsync, nonceMap, data.JoinNonce)
	local secretOk, secret = retry(function() return secretMap:GetAsync(data.RoomId) end)
	if not secretOk or type(secret) ~= "table" or secret.PrivateServerId ~= game.PrivateServerId then player:Kick("Room is unavailable"); return end
	ownedRoom = roomService:AcceptTeleportedPlayer(player, secret, data.RequestedRole) and roomService:GetRoom(player) or ownedRoom
end

function Directory:Init(remoteRegistry, rooms)
	roomService = rooms; roomService:SetDirectoryService(self)
	remoteRegistry.DirectoryRequest.OnServerInvoke = function(player, operation, payload)
		if not RateLimiter.Allow(limiter, player, "Directory", Config.BrowserQueryCooldownSeconds, 2) then return { Success = false, Code = "RATE_LIMITED" } end
		if operation == "List" then local result, code = listRooms(); return { Success = result ~= nil, Code = code or "OK", Rooms = result } end
		if operation == "Create" then
			if RunService:IsStudio() then local roomSnapshot, code = roomService:CreateForPlayer(player, payload); return { Success = roomSnapshot ~= nil, Code = code or "LOCAL_ROOM", Snapshot = roomSnapshot } end
			local secret, code = reserveRoom(player, payload); if not secret then return { Success = false, Code = code } end; local success, teleportCode = teleportToRoom(player, secret.RoomId, "Player"); return { Success = success, Code = teleportCode or "TELEPORTING" }
		end
		if operation == "Join" and type(payload) == "table" and type(payload.RoomId) == "string" and #payload.RoomId <= 64 then
			if RunService:IsStudio() then local snapshot, code = roomService:JoinForPlayer(player, payload); return { Success = snapshot ~= nil, Code = code or "LOCAL_ROOM", Snapshot = snapshot } end
			local success, code = teleportToRoom(player, payload.RoomId, payload.RequestedRole); return { Success = success, Code = code or "TELEPORTING" }
		end
		if operation == "JoinCode" and not RunService:IsStudio() and type(payload) == "string" and #payload == Config.JoinCodeLength then
			local ok, roomId = retry(function() return codeLookup:GetAsync(payload:upper()) end)
			if not ok or type(roomId) ~= "string" then return { Success = false, Code = "INVALID_JOIN_CODE" } end
			local success, code = teleportToRoom(player, roomId, "Player"); return { Success = success, Code = code or "TELEPORTING" }
		end
		return { Success = false, Code = "INVALID_OPERATION" }
	end
	local subscribed, connection = pcall(MessagingService.SubscribeAsync, MessagingService, directoryConfig.MessagingTopic, function() end)
	if subscribed then subscription = connection end
	TeleportService.TeleportInitFailed:Connect(function(player) if player.Parent == Players then remoteRegistry.RoomUpdated:FireClient(player, { Warning = "TELEPORT_FAILED_RETRY" }) end end)
	Players.PlayerAdded:Connect(validateArrival); for _, player in Players:GetPlayers() do task.defer(validateArrival, player) end
	game:BindToClose(function() heartbeatGeneration += 1; if subscription then subscription:Disconnect() end; if ownedRoom then self:CloseRoom(ownedRoom.RoomId) end end)
	heartbeatGeneration += 1; local generation = heartbeatGeneration
	task.spawn(function() while heartbeatGeneration == generation do task.wait(directoryConfig.HeartbeatSeconds); if ownedRoom then self:UpdateRoom(ownedRoom) end end end)
end

return Directory
