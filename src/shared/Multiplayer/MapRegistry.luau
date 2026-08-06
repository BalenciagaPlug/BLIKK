local maps = {
	DistrictZero = {
		Id = "DistrictZero",
		DisplayName = "DISTRICT ZERO",
		IsMultiplayerEnabled = true,
		SupportedModes = { "Training", "Deathmatch", "TeamDeathmatchExtreme", "Elimination" },
		MinimumPlayers = 1,
		MaximumPlayers = 16,
		FreeForAllSpawnIds = { "SPAWN_A", "SPAWN_B", "SPAWN_C" },
		TeamSpawnIds = {
			ALPHA = { "SPAWN_A", "SPAWN_B" },
			OMEGA = { "SPAWN_C" },
		},
	},
}

local MapRegistry = { All = maps }

function MapRegistry.Get(mapId)
	return if type(mapId) == "string" then maps[mapId] else nil
end

function MapRegistry.SupportsMode(mapId, modeId)
	local map = MapRegistry.Get(mapId)
	return map ~= nil and table.find(map.SupportedModes, modeId) ~= nil
end

return MapRegistry
