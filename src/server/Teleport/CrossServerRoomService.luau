local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)
local Modes = require(ReplicatedStorage.Shared.Multiplayer.GameModeRegistry)
local RateLimiter = require(script.Parent.Parent.Networking.RateLimiter)

local Directory = {}
local directoryConfig = Config.Directory
local listingMap = MemoryStoreService:GetSortedMap(directoryConfig.ListingMapName)
local secretMap = MemoryStoreService:GetHashMap(directoryConfig.SecretMapName)
local privateLookup = MemoryStoreService:GetHashMap(directoryConfig.PrivateServerLookupName)
local codeLookup = MemoryStoreService:GetHashMap(directoryConfig.JoinCodeLookupName)
local nonceMap = MemoryStoreService:GetHashMap(directoryConfig.JoinNonceMapName)
local publicDeathmatchConfig = Config.PublicDeathmatch
local publicDeathmatchReservationStore = DataStoreService:GetDataStore(
	publicDeathmatchConfig.ReservationStoreName
)
local publicDeathmatchAnchorMap = MemoryStoreService:GetHashMap(
	publicDeathmatchConfig.AnchorMapName
)
local limiter = RateLimiter.New()
local roomService = nil
local subscription = nil
local ownedRoom = nil
local heartbeatGeneration = 0
local reservedRoomMetadata = {}
local transportAttempts = {}

local function publicDeathmatchRoomId()
	return "BLIKK-PUBLIC-FFA-" .. game.MatchmakingType.Name
end

local function publicDeathmatchAnchorKey()
	return "PARTITION-" .. game.MatchmakingType.Name
end

local function publicDeathmatchRoomConfig()
	return {
		MapId = publicDeathmatchConfig.MapId,
		ModeId = publicDeathmatchConfig.ModeId,
		MaximumPlayers = publicDeathmatchConfig.MaximumPlayers,
		IsPublic = true,
		Mutators = {},
		TeamAssignmentMode = "NONE",
		JoinInProgressEnabled = true,
		SpectatorSlots = publicDeathmatchConfig.SpectatorSlots,
		ReadyRequired = false,
	}
end

local function retry(callback, shouldContinue)
	local lastError = nil
	for attempt = 1, directoryConfig.RetryCount do
		if shouldContinue and not shouldContinue() then return false, "OPERATION_CANCELLED" end
		local ok, result, extra = pcall(callback)
		if shouldContinue and not shouldContinue() then return false, "OPERATION_CANCELLED" end
		if ok then return true, result, extra end
		lastError = result
		if attempt < directoryConfig.RetryCount then
			task.wait(directoryConfig.RetryBaseDelaySeconds * 2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

local function beginTransportAttempt(player, operation)
	if transportAttempts[player] then return nil end
	local attempt = {
		Id = HttpService:GenerateGUID(false),
		Operation = operation,
		Player = player,
		RoomId = nil,
		JoinCode = nil,
		Room = nil,
		ReservationGeneration = nil,
		PrivateServerId = nil,
		JoinNonce = nil,
		Stage = "Starting",
		Cancelled = false,
		ResourceGeneration = 0,
		CleanupRequestedGeneration = 0,
		CleanupCompletedGeneration = 0,
		CleanupRunning = false,
	}
	transportAttempts[player] = attempt
	return attempt
end

local function clearTransportAttempt(player, attempt)
	if transportAttempts[player] ~= attempt then return false end
	attempt.Cancelled = true
	transportAttempts[player] = nil
	return true
end

local function isTransportAttemptCurrent(player, attempt)
	return transportAttempts[player] == attempt
		and not attempt.Cancelled
		and player.Parent == Players
end

local function markAttemptResourcesChanged(attempt)
	attempt.ResourceGeneration += 1
end

local function publishInvalidation(kind, roomId)
	local ok = pcall(MessagingService.PublishAsync, MessagingService, directoryConfig.MessagingTopic, {
		Kind = kind,
		RoomId = roomId,
		At = os.time(),
	})
	if not ok then warn("[BLIKK ROOM] Directory invalidation failed: MESSAGING_UNAVAILABLE") end
end

local function publicRecord(room)
	local count = 0; for _ in room.Members do count += 1 end
	local leader = Players:GetPlayerByUserId(room.RoomLeaderUserId)
	local mode = Modes.Get(room.Config.ModeId)
	local joinable = room.State == "Lobby"
		or (room.Config.JoinInProgressEnabled
			and (room.State == "LoadingMatch" or room.State == "Countdown"
				or room.State == "InProgress" or room.State == "RoundIntermission"))
		or (room.SystemKind == publicDeathmatchConfig.SystemKind
			and (room.State == "PostMatch" or room.State == "ReturningToLobby"))
	return { DirectoryVersion = 1, RoomId = room.RoomId, Name = room.Name, LeaderUserId = room.RoomLeaderUserId, LeaderDisplayName = leader and leader.DisplayName or "", LeaderClanTag = leader and leader:GetAttribute("BLIKK_ClanTag") or nil, ModeId = room.Config.ModeId, MapId = room.Config.MapId, Mutators = table.clone(room.Config.Mutators), CurrentPlayers = count, MaximumPlayers = room.Config.MaximumPlayers, State = room.State, IsPublic = room.Config.IsPublic, JoinInProgressEnabled = room.Config.JoinInProgressEnabled, Joinable = joinable, LateJoinBehavior = mode and mode.LateJoinBehavior or nil, MatchmakingType = game.MatchmakingType.Name, Revision = room.Revision, UpdatedAtUnix = os.time(), SystemKind = room.SystemKind }
end

function Directory:UpdateRoom(room)
	if RunService:IsStudio() then return end
	local record = publicRecord(room)
	local wasOwnedDestination = ownedRoom == room
	local function isCurrentDestinationOwner()
		return ownedRoom == room
			and roomService:GetRoomById(room.RoomId) == room
	end
	local function clearStaleDestinationWrite(secret)
		listingMap:RemoveAsync(room.RoomId)
		secretMap:RemoveAsync(room.RoomId)
		local privateServerId = type(secret) == "table" and secret.PrivateServerId or game.PrivateServerId
		if type(privateServerId) == "string" and privateServerId ~= "" then
			privateLookup:RemoveAsync(privateServerId)
		end
		local joinCode = type(secret) == "table" and secret.JoinCode or room.JoinCode
		if type(joinCode) == "string" and joinCode ~= "" then
			codeLookup:RemoveAsync(joinCode)
		end
	end
	local function abortStaleDestination(secret)
		if not wasOwnedDestination or isCurrentDestinationOwner() then return false end
		clearStaleDestinationWrite(secret)
		return true
	end
	local ok = retry(function()
		if abortStaleDestination(nil) then return end
		listingMap:SetAsync(room.RoomId, record, directoryConfig.ListingTtlSeconds, record.UpdatedAtUnix)
		if abortStaleDestination(nil) then return end
		if not ownedRoom or ownedRoom.RoomId ~= room.RoomId then return end
		local metadata = reservedRoomMetadata[room.RoomId]
		local secret = metadata and metadata.Secret or secretMap:GetAsync(room.RoomId)
		if abortStaleDestination(secret) then return end
		if type(secret) ~= "table" or type(secret.PrivateServerId) ~= "string"
			or type(secret.AccessCode) ~= "string" then
			error("ROOM_SECRET_UNAVAILABLE")
		end
		secret.Name = room.Name
		secret.Config = room.Config
		secret.RoomLeaderUserId = room.RoomLeaderUserId
		secret.JoinCode = room.JoinCode
		secret.SystemKind = room.SystemKind
		if metadata then metadata.Secret = secret end
		secretMap:SetAsync(room.RoomId, secret, directoryConfig.SecretTtlSeconds)
		if abortStaleDestination(secret) then return end
		privateLookup:SetAsync(secret.PrivateServerId, room.RoomId, directoryConfig.SecretTtlSeconds)
		if abortStaleDestination(secret) then return end
		if room.JoinCode then
			codeLookup:SetAsync(room.JoinCode, room.RoomId, directoryConfig.SecretTtlSeconds)
			if abortStaleDestination(secret) then return end
		end
		if room.SystemKind == publicDeathmatchConfig.SystemKind then
			local now = os.time()
			publicDeathmatchAnchorMap:UpdateAsync(publicDeathmatchAnchorKey(), function(current)
				local bootstrapId = type(current) == "table" and current.BootstrapId or nil
				return {
					BootstrapId = bootstrapId,
					RoomId = room.RoomId,
					PrivateServerId = secret.PrivateServerId,
					LeaderUserId = room.RoomLeaderUserId,
					ServerJobId = game.JobId,
					MatchmakingType = game.MatchmakingType.Name,
					UpdatedAtUnix = now,
					ExpiresAtUnix = now + publicDeathmatchConfig.AnchorTtlSeconds,
				}
			end, publicDeathmatchConfig.AnchorTtlSeconds)
		end
	end)
	if not ok then warn("[BLIKK ROOM] Directory heartbeat failed: DIRECTORY_UNAVAILABLE") end
	if ok and wasOwnedDestination and isCurrentDestinationOwner()
		and room.Revision ~= record.Revision then
		task.defer(function()
			if isCurrentDestinationOwner() then self:UpdateRoom(room) end
		end)
	end
end

function Directory:CloseRoom(roomOrId)
	local room = if type(roomOrId) == "table" then roomOrId else nil
	local roomId = if room then room.RoomId else roomOrId
	if type(roomId) ~= "string" then return end
	local wasOwnedRoom = ownedRoom and ownedRoom.RoomId == roomId
	if wasOwnedRoom then ownedRoom = nil end
	if RunService:IsStudio() then return end
	local metadata = reservedRoomMetadata[roomId]
	local privateServerId = room and room.PrivateServerId
		or metadata and metadata.PrivateServerId
		or (wasOwnedRoom and game.PrivateServerId)
	local joinCode = room and room.JoinCode or metadata and metadata.JoinCode
	local systemKind = room and room.SystemKind
	local listingRemoved = retry(function() return listingMap:RemoveAsync(roomId) end)
	local secretRemoved = retry(function() return secretMap:RemoveAsync(roomId) end)
	local privateLookupRemoved = true
	local joinCodeRemoved = true
	if type(privateServerId) == "string" and privateServerId ~= "" then
		privateLookupRemoved = retry(function() return privateLookup:RemoveAsync(privateServerId) end)
	end
	if type(joinCode) == "string" and joinCode ~= "" then
		joinCodeRemoved = retry(function() return codeLookup:RemoveAsync(joinCode) end)
	end
	if systemKind == publicDeathmatchConfig.SystemKind then
		retry(function()
			return publicDeathmatchAnchorMap:UpdateAsync(
				publicDeathmatchAnchorKey(),
				function(current)
					if type(current) == "table" and current.RoomId == roomId
						and current.ServerJobId == game.JobId then return nil end
					return current
				end,
				publicDeathmatchConfig.AnchorTtlSeconds
			)
		end)
	end
	reservedRoomMetadata[roomId] = nil
	if not listingRemoved or not secretRemoved or not privateLookupRemoved or not joinCodeRemoved then
		warn("[BLIKK ROOM] Room directory cleanup failed: DIRECTORY_REMOVE_FAILED")
	end
	publishInvalidation("RoomClosed", roomId)
end

local function listRooms()
	if RunService:IsStudio() then return roomService:GetLocalListings() end
	local ok, page = retry(function() return listingMap:GetRangeAsync(Enum.SortDirection.Descending, directoryConfig.QueryPageSize) end)
	if not ok then return nil, "DIRECTORY_UNAVAILABLE" end
	local results = {}
	for _, item in page do
		local record = item.value
		if type(record) == "table" and record.IsPublic == true
			and record.MatchmakingType == game.MatchmakingType.Name
			and os.time() - (record.UpdatedAtUnix or 0) <= directoryConfig.StaleSeconds
			and #results < directoryConfig.MaximumBrowserResults then
			table.insert(results, record)
		end
	end
	return results
end

local function validPublicReservation(value)
	return type(value) == "table"
		and value.SchemaVersion == 1
		and value.PlaceId == game.PlaceId
		and type(value.AccessCode) == "string" and value.AccessCode ~= ""
		and type(value.PrivateServerId) == "string" and value.PrivateServerId ~= ""
end

local function ensurePublicDeathmatchReservation(player, attempt)
	local function attemptCurrent()
		return isTransportAttemptCurrent(player, attempt)
	end
	local readOk, stored = retry(function()
		return publicDeathmatchReservationStore:GetAsync(
			publicDeathmatchConfig.ReservationStoreKey
		)
	end, attemptCurrent)
	if readOk and validPublicReservation(stored) then return stored end
	if not attemptCurrent() then return nil, "TRANSPORT_CANCELLED" end
	attempt.Stage = "ReservingPublicDeathmatch"
	local reserved, accessCode, privateServerId = retry(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end, attemptCurrent)
	if not reserved or type(accessCode) ~= "string" or type(privateServerId) ~= "string" then
		return nil, "PUBLIC_FFA_RESERVE_FAILED"
	end
	local candidate = {
		SchemaVersion = 1,
		PlaceId = game.PlaceId,
		AccessCode = accessCode,
		PrivateServerId = privateServerId,
		CreatedAtUnix = os.time(),
	}
	local storedOk, authoritative = retry(function()
		return publicDeathmatchReservationStore:UpdateAsync(
			publicDeathmatchConfig.ReservationStoreKey,
			function(current)
				return if validPublicReservation(current) then current else candidate
			end
		)
	end, attemptCurrent)
	if not storedOk or not validPublicReservation(authoritative) then
		return nil, "PUBLIC_FFA_RESERVATION_STORE_FAILED"
	end
	return authoritative
end

local function publicDeathmatchListing(leaderUserId)
	local mode = Modes.Get(publicDeathmatchConfig.ModeId)
	return {
		DirectoryVersion = 1,
		RoomId = publicDeathmatchRoomId(),
		Name = publicDeathmatchConfig.DisplayName,
		LeaderUserId = leaderUserId,
		LeaderDisplayName = "",
		ModeId = publicDeathmatchConfig.ModeId,
		MapId = publicDeathmatchConfig.MapId,
		Mutators = {},
		CurrentPlayers = 0,
		MaximumPlayers = publicDeathmatchConfig.MaximumPlayers,
		State = "Lobby",
		IsPublic = true,
		JoinInProgressEnabled = true,
		Joinable = true,
		LateJoinBehavior = mode and mode.LateJoinBehavior or "SPAWN_IMMEDIATELY",
		MatchmakingType = game.MatchmakingType.Name,
		Revision = 0,
		UpdatedAtUnix = os.time(),
		SystemKind = publicDeathmatchConfig.SystemKind,
	}
end

local function preparePublicDeathmatch(player, attempt, reservation)
	local roomId = publicDeathmatchRoomId()
	local now = os.time()
	local proposed = {
		BootstrapId = attempt.Id,
		RoomId = roomId,
		PrivateServerId = reservation.PrivateServerId,
		LeaderUserId = player.UserId,
		ServerJobId = "",
		MatchmakingType = game.MatchmakingType.Name,
		UpdatedAtUnix = now,
		ExpiresAtUnix = now + publicDeathmatchConfig.AnchorTtlSeconds,
	}
	local anchorOk, anchor = retry(function()
		return publicDeathmatchAnchorMap:UpdateAsync(
			publicDeathmatchAnchorKey(),
			function(current)
				local isLive = type(current) == "table"
					and current.RoomId == roomId
					and current.PrivateServerId == reservation.PrivateServerId
					and current.MatchmakingType == game.MatchmakingType.Name
					and (current.ExpiresAtUnix or 0) > os.time()
				return if isLive then current else proposed
			end,
			publicDeathmatchConfig.AnchorTtlSeconds
		)
	end, function()
		return isTransportAttemptCurrent(player, attempt)
	end)
	if not anchorOk or type(anchor) ~= "table" then
		return nil, "PUBLIC_FFA_DIRECTORY_UNAVAILABLE"
	end
	attempt.RoomId = roomId
	attempt.PrivateServerId = reservation.PrivateServerId
	attempt.PublicBootstrapId = anchor.BootstrapId
	if anchor.BootstrapId == attempt.Id then
		attempt.OwnsPublicBootstrap = true
		attempt.Stage = "WritingPublicDeathmatch"
		local secret = {
			RoomId = roomId,
			Name = publicDeathmatchConfig.DisplayName,
			Config = publicDeathmatchRoomConfig(),
			RoomLeaderUserId = player.UserId,
			JoinCode = nil,
			AccessCode = reservation.AccessCode,
			PrivateServerId = reservation.PrivateServerId,
			MatchmakingType = game.MatchmakingType.Name,
			CreatedAtUnix = os.time(),
			SystemKind = publicDeathmatchConfig.SystemKind,
		}
		local function attemptCurrent()
			return isTransportAttemptCurrent(player, attempt)
		end
		local secretStored = retry(function()
			return secretMap:SetAsync(roomId, secret, directoryConfig.SecretTtlSeconds)
		end, attemptCurrent)
		markAttemptResourcesChanged(attempt)
		local lookupStored = secretStored and retry(function()
			return privateLookup:SetAsync(
				reservation.PrivateServerId,
				roomId,
				directoryConfig.SecretTtlSeconds
			)
		end, attemptCurrent)
		if lookupStored then markAttemptResourcesChanged(attempt) end
		local listingStored = lookupStored and retry(function()
			local listing = publicDeathmatchListing(player.UserId)
			return listingMap:SetAsync(
				roomId,
				listing,
				directoryConfig.ListingTtlSeconds,
				listing.UpdatedAtUnix
			)
		end, attemptCurrent)
		if listingStored then markAttemptResourcesChanged(attempt) end
		if not secretStored or not lookupStored or not listingStored then
			return nil, "PUBLIC_FFA_DIRECTORY_WRITE_FAILED"
		end
		return secret
	end

	local deadline = os.clock() + publicDeathmatchConfig.BootstrapWaitSeconds
	repeat
		if not isTransportAttemptCurrent(player, attempt) then
			return nil, "TRANSPORT_CANCELLED"
		end
		local secretOk, secret = pcall(secretMap.GetAsync, secretMap, roomId)
		if secretOk and type(secret) == "table"
			and secret.PrivateServerId == reservation.PrivateServerId
			and secret.SystemKind == publicDeathmatchConfig.SystemKind then return secret end
		task.wait(0.25)
	until os.clock() >= deadline
	return nil, "PUBLIC_FFA_BOOTSTRAP_TIMEOUT"
end

local function closeAttemptRoom(attempt)
	local room = attempt.Room
	if room and roomService:GetRoom(attempt.Player) == room then
		roomService:LeavePlayer(attempt.Player)
	end
	if attempt.RoomId then
		Directory:CloseRoom({
			RoomId = attempt.RoomId,
			JoinCode = attempt.JoinCode,
			PrivateServerId = attempt.PrivateServerId,
		})
	end
end

local function cleanupTransportResources(attempt)
	if attempt.DepartureConfirmed then return end
	if attempt.JoinNonce then
		local removed = retry(function()
			return nonceMap:RemoveAsync(attempt.JoinNonce)
		end)
		if not removed then
			warn("[BLIKK TELEPORT] Join authorization cleanup failed: NONCE_REMOVE_FAILED")
		end
	end
	if attempt.Operation == "Create" then closeAttemptRoom(attempt) end
end

local function requestTransportCleanup(attempt)
	attempt.CleanupRequestedGeneration = math.max(
		attempt.CleanupRequestedGeneration,
		attempt.ResourceGeneration
	)
	if attempt.CleanupRunning
		or attempt.CleanupRequestedGeneration <= attempt.CleanupCompletedGeneration then return end
	attempt.CleanupRunning = true
	task.spawn(function()
		while attempt.CleanupRequestedGeneration > attempt.CleanupCompletedGeneration do
			local targetGeneration = attempt.CleanupRequestedGeneration
			cleanupTransportResources(attempt)
			attempt.CleanupCompletedGeneration = targetGeneration
		end
		attempt.CleanupRunning = false
		if attempt.CleanupRequestedGeneration > attempt.CleanupCompletedGeneration then
			requestTransportCleanup(attempt)
		end
	end)
end

local function reserveRoom(player, payload, attempt)
	if RunService:IsStudio() then return nil, "PUBLISHED_CLIENT_REQUIRED" end
	local roomSnapshot, code = roomService:CreateForPlayer(player, payload, true)
	if not roomSnapshot then return nil, code end
	local room = roomService:GetRoom(player)
	local reservationGeneration = room and room.ReservationGeneration
	attempt.Room = room
	attempt.RoomId = room and room.RoomId or nil
	attempt.JoinCode = room and room.JoinCode or nil
	attempt.ReservationGeneration = reservationGeneration
	markAttemptResourcesChanged(attempt)
	if not isTransportAttemptCurrent(player, attempt)
		or not room
		or not roomService:IsReservationCurrent(player, room, reservationGeneration) then
		requestTransportCleanup(attempt)
		return nil, "RESERVATION_CANCELLED"
	end
	attempt.Stage = "ReservingServer"
	local function attemptCurrent()
		return isTransportAttemptCurrent(player, attempt)
	end
	local ok, accessCode, privateServerId = retry(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end, attemptCurrent)
	if not ok then
		if not attemptCurrent() then
			requestTransportCleanup(attempt)
			return nil, "RESERVATION_CANCELLED"
		end
		warn("[BLIKK TELEPORT] Reserved room creation failed: RESERVE_FAILED")
		return nil, "RESERVE_FAILED"
	end
	if not isTransportAttemptCurrent(player, attempt)
		or not roomService:IsReservationCurrent(player, room, reservationGeneration) then
		requestTransportCleanup(attempt)
		return nil, "RESERVATION_CANCELLED"
	end
	attempt.PrivateServerId = privateServerId
	attempt.Stage = "WritingDirectory"
	local secret = { RoomId = room.RoomId, Name = room.Name, Config = room.Config, RoomLeaderUserId = player.UserId, JoinCode = room.JoinCode, AccessCode = accessCode, PrivateServerId = privateServerId, MatchmakingType = game.MatchmakingType.Name, CreatedAtUnix = room.CreatedAtUnix }
	reservedRoomMetadata[room.RoomId] = {
		PrivateServerId = privateServerId,
		JoinCode = room.JoinCode,
		Secret = secret,
	}
	local secretStored = retry(function()
		return secretMap:SetAsync(room.RoomId, secret, directoryConfig.SecretTtlSeconds)
	end, attemptCurrent)
	markAttemptResourcesChanged(attempt)
	local reservationCurrent = secretStored
		and isTransportAttemptCurrent(player, attempt)
		and roomService:IsReservationCurrent(player, room, reservationGeneration)
	local privateLookupStored = reservationCurrent and retry(function()
		return privateLookup:SetAsync(privateServerId, room.RoomId, directoryConfig.SecretTtlSeconds)
	end, attemptCurrent)
	if reservationCurrent then markAttemptResourcesChanged(attempt) end
	reservationCurrent = privateLookupStored
		and isTransportAttemptCurrent(player, attempt)
		and roomService:IsReservationCurrent(player, room, reservationGeneration)
	local joinCodeStored = true
	if reservationCurrent and room.JoinCode then
		joinCodeStored = retry(function()
			return codeLookup:SetAsync(room.JoinCode, room.RoomId, directoryConfig.SecretTtlSeconds)
		end, attemptCurrent)
		markAttemptResourcesChanged(attempt)
	end
	reservationCurrent = joinCodeStored
		and isTransportAttemptCurrent(player, attempt)
		and roomService:IsReservationCurrent(player, room, reservationGeneration)
	if not secretStored or not privateLookupStored or not joinCodeStored or not reservationCurrent then
		local stillCurrent = isTransportAttemptCurrent(player, attempt)
			and roomService:IsReservationCurrent(player, room, reservationGeneration)
		if not stillCurrent then
			requestTransportCleanup(attempt)
		else
			warn("[BLIKK TELEPORT] Reserved room creation failed: DIRECTORY_WRITE_FAILED")
		end
		return nil, if stillCurrent then "DIRECTORY_WRITE_FAILED" else "RESERVATION_CANCELLED"
	end
	return secret, nil, room, reservationGeneration
end

local function teleportToRoom(player, roomId, requestedRole, attempt, bypassListingCheck)
	local function cancelledResult()
		requestTransportCleanup(attempt)
		return false, "TRANSPORT_CANCELLED"
	end
	if not isTransportAttemptCurrent(player, attempt) then return cancelledResult() end
	local function attemptCurrent()
		return isTransportAttemptCurrent(player, attempt)
	end
	if not bypassListingCheck then
		local listingOk, listing = retry(function() return listingMap:GetAsync(roomId) end, attemptCurrent)
		if not isTransportAttemptCurrent(player, attempt) then return cancelledResult() end
		if not listingOk or type(listing) ~= "table" or listing.Joinable ~= true then
			return false, "ROOM_NOT_JOINABLE"
		end
	end
	local ok, secret = retry(function() return secretMap:GetAsync(roomId) end, attemptCurrent)
	if not isTransportAttemptCurrent(player, attempt) then return cancelledResult() end
	if not ok or type(secret) ~= "table" or type(secret.AccessCode) ~= "string" then return false, "ROOM_UNAVAILABLE" end
	if secret.MatchmakingType ~= game.MatchmakingType.Name then
		return false, "CROSS_PLAY_PARTITION_UNAVAILABLE"
	end
	local nonce = HttpService:GenerateGUID(false)
	attempt.JoinNonce = nonce
	local nonceStored = retry(function() nonceMap:SetAsync(nonce, { UserId = player.UserId, RoomId = roomId, PrivateServerId = secret.PrivateServerId, ExpiresAtUnix = os.time() + directoryConfig.JoinNonceTtlSeconds }, directoryConfig.JoinNonceTtlSeconds) end, attemptCurrent)
	markAttemptResourcesChanged(attempt)
	if not isTransportAttemptCurrent(player, attempt) then return cancelledResult() end
	if not nonceStored then return false, "JOIN_AUTH_FAILED" end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = secret.AccessCode
	options:SetTeleportData({ ProtocolVersion = Config.ProtocolVersion, RoomId = roomId, JoinNonce = nonce, RequestedRole = requestedRole == "Spectator" and "Spectator" or "Player", SourceServerJobId = game.JobId, TransportAttemptId = attempt.Id })
	for retryIndex = 1, directoryConfig.TeleportRetryCount do
		if not isTransportAttemptCurrent(player, attempt) then return cancelledResult() end
		attempt.Stage = "TeleportCalling"
		local teleported = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
		if teleported then
			if attempt.PlayerDepartedDuringTeleportCall or player.Parent ~= Players then
				attempt.DepartureConfirmed = true
			end
			if transportAttempts[player] ~= attempt or attempt.Cancelled then
				return cancelledResult()
			end
			attempt.Stage = "TeleportInitiated"
			return true
		end
		attempt.DepartureConfirmed = false
		attempt.PlayerDepartedDuringTeleportCall = false
		attempt.Stage = "TeleportRetry"
		if attempt.DeadlineExpiredDuringTeleportCall then
			return false, "TRANSPORT_DEADLINE_EXCEEDED"
		end
		if not isTransportAttemptCurrent(player, attempt) then return cancelledResult() end
		if retryIndex < directoryConfig.TeleportRetryCount then
			task.wait(directoryConfig.RetryBaseDelaySeconds * retryIndex)
		end
	end
	warn("[BLIKK TELEPORT] Reserved teleport failed: TELEPORT_FAILED")
	return false, "TELEPORT_FAILED"
end

local function validateArrival(player)
	if game.PrivateServerId == "" then return end
	local joinData = player:GetJoinData(); local data = joinData and joinData.TeleportData
	if type(data) ~= "table" or data.ProtocolVersion ~= Config.ProtocolVersion or type(data.RoomId) ~= "string" or type(data.JoinNonce) ~= "string" then player:Kick("Room authorization failed"); return end
	local consumedBy = HttpService:GenerateGUID(false)
	local now = os.time()
	local ok, nonce = retry(function()
		return nonceMap:UpdateAsync(data.JoinNonce, function(current)
			if type(current) ~= "table" or current.ConsumedBy ~= nil
				or current.UserId ~= player.UserId or current.RoomId ~= data.RoomId
				or current.PrivateServerId ~= game.PrivateServerId
				or (current.ExpiresAtUnix or 0) < now then return nil end
			local consumed = table.clone(current)
			consumed.ConsumedBy = consumedBy
			consumed.ConsumedAtUnix = now
			return consumed
		end, directoryConfig.JoinNonceTtlSeconds)
	end)
	if not ok or type(nonce) ~= "table" or nonce.ConsumedBy ~= consumedBy then
		player:Kick("Room authorization expired")
		return
	end
	local secretOk, secret = retry(function() return secretMap:GetAsync(data.RoomId) end)
	if not secretOk or type(secret) ~= "table" or secret.PrivateServerId ~= game.PrivateServerId
		or secret.MatchmakingType ~= game.MatchmakingType.Name then
		player:Kick("Room is unavailable")
		return
	end
	local accepted = roomService:AcceptTeleportedPlayer(player, secret, data.RequestedRole)
	if not accepted then
		warn("[BLIKK ROOM] Reserved-room membership failed: ARRIVAL_REJECTED")
		player:Kick("Room admission failed")
		return
	end
	reservedRoomMetadata[data.RoomId] = {
		PrivateServerId = secret.PrivateServerId,
		JoinCode = secret.JoinCode,
		Secret = secret,
	}
	ownedRoom = roomService:GetRoom(player)
	local admittedRoom = ownedRoom
	if admittedRoom then
		task.defer(function()
			if ownedRoom == admittedRoom then Directory:UpdateRoom(admittedRoom) end
		end)
	end
end

local function failure(code)
	return {
		Success = false,
		Transport = "Failure",
		Code = code or "UNKNOWN_FAILURE",
	}
end

local function localRoomResult(snapshotValue, code, matchSnapshot)
	if not snapshotValue then return failure(code) end
	return {
		Success = true,
		Transport = "LocalRoom",
		Code = "LOCAL_ROOM",
		RoomSnapshot = snapshotValue,
		MatchSnapshot = matchSnapshot,
	}
end

local function teleportResult(success, code, attempt)
	if not success then return failure(code) end
	return {
		Success = true,
		Transport = "ReservedServerTeleport",
		Status = "Teleporting",
		Code = "TELEPORTING",
		TransportAttemptId = attempt and attempt.Id or nil,
	}
end

function Directory:Init(remoteRegistry, rooms)
	roomService = rooms; roomService:SetDirectoryService(self)
	local function failTransportAttempt(player, attempt, reason)
		if not clearTransportAttempt(player, attempt) then return false end
		warn("[BLIKK TELEPORT] Reserved teleport failed: " .. reason)
		if player.Parent == Players then
			remoteRegistry.RoomUpdated:FireClient(player, {
				Warning = "TELEPORT_FAILED_RETRY",
				TransportAttemptId = attempt.Id,
			})
		end
		requestTransportCleanup(attempt)
		return true
	end
	local function armTransportDeadline(player, attempt)
		task.delay(directoryConfig.TransportPrecommitDeadlineSeconds, function()
			if transportAttempts[player] ~= attempt then return end
			if attempt.Stage ~= "TeleportCalling" and attempt.Stage ~= "TeleportInitiated" then
				failTransportAttempt(player, attempt, "TRANSPORT_DEADLINE_EXCEEDED")
				return
			end
			if attempt.PlayerDepartedDuringTeleportCall or player.Parent ~= Players then
				attempt.DepartureConfirmed = true
				clearTransportAttempt(player, attempt)
				if attempt.Operation == "Create" and attempt.RoomId then
					reservedRoomMetadata[attempt.RoomId] = nil
				end
				return
			end
			attempt.DeadlineExpiredDuringTeleportCall = true
			warn("[BLIKK TELEPORT] Transport deadline reached during a committed platform call.")
			remoteRegistry.RoomUpdated:FireClient(player, {
				Warning = "TELEPORT_COMMIT_PENDING",
				TransportAttemptId = attempt.Id,
			})
			task.delay(directoryConfig.CommittedTransportAbortDelaySeconds, function()
				if transportAttempts[player] ~= attempt
					or (attempt.Stage ~= "TeleportCalling"
						and attempt.Stage ~= "TeleportInitiated") then return end
				if attempt.PlayerDepartedDuringTeleportCall or player.Parent ~= Players then
					attempt.DepartureConfirmed = true
					clearTransportAttempt(player, attempt)
					if attempt.Operation == "Create" and attempt.RoomId then
						reservedRoomMetadata[attempt.RoomId] = nil
					end
					return
				end
				attempt.DepartureConfirmed = true
				clearTransportAttempt(player, attempt)
				if attempt.Operation == "Create" and attempt.RoomId then
					reservedRoomMetadata[attempt.RoomId] = nil
				end
				if player.Parent == Players then
					player:Kick("Teleport did not complete. Please reconnect and retry.")
				end
			end)
		end)
	end
	local function cancelTransportWithoutNotice(player, attempt)
		clearTransportAttempt(player, attempt)
		requestTransportCleanup(attempt)
	end
	remoteRegistry.DirectoryRequest.OnServerInvoke = function(player, operation, payload)
		if not RateLimiter.Allow(limiter, player, "Directory", Config.BrowserQueryCooldownSeconds, 2) then return failure("RATE_LIMITED") end
		if operation == "List" then local result, code = listRooms(); return { Success = result ~= nil, Code = code or "OK", Rooms = result } end
		if operation == "QuickPlayPublicDeathmatch" then
			if not roomService:CanEnterDirectoryRoom(player) then
				return failure("PLAYER_UNAVAILABLE")
			end
			if RunService:IsStudio() then
				local roomSnapshot, code = roomService:JoinPublicDeathmatchLocal(player)
				return localRoomResult(roomSnapshot, code, roomService:GetMatchSnapshot(player))
			end
			local attempt = beginTransportAttempt(player, operation)
			if not attempt then return failure("TRANSPORT_IN_PROGRESS") end
			armTransportDeadline(player, attempt)
			local reservation, reservationCode = ensurePublicDeathmatchReservation(player, attempt)
			if not reservation then
				cancelTransportWithoutNotice(player, attempt)
				return failure(reservationCode)
			end
			local secret, bootstrapCode = preparePublicDeathmatch(player, attempt, reservation)
			if not secret then
				cancelTransportWithoutNotice(player, attempt)
				return failure(bootstrapCode)
			end
			local success, code = teleportToRoom(
				player,
				secret.RoomId,
				"Player",
				attempt,
				true
			)
			if not success then cancelTransportWithoutNotice(player, attempt) end
			if success and player.Parent ~= Players then clearTransportAttempt(player, attempt) end
			return teleportResult(success, code, attempt)
		end
		if operation == "Create" then
			if RunService:IsStudio() then
				local roomSnapshot, code = roomService:CreateForPlayer(player, payload)
				return localRoomResult(roomSnapshot, code, nil)
			end
			local attempt = beginTransportAttempt(player, operation)
			if not attempt then return failure("TRANSPORT_IN_PROGRESS") end
			armTransportDeadline(player, attempt)
			local secret, code, room, reservationGeneration = reserveRoom(player, payload, attempt)
			if not secret then
				cancelTransportWithoutNotice(player, attempt)
				return failure(code)
			end
			local success, teleportCode = teleportToRoom(
				player,
				secret.RoomId,
				"Player",
				attempt,
				true
			)
			if success then
				local released = roomService:ReleaseForTeleport(player, room, reservationGeneration)
				if released or player.Parent ~= Players then
					attempt.ReleasedForTeleport = true
					if player.Parent ~= Players then attempt.DepartureConfirmed = true end
				else
					cancelTransportWithoutNotice(player, attempt)
					return failure("RESERVATION_SUPERSEDED")
				end
			else
				cancelTransportWithoutNotice(player, attempt)
			end
			if success and player.Parent ~= Players then
				clearTransportAttempt(player, attempt)
				reservedRoomMetadata[attempt.RoomId] = nil
			end
			return teleportResult(success, teleportCode, attempt)
		end
		if operation == "Join" and type(payload) == "table" and type(payload.RoomId) == "string" and #payload.RoomId <= 64 then
			if RunService:IsStudio() then
				local snapshotValue, code = roomService:JoinForPlayer(player, payload)
				return localRoomResult(snapshotValue, code, roomService:GetMatchSnapshot(player))
			end
			local attempt = beginTransportAttempt(player, operation)
			if not attempt then return failure("TRANSPORT_IN_PROGRESS") end
			armTransportDeadline(player, attempt)
			attempt.RoomId = payload.RoomId
			local success, code = teleportToRoom(
				player,
				payload.RoomId,
				payload.RequestedRole,
				attempt,
				false
			)
			if not success then cancelTransportWithoutNotice(player, attempt) end
			if success and player.Parent ~= Players then clearTransportAttempt(player, attempt) end
			return teleportResult(success, code, attempt)
		end
		if operation == "JoinCode" and not RunService:IsStudio() and type(payload) == "string" and #payload == Config.JoinCodeLength then
			local attempt = beginTransportAttempt(player, operation)
			if not attempt then return failure("TRANSPORT_IN_PROGRESS") end
			armTransportDeadline(player, attempt)
			local ok, roomId = retry(function()
				return codeLookup:GetAsync(payload:upper())
			end, function()
				return isTransportAttemptCurrent(player, attempt)
			end)
			if not ok or type(roomId) ~= "string" then
				local wasCurrent = isTransportAttemptCurrent(player, attempt)
				cancelTransportWithoutNotice(player, attempt)
				return failure(if wasCurrent then "INVALID_JOIN_CODE" else "TRANSPORT_CANCELLED")
			end
			attempt.RoomId = roomId
			local success, code = teleportToRoom(player, roomId, "Player", attempt, false)
			if not success then cancelTransportWithoutNotice(player, attempt) end
			if success and player.Parent ~= Players then clearTransportAttempt(player, attempt) end
			return teleportResult(success, code, attempt)
		end
		return failure("INVALID_OPERATION")
	end
	local subscribed, connection = pcall(MessagingService.SubscribeAsync, MessagingService, directoryConfig.MessagingTopic, function() end)
	if subscribed then
		subscription = connection
	elseif not RunService:IsStudio() then
		warn("[BLIKK ROOM] Directory subscription failed: MESSAGING_UNAVAILABLE")
	end
	TeleportService.TeleportInitFailed:Connect(function(player, _teleportResult, _errorMessage, placeId, teleportOptions)
		local attempt = transportAttempts[player]
		if not attempt then return end
		if not teleportOptions or not teleportOptions:IsA("TeleportOptions") then
			warn("[BLIKK TELEPORT] Ignored TeleportInitFailed without correlation data.")
			return
		end
		local dataSucceeded, teleportData = pcall(
			teleportOptions.GetTeleportData,
			teleportOptions
		)
		if placeId ~= game.PlaceId or not dataSucceeded or type(teleportData) ~= "table"
			or teleportData.TransportAttemptId ~= attempt.Id then
			warn("[BLIKK TELEPORT] Ignored an uncorrelated TeleportInitFailed event.")
			return
		end
		failTransportAttempt(player, attempt, "TELEPORT_INIT_FAILED")
	end)
	Players.PlayerAdded:Connect(validateArrival)
	Players.PlayerRemoving:Connect(function(player)
		local attempt = transportAttempts[player]
		if attempt then
			if attempt.Stage == "TeleportCalling" then
				attempt.PlayerDepartedDuringTeleportCall = true
			elseif attempt.Stage == "TeleportInitiated" or attempt.ReleasedForTeleport then
				attempt.DepartureConfirmed = true
				clearTransportAttempt(player, attempt)
				if attempt.Operation == "Create" and attempt.RoomId then
					reservedRoomMetadata[attempt.RoomId] = nil
				end
			else
				cancelTransportWithoutNotice(player, attempt)
			end
		end
		RateLimiter.Clear(limiter, player)
	end)
	for _, player in Players:GetPlayers() do task.defer(validateArrival, player) end
	game:BindToClose(function()
		heartbeatGeneration += 1
		if subscription then subscription:Disconnect() end
		if ownedRoom then self:CloseRoom(ownedRoom) end
	end)
	heartbeatGeneration += 1; local generation = heartbeatGeneration
	task.spawn(function() while heartbeatGeneration == generation do task.wait(directoryConfig.HeartbeatSeconds); if ownedRoom then self:UpdateRoom(ownedRoom) end end end)
end

return Directory
