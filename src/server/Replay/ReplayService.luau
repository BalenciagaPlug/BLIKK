local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Replay.ReplayConfig)
local RateLimiter = require(script.Parent.Parent.Networking.RateLimiter)

local ReplayService = {}
local recordings = {}
local playerMatchIds = {}
local remote = nil
local limiter = RateLimiter.New()
local isRunning = false

local function boundedPayload(payload)
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
	return ok and #encoded <= Config.MaximumSerializedClipBytes
end

function ReplayService:StartMatch(matchId, match)
	recordings[matchId] = { StartedAt = os.clock(), Sequence = 0, Events = {}, Snapshots = {}, Clips = {}, Match = match, Active = true }
	for player in match.Players do playerMatchIds[player] = matchId end
	self:RecordEvent(matchId, "MatchStart", { ModeId = match.ModeId, MapId = match.MapId })
end

function ReplayService:RecordEvent(matchId, eventType, payload)
	local recording = recordings[matchId]
	if not recording or #recording.Events >= Config.MaximumEventsPerMatch then return end
	recording.Sequence += 1
	table.insert(recording.Events, { Sequence = recording.Sequence, ServerTimestamp = os.time(), MatchTime = os.clock() - recording.StartedAt, Type = eventType, Payload = payload or {} })
end

function ReplayService:AddPlayer(matchId, player)
	local recording = recordings[matchId]
	if not recording or not recording.Active then return false end
	self:RecordEvent(matchId, "PlayerJoined", { UserId = player.UserId })
	return true
end

function ReplayService:RemovePlayer(player)
	playerMatchIds[player] = nil
end

function ReplayService:RecordDeath(matchId, victimUserId, killerUserId)
	self:RecordEvent(matchId, "Death", { VictimUserId = victimUserId, KillerUserId = killerUserId })
	local recording = recordings[matchId]
	if not recording then return end
	local eventTime = os.clock() - recording.StartedAt
	task.delay(Config.PostEventSeconds, function()
		if recordings[matchId] ~= recording then return end
		local frames = {}
		for _, frame in recording.Snapshots do if frame.MatchTime >= eventTime - Config.PreEventSeconds and frame.MatchTime <= eventTime + Config.PostEventSeconds then table.insert(frames, frame) end end
		local clip = { ClipId = HttpService:GenerateGUID(false), EventType = "Death", EventTime = eventTime, VictimUserId = victimUserId, KillerUserId = killerUserId, Frames = frames }
		if boundedPayload(clip) then table.insert(recording.Clips, clip); if #recording.Clips > Config.MaximumClipsPerMatch then table.remove(recording.Clips, 1) end end
	end)
end

function ReplayService:GetEvidence(matchId)
	local recording = recordings[matchId]
	if not recording then return {} end
	local excerpt = {}
	local first = math.max(1, #recording.Events - 31)
	for index = first, #recording.Events do table.insert(excerpt, recording.Events[index]) end
	return excerpt
end

function ReplayService:EndMatch(matchId)
	local recording = recordings[matchId]
	if recording then
		recording.Active = false
		task.delay(Config.PostMatchRetentionSeconds, function() if recordings[matchId] == recording then recordings[matchId] = nil end end)
	end
end

local function capture(recording)
	local players = {}
	for player in recording.Match.Players do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local _, yaw = root.CFrame:ToEulerAnglesYXZ()
			table.insert(players, { UserId = player.UserId, Position = { root.Position.X, root.Position.Y, root.Position.Z }, Yaw = yaw, Velocity = { root.AssemblyLinearVelocity.X, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z }, Alive = humanoid.Health > 0, Health = math.floor(humanoid.Health + 0.5), MovementState = tostring(humanoid:GetState()), Team = player.Team and player.Team.Name, WeaponSlot = player:GetAttribute("BLIKK_EquippedSlot") })
		end
	end
	recording.Sequence += 1
	table.insert(recording.Snapshots, { Sequence = recording.Sequence, MatchTime = os.clock() - recording.StartedAt, Players = players })
	local maximumFrames = Config.SampleRateHz * Config.RollingBufferSeconds
	while #recording.Snapshots > maximumFrames do table.remove(recording.Snapshots, 1) end
end

function ReplayService:Init(remoteRegistry)
	isRunning = true
	remote = remoteRegistry.ReplayRequest
	remote.OnServerInvoke = function(player, operation, clipId)
		if operation ~= "List" and operation ~= "Get" then return { Success = false, Code = "INVALID_OPERATION" } end
		if not RateLimiter.Allow(limiter, player, "Replay", Config.RequestCooldownSeconds, 1) then return { Success = false, Code = "RATE_LIMITED" } end
		local recording = recordings[playerMatchIds[player]]
		if not recording then return { Success = false, Code = "NO_REPLAY" } end
		if operation == "List" then
			local list = {}; for _, clip in recording.Clips do table.insert(list, { ClipId = clip.ClipId, EventType = clip.EventType, VictimUserId = clip.VictimUserId, KillerUserId = clip.KillerUserId }) end
			return { Success = true, Clips = list }
		end
		if type(clipId) ~= "string" or #clipId > 64 then return { Success = false, Code = "INVALID_CLIP" } end
		for _, clip in recording.Clips do if clip.ClipId == clipId and boundedPayload(clip) then return { Success = true, Clip = clip } end end
		return { Success = false, Code = "INVALID_CLIP" }
	end
	Players.PlayerRemoving:Connect(function(player) playerMatchIds[player] = nil; RateLimiter.Clear(limiter, player) end)
	task.spawn(function()
		while isRunning do
			task.wait(1 / Config.SampleRateHz)
			for _, recording in recordings do if recording.Active then capture(recording) end end
		end
	end)
	game:BindToClose(function() isRunning = false end)
end

return ReplayService
