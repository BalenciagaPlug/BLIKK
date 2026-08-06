local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Clans.ClanConfig)
local RateLimiter = require(script.Parent.Parent.Networking.RateLimiter)

local ClanService = {}
local clanStore = DataStoreService:GetDataStore(Config.Stores.Clans)
local membershipStore = DataStoreService:GetDataStore(Config.Stores.Membership)
local inviteStore = DataStoreService:GetDataStore(Config.Stores.Invites)
local nameIndex = DataStoreService:GetDataStore(Config.Stores.NameIndex)
local tagIndex = DataStoreService:GetDataStore(Config.Stores.TagIndex)
local presenceMap = MemoryStoreService:GetHashMap(Config.PresenceMapName)
local sessions = {}
local limiter = RateLimiter.New()
local updateRemote = nil
local heartbeatGeneration = 0
local presenceCache = {}

local function retry(callback)
	local lastError = nil
	for attempt = 1, Config.DataStoreRetryCount do
		local ok, result = pcall(callback)
		if ok then return true, result end
		lastError = result
		if attempt < Config.DataStoreRetryCount then task.wait(Config.RetryBaseDelaySeconds * 2 ^ (attempt - 1)) end
	end
	return false, lastError
end

local function normalize(value)
	return value:lower():gsub("[^%w]", "")
end

local function filter(player, value, minimum, maximum)
	if type(value) ~= "string" then return nil end
	value = value:match("^%s*(.-)%s*$")
	if #value < minimum or #value > maximum then return nil end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(value, player.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(result) == "string" and result ~= "" then result else nil
end

local function membershipKey(userId) return "User_" .. tostring(userId) end
local function clanKey(clanId) return "Clan_" .. clanId end
local function invitesKey(userId) return "User_" .. tostring(userId) end

local function validClan(clan)
	if type(clan) ~= "table" or clan.SchemaVersion ~= Config.SchemaVersion or clan.Disbanded
		or type(clan.ClanId) ~= "string" or #clan.ClanId > 64
		or type(clan.Name) ~= "string" or #clan.Name > Config.NameMaximumLength
		or type(clan.Tag) ~= "string" or #clan.Tag > Config.TagMaximumLength
		or type(clan.OwnerUserId) ~= "number" or type(clan.Members) ~= "table" then return false end
	local count = 0
	for id, member in clan.Members do
		count += 1
		if count > Config.MaximumMembers or not tonumber(id) or type(member) ~= "table" or not Config.Roles[member.Role] then return false end
	end
	local owner = clan.Members[tostring(clan.OwnerUserId)]
	return owner ~= nil and owner.Role == "OWNER"
end

local function sanitized(clan, userId, invites)
	if clan and not validClan(clan) then clan = nil end
	local members = {}
	if clan then
		for id, member in clan.Members do
			local numericId = tonumber(id)
			if not numericId or type(member) ~= "table" or not Config.Roles[member.Role] then continue end
			local online = Players:GetPlayerByUserId(numericId) ~= nil
			local cached = presenceCache[numericId]
			if not online and (not cached or os.clock() - cached.CheckedAt >= Config.PresenceHeartbeatSeconds) then
				local ok, presence = pcall(presenceMap.GetAsync, presenceMap, id)
				cached = { CheckedAt = os.clock(), Online = ok and type(presence) == "table" and os.time() - (presence.LastHeartbeatUnix or 0) <= Config.PresenceTtlSeconds }
				presenceCache[numericId] = cached
			end
			table.insert(members, { UserId = numericId, Role = member.Role, JoinedAtUnix = member.JoinedAtUnix, Online = online or cached and cached.Online or false })
		end
		table.sort(members, function(a, b) return a.UserId < b.UserId end)
	end
	return { Clan = clan and { ClanId = clan.ClanId, Name = clan.Name, Tag = clan.Tag, Description = clan.Description, OwnerUserId = clan.OwnerUserId, Revision = clan.Revision, Members = members }, Membership = sessions[userId] and sessions[userId].Membership, Invites = invites or {} }
end

local function publish(player)
	local session = sessions[player.UserId]
	if not session then return end
	updateRemote:FireClient(player, sanitized(session.Clan, player.UserId, session.Invites))
end

local function claim(store, key, clanId)
	local accepted = false
	local ok = retry(function() return store:UpdateAsync(key, function(previous) if previous == nil or previous == clanId then accepted = true; return clanId end return previous end) end)
	return ok and accepted
end

local function createClan(player, payload)
	local session = sessions[player.UserId]
	if not session or session.Membership then return nil, "ALREADY_IN_CLAN" end
	if type(payload) ~= "table" then return nil, "INVALID_CLAN" end
	local name = filter(player, payload.Name, Config.NameMinimumLength, Config.NameMaximumLength)
	local tag = filter(player, payload.Tag, Config.TagMinimumLength, Config.TagMaximumLength)
	local description = payload.Description == nil and "" or filter(player, payload.Description, 0, Config.DescriptionMaximumLength)
	if not name or not tag or description == nil then return nil, "INVALID_OR_UNFILTERED_TEXT" end
	tag = tag:upper(); local normalizedName, normalizedTag = normalize(name), normalize(tag)
	local clanId = HttpService:GenerateGUID(false)
	if not claim(nameIndex, "Name_" .. normalizedName, clanId) then return nil, "NAME_TAKEN" end
	if not claim(tagIndex, "Tag_" .. normalizedTag, clanId) then pcall(nameIndex.RemoveAsync, nameIndex, "Name_" .. normalizedName); return nil, "TAG_TAKEN" end
	local now = os.time()
	local clan = { SchemaVersion = Config.SchemaVersion, ClanId = clanId, Name = name, NormalizedName = normalizedName, Tag = tag, OwnerUserId = player.UserId, Description = description, CreatedAtUnix = now, UpdatedAtUnix = now, Revision = 1, PendingInviteCount = 0, Members = { [tostring(player.UserId)] = { Role = "OWNER", JoinedAtUnix = now } }, Settings = { ApplicationsOpen = false } }
	local saved = retry(function() return clanStore:UpdateAsync(clanKey(clanId), function(previous) return previous or clan end) end)
	if not saved then return nil, "CREATE_FAILED_REPAIR_REQUIRED" end
	local pointer = { UserId = player.UserId, ClanId = clanId, Role = "OWNER", UpdatedAtUnix = now }
	local pointerSaved = retry(function() membershipStore:UpdateAsync(membershipKey(player.UserId), function(previous) return previous or pointer end) end)
	if not pointerSaved then pcall(function() clanStore:UpdateAsync(clanKey(clanId), function(current) if type(current) == "table" then current.Repair = { Kind = "OWNER_POINTER", UserId = player.UserId, CreatedAtUnix = os.time() }; current.Revision += 1 end return current end) end); return nil, "MEMBERSHIP_WRITE_FAILED_REPAIR_REQUIRED" end
	session.Clan = clan; session.Membership = pointer; player:SetAttribute("BLIKK_ClanId", clanId); player:SetAttribute("BLIKK_ClanTag", tag); publish(player)
	return sanitized(clan, player.UserId, session.Invites)
end

local function invite(player, targetIdentity)
	local session = sessions[player.UserId]; local clan = session and session.Clan; local role = session and session.Membership and session.Membership.Role
	if not clan or (role ~= "OWNER" and role ~= "OFFICER") then return nil, "NOT_PERMITTED" end
	local targetUserId = targetIdentity
	if type(targetIdentity) == "string" and #targetIdentity >= 3 and #targetIdentity <= 20 then local ok, resolved = pcall(Players.GetUserIdFromNameAsync, Players, targetIdentity); targetUserId = ok and resolved or nil end
	if type(targetUserId) ~= "number" or targetUserId % 1 ~= 0 or targetUserId == player.UserId then return nil, "INVALID_TARGET" end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or (sessions[targetUserId] and sessions[targetUserId].Membership) then return nil, "INVALID_TARGET" end
	local reserved = false
	local reservedOk, updatedClan = retry(function() return clanStore:UpdateAsync(clanKey(clan.ClanId), function(current)
		local currentMember = type(current) == "table" and current.Members[tostring(player.UserId)]
		if not currentMember or (currentMember.Role ~= "OWNER" and currentMember.Role ~= "OFFICER") or (current.PendingInviteCount or 0) >= Config.MaximumPendingInvites then return current end
		current.PendingInviteCount = (current.PendingInviteCount or 0) + 1; current.Revision += 1; reserved = true; return current
	end) end)
	if not reservedOk or not reserved then return nil, "CLAN_INVITE_LIMIT" end
	session.Clan = updatedClan
	local inviteRecord = { InviteId = HttpService:GenerateGUID(false), ClanId = clan.ClanId, ClanName = clan.Name, ClanTag = clan.Tag, InviterUserId = player.UserId, CreatedAtUnix = os.time(), ExpiresAtUnix = os.time() + Config.InviteExpirySeconds }
	local accepted = false
	local ok = retry(function() inviteStore:UpdateAsync(invitesKey(targetUserId), function(previous) local list = type(previous) == "table" and previous or {}; if #list >= Config.MaximumPendingInvites then return list end; table.insert(list, inviteRecord); accepted = true; return list end) end)
	if not ok or not accepted then pcall(function() clanStore:UpdateAsync(clanKey(clan.ClanId), function(current) if type(current) == "table" then current.PendingInviteCount = math.max(0, (current.PendingInviteCount or 1) - 1); current.Revision += 1 end return current end) end); return nil, "INVITE_FAILED" end
	local targetSession = sessions[targetUserId]; if targetSession then table.insert(targetSession.Invites, inviteRecord); publish(target) end
	return sanitized(clan, player.UserId, session.Invites)
end

local function acceptInvite(player, inviteId)
	local session = sessions[player.UserId]
	if not session or session.Membership or type(inviteId) ~= "string" then return nil, "INVALID_INVITE" end
	local invite = nil
	for _, candidate in session.Invites do if candidate.InviteId == inviteId and candidate.ExpiresAtUnix >= os.time() then invite = candidate end end
	if not invite then return nil, "INVITE_EXPIRED" end
	local added, updatedClan = false, nil
	local ok = retry(function() return clanStore:UpdateAsync(clanKey(invite.ClanId), function(clan) if type(clan) ~= "table" or clan.Members[tostring(player.UserId)] then return clan end; local count = 0; for _ in clan.Members do count += 1 end; if count >= Config.MaximumMembers then return clan end; clan.Members[tostring(player.UserId)] = { Role = "MEMBER", JoinedAtUnix = os.time(), InvitedByUserId = invite.InviterUserId }; clan.PendingInviteCount = math.max(0, (clan.PendingInviteCount or 1) - 1); clan.Revision += 1; clan.UpdatedAtUnix = os.time(); added = true; updatedClan = clan; return clan end) end)
	if not ok or not added then return nil, "CLAN_FULL_OR_UNAVAILABLE" end
	local pointer = { UserId = player.UserId, ClanId = invite.ClanId, Role = "MEMBER", UpdatedAtUnix = os.time() }
	local pointerOk = retry(function() membershipStore:UpdateAsync(membershipKey(player.UserId), function(previous) return previous or pointer end) end)
	if not pointerOk then pcall(function() clanStore:UpdateAsync(clanKey(invite.ClanId), function(clan) clan.Members[tostring(player.UserId)] = nil; clan.Revision += 1; return clan end) end); return nil, "JOIN_ROLLED_BACK" end
	pcall(function() inviteStore:UpdateAsync(invitesKey(player.UserId), function(previous) local remaining = {}; for _, candidate in type(previous) == "table" and previous or {} do if candidate.InviteId ~= inviteId then table.insert(remaining, candidate) end end; return remaining end) end)
	local remaining = {}; for _, candidate in session.Invites do if candidate.InviteId ~= inviteId then table.insert(remaining, candidate) end end
	session.Invites = remaining; session.Clan = updatedClan; session.Membership = pointer; player:SetAttribute("BLIKK_ClanId", invite.ClanId); player:SetAttribute("BLIKK_ClanTag", updatedClan.Tag); publish(player)
	return sanitized(updatedClan, player.UserId, session.Invites)
end

local function declineInvite(player, inviteId)
	local session = sessions[player.UserId]
	if not session or type(inviteId) ~= "string" then return nil, "INVALID_INVITE" end
	local removed, removedInvite = false, nil
	local ok = retry(function() inviteStore:UpdateAsync(invitesKey(player.UserId), function(previous)
		local nextInvites = {}; for _, invite in type(previous) == "table" and previous or {} do if invite.InviteId ~= inviteId then table.insert(nextInvites, invite) else removed = true; removedInvite = invite end end; return nextInvites
	end) end)
	if not ok or not removed then return nil, "INVALID_INVITE" end
	if removedInvite and type(removedInvite.ClanId) == "string" then pcall(function() clanStore:UpdateAsync(clanKey(removedInvite.ClanId), function(clan) if type(clan) == "table" then clan.PendingInviteCount = math.max(0, (clan.PendingInviteCount or 1) - 1); clan.Revision += 1 end return clan end) end) end
	local nextInvites = {}; for _, invite in session.Invites do if invite.InviteId ~= inviteId then table.insert(nextInvites, invite) end end; session.Invites = nextInvites; publish(player)
	return sanitized(session.Clan, player.UserId, session.Invites)
end

local function leaveOrKick(player, targetUserId)
	local session = sessions[player.UserId]; local clan = session and session.Clan
	if not clan or type(targetUserId) ~= "number" then return nil, "INVALID_TARGET" end
	local actor = clan.Members[tostring(player.UserId)]; local target = clan.Members[tostring(targetUserId)]
	if not actor or not target or target.Role == "OWNER" then return nil, "NOT_PERMITTED" end
	if targetUserId ~= player.UserId and Config.Roles[actor.Role] <= Config.Roles[target.Role] then return nil, "NOT_PERMITTED" end
	local removed = false
	local ok, updated = retry(function() return clanStore:UpdateAsync(clanKey(clan.ClanId), function(current)
		if type(current) ~= "table" or not current.Members[tostring(targetUserId)] then return current end
		current.Members[tostring(targetUserId)] = nil; current.Revision += 1; current.UpdatedAtUnix = os.time(); removed = true; return current
	end) end)
	if not ok or not removed then return nil, "UPDATE_FAILED" end
	pcall(membershipStore.RemoveAsync, membershipStore, membershipKey(targetUserId))
	local targetPlayer = Players:GetPlayerByUserId(targetUserId); local targetSession = sessions[targetUserId]
	if targetSession then targetSession.Membership = nil; targetSession.Clan = nil end
	if targetPlayer then targetPlayer:SetAttribute("BLIKK_ClanId", nil); targetPlayer:SetAttribute("BLIKK_ClanTag", nil); publish(targetPlayer) end
	session.Clan = updated; publish(player); return sanitized(updated, player.UserId, session.Invites)
end

local function setRole(player, payload)
	local session = sessions[player.UserId]; local clan = session and session.Clan
	if not clan or not session.Membership or session.Membership.Role ~= "OWNER" or type(payload) ~= "table" or type(payload.TargetUserId) ~= "number" or (payload.Role ~= "OFFICER" and payload.Role ~= "MEMBER") then return nil, "NOT_PERMITTED" end
	local targetKey = tostring(payload.TargetUserId); if not clan.Members[targetKey] or clan.Members[targetKey].Role == "OWNER" then return nil, "INVALID_TARGET" end
	local changed = false
	local ok, updated = retry(function() return clanStore:UpdateAsync(clanKey(clan.ClanId), function(current) local member = type(current) == "table" and current.Members[targetKey]; if not member or member.Role == "OWNER" then return current end; member.Role = payload.Role; current.Revision += 1; current.UpdatedAtUnix = os.time(); changed = true; return current end) end)
	if not ok or not changed then return nil, "UPDATE_FAILED" end
	pcall(function() membershipStore:UpdateAsync(membershipKey(payload.TargetUserId), function(pointer) if type(pointer) == "table" and pointer.ClanId == clan.ClanId then pointer.Role = payload.Role; pointer.UpdatedAtUnix = os.time() end return pointer end) end)
	session.Clan = updated; local targetSession = sessions[payload.TargetUserId]; if targetSession then targetSession.Clan = updated; targetSession.Membership.Role = payload.Role end
	publish(player); local targetPlayer = Players:GetPlayerByUserId(payload.TargetUserId); if targetPlayer then publish(targetPlayer) end
	return sanitized(updated, player.UserId, session.Invites)
end

local function transferOwnership(player, targetUserId)
	local session = sessions[player.UserId]; local clan = session and session.Clan
	if not clan or not session.Membership or session.Membership.Role ~= "OWNER" or type(targetUserId) ~= "number" or not clan.Members[tostring(targetUserId)] then return nil, "NOT_PERMITTED" end
	local changed = false
	local ok, updated = retry(function() return clanStore:UpdateAsync(clanKey(clan.ClanId), function(current) if type(current) ~= "table" or current.OwnerUserId ~= player.UserId or not current.Members[tostring(targetUserId)] then return current end; current.Members[tostring(player.UserId)].Role = "OFFICER"; current.Members[tostring(targetUserId)].Role = "OWNER"; current.OwnerUserId = targetUserId; current.Revision += 1; current.UpdatedAtUnix = os.time(); changed = true; return current end) end)
	if not ok or not changed then return nil, "UPDATE_FAILED" end
	for userId, role in { [player.UserId] = "OFFICER", [targetUserId] = "OWNER" } do pcall(function() membershipStore:UpdateAsync(membershipKey(userId), function(pointer) if type(pointer) == "table" and pointer.ClanId == clan.ClanId then pointer.Role = role; pointer.UpdatedAtUnix = os.time() end return pointer end) end); local online = sessions[userId]; if online then online.Clan = updated; online.Membership.Role = role end end
	publish(player); local targetPlayer = Players:GetPlayerByUserId(targetUserId); if targetPlayer then publish(targetPlayer) end
	return sanitized(updated, player.UserId, session.Invites)
end

local function disband(player)
	local session = sessions[player.UserId]; local clan = session and session.Clan
	if not clan or not session.Membership or session.Membership.Role ~= "OWNER" then return nil, "NOT_PERMITTED" end
	local removed = false
	local ok = retry(function() clanStore:UpdateAsync(clanKey(clan.ClanId), function(current)
		if type(current) == "table" and current.OwnerUserId == player.UserId then
			removed = true
			return { SchemaVersion = Config.SchemaVersion, ClanId = clan.ClanId, Disbanded = true, UpdatedAtUnix = os.time() }
		end
		return current
	end) end)
	if not ok or not removed then return nil, "DISBAND_FAILED" end
	pcall(nameIndex.RemoveAsync, nameIndex, "Name_" .. clan.NormalizedName); pcall(tagIndex.RemoveAsync, tagIndex, "Tag_" .. normalize(clan.Tag))
	for userId in clan.Members do local numericId = tonumber(userId); pcall(membershipStore.RemoveAsync, membershipStore, membershipKey(numericId)); local online = sessions[numericId]; local onlinePlayer = Players:GetPlayerByUserId(numericId); if online then online.Membership = nil; online.Clan = nil end; if onlinePlayer then onlinePlayer:SetAttribute("BLIKK_ClanId", nil); onlinePlayer:SetAttribute("BLIKK_ClanTag", nil); publish(onlinePlayer) end end
	return { Clan = nil, Membership = nil, Invites = session.Invites }
end

local function loadPlayer(player)
	local _, pointer = retry(function() return membershipStore:GetAsync(membershipKey(player.UserId)) end)
	local _, invites = retry(function() return inviteStore:GetAsync(invitesKey(player.UserId)) end)
	invites = type(invites) == "table" and invites or {}
	local validInvites = {}
	for _, invite in invites do
		if type(invite) == "table" and (invite.ExpiresAtUnix or 0) >= os.time() and #validInvites < Config.MaximumPendingInvites then table.insert(validInvites, invite)
		elseif type(invite) == "table" and type(invite.ClanId) == "string" then pcall(function() clanStore:UpdateAsync(clanKey(invite.ClanId), function(clan) if type(clan) == "table" then clan.PendingInviteCount = math.max(0, (clan.PendingInviteCount or 1) - 1); clan.Revision += 1 end return clan end) end) end
	end
	if #validInvites ~= #invites then pcall(function() inviteStore:UpdateAsync(invitesKey(player.UserId), function() return validInvites end) end) end
	local clan = nil
	if type(pointer) == "table" and type(pointer.ClanId) == "string" then
		local _, loaded = retry(function() return clanStore:GetAsync(clanKey(pointer.ClanId)) end)
		if validClan(loaded) and loaded.Members[tostring(player.UserId)] then
			clan = loaded
			local rosterRole = loaded.Members[tostring(player.UserId)].Role
			if pointer.Role ~= rosterRole then pointer.Role = rosterRole; pointer.UpdatedAtUnix = os.time(); pcall(function() membershipStore:UpdateAsync(membershipKey(player.UserId), function(current) if type(current) == "table" and current.ClanId == pointer.ClanId then current.Role = rosterRole; current.UpdatedAtUnix = pointer.UpdatedAtUnix end return current end) end) end
		else pcall(membershipStore.RemoveAsync, membershipStore, membershipKey(player.UserId)); pointer = nil end
	end
	sessions[player.UserId] = { Membership = pointer, Clan = clan, Invites = validInvites }
	player:SetAttribute("BLIKK_ClanId", clan and clan.ClanId or nil); player:SetAttribute("BLIKK_ClanTag", clan and clan.Tag or nil); publish(player)
end

function ClanService:Init(remoteRegistry)
	updateRemote = remoteRegistry.ClanUpdated
	remoteRegistry.ClanRequest.OnServerInvoke = function(player, operation, payload)
		if operation == "Snapshot" then
			if not RateLimiter.Allow(limiter, player, "ClanQuery", Config.QueryCooldownSeconds, 1) then return { Success = false, Code = "RATE_LIMITED" } end
			local session = sessions[player.UserId]; return { Success = session ~= nil, Snapshot = session and sanitized(session.Clan, player.UserId, session.Invites) }
		end
		if not RateLimiter.Allow(limiter, player, "ClanMutation", Config.MutationCooldownSeconds, 1) then return { Success = false, Code = "RATE_LIMITED" } end
		local result, code
		if operation == "Create" then result, code = createClan(player, payload)
		elseif operation == "Invite" then result, code = invite(player, payload)
		elseif operation == "AcceptInvite" then result, code = acceptInvite(player, payload)
		elseif operation == "DeclineInvite" then result, code = declineInvite(player, payload)
		elseif operation == "Leave" then result, code = leaveOrKick(player, player.UserId)
		elseif operation == "Kick" then result, code = leaveOrKick(player, payload)
		elseif operation == "SetRole" then result, code = setRole(player, payload)
		elseif operation == "TransferOwnership" then result, code = transferOwnership(player, payload)
		elseif operation == "Disband" then result, code = disband(player)
		else return { Success = false, Code = "UNSUPPORTED_OPERATION" } end
		return { Success = result ~= nil, Code = code or "OK", Snapshot = result }
	end
	Players.PlayerAdded:Connect(function(player) task.spawn(loadPlayer, player) end)
	Players.PlayerRemoving:Connect(function(player) sessions[player.UserId] = nil; presenceCache[player.UserId] = nil; RateLimiter.Clear(limiter, player); pcall(presenceMap.RemoveAsync, presenceMap, tostring(player.UserId)) end)
	for _, player in Players:GetPlayers() do task.spawn(loadPlayer, player) end
	heartbeatGeneration += 1; local generation = heartbeatGeneration
	task.spawn(function() while heartbeatGeneration == generation do task.wait(Config.PresenceHeartbeatSeconds); for _, player in Players:GetPlayers() do local session = sessions[player.UserId]; if session and session.Membership then pcall(presenceMap.SetAsync, presenceMap, tostring(player.UserId), { UserId = player.UserId, ClanId = session.Membership.ClanId, Role = session.Membership.Role, LastHeartbeatUnix = os.time() }, Config.PresenceTtlSeconds) end end end end)
	game:BindToClose(function() heartbeatGeneration += 1 end)
end

return ClanService
