local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local MusicConfig = require(ReplicatedStorage.Shared.Audio.MusicConfig)

local MusicController = {}

local isInitialised = false
local currentContext = nil
local currentSound = nil
local fadingSound = nil
local endedConnection = nil
local transitionGeneration = 0
local playlistIndices = {}
local lastTrackByContext = {}

local function diagnose(message)
	if MusicConfig.DiagnosticsEnabled then print("BLIKK MUSIC // " .. message) end
end

local function disconnectEnded()
	if endedConnection then endedConnection:Disconnect(); endedConnection = nil end
end

local function destroySound(sound)
	if sound then sound:Stop(); sound:Destroy() end
end

local function validTracks(contextName)
	local context = MusicConfig.Contexts[contextName]
	local tracks = {}
	if not context then return tracks end
	for _, trackId in context.Playlist do
		local definition = MusicConfig.Tracks[trackId]
		if definition and definition.SoundId ~= "" then table.insert(tracks, trackId) end
	end
	return tracks
end

local function chooseTrack(contextName)
	local context = MusicConfig.Contexts[contextName]
	local tracks = validTracks(contextName)
	if not context or #tracks == 0 then return nil end

	local selectedIndex
	if context.PlaybackOrder == "Shuffle" and #tracks > 1 then
		repeat selectedIndex = math.random(1, #tracks)
		until tracks[selectedIndex] ~= lastTrackByContext[contextName]
	else
		selectedIndex = (playlistIndices[contextName] or 0) % #tracks + 1
		playlistIndices[contextName] = selectedIndex
	end
	local trackId = tracks[selectedIndex]
	lastTrackByContext[contextName] = trackId
	return trackId
end

local playContext

local function startTrack(contextName, generation)
	if generation ~= transitionGeneration or currentContext ~= contextName then return end
	local trackId = chooseTrack(contextName)
	if not trackId then
		diagnose("no configured track for " .. contextName)
		return
	end
	local musicGroup = SoundService:FindFirstChild("BLIKK_Music")
	if not musicGroup or not musicGroup:IsA("SoundGroup") then return end

	local sound = Instance.new("Sound")
	sound.Name = "BLIKKMusic_" .. trackId
	sound.SoundGroup = musicGroup
	sound.SoundId = MusicConfig.Tracks[trackId].SoundId
	sound.Volume = 0
	sound.Parent = SoundService
	currentSound = sound
	endedConnection = sound.Ended:Connect(function()
		if sound ~= currentSound or contextName ~= currentContext then return end
		disconnectEnded()
		currentSound = nil
		destroySound(sound)
		playContext(contextName, transitionGeneration)
	end)
	sound:Play()
	TweenService:Create(
		sound,
		TweenInfo.new(MusicConfig.CrossfadeDurationSeconds * 0.5, Enum.EasingStyle.Linear),
		{ Volume = 1 }
	):Play()
	diagnose("playing " .. trackId)
end

playContext = function(contextName, generation)
	startTrack(contextName, generation)
end

function MusicController:SetContext(contextName)
	if currentContext == contextName then return end
	if not MusicConfig.Contexts[contextName] then return end
	currentContext = contextName
	transitionGeneration += 1
	local generation = transitionGeneration
	disconnectEnded()
	if fadingSound then destroySound(fadingSound); fadingSound = nil end

	local outgoing = currentSound
	currentSound = nil
	if not outgoing then
		playContext(contextName, generation)
		return
	end
	fadingSound = outgoing
	local tween = TweenService:Create(
		outgoing,
		TweenInfo.new(MusicConfig.CrossfadeDurationSeconds * 0.5, Enum.EasingStyle.Linear),
		{ Volume = 0 }
	)
	tween.Completed:Connect(function()
		destroySound(outgoing)
		if fadingSound == outgoing then fadingSound = nil end
		if generation == transitionGeneration then playContext(contextName, generation) end
	end)
	tween:Play()
end

function MusicController:Init(navigationController)
	if isInitialised then return end
	isInitialised = true
	navigationController.Changed.Event:Connect(function(route)
		local contextName = MusicConfig.RouteContexts[route]
		if contextName then self:SetContext(contextName) end
	end)
end

return MusicController
