local Players = game:GetService("Players")
Players.CharacterAutoLoads = false

local RemoteRegistry = require(script.Networking.RemoteRegistry)
RemoteRegistry:Init()

local CharacterLifecycleService = require(script.Character.CharacterLifecycleService)
local CharacterProfileService = require(script.Character.CharacterProfileService)
local DistrictZeroBuilder = require(script.Maps.DistrictZeroBuilder)
local DistrictZeroSpawnService = require(script.Maps.DistrictZeroSpawnService)
local ClanService = require(script.Clans.ClanService)
local MatchService = require(script.Match.MatchService)
local FirearmService = require(script.Combat.FirearmService)
local ReplayService = require(script.Replay.ReplayService)
local ReportingService = require(script.Reporting.ReportingService)
local RoomService = require(script.Rooms.RoomService)
local SpectatorService = require(script.Spectator.SpectatorService)
local CrossServerRoomService = require(script.Teleport.CrossServerRoomService)

CharacterProfileService:Init(RemoteRegistry)
DistrictZeroSpawnService:Init()
CharacterLifecycleService:Init(RemoteRegistry, DistrictZeroSpawnService)
ReplayService:Init(RemoteRegistry)
RoomService:Init(RemoteRegistry, CharacterProfileService)
MatchService:Init(
	RemoteRegistry,
	RoomService,
	DistrictZeroSpawnService,
	ReplayService,
	CharacterLifecycleService
)
FirearmService:Init(RemoteRegistry, MatchService)
RoomService:SetMatchService(MatchService)
CharacterLifecycleService:SetMovementLabEligibilityCallback(function(player)
	if RoomService:GetRoom(player) then return false, "PLAYER_IN_ROOM" end
	if MatchService:GetMatch(player) then return false, "PLAYER_IN_MATCH" end
	return true
end)
SpectatorService:Init(RemoteRegistry, MatchService)
ReportingService:Init(RemoteRegistry, MatchService, ReplayService)
ClanService:Init(RemoteRegistry)
CrossServerRoomService:Init(RemoteRegistry, RoomService)

local didBuild, buildError = xpcall(function()
	DistrictZeroBuilder:Build()
end, debug.traceback)

if not didBuild then
	warn("[BLIKK STARTUP] District Zero construction failed:\n" .. tostring(buildError))
end
