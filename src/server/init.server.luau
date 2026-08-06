local CharacterProfileService = require(script.Character.CharacterProfileService)
local DistrictZeroBuilder = require(script.Maps.DistrictZeroBuilder)
local DistrictZeroSpawnService = require(script.Maps.DistrictZeroSpawnService)
local RemoteRegistry = require(script.Networking.RemoteRegistry)

RemoteRegistry:Init()
CharacterProfileService:Init(RemoteRegistry)
DistrictZeroSpawnService:Init(RemoteRegistry)

local didBuild, buildError = xpcall(function()
	DistrictZeroBuilder:Build()
end, debug.traceback)

if not didBuild then
	warn("[BLIKK STARTUP] District Zero construction failed:\n" .. tostring(buildError))
end
