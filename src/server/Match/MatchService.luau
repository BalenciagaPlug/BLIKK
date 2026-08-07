local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameModeRegistry = require(ReplicatedStorage.Shared.Multiplayer.GameModeRegistry)
local Config = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)
local RateLimiter = require(script.Parent.Parent.Networking.RateLimiter)

local MatchService = {}

local matchUpdatedRemote = nil
local roomService = nil
local spawnService = nil
local replayService = nil
local characterLifecycle = nil
local matches = {}
local playerMatch = {}
local damageSources = {}
local readinessLimiter = RateLimiter.New()
local isRunning = false

local beginSharedPreparation
local beginIndividualPreparation
local evaluateDeath
local finishMatch
local tryCompleteBarrier
local tryArmIndividual

local function isFiniteInteger(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
		and value % 1 == 0
end

local function identitiesMatch(left, right)
	return type(left) == "table"
		and type(right) == "table"
		and left.Context == right.Context
		and left.RoomId == right.RoomId
		and left.MatchId == right.MatchId
		and left.MatchGeneration == right.MatchGeneration
		and left.Round == right.Round
		and left.SpawnGeneration == right.SpawnGeneration
end

local function isCurrent(match)
	return matches[match.RoomId] == match and not match.Cancelled
end

local function findStats(match, userId)
	for _, stats in match.Stats do
		if stats.UserId == userId then return stats end
	end
	return nil
end

local function newStats(player, member)
	return {
		UserId = player.UserId,
		DisplayName = player.DisplayName,
		TeamId = member.TeamId,
		Kills = 0,
		Deaths = 0,
		Assists = 0,
		Streak = 0,
		Score = 0,
		RoundKills = 0,
		RoundDeaths = 0,
		IsAlive = false,
		IsSpectating = true,
		Released = false,
		PreparationPhase = "Registered",
		ServerPrepared = false,
		ClientReady = false,
		ReleaseAtServerTime = 0,
		PreparationFailureCode = nil,
		Identity = nil,
		PreparationKind = nil,
		PendingLateJoin = false,
		PingMilliseconds = 0,
		RoomLeader = member.IsRoomLeader,
		ClanId = player:GetAttribute("BLIKK_ClanId"),
		ClanTag = player:GetAttribute("BLIKK_ClanTag"),
	}
end

local function participantUserIds(match)
	local result = {}
	for player in match.Players do table.insert(result, player.UserId) end
	table.sort(result)
	return result
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
		MatchId = match.MatchId,
		RoomId = match.RoomId,
		State = match.State,
		Phase = match.Phase,
		Generation = match.Generation,
		Revision = match.Revision,
		ModeId = match.ModeId,
		MapId = match.MapId,
		EndsAtUnix = match.EndsAtUnix,
		EndsAtServerTime = match.EndsAtServerTime,
		Round = match.Round,
		RoundEndsAtUnix = match.RoundEndsAtUnix,
		RoundEndsAtServerTime = match.RoundEndsAtServerTime,
		PreparationStartedAtServerTime = match.PreparationStartedAtServerTime,
		PreparationDeadlineAtServerTime = match.PreparationDeadlineAtServerTime,
		ReleaseAtServerTime = match.ReleaseAtServerTime,
		ParticipantUserIds = participantUserIds(match),
		LateJoinBehavior = match.LateJoinBehavior,
		FailureCode = match.FailureCode,
		Winner = match.Winner,
		TeamScores = table.clone(match.TeamScores),
		Stats = stats,
		CompetitiveResolutionActive = match.CompetitiveResolutionActive,
		Diagnostics = table.clone(match.Diagnostics),
	}
end

local function publish(match)
	if not matchUpdatedRemote then return end
	match.Revision += 1
	local value = snapshot(match)
	for player in match.Players do
		if player.Parent == Players then matchUpdatedRemote:FireClient(player, value) end
	end
end

local function hasCompetitiveDistribution(match, mode)
	if not mode.Competitive then return true end
	local participants = 0
	local teams = { ALPHA = 0, OMEGA = 0 }
	for player in match.Players do
		local stats = findStats(match, player.UserId)
		if stats and stats.Released and not stats.IsSpectating then
			participants += 1
			if stats.TeamId then teams[stats.TeamId] += 1 end
		end
	end
	if participants < mode.CompetitiveMinimumPlayers then return false end
	return not mode.TeamMode or (teams.ALPHA > 0 and teams.OMEGA > 0)
end

local function hasDistributionForPlayers(match, mode, playersSet)
	if not mode.Competitive then return true end
	local participants = 0
	local teams = { ALPHA = 0, OMEGA = 0 }
	for player in playersSet do
		local stats = findStats(match, player.UserId)
		if stats then
			participants += 1
			if stats.TeamId then teams[stats.TeamId] += 1 end
		end
	end
	if participants < mode.CompetitiveMinimumPlayers then return false end
	return not mode.TeamMode or (teams.ALPHA > 0 and teams.OMEGA > 0)
end

local function refreshCompetitiveState(match, mode)
	match.CompetitiveResolutionActive = hasCompetitiveDistribution(match, mode)
end

local function setMemberStates(match, statesByPlayer)
	if next(statesByPlayer) then
		roomService:SetMatchMemberStates(match.RoomId, statesByPlayer)
	end
end

local function callLifecycle(methodName, player, ...)
	local method = characterLifecycle and characterLifecycle[methodName]
	if type(method) ~= "function" then return false, "LIFECYCLE_UNAVAILABLE" end
	local succeeded, result, code = pcall(method, characterLifecycle, player, ...)
	if not succeeded then
		warn(string.format(
			"[BLIKK MATCH] Character lifecycle %s failed for user %d: %s",
			methodName,
			player.UserId,
			tostring(result)
		))
		return false, "LIFECYCLE_EXCEPTION"
	end
	return result, code
end

local function clearPlayerMatchState(match, player, shouldNotify, reason)
	if playerMatch[player] == match then playerMatch[player] = nil end
	player:SetAttribute("BLIKK_TeamId", nil)
	damageSources[player] = nil
	RateLimiter.Clear(readinessLimiter, player)
	if replayService then replayService:RemovePlayer(player) end
	if characterLifecycle then callLifecycle("CancelPlayer", player, reason or "MATCH_EXIT") end
	if shouldNotify and player.Parent == Players and matchUpdatedRemote then
		matchUpdatedRemote:FireClient(player, {
			Cleared = true,
			RoomId = match.RoomId,
			MatchId = match.MatchId,
			Generation = match.Generation,
			Revision = match.Revision + 1,
		})
	end
end

local function cancelMatch(match, code)
	if not isCurrent(match) then return end
	match.Cancelled = true
	match.State = "Cancelled"
	match.Phase = "Cancelled"
	match.FailureCode = code or "MATCH_CANCELLED"
	match.TaskGeneration += 1
	match.CompetitiveResolutionActive = false
	publish(match)
	task.defer(function()
		if matches[match.RoomId] ~= match then return end
		if replayService and match.ReplayStarted then replayService:EndMatch(match.MatchId) end
		for player in match.Players do
			clearPlayerMatchState(match, player, true, match.FailureCode)
		end
		matches[match.RoomId] = nil
		roomService:ReturnToLobby(match.RoomId)
	end)
end

local function releaseSharedBarrier(match, generation)
	if not isCurrent(match) or match.Generation ~= generation or match.Phase ~= "Armed" then return end
	local barrier = match.Barrier
	if not barrier or barrier.Generation ~= generation then return end
	local mode = GameModeRegistry.Get(match.ModeId)
	local releasedCount = 0
	local releaseFailed = false
	local releasedParticipants = {}
	local memberStates = {}
	for player, identity in barrier.Accepted do
		local stats = findStats(match, player.UserId)
		if playerMatch[player] == match and stats and identitiesMatch(stats.Identity, identity) then
			local released, code = callLifecycle("ReleaseCharacter", player, identity, "FIGHT")
			if released then
				releasedCount += 1
				releasedParticipants[player] = identity
				stats.Released = true
				stats.IsAlive = true
				stats.IsSpectating = false
				stats.PreparationPhase = "Fighting"
				stats.PreparationFailureCode = nil
				memberStates[player] = "Alive"
				spawnService:SetSpawnProtection(player, GameModeRegistry.Get(match.ModeId).SpawnProtectionSeconds)
			else
				releaseFailed = true
				stats.Released = false
				stats.IsAlive = false
				stats.IsSpectating = true
				stats.PreparationPhase = "Failed"
				stats.PreparationFailureCode = code or "RELEASE_FAILED"
				memberStates[player] = "Spectating"
				callLifecycle("CancelPlayer", player, stats.PreparationFailureCode)
			end
		end
	end
	if mode.Competitive and releaseFailed then
		for player, identity in releasedParticipants do
			callLifecycle("HoldCharacter", player, identity, "SHARED_RELEASE_ABORTED")
		end
		cancelMatch(match, "SHARED_RELEASE_FAILED")
		return
	end
	if releasedCount == 0 then
		cancelMatch(match, "NO_RELEASED_PARTICIPANTS")
		return
	end

	local now = Workspace:GetServerTimeNow()
	match.Phase = "Fighting"
	match.State = "Active"
	match.EndsAtServerTime = if mode.TimeLimitSeconds > 0 then now + mode.TimeLimitSeconds else 0
	match.EndsAtUnix = if mode.TimeLimitSeconds > 0 then os.time() + mode.TimeLimitSeconds else 0
	match.RoundEndsAtServerTime = if mode.RoundBased then now + mode.RoundTimeSeconds else 0
	match.RoundEndsAtUnix = if mode.RoundBased then os.time() + mode.RoundTimeSeconds else 0
	setMemberStates(match, memberStates)
	roomService:SetMatchPhase(match.RoomId, "InProgress")
	refreshCompetitiveState(match, mode)
	if replayService then
		if not match.ReplayStarted then
			match.ReplayStarted = true
			replayService:StartMatch(match.MatchId, match)
		else
			replayService:RecordEvent(match.MatchId, "RoundStart", { Round = match.Round })
		end
	end
	publish(match)

	for player in match.Players do
		local stats = findStats(match, player.UserId)
		if stats and stats.PendingLateJoin and mode.Id ~= "Elimination" then
			stats.PendingLateJoin = false
			task.defer(beginIndividualPreparation, match, player, "JoinInProgress")
		end
	end
end

local function armSharedBarrier(match)
	if not isCurrent(match) or (match.Phase ~= "Preparing" and match.Phase ~= "WaitingForClients") then return end
	local barrier = match.Barrier
	if not barrier or barrier.Generation ~= match.Generation or barrier.Armed then return end
	barrier.Armed = true
	barrier.Accepted = {}
	local memberStates = {}
	for player in barrier.Registered do
		local stats = findStats(match, player.UserId)
		if playerMatch[player] == match and stats and stats.ServerPrepared and stats.ClientReady
			and stats.PreparationPhase ~= "Failed" and stats.PreparationPhase ~= "TimedOut" then
			barrier.Accepted[player] = stats.Identity
			stats.PreparationPhase = "Armed"
		else
			if stats then
				stats.Released = false
				stats.IsAlive = false
				stats.IsSpectating = true
				if stats.PreparationPhase ~= "Failed" then stats.PreparationPhase = "TimedOut" end
				stats.PreparationFailureCode = stats.PreparationFailureCode or "READINESS_TIMEOUT"
			end
			memberStates[player] = "Spectating"
			callLifecycle(
				"CancelPlayer",
				player,
				stats and stats.PreparationFailureCode or "READINESS_TIMEOUT"
			)
		end
	end
	if not next(barrier.Accepted) then
		cancelMatch(match, "PREPARATION_FAILED")
		return
	end
	local mode = GameModeRegistry.Get(match.ModeId)
	if mode.Competitive and hasDistributionForPlayers(match, mode, match.Players)
		and not hasDistributionForPlayers(match, mode, barrier.Accepted) then
		cancelMatch(match, "INSUFFICIENT_READY_DISTRIBUTION")
		return
	end
	setMemberStates(match, memberStates)
	match.Phase = "Armed"
	match.State = "Countdown"
	match.ReleaseAtServerTime = Workspace:GetServerTimeNow() + Config.CountdownSeconds
	for player in barrier.Accepted do
		local stats = findStats(match, player.UserId)
		if stats then stats.ReleaseAtServerTime = match.ReleaseAtServerTime end
	end
	roomService:SetMatchPhase(match.RoomId, "Countdown")
	publish(match)
	local generation = match.Generation
	task.delay(math.max(0, match.ReleaseAtServerTime - Workspace:GetServerTimeNow()), function()
		releaseSharedBarrier(match, generation)
	end)
end

tryCompleteBarrier = function(match)
	if not isCurrent(match) or (match.Phase ~= "Preparing" and match.Phase ~= "WaitingForClients") then return end
	local barrier = match.Barrier
	if not barrier or not barrier.RequestsIssued or barrier.Generation ~= match.Generation then return end
	local hasPending = false
	for player in barrier.Registered do
		if playerMatch[player] == match then
			local stats = findStats(match, player.UserId)
			if stats and stats.PreparationPhase ~= "Failed" and stats.PreparationPhase ~= "TimedOut"
				and not (stats.ServerPrepared and stats.ClientReady) then
				hasPending = true
				break
			end
		end
	end
	if not hasPending then armSharedBarrier(match) end
end

beginSharedPreparation = function(match, context)
	if not isCurrent(match) then return false end
	match.Generation += 1
	match.TaskGeneration += 1
	local generation = match.Generation
	match.Phase = "Preparing"
	match.State = "Countdown"
	match.FailureCode = nil
	match.ReleaseAtServerTime = 0
	match.PreparationStartedAtServerTime = Workspace:GetServerTimeNow()
	match.PreparationDeadlineAtServerTime = match.PreparationStartedAtServerTime
		+ Config.MatchPreparationTimeoutSeconds
	match.CompetitiveResolutionActive = false
	match.Barrier = {
		Generation = generation,
		Context = context,
		Registered = {},
		Accepted = {},
		RequestsIssued = false,
		Armed = false,
	}
	local participants = {}
	for player in match.Players do
		if player.Parent == Players then table.insert(participants, player) end
	end
	table.sort(participants, function(a, b) return a.UserId < b.UserId end)
	for _, player in participants do
		match.Barrier.Registered[player] = true
		local stats = findStats(match, player.UserId)
		if stats then
			stats.IsAlive = false
			stats.IsSpectating = true
			stats.Released = false
			stats.PreparationPhase = "Registered"
			stats.PreparationKind = "Shared"
			stats.ServerPrepared = false
			stats.ClientReady = false
			stats.ReleaseAtServerTime = 0
			stats.PreparationFailureCode = nil
			stats.Identity = nil
			stats.PendingLateJoin = false
		end
	end
	roomService:SetMatchPhase(match.RoomId, "LoadingMatch")
	publish(match)

	for _, player in participants do
		if not isCurrent(match) or match.Generation ~= generation then return false end
		local stats = findStats(match, player.UserId)
		local identity, code = callLifecycle("RequestCharacter", player, {
			Context = context,
			RoomId = match.RoomId,
			MatchId = match.MatchId,
			ModeId = match.ModeId,
			MatchGeneration = generation,
			Round = match.Round,
		})
		if stats then
			if identity then
				stats.Identity = identity
				stats.PreparationPhase = "Preparing"
			else
				stats.PreparationPhase = "Failed"
				stats.PreparationFailureCode = code or "CHARACTER_REQUEST_FAILED"
			end
		end
	end
	if not isCurrent(match) or match.Generation ~= generation then return false end
	match.Barrier.RequestsIssued = true
	match.Phase = "WaitingForClients"
	publish(match)
	task.delay(Config.MatchPreparationTimeoutSeconds, function()
		if not isCurrent(match) or match.Generation ~= generation
			or (match.Phase ~= "Preparing" and match.Phase ~= "WaitingForClients") then return end
		match.Diagnostics.ReadinessTimeouts += 1
		armSharedBarrier(match)
	end)
	tryCompleteBarrier(match)
	return true
end

local function releaseIndividual(match, player, identity)
	if not isCurrent(match) or match.Phase ~= "Fighting" or playerMatch[player] ~= match then return end
	local stats = findStats(match, player.UserId)
	if not stats or not identitiesMatch(stats.Identity, identity)
		or stats.PreparationPhase ~= "Armed" then return end
	local released, code = callLifecycle("ReleaseCharacter", player, identity, "INDIVIDUAL_FIGHT")
	if released then
		stats.Released = true
		stats.IsAlive = true
		stats.IsSpectating = false
		stats.PreparationPhase = "Fighting"
		stats.PreparationFailureCode = nil
		roomService:SetMemberMatchState(player, "Alive")
		spawnService:SetSpawnProtection(player, GameModeRegistry.Get(match.ModeId).SpawnProtectionSeconds)
	else
		stats.Released = false
		stats.IsAlive = false
		stats.IsSpectating = true
		stats.PreparationPhase = "Failed"
		stats.PreparationFailureCode = code or "RELEASE_FAILED"
		roomService:SetMemberMatchState(player, "Spectating")
		callLifecycle("CancelPlayer", player, stats.PreparationFailureCode)
	end
	refreshCompetitiveState(match, GameModeRegistry.Get(match.ModeId))
	publish(match)
end

tryArmIndividual = function(match, player)
	if not isCurrent(match) or match.Phase ~= "Fighting" or playerMatch[player] ~= match then return end
	local stats = findStats(match, player.UserId)
	if not stats or stats.PreparationKind ~= "Individual"
		or (stats.PreparationPhase ~= "Preparing" and stats.PreparationPhase ~= "WaitingForClient")
		or not stats.ServerPrepared or not stats.ClientReady or not stats.Identity then return end
	stats.PreparationPhase = "Armed"
	stats.ReleaseAtServerTime = Workspace:GetServerTimeNow() + Config.IndividualFightLeadSeconds
	publish(match)
	local identity = stats.Identity
	task.delay(math.max(0, stats.ReleaseAtServerTime - Workspace:GetServerTimeNow()), function()
		releaseIndividual(match, player, identity)
	end)
end

beginIndividualPreparation = function(match, player, context)
	if not isCurrent(match) or match.Phase ~= "Fighting" or playerMatch[player] ~= match then return false end
	local stats = findStats(match, player.UserId)
	if not stats then return false end
	stats.IsAlive = false
	stats.IsSpectating = true
	stats.Released = false
	stats.PreparationPhase = "Preparing"
	stats.PreparationKind = "Individual"
	stats.ServerPrepared = false
	stats.ClientReady = false
	stats.ReleaseAtServerTime = 0
	stats.PreparationFailureCode = nil
	local identity, code = callLifecycle("RequestCharacter", player, {
		Context = context,
		RoomId = match.RoomId,
		MatchId = match.MatchId,
		ModeId = match.ModeId,
		MatchGeneration = match.Generation,
		Round = match.Round,
	})
	if not identity then
		stats.PreparationPhase = "Failed"
		stats.PreparationFailureCode = code or "CHARACTER_REQUEST_FAILED"
		roomService:SetMemberMatchState(player, "Spectating")
		publish(match)
		return false
	end
	stats.Identity = identity
	roomService:SetMemberMatchState(player, "Loading")
	publish(match)
	task.delay(Config.IndividualPreparationTimeoutSeconds, function()
		if not isCurrent(match) or playerMatch[player] ~= match then return end
		local current = findStats(match, player.UserId)
		if not current or not identitiesMatch(current.Identity, identity)
			or (current.PreparationPhase ~= "Preparing"
				and current.PreparationPhase ~= "WaitingForClient"
				and current.PreparationPhase ~= "Armed") then return end
		current.PreparationPhase = "TimedOut"
		current.PreparationFailureCode = "READINESS_TIMEOUT"
		current.IsAlive = false
		current.IsSpectating = true
		current.Released = false
		current.ServerPrepared = false
		current.ClientReady = false
		current.ReleaseAtServerTime = 0
		current.Identity = nil
		match.Diagnostics.ReadinessTimeouts += 1
		callLifecycle("CancelPlayer", player, "READINESS_TIMEOUT")
		roomService:SetMemberMatchState(player, "Spectating")
		publish(match)
	end)
	return true
end

local function startNextEliminationRound(match, mode)
	if not isCurrent(match) or match.Phase ~= "Fighting" then return end
	match.Phase = "PostRound"
	match.State = "Intermission"
	match.CompetitiveResolutionActive = false
	match.ReleaseAtServerTime = 0
	match.TaskGeneration += 1
	local taskGeneration = match.TaskGeneration
	for player in match.Players do
		local stats = findStats(match, player.UserId)
		if stats then
			stats.Released = false
			stats.PreparationPhase = "PostRound"
			if stats.Identity then callLifecycle("HoldCharacter", player, stats.Identity, "POST_ROUND") end
		end
	end
	roomService:SetMatchPhase(match.RoomId, "RoundIntermission")
	publish(match)
	task.delay(mode.RoundIntermissionSeconds, function()
		if not isCurrent(match) or match.TaskGeneration ~= taskGeneration or match.Phase ~= "PostRound" then return end
		match.Round += 1
		for _, stats in match.Stats do
			stats.IsAlive = false
			stats.IsSpectating = true
			stats.RoundKills = 0
			stats.RoundDeaths = 0
		end
		beginSharedPreparation(match, "RoundTransition")
	end)
end

evaluateDeath = function(match, mode)
	if not match.CompetitiveResolutionActive then return end
	if mode.Id == "Deathmatch" then
		for _, stats in match.Stats do
			if stats.Score >= mode.ScoreLimit then finishMatch(match, stats.UserId); return end
		end
	elseif mode.Id == "TeamDeathmatchExtreme" then
		for teamId, score in match.TeamScores do
			if score >= mode.ScoreLimit then finishMatch(match, teamId); return end
		end
	elseif mode.Id == "Elimination" then
		local alive = { ALPHA = 0, OMEGA = 0 }
		for _, stats in match.Stats do
			if stats.IsAlive and stats.Released and stats.TeamId then alive[stats.TeamId] += 1 end
		end
		if alive.ALPHA > 0 and alive.OMEGA > 0 then return end
		local winner = if alive.ALPHA > alive.OMEGA then "ALPHA"
			elseif alive.OMEGA > alive.ALPHA then "OMEGA" else nil
		if winner then match.TeamScores[winner] += 1 end
		if winner and match.TeamScores[winner] >= math.ceil(mode.BestOfRounds / 2) then
			finishMatch(match, winner)
		else
			startNextEliminationRound(match, mode)
		end
	end
end

finishMatch = function(match, winner)
	if not isCurrent(match) or match.Phase == "PostMatch" then return end
	match.Phase = "PostMatch"
	match.State = "PostMatch"
	match.Winner = winner
	match.CompetitiveResolutionActive = false
	match.TaskGeneration += 1
	local taskGeneration = match.TaskGeneration
	for player in match.Players do
		local stats = findStats(match, player.UserId)
		if stats then
			stats.Released = false
			stats.PreparationPhase = "PostMatch"
			if stats.Identity then callLifecycle("HoldCharacter", player, stats.Identity, "POST_MATCH") end
		end
	end
	roomService:SetMatchPhase(match.RoomId, "PostMatch")
	if replayService then replayService:RecordEvent(match.MatchId, "MatchEnd", { Winner = winner }) end
	publish(match)
	task.delay(Config.PostMatchSeconds, function()
		if not isCurrent(match) or match.TaskGeneration ~= taskGeneration or match.Phase ~= "PostMatch" then return end
		if replayService then replayService:EndMatch(match.MatchId) end
		for player in match.Players do clearPlayerMatchState(match, player, true, "POST_MATCH_COMPLETE") end
		matches[match.RoomId] = nil
		roomService:ReturnToLobby(match.RoomId)
	end)
end

local function onCharacterPrepared(player, identity)
	local match = playerMatch[player]
	if not match or not isCurrent(match) then return end
	local stats = findStats(match, player.UserId)
	if not stats or not identitiesMatch(stats.Identity, identity) then return end
	local canAcceptPreparation = if stats.PreparationKind == "Shared"
		then (match.Phase == "Preparing" or match.Phase == "WaitingForClients")
			and (stats.PreparationPhase == "Preparing" or stats.PreparationPhase == "WaitingForClient")
		else stats.PreparationKind == "Individual" and match.Phase == "Fighting"
			and (stats.PreparationPhase == "Preparing" or stats.PreparationPhase == "WaitingForClient")
	if not canAcceptPreparation then return end
	stats.ServerPrepared = true
	stats.PreparationPhase = "WaitingForClient"
	match.Diagnostics.CharactersPrepared += 1
	publish(match)
	if stats.PreparationKind == "Shared" then tryCompleteBarrier(match) else tryArmIndividual(match, player) end
end

local function onCharacterFailed(player, identity, code)
	local match = playerMatch[player]
	if not match or not isCurrent(match) then return end
	local stats = findStats(match, player.UserId)
	if not stats or not identitiesMatch(stats.Identity, identity) then return end
	stats.ServerPrepared = false
	stats.Released = false
	stats.IsAlive = false
	stats.IsSpectating = true
	stats.PreparationPhase = "Failed"
	stats.PreparationFailureCode = code or "CHARACTER_PREPARATION_FAILED"
	match.Diagnostics.CharacterFailures += 1
	roomService:SetMemberMatchState(player, "Spectating")
	publish(match)
	if stats.PreparationKind == "Shared" then tryCompleteBarrier(match) end
end

local function onCharacterDied(player, identity)
	local match = playerMatch[player]
	if not match or not isCurrent(match) then return end
	local victim = findStats(match, player.UserId)
	if not victim or not identitiesMatch(victim.Identity, identity) then return end
	local preparationDied = (victim.PreparationKind == "Shared"
		and (match.Phase == "Preparing" or match.Phase == "WaitingForClients" or match.Phase == "Armed")
		and (victim.PreparationPhase == "Preparing" or victim.PreparationPhase == "WaitingForClient"
			or victim.PreparationPhase == "Armed"))
		or (victim.PreparationKind == "Individual" and match.Phase == "Fighting"
			and (victim.PreparationPhase == "Preparing" or victim.PreparationPhase == "WaitingForClient"
				or victim.PreparationPhase == "Armed"))
	if preparationDied then
		victim.ServerPrepared = false
		victim.ClientReady = false
		victim.Released = false
		victim.IsAlive = false
		victim.IsSpectating = true
		victim.ReleaseAtServerTime = 0
		victim.PreparationPhase = "Failed"
		victim.PreparationFailureCode = "CHARACTER_DIED_BEFORE_RELEASE"
		match.Diagnostics.CharacterFailures += 1
		if match.Barrier and match.Barrier.Accepted then match.Barrier.Accepted[player] = nil end
		callLifecycle("CancelPlayer", player, victim.PreparationFailureCode)
		roomService:SetMemberMatchState(player, "Spectating")
		if victim.PreparationKind == "Shared" and match.Phase == "Armed" then
			cancelMatch(match, "PARTICIPANT_DIED_BEFORE_RELEASE")
		else
			publish(match)
			if victim.PreparationKind == "Shared" then tryCompleteBarrier(match) end
		end
		return
	end
	if match.Phase ~= "Fighting" or not victim.IsAlive then return end
	victim.IsAlive = false
	victim.IsSpectating = true
	victim.Released = false
	victim.Deaths += 1
	victim.RoundDeaths += 1
	victim.Streak = 0
	victim.PreparationPhase = "Dead"
	roomService:SetMemberMatchState(player, "Dead")
	local source = damageSources[player]
	damageSources[player] = nil
	local killer = source and os.clock() - source.At <= Config.DamageAttributionWindowSeconds
		and findStats(match, source.UserId) or nil
	if killer and killer.UserId ~= victim.UserId and killer.IsAlive and killer.Released then
		killer.Kills += 1
		killer.RoundKills += 1
		killer.Streak += 1
		killer.Score += 1
		if killer.TeamId and match.ModeId == "TeamDeathmatchExtreme" then
			match.TeamScores[killer.TeamId] = (match.TeamScores[killer.TeamId] or 0) + 1
		end
	end
	if replayService then replayService:RecordDeath(match.MatchId, victim.UserId, killer and killer.UserId) end
	publish(match)
	local mode = GameModeRegistry.Get(match.ModeId)
	evaluateDeath(match, mode)
	if mode.RespawnEnabled and isCurrent(match) and match.Phase == "Fighting" then
		local generation = match.Generation
		task.delay(mode.RespawnDelaySeconds, function()
			if not isCurrent(match) or match.Generation ~= generation or match.Phase ~= "Fighting"
				or playerMatch[player] ~= match or findStats(match, player.UserId) ~= victim
				or victim.IsAlive then return end
			beginIndividualPreparation(match, player, "Respawn")
		end)
	elseif mode.Id == "Elimination" and not match.CompetitiveResolutionActive
		and isCurrent(match) and match.Phase == "Fighting" then
		local generation = match.Generation
		task.delay(Config.SoloEliminationRespawnDelaySeconds, function()
			if not isCurrent(match) or match.Generation ~= generation or match.Phase ~= "Fighting"
				or match.CompetitiveResolutionActive or playerMatch[player] ~= match
				or findStats(match, player.UserId) ~= victim or victim.IsAlive then return end
			beginIndividualPreparation(match, player, "Respawn")
		end)
	end
end

function MatchService:StartRoom(room)
	local mode = GameModeRegistry.Get(room.Config.ModeId)
	if not mode or matches[room.RoomId] then return false end
	local match = {
		MatchId = HttpService:GenerateGUID(false),
		RoomId = room.RoomId,
		ModeId = mode.Id,
		MapId = room.Config.MapId,
		State = "Countdown",
		Phase = "Preparing",
		Generation = 0,
		TaskGeneration = 0,
		Revision = 0,
		EndsAtUnix = 0,
		EndsAtServerTime = 0,
		Round = 1,
		RoundEndsAtUnix = 0,
		RoundEndsAtServerTime = 0,
		PreparationStartedAtServerTime = 0,
		PreparationDeadlineAtServerTime = 0,
		ReleaseAtServerTime = 0,
		LateJoinBehavior = mode.LateJoinBehavior,
		FailureCode = nil,
		Winner = nil,
		TeamScores = { ALPHA = 0, OMEGA = 0 },
		Stats = {},
		Players = {},
		Barrier = nil,
		ReplayStarted = false,
		CompetitiveResolutionActive = false,
		Cancelled = false,
		Diagnostics = {
			ReadyAccepted = 0,
			ReadyDuplicate = 0,
			ReadyStaleRejected = 0,
			ReadyRateLimited = 0,
			PreFightRejected = 0,
			CharactersPrepared = 0,
			CharacterFailures = 0,
			ReadinessTimeouts = 0,
		},
	}
	matches[room.RoomId] = match
	local participants = {}
	for player, member in room.Members do
		if not member.IsSpectator then table.insert(participants, { Player = player, Member = member }) end
	end
	table.sort(participants, function(a, b) return a.Player.UserId < b.Player.UserId end)
	for _, participant in participants do
		local player = participant.Player
		player:SetAttribute("BLIKK_TeamId", participant.Member.TeamId)
		match.Players[player] = true
		playerMatch[player] = match
		table.insert(match.Stats, newStats(player, participant.Member))
	end
	if not next(match.Players) then
		matches[room.RoomId] = nil
		return false
	end
	return beginSharedPreparation(match, "MatchEntry")
end

function MatchService:AddLatePlayer(room, player, member)
	local match = matches[room.RoomId]
	local mode = GameModeRegistry.Get(room.Config.ModeId)
	if not match or not mode or not isCurrent(match) or match.Phase == "PostMatch"
		or match.Players[player] then return false end
	player:SetAttribute("BLIKK_TeamId", member.TeamId)
	match.Players[player] = true
	playerMatch[player] = match
	local stats = newStats(player, member)
	table.insert(match.Stats, stats)
	stats.IsAlive = false
	stats.IsSpectating = true
	member.State = "Spectating"
	if mode.Id == "Elimination" then
		stats.PreparationPhase = "WaitingForRound"
	elseif match.Phase == "Fighting" then
		beginIndividualPreparation(match, player, "JoinInProgress")
	else
		stats.PendingLateJoin = true
		stats.PreparationPhase = "WaitingForSafeEntry"
	end
	if replayService and match.ReplayStarted then replayService:AddPlayer(match.MatchId, player) end
	refreshCompetitiveState(match, mode)
	publish(match)
	if mode.Id == "Elimination" and match.Phase == "Fighting"
		and not match.CompetitiveResolutionActive
		and hasDistributionForPlayers(match, mode, match.Players) then
		startNextEliminationRound(match, mode)
	end
	return true
end

function MatchService:RegisterDamageSource(victimPlayer, attackerPlayer)
	local match = playerMatch[victimPlayer]
	if not match or playerMatch[attackerPlayer] ~= match or not isCurrent(match) then return false end
	local victim = findStats(match, victimPlayer.UserId)
	local attacker = findStats(match, attackerPlayer.UserId)
	if match.Phase ~= "Fighting" or not victim or not attacker
		or not victim.Released or not attacker.Released
		or not victim.IsAlive or not attacker.IsAlive
		or victimPlayer:GetAttribute("BLIKK_GameplayReleased") ~= true
		or attackerPlayer:GetAttribute("BLIKK_GameplayReleased") ~= true then
		match.Diagnostics.PreFightRejected += 1
		return false
	end
	damageSources[victimPlayer] = { UserId = attackerPlayer.UserId, At = os.clock() }
	spawnService:ClearSpawnProtection(attackerPlayer)
	return true
end

function MatchService:ClearDamageSource(player)
	damageSources[player] = nil
end

function MatchService:DebugEliminate(player)
	local match = playerMatch[player]
	if not RunService:IsStudio() or not Config.StudioDebugEliminationsEnabled
		or not match or match.Phase ~= "Fighting" then return false end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Health = 0; return true end
	return false
end

function MatchService:GetSnapshot(player)
	local match = playerMatch[player]
	return match and snapshot(match) or nil
end

function MatchService:GetMatch(player)
	return playerMatch[player]
end

function MatchService:RemovePlayer(player)
	local match = playerMatch[player]
	if not match then return end
	local mode = GameModeRegistry.Get(match.ModeId)
	local wasCompetitive = match.CompetitiveResolutionActive
	match.Players[player] = nil
	local stats = findStats(match, player.UserId)
	if match.Barrier then
		match.Barrier.Registered[player] = nil
		match.Barrier.Accepted[player] = nil
	end
	for index, candidate in match.Stats do
		if candidate == stats then table.remove(match.Stats, index); break end
	end
	clearPlayerMatchState(match, player, true, "PLAYER_LEFT_MATCH")
	if isCurrent(match) then
		if not next(match.Players) then
			cancelMatch(match, "NO_ACTIVE_PARTICIPANTS")
			return
		end
		if wasCompetitive and mode.Id == "Elimination" and match.Phase == "Fighting" then
			evaluateDeath(match, mode)
			if not isCurrent(match) or match.Phase ~= "Fighting" then return end
		end
		refreshCompetitiveState(match, mode)
		publish(match)
		tryCompleteBarrier(match)
	end
end

function MatchService:StopRoom(roomId)
	local match = matches[roomId]
	if not match then return false end
	match.Cancelled = true
	match.TaskGeneration += 1
	for player in match.Players do clearPlayerMatchState(match, player, true, "ROOM_CLOSED") end
	if replayService and match.ReplayStarted then replayService:EndMatch(match.MatchId) end
	matches[roomId] = nil
	return true
end

function MatchService:Init(remoteRegistry, rooms, spawns, replays, lifecycle)
	if isRunning then return end
	isRunning = true
	matchUpdatedRemote = remoteRegistry.MatchUpdated
	roomService = rooms
	spawnService = spawns
	replayService = replays
	characterLifecycle = lifecycle
	assert(characterLifecycle, "MatchService requires CharacterLifecycleService")

	characterLifecycle.CharacterPrepared.Event:Connect(onCharacterPrepared)
	characterLifecycle.CharacterFailed.Event:Connect(onCharacterFailed)
	characterLifecycle.CharacterDied.Event:Connect(onCharacterDied)
	remoteRegistry.MatchReady.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or payload.Context == "MovementLab"
			or type(payload.Identity) ~= "table" then return end
		local match = playerMatch[player]
		local stats = match and findStats(match, player.UserId)
		if not match or not stats or not isCurrent(match) then return end
		if not RateLimiter.Allow(
			readinessLimiter,
			player,
			"MatchReady",
			Config.MatchReadyWindowSeconds,
			Config.MatchReadyMaximumBurst
		) then
			match.Diagnostics.ReadyRateLimited += 1
			return
		end
		if not identitiesMatch(stats.Identity, payload.Identity) then
			if match then match.Diagnostics.ReadyStaleRejected += 1 end
			return
		end
		local identity = payload.Identity
		if not isFiniteInteger(identity.MatchGeneration) or not isFiniteInteger(identity.Round)
			or not isFiniteInteger(identity.SpawnGeneration) then
			match.Diagnostics.ReadyStaleRejected += 1
			return
		end
		local canAcceptReadiness = if stats.PreparationKind == "Shared"
			then (match.Phase == "Preparing" or match.Phase == "WaitingForClients")
				and (stats.PreparationPhase == "Preparing" or stats.PreparationPhase == "WaitingForClient")
			else stats.PreparationKind == "Individual" and match.Phase == "Fighting"
				and (stats.PreparationPhase == "Preparing" or stats.PreparationPhase == "WaitingForClient")
		if not canAcceptReadiness then
			match.Diagnostics.ReadyStaleRejected += 1
			return
		end
		if stats.ClientReady then
			match.Diagnostics.ReadyDuplicate += 1
			return
		end
		stats.ClientReady = true
		match.Diagnostics.ReadyAccepted += 1
		publish(match)
		if stats.PreparationKind == "Shared" then tryCompleteBarrier(match) else tryArmIndividual(match, player) end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:RemovePlayer(player)
		RateLimiter.Clear(readinessLimiter, player)
	end)
	task.spawn(function()
		while isRunning do
			task.wait(1)
			local now = Workspace:GetServerTimeNow()
			for _, match in matches do
				if not isCurrent(match) then continue end
				for player in match.Players do
					local stats = findStats(match, player.UserId)
					if stats then stats.PingMilliseconds = math.floor(player:GetNetworkPing() * 2000 + 0.5) end
				end
				if match.Phase == "Fighting" and match.CompetitiveResolutionActive
					and match.EndsAtServerTime > 0 and now >= match.EndsAtServerTime then
					local winner = nil
					if match.ModeId == "TeamDeathmatchExtreme"
						and match.TeamScores.ALPHA ~= match.TeamScores.OMEGA then
						winner = if match.TeamScores.ALPHA > match.TeamScores.OMEGA then "ALPHA" else "OMEGA"
					elseif match.ModeId == "Deathmatch" then
						local ordered = table.clone(match.Stats)
						table.sort(ordered, function(a, b)
							if a.Score ~= b.Score then return a.Score > b.Score end
							if a.Kills ~= b.Kills then return a.Kills > b.Kills end
							if a.Deaths ~= b.Deaths then return a.Deaths < b.Deaths end
							return a.UserId < b.UserId
						end)
						if ordered[1] and (not ordered[2] or ordered[1].Score ~= ordered[2].Score
							or ordered[1].Kills ~= ordered[2].Kills
							or ordered[1].Deaths ~= ordered[2].Deaths) then
							winner = ordered[1].UserId
						end
					end
					finishMatch(match, winner)
				elseif match.Phase == "Fighting" and match.CompetitiveResolutionActive
					and match.ModeId == "Elimination" and match.RoundEndsAtServerTime > 0
					and now >= match.RoundEndsAtServerTime then
					local mode = GameModeRegistry.Get(match.ModeId)
					local alive = { ALPHA = 0, OMEGA = 0 }
					local health = { ALPHA = 0, OMEGA = 0 }
					for player in match.Players do
						local stats = findStats(match, player.UserId)
						local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
						if stats and stats.TeamId and stats.IsAlive and stats.Released then
							alive[stats.TeamId] += 1
							health[stats.TeamId] += humanoid and humanoid.Health or 0
						end
					end
					local winner = if alive.ALPHA ~= alive.OMEGA
						then (if alive.ALPHA > alive.OMEGA then "ALPHA" else "OMEGA")
						elseif health.ALPHA ~= health.OMEGA
						then (if health.ALPHA > health.OMEGA then "ALPHA" else "OMEGA")
						else nil
					if winner then match.TeamScores[winner] += 1 end
					if winner and match.TeamScores[winner] >= math.ceil(mode.BestOfRounds / 2) then
						finishMatch(match, winner)
					else
						startNextEliminationRound(match, mode)
					end
				end
			end
		end
	end)
	game:BindToClose(function() isRunning = false end)
end

return MatchService
