local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioPreloadController = require(script.Parent.AudioPreloadController)
local MusicConfig = require(ReplicatedStorage.Shared.Audio.MusicConfig)

local MusicController = {}

local musicRandom = Random.new()
local isInitialised = false
local currentContext = "Silent"
local currentSessionKey = nil
local state = "Stopped"
local playbackSound = nil
local currentTrack = nil
local pendingTrack = nil
local pendingContextGeneration = 0
local pendingPlaylistGeneration = 0
local contextGeneration = 0
local playbackGeneration = 0
local playlistGeneration = 0
local transitionGeneration = 0
local fadeTween = nil
local fadeConnection = nil
local endedConnection = nil
local navigationConnection = nil
local preloadStatusConnection = nil
local destroyingConnection = nil
local warnedUnavailableTracks = {}
local duelBag = {}
local duelBagIndex = 0
local duelLastTrackKey = nil
local duelUnavailableTracks = {}
local duelUnavailableCount = 0
local duelAllUnavailableWarned = false

local advanceDuelTrack
local handleTrackUnavailable
local requestTrack
local transitionToTrack
local fadeToSilence

local function diagnose(message)
	if MusicConfig.DiagnosticsEnabled then print("[BLIKK AUDIO] " .. message) end
end

local function disconnectEnded()
	if endedConnection then endedConnection:Disconnect(); endedConnection = nil end
end

local function cancelFade()
	if fadeConnection then fadeConnection:Disconnect(); fadeConnection = nil end
	if fadeTween then fadeTween:Cancel(); fadeTween = nil end
end

local function ensurePlaybackSound()
	if playbackSound and playbackSound.Parent == SoundService then return playbackSound end
	local existing = SoundService:FindFirstChild(MusicConfig.PlaybackSoundName)
	if existing and existing:IsA("Sound") then
		playbackSound = existing
	else
		if existing then
			warn("[BLIKK AUDIO] Reserved music playback name is occupied; using one owned Sound.")
		end
		playbackSound = Instance.new("Sound")
		playbackSound.Name = MusicConfig.PlaybackSoundName
		playbackSound.Parent = SoundService
	end
	playbackSound:Stop()
	playbackSound.SoundId = ""
	playbackSound.Looped = false
	playbackSound.PlaybackSpeed = MusicConfig.PlaybackSpeed
	playbackSound.TimePosition = 0
	playbackSound.Volume = 0
	local musicGroup = SoundService:FindFirstChild(MusicConfig.SoundGroupName)
	if musicGroup and musicGroup:IsA("SoundGroup") then
		playbackSound.SoundGroup = musicGroup
	else
		warn("[BLIKK AUDIO] Music SoundGroup is unavailable; music will remain silent.")
	end
	return playbackSound
end

local function isPlaybackCurrent(
	expectedContextGeneration,
	expectedPlaybackGeneration,
	expectedPlaylistGeneration,
	expectedSound,
	expectedTrack
)
	return contextGeneration == expectedContextGeneration
		and playbackGeneration == expectedPlaybackGeneration
		and playlistGeneration == expectedPlaylistGeneration
		and playbackSound == expectedSound
		and expectedSound.Parent == SoundService
		and currentTrack == expectedTrack
		and expectedSound.SoundId == expectedTrack.SoundId
end

local function beginFade(
	targetVolume,
	durationSeconds,
	expectedTransitionGeneration,
	expectedContextGeneration,
	expectedPlaybackGeneration,
	completed
)
	cancelFade()
	local sound = playbackSound
	if durationSeconds <= 0 then
		if transitionGeneration ~= expectedTransitionGeneration
			or contextGeneration ~= expectedContextGeneration
			or playbackGeneration ~= expectedPlaybackGeneration then return end
		sound.Volume = targetVolume
		completed()
		return
	end
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(durationSeconds, Enum.EasingStyle.Linear),
		{ Volume = targetVolume }
	)
	local connection
	connection = tween.Completed:Connect(function(playbackState)
		if connection == fadeConnection then fadeConnection = nil end
		if tween == fadeTween then fadeTween = nil end
		connection:Disconnect()
		if playbackState ~= Enum.PlaybackState.Completed
			or transitionGeneration ~= expectedTransitionGeneration
			or contextGeneration ~= expectedContextGeneration
			or playbackGeneration ~= expectedPlaybackGeneration
			or playbackSound ~= sound then return end
		completed()
	end)
	fadeTween = tween
	fadeConnection = connection
	tween:Play()
end

local function warnUnavailable(track)
	if warnedUnavailableTracks[track.Key] then return end
	warnedUnavailableTracks[track.Key] = true
end

local function startTrack(
	track,
	expectedTransitionGeneration,
	expectedContextGeneration,
	expectedPlaylistGeneration
)
	if transitionGeneration ~= expectedTransitionGeneration
		or contextGeneration ~= expectedContextGeneration
		or playlistGeneration ~= expectedPlaylistGeneration
		or AudioPreloadController:GetStatus(track.Key) ~= "Success" then return end
	disconnectEnded()
	local sound = ensurePlaybackSound()
	sound:Stop()
	sound.SoundId = track.SoundId
	sound.Looped = track.Looped == true
	sound.PlaybackSpeed = MusicConfig.PlaybackSpeed
	sound.TimePosition = 0
	sound.Volume = 0
	sound:SetAttribute("BLIKK_MusicTrackKey", track.Key)
	sound:SetAttribute("BLIKK_MusicTrackName", track.Name)
	sound:SetAttribute("BLIKK_MusicContext", currentContext)
	currentTrack = track
	pendingTrack = nil
	playbackGeneration += 1
	local expectedPlaybackGeneration = playbackGeneration
	sound:Play()
	state = "FadingIn"

	if currentContext == "Gameplay" and not sound.Looped then
		endedConnection = sound.Ended:Connect(function()
			if not isPlaybackCurrent(
				expectedContextGeneration,
				expectedPlaybackGeneration,
				expectedPlaylistGeneration,
				sound,
				track
			) or currentContext ~= "Gameplay" then return end
			disconnectEnded()
			advanceDuelTrack()
		end)
	end

	beginFade(
		MusicConfig.VolumeMultiplier,
		MusicConfig.FadeInSeconds,
		expectedTransitionGeneration,
		expectedContextGeneration,
		expectedPlaybackGeneration,
		function()
			state = "Playing"
			diagnose(string.format("%s active in %s", track.Key, currentContext))
		end
	)
	if currentContext == "Gameplay" then
		local lookahead = duelBag[duelBagIndex + 1]
		if lookahead then AudioPreloadController:GetStatus(lookahead.Key) end
	end
end

transitionToTrack = function(track)
	if currentTrack == track and playbackSound and playbackSound.IsPlaying then return end
	transitionGeneration += 1
	local expectedTransitionGeneration = transitionGeneration
	local expectedContextGeneration = contextGeneration
	local expectedPlaylistGeneration = playlistGeneration
	local expectedPlaybackGeneration = playbackGeneration
	disconnectEnded()
	cancelFade()
	local sound = ensurePlaybackSound()
	local function beginSelectedTrack()
		startTrack(
			track,
			expectedTransitionGeneration,
			expectedContextGeneration,
			expectedPlaylistGeneration
		)
	end
	if not sound.IsPlaying or currentTrack == nil or sound.Volume <= 0 then
		sound.Volume = 0
		beginSelectedTrack()
		return
	end
	state = "FadingOut"
	beginFade(
		0,
		MusicConfig.FadeOutSeconds,
		expectedTransitionGeneration,
		expectedContextGeneration,
		expectedPlaybackGeneration,
		beginSelectedTrack
	)
end

fadeToSilence = function(finalState)
	transitionGeneration += 1
	local expectedTransitionGeneration = transitionGeneration
	local expectedContextGeneration = contextGeneration
	local expectedPlaybackGeneration = playbackGeneration
	disconnectEnded()
	cancelFade()
	local sound = ensurePlaybackSound()
	local function stopSound()
		sound:Stop()
		sound.TimePosition = 0
		sound.Volume = 0
		sound.SoundId = ""
		sound:SetAttribute("BLIKK_MusicTrackKey", nil)
		sound:SetAttribute("BLIKK_MusicTrackName", nil)
		currentTrack = nil
		playbackGeneration += 1
		state = finalState
	end
	if not sound.IsPlaying or sound.Volume <= 0 then
		stopSound()
		return
	end
	state = "FadingOut"
	beginFade(
		0,
		MusicConfig.FadeOutSeconds,
		expectedTransitionGeneration,
		expectedContextGeneration,
		expectedPlaybackGeneration,
		stopSound
	)
end

local function enabledDuelTracks()
	local tracks = {}
	for _, track in MusicConfig.Tracks.DuelPlaylist do
		if track.Enabled == true and AudioPreloadController:IsEnabled(track.Key) then
			table.insert(tracks, track)
		end
	end
	return tracks
end

local function buildDuelBag()
	table.clear(duelBag)
	for _, track in enabledDuelTracks() do table.insert(duelBag, track) end
	for index = #duelBag, 2, -1 do
		local swapIndex = musicRandom:NextInteger(1, index)
		duelBag[index], duelBag[swapIndex] = duelBag[swapIndex], duelBag[index]
	end
	if #duelBag > 1 and duelLastTrackKey and duelBag[1].Key == duelLastTrackKey then
		local swapIndex = musicRandom:NextInteger(2, #duelBag)
		duelBag[1], duelBag[swapIndex] = duelBag[swapIndex], duelBag[1]
	end
	duelBagIndex = 0
end

local function silenceUnavailableDuelSession()
	if not duelAllUnavailableWarned then
		duelAllUnavailableWarned = true
		warn("[BLIKK AUDIO] All enabled Duel playlist tracks were unavailable; gameplay continues silently.")
	end
	pendingTrack = nil
	fadeToSilence("Unavailable")
end

advanceDuelTrack = function()
	if currentContext ~= "Gameplay" then return end
	local trackCount = #enabledDuelTracks()
	if trackCount == 0 or duelUnavailableCount >= trackCount then
		silenceUnavailableDuelSession()
		return
	end
	local checked = 0
	while checked < trackCount do
		if duelBagIndex >= #duelBag then buildDuelBag() end
		if #duelBag == 0 then break end
		duelBagIndex += 1
		checked += 1
		local track = duelBag[duelBagIndex]
		if not duelUnavailableTracks[track.Key] then
			duelLastTrackKey = track.Key
			requestTrack(track)
			return
		end
	end
	silenceUnavailableDuelSession()
end

handleTrackUnavailable = function(track, expectedPlaylistGeneration)
	if currentContext ~= "Gameplay" or playlistGeneration ~= expectedPlaylistGeneration then return end
	if not duelUnavailableTracks[track.Key] then
		duelUnavailableTracks[track.Key] = true
		duelUnavailableCount += 1
	end
	advanceDuelTrack()
end

requestTrack = function(track)
	if track.Enabled ~= true or not AudioPreloadController:IsEnabled(track.Key) then
		if currentContext == "Gameplay" then
			handleTrackUnavailable(track, playlistGeneration)
		else
			fadeToSilence("Disabled")
		end
		return
	end
	local preloadStatus = AudioPreloadController:GetStatus(track.Key)
	if preloadStatus == "Success" then
		pendingTrack = nil
		transitionToTrack(track)
	elseif preloadStatus == "Failure" or preloadStatus == "Disabled" then
		warnUnavailable(track)
		if currentContext == "Gameplay" then
			handleTrackUnavailable(track, playlistGeneration)
		else
			pendingTrack = nil
			fadeToSilence("Unavailable")
		end
	else
		pendingTrack = track
		pendingContextGeneration = contextGeneration
		pendingPlaylistGeneration = playlistGeneration
		fadeToSilence("WaitingForAsset")
	end
end

local function beginDuelSession()
	table.clear(duelBag)
	table.clear(duelUnavailableTracks)
	duelBagIndex = 0
	duelLastTrackKey = nil
	duelUnavailableCount = 0
	advanceDuelTrack()
end

local function handlePreloadStatus(key, preloadStatus)
	local track = pendingTrack
	if not track or track.Key ~= key
		or contextGeneration ~= pendingContextGeneration
		or playlistGeneration ~= pendingPlaylistGeneration then return end
	if preloadStatus == "Success" then
		pendingTrack = nil
		transitionToTrack(track)
	elseif preloadStatus == "Failure" then
		pendingTrack = nil
		warnUnavailable(track)
		if currentContext == "Gameplay" then
			handleTrackUnavailable(track, pendingPlaylistGeneration)
		else
			fadeToSilence("Unavailable")
		end
	end
end

function MusicController:SetContext(contextName, sessionKey)
	if contextName ~= "Silent" and contextName ~= "CharacterSelection"
		and contextName ~= "MainMenu" and contextName ~= "Gameplay" then
		warn("[BLIKK AUDIO] Ignored unknown music context: " .. tostring(contextName))
		return false
	end
	if currentContext == contextName
		and (contextName ~= "Gameplay" or currentSessionKey == sessionKey) then return true end

	currentContext = contextName
	currentSessionKey = sessionKey
	contextGeneration += 1
	playlistGeneration += 1
	pendingTrack = nil
	if contextName == "CharacterSelection" then
		requestTrack(MusicConfig.Tracks.CharacterSelection)
	elseif contextName == "MainMenu" then
		requestTrack(MusicConfig.Tracks.OperationsHub)
	elseif contextName == "Gameplay" then
		beginDuelSession()
	else
		fadeToSilence("Stopped")
	end
	return true
end

function MusicController:GetState()
	return state
end

function MusicController:GetContext()
	return currentContext
end

function MusicController:Init(navigationController)
	if isInitialised then return end
	isInitialised = true
	ensurePlaybackSound()
	preloadStatusConnection = AudioPreloadController.StatusChanged.Event:Connect(handlePreloadStatus)
	navigationConnection = navigationController.Changed.Event:Connect(function(route)
		local context = MusicConfig.RouteContexts[route]
		if context then self:SetContext(context, "Route:" .. route) end
	end)
	destroyingConnection = script.Destroying:Connect(function()
		contextGeneration += 1
		playlistGeneration += 1
		transitionGeneration += 1
		disconnectEnded()
		cancelFade()
		if navigationConnection then navigationConnection:Disconnect(); navigationConnection = nil end
		if preloadStatusConnection then
			preloadStatusConnection:Disconnect()
			preloadStatusConnection = nil
		end
		if destroyingConnection then destroyingConnection:Disconnect(); destroyingConnection = nil end
		if playbackSound then playbackSound:Destroy(); playbackSound = nil end
	end)
end

return MusicController
