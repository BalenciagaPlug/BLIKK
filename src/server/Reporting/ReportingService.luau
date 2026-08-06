local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Replay.ReplayConfig)
local RateLimiter = require(script.Parent.Parent.Networking.RateLimiter)

local ReportingService = {}
local store = DataStoreService:GetDataStore(Config.ReportStoreName)
local limiter = RateLimiter.New()
local matchService = nil
local replayService = nil
local submissions = {}

local function filterNote(player, note)
	if note == nil or note == "" then return "" end
	if type(note) ~= "string" or #note > Config.ReportNoteMaximumLength then return nil end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(note, player.UserId, Enum.TextFilterContext.PrivateChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(filtered) == "string" then filtered else nil
end

local function findStats(match, userId)
	for _, stats in match.Stats do if stats.UserId == userId then return stats end end
	return nil
end

function ReportingService:Init(remoteRegistry, matches, replays)
	matchService = matches
	replayService = replays
	remoteRegistry.ReportRequest.OnServerInvoke = function(player, payload)
		if type(payload) ~= "table" or type(payload.TargetUserId) ~= "number" or payload.TargetUserId == player.UserId or not table.find(Config.ReportReasons, payload.ReasonCode) then return { Success = false, Code = "INVALID_REPORT" } end
		if not RateLimiter.Allow(limiter, player, "Report", Config.ReportWindowSeconds, Config.MaximumReportsPerWindow) then return { Success = false, Code = "RATE_LIMITED" } end
		local match = matchService:GetMatch(player); local targetStats = match and findStats(match, payload.TargetUserId)
		if not match or not targetStats then return { Success = false, Code = "NOT_SHARED_MATCH" } end
		local state = submissions[player] or { MatchId = match.MatchId, Count = 0, MatchTargets = {}, TargetTimes = {} }
		if state.MatchId ~= match.MatchId then state.MatchId = match.MatchId; state.Count = 0; state.MatchTargets = {} end
		if state.Count >= Config.MaximumReportsPerMatch or state.MatchTargets[payload.TargetUserId]
			or os.time() - (state.TargetTimes[payload.TargetUserId] or 0) < Config.SameTargetCooldownSeconds then return { Success = false, Code = "DUPLICATE_OR_LIMITED" } end
		local note = filterNote(player, payload.Note)
		if note == nil then return { Success = false, Code = "FILTER_FAILED" } end
		local reportId = HttpService:GenerateGUID(false)
		local reporterStats = findStats(match, player.UserId)
		local record = { SchemaVersion = Config.ReportSchemaVersion, ReportId = reportId, CreatedAtUnix = os.time(), ReporterUserId = player.UserId, ReportedUserId = payload.TargetUserId, ReasonCode = payload.ReasonCode, FilteredNote = note, MatchId = match.MatchId, RoomId = match.RoomId, ModeId = match.ModeId, MapId = match.MapId, ServerJobId = game.JobId, PrivateServerId = game.PrivateServerId, RelevantStats = { Reporter = reporterStats and { Kills = reporterStats.Kills, Deaths = reporterStats.Deaths, Score = reporterStats.Score }, Reported = { Kills = targetStats.Kills, Deaths = targetStats.Deaths, Score = targetStats.Score } }, EventExcerpt = replayService:GetEvidence(match.MatchId), EvidenceVersion = 1 }
		local saved = pcall(function() store:UpdateAsync("Report_" .. reportId, function(previous) return previous or record end) end)
		if not saved then return { Success = false, Code = "STORE_FAILED" } end
		state.Count += 1; state.MatchTargets[payload.TargetUserId] = true; state.TargetTimes[payload.TargetUserId] = os.time(); submissions[player] = state
		return { Success = true, Code = "RECEIVED", ReportId = reportId }
	end
	Players.PlayerRemoving:Connect(function(player) submissions[player] = nil; RateLimiter.Clear(limiter, player) end)
end

return ReportingService
