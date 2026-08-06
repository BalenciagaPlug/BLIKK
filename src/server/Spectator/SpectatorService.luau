local Players = game:GetService("Players")

local SpectatorService = {}
local matchService = nil

local function allowedTargets(player)
	local match = matchService:GetMatch(player)
	if not match then return {} end
	local ownStats = nil
	for _, stats in match.Stats do if stats.UserId == player.UserId then ownStats = stats end end
	if not ownStats or not ownStats.IsSpectating then return {} end
	local targets = {}
	for candidate in match.Players do
		if candidate ~= player then
			local stats = nil; for _, record in match.Stats do if record.UserId == candidate.UserId then stats = record end end
			if stats and stats.IsAlive and (match.ModeId == "Deathmatch" or ownStats.TeamId == stats.TeamId) then
				table.insert(targets, { UserId = candidate.UserId, DisplayName = candidate.DisplayName, TeamId = stats.TeamId, ClanTag = stats.ClanTag })
			end
		end
	end
	table.sort(targets, function(a, b) return a.UserId < b.UserId end)
	return targets
end

function SpectatorService:Init(remoteRegistry, matches)
	matchService = matches
	remoteRegistry.SpectatorRequest.OnServerInvoke = function(player, operation)
		if operation ~= "Targets" then return { Success = false, Code = "INVALID_OPERATION" } end
		return { Success = true, Targets = allowedTargets(player) }
	end
	Players.PlayerRemoving:Connect(function() end)
end

return SpectatorService
