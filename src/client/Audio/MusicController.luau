local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local MusicConfig = require(ReplicatedStorage.Shared.Audio.MusicConfig)

local MusicController = {}

local isInitialised = false
local isFrontendActive = false
local state = "Stopped"
local soundtrack = nil
local fadeTween = nil
local fadeConnection = nil
local navigationConnection = nil
local destroyingConnection = nil
local transitionGeneration = 0
local warnedAssetUnavailable = false

local function diagnose(message)
	if MusicConfig.DiagnosticsEnabled then print("[BLIKK AUDIO] " .. message) end
end

local function cancelFade()
	transitionGeneration += 1
	if fadeConnection then fadeConnection:Disconnect(); fadeConnection = nil end
	if fadeTween then fadeTween:Cancel(); fadeTween = nil end
end

local function beginFade(targetVolume, durationSeconds, completed)
	cancelFade()
	local generation = transitionGeneration
	if durationSeconds <= 0 then
		soundtrack.Volume = targetVolume
		completed()
		return
	end
	fadeTween = TweenService:Create(
		soundtrack,
		TweenInfo.new(durationSeconds, Enum.EasingStyle.Linear),
		{ Volume = targetVolume }
	)
	fadeConnection = fadeTween.Completed:Connect(function(playbackState)
		if generation ~= transitionGeneration or playbackState ~= Enum.PlaybackState.Completed then return end
		fadeConnection:Disconnect()
		fadeConnection = nil
		fadeTween = nil
		completed()
	end)
	fadeTween:Play()
end

local function ensureSoundtrack()
	if soundtrack and soundtrack.Parent then return soundtrack end
	local config = MusicConfig.FrontendSoundtrack
	local existing = SoundService:FindFirstChild(config.Name)
	if existing and existing:IsA("Sound") then
		soundtrack = existing
	else
		if existing then
			warn("[BLIKK AUDIO] Reserved soundtrack name is occupied; creating the owned Sound safely.")
		end
		soundtrack = Instance.new("Sound")
		soundtrack.Name = config.Name
		soundtrack.SoundId = config.SoundId
		soundtrack.Looped = config.Looped
		soundtrack.PlaybackSpeed = config.PlaybackSpeed
		soundtrack.Volume = 0
		soundtrack.Parent = SoundService
	end
	local musicGroup = SoundService:FindFirstChild(config.SoundGroupName)
	if musicGroup and musicGroup:IsA("SoundGroup") then
		soundtrack.SoundGroup = musicGroup
	else
		warn("[BLIKK AUDIO] Music SoundGroup is unavailable; frontend soundtrack will remain silent.")
	end
	return soundtrack
end

local function observeAssetReadiness()
	local observedSound = soundtrack
	task.delay(MusicConfig.FrontendSoundtrack.AssetObservationSeconds, function()
		if warnedAssetUnavailable or observedSound ~= soundtrack or not observedSound.Parent then return end
		if RunService:IsStudio() and not observedSound.IsLoaded then
			warnedAssetUnavailable = true
			warn("[BLIKK AUDIO] Frontend soundtrack has not loaded; frontend remains available.")
		end
	end)
end

function MusicController:SetFrontendActive(active)
	active = active == true
	if isFrontendActive == active
		and (active and (state == "Playing" or state == "FadingIn")
			or not active and (state == "PausedForGameplay" or state == "FadingOut")) then
		return
	end
	isFrontendActive = active
	ensureSoundtrack()
	local config = MusicConfig.FrontendSoundtrack
	if active then
		local wasPaused = state == "PausedForGameplay"
		cancelFade()
		if wasPaused and config.ResumeOnFrontendReturn then
			soundtrack:Resume()
		elseif not soundtrack.IsPlaying then
			soundtrack:Play()
		end
		state = "FadingIn"
		beginFade(config.VolumeMultiplier, config.FadeInSeconds, function()
			state = "Playing"
			diagnose("frontend soundtrack active")
		end)
	elseif state ~= "Stopped" and state ~= "PausedForGameplay" then
		state = "FadingOut"
		beginFade(0, config.FadeOutSeconds, function()
			soundtrack:Pause()
			state = "PausedForGameplay"
			diagnose("frontend soundtrack paused for gameplay")
		end)
	end
end

function MusicController:SetContext(contextName)
	self:SetFrontendActive(contextName == "CharacterSelection" or contextName == "OperationsHub")
end

function MusicController:GetState()
	return state
end

function MusicController:Init(navigationController)
	if isInitialised then return end
	isInitialised = true
	ensureSoundtrack()
	observeAssetReadiness()
	navigationConnection = navigationController.Changed.Event:Connect(function(route)
		if MusicConfig.FrontendRoutes[route] then self:SetFrontendActive(true) end
	end)
	destroyingConnection = script.Destroying:Connect(function()
		cancelFade()
		if navigationConnection then navigationConnection:Disconnect(); navigationConnection = nil end
		if destroyingConnection then destroyingConnection:Disconnect(); destroyingConnection = nil end
	end)
end

return MusicController
