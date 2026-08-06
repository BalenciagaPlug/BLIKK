local DistrictZeroBuilder = require(script.Maps.DistrictZeroBuilder)
local DistrictZeroSpawnService = require(script.Maps.DistrictZeroSpawnService)

DistrictZeroSpawnService:Init()

local didBuild, buildError = xpcall(function()
	DistrictZeroBuilder:Build()
end, debug.traceback)

if not didBuild then
	warn("[BLIKK STARTUP] District Zero construction failed:\n" .. tostring(buildError))
end
