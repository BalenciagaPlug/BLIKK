local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameModeRegistry = require(ReplicatedStorage.Shared.Multiplayer.GameModeRegistry)
local Config = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local MatchService = {}
local remote = nil
local roomService = nil
local spawnService = nil
local replayService = nil
local matches = {}
local playerMatch = {}
local deathConnections = {}
local damageSources = {}
local isRunning = false

local function newStats(player, member)
	return {
		UserId = player.UserId, DisplayName = player.DisplayName, TeamId = member.TeamId,
		Kills = 0, Deaths = 0, Assists = 0, Streak = 0, Score = 0,
		RoundKills = 0, RoundDeaths = 0, IsAlive = true, IsSpectating = false,
		PingMilliseconds = 0, RoomLeader = member.IsRoomLeader,
		ClanId = player:GetAttribute("BLIKK_ClanId"), ClanTag = player:GetAttribute("BLIKK_ClanTag"),
	}
end

local function snapshot(match)
	local stats = {}
	for _, record in match.Stats do table.insert(stats, table.clone(record)) end
	table.sort(stats, function(a, b)
		if a.Score ~= b.Score then return a.Score > b.Score end
		if a.Kills ~= b.Kills then return a.Kills > b.Kills end
		if a.Deaths ~= b.Deaths then return a.Deaths < b.Deaths end
		return a.UserId < b.UserId
	end)
	return {
		MatchId = match.MatchId, RoomId = match.RoomId, State = match.State,
		ModeId = match.ModeId, MapId = match.MapId, EndsAtUnix = match.EndsAtUnix,
		Round = match.Round, RoundEndsAtUnix = match.RoundEndsAtUnix,
		TeamScores = table.clone(match.TeamScores), Stats = stats,
	}
end

local function publish(match)
	local value = snapshot(match)
	for player in match.Players do
		if player.Parent == Players then remote:FireClient(player, value) end
	end
end

local function findStats(match, userId)
	for _, stats in match.Stats do if stats.UserId == userId then return stats end end
	return nil
end

local bindDeath

local function finishMatch(match, winner)
	if match.State == "PostMatch" then return end
	match.State = "PostMatch"; match.Winner = winner
	if replayService then replayService:RecordEvent(match.MatchId, "MatchEnd", { Winner = winner }) end
	publish(match)
	task.delay(Config.PostMatchSeconds, function()
		if matches[match.RoomId] ~= match then return end
		if replayService then replayService:EndMatch(match.MatchId) end
		for player in match.Players do playerMatch[player] = nil; player:SetAttribute("BLIKK_TeamId", nil) end
		matches[match.RoomId] = nil
		roomService:ReturnToLobby(match.RoomId)
	end)
end

local function startNextEliminationRound(match, mode)
	match.State = "Intermission"; publish(match)
	task.delay(mode.RoundIntermissionSeconds, function()
		if match.State ~= "Intermission" then return end
		match.Round += 1; match.State = "Active"
		match.RoundEndsAtUnix = os.time() + mode.RoundTimeSeconds
		for _, stats in match.Stats do stats.IsAlive = true; stats.IsSpectating = false; stats.RoundKills = 0; stats.RoundDeaths = 0 end
		for player in match.Players do player:LoadCharacterAsync(); task.defer(function() bindDeath(player, match); spawnService:SetSpawnProtection(player, mode.SpawnProtectionSeconds) end) end
		if replayService then replayService:RecordEvent(match.MatchId, "RoundStart", { Round = match.Round }) end
		publish(match)
	end)
end

local function evaluateDeath(match, mode)
	if mode.Id == "Deathmatch" then
		for _, stats in match.Stats do if stats.Score >= mode.ScoreLimit then finishMatch(match, stats.UserId); return end end
	elseif mode.Id == "TeamDeathmatchExtreme" then
		for teamId, score in match.TeamScores do if score >= mode.ScoreLimit then finishMatch(match, teamId); return end end
	elseif mode.Id == "Elimination" then
		local alive = { ALPHA = 0, OMEGA = 0 }
		for _, stats in match.Stats do if stats.IsAlive and stats.TeamId then alive[stats.TeamId] += 1 end end
		if alive.ALPHA > 0 and alive.OMEGA > 0 then return end
		local winner = if alive.ALPHA > alive.OMEGA then "ALPHA" elseif alive.OMEGA > alive.ALPHA then "OMEGA" else nil
		if winner then match.TeamScores[winner] += 1 end
		if winner and match.TeamScores[winner] >= math.ceil(mode.BestOfRounds / 2) then finishMatch(match, winner) else startNextEliminationRound(match, mode) end
	end
end

bindDeath = function(player, match)
	if deathConnections[player] then deathConnections[player]:Disconnect() end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	deathConnections[player] = humanoid.Died:Connect(function()
		if playerMatch[player] ~= match or match.State ~= "Active" then return end
		local victim = findStats(match, player.UserId)
		if not victim or not victim.IsAlive then return end
		victim.IsAlive = false; victim.IsSpectating = true; victim.Deaths += 1
		victim.RoundDeaths += 1; victim.Streak = 0
		local source = damageSources[player]
		damageSources[player] = nil
		local killer = source and os.clock() - source.At <= Config.DamageAttributionWindowSeconds
			and findStats(match, source.UserId) or nil
		if killer and killer.UserId ~= victim.UserId then
			killer.Kills += 1; killer.RoundKills += 1; killer.Streak += 1; killer.Score += 1
			if killer.TeamId then match.TeamScores[killer.TeamId] = (match.TeamScores[killer.TeamId] or 0) + 1 end
		end
		if replayService then replayService:RecordDeath(match.MatchId, victim.UserId, killer and killer.UserId) end
		publish(match)
		local mode = GameModeRegistry.Get(match.ModeId)
		evaluateDeath(match, mode)
		if mode.RespawnEnabled and match.State == "Active" then
			task.delay(mode.RespawnDelaySeconds, function()
				if playerMatch[player] ~= match or match.State ~= "Active" then return end
				player:LoadCharacterAsync()
				victim.IsAlive = true; victim.IsSpectating = false
				spawnService:SetSpawnProtection(player, mode.SpawnProtectionSeconds)
				publish(match)
			end)
		end
	end)
end

function MatchService:StartRoom(room)
	local mode = GameModeRegistry.Get(room.Config.ModeId)
	if not mode or matches[room.RoomId] then return false end
	local match = {
		MatchId = game:GetService("HttpService"):GenerateGUID(false), RoomId = room.RoomId,
		ModeId = mode.Id, MapId = room.Config.MapId, State = "Countdown",
		EndsAtUnix = mode.TimeLimitSeconds > 0 and os.time() + Config.CountdownSeconds + mode.TimeLimitSeconds or 0,
		Round = 1, TeamScores = { ALPHA = 0, OMEGA = 0 }, Stats = {}, Players = {},
		RoundEndsAtUnix = mode.RoundBased and os.time() + Config.CountdownSeconds + mode.RoundTimeSeconds or 0,
	}
	matches[room.RoomId] = match
	for player, member in room.Members do
		if not member.IsSpectator then
			player:SetAttribute("BLIKK_TeamId", member.TeamId)
			match.Players[player] = true; playerMatch[player] = match
			table.insert(match.Stats, newStats(player, member))
		end
	end
	publish(match)
	task.delay(Config.CountdownSeconds, function()
		if matches[room.RoomId] ~= match then return end
		match.State = "Active"
		for player in match.Players do
			player:LoadCharacterAsync()
			task.defer(function() bindDeath(player, match); spawnService:SetSpawnProtection(player, mode.SpawnProtectionSeconds) end)
		end
		if replayService then replayService:StartMatch(match.MatchId, match) end
		publish(match)
	end)
	return true
end

function MatchService:RegisterDamageSource(victimPlayer, attackerPlayer)
	local match = playerMatch[victimPlayer]
	if not match or playerMatch[attackerPlayer] ~= match then return false end
	damageSources[victimPlayer] = { UserId = attackerPlayer.UserId, At = os.clock() }
	spawnService:ClearSpawnProtection(attackerPlayer)
	return true
end

function MatchService:ClearDamageSource(player) damageSources[player] = nil end

function MatchService:DebugEliminate(player)
	if not RunService:IsStudio() or not Config.StudioDebugEliminationsEnabled then return false end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Health = 0; return true end
	return false
end

function MatchService:GetSnapshot(player)
	local match = playerMatch[player]
	return match and snapshot(match) or nil
end

function MatchService:GetMatch(player) return playerMatch[player] end

function MatchService:Init(remoteRegistry, rooms, spawns, replays)
	isRunning = true
	remote = remoteRegistry.MatchUpdated; roomService = rooms; spawnService = spawns; replayService = replays
	Players.PlayerRemoving:Connect(function(player)
		local match = playerMatch[player]
		if match then match.Players[player] = nil; playerMatch[player] = nil; publish(match) end
		if deathConnections[player] then deathConnections[player]:Disconnect(); deathConnections[player] = nil end
		damageSources[player] = nil
	end)
	task.spawn(function()
		while isRunning do
			task.wait(1)
			for _, match in matches do
				for player in match.Players do
					local stats = findStats(match, player.UserId)
					if stats then stats.PingMilliseconds = math.floor(player:GetNetworkPing() * 2000 + 0.5) end
				end
				if match.State == "Active" and match.EndsAtUnix > 0 and os.time() >= match.EndsAtUnix then
					local winner = nil
					if match.ModeId == "TeamDeathmatchExtreme" and match.TeamScores.ALPHA ~= match.TeamScores.OMEGA then winner = match.TeamScores.ALPHA > match.TeamScores.OMEGA and "ALPHA" or "OMEGA"
					elseif match.ModeId == "Deathmatch" then
						local ordered = table.clone(match.Stats); table.sort(ordered, function(a, b) if a.Score ~= b.Score then return a.Score > b.Score end; if a.Kills ~= b.Kills then return a.Kills > b.Kills end; if a.Deaths ~= b.Deaths then return a.Deaths < b.Deaths end; return a.UserId < b.UserId end)
						if ordered[1] and (not ordered[2] or ordered[1].Score ~= ordered[2].Score or ordered[1].Kills ~= ordered[2].Kills or ordered[1].Deaths ~= ordered[2].Deaths) then winner = ordered[1].UserId end
					end
					finishMatch(match, winner)
				end
				if match.State == "Active" and match.ModeId == "Elimination"
					and os.time() >= match.RoundEndsAtUnix then
					local mode = GameModeRegistry.Get(match.ModeId)
					local alive, health = { ALPHA = 0, OMEGA = 0 }, { ALPHA = 0, OMEGA = 0 }
					for player in match.Players do
						local stats = findStats(match, player.UserId); local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
						if stats and stats.TeamId and stats.IsAlive then alive[stats.TeamId] += 1; health[stats.TeamId] += humanoid and humanoid.Health or 0 end
					end
					local winner = if alive.ALPHA ~= alive.OMEGA then (alive.ALPHA > alive.OMEGA and "ALPHA" or "OMEGA") elseif health.ALPHA ~= health.OMEGA then (health.ALPHA > health.OMEGA and "ALPHA" or "OMEGA") else nil
					if winner then match.TeamScores[winner] += 1 end
					if winner and match.TeamScores[winner] >= math.ceil(mode.BestOfRounds / 2) then finishMatch(match, winner) else startNextEliminationRound(match, mode) end
				end
			end
		end
	end)
	game:BindToClose(function() isRunning = false end)
end

return MatchService
