local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerPreferencesController = require(script.Parent.Parent.Settings.PlayerPreferencesController)
local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local SettingsConfig = require(ReplicatedStorage.Shared.Settings.SettingsConfig)

local AudioController = {}

local isInitialised = false
local masterGroup = nil
local musicGroup = nil
local soundEffectsGroup = nil
local uiGroup = nil
local dashGroup = nil

local function decibelsToLinear(decibels)
	return 10 ^ (decibels / 20)
end

local function silenceGroups()
	masterGroup.Volume = 0
	musicGroup.Volume = 0
	soundEffectsGroup.Volume = 0
	uiGroup.Volume = 0
	dashGroup.Volume = 0
end

local function getOrCreateSoundGroup(name)
	local existing = SoundService:FindFirstChild(name)

	if existing and existing:IsA("SoundGroup") then
		return existing
	end

	local soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = name
	soundGroup.Parent = SoundService
	return soundGroup
end

local function updateVolumes()
	-- Local defaults are not account truth, so they must never become audible during loading.
	if not PlayerPreferencesController:HasConfirmedPreferences() then
		silenceGroups()
		return
	end

	local masterVolume = SessionSettings:Get("MasterVolume")
	local mix = SettingsConfig.AudioMix
	masterGroup.Volume = masterVolume
	musicGroup.Volume = if SessionSettings:Get("MusicMuted")
		then 0
		else masterVolume * SessionSettings:Get("MusicVolume")
			* decibelsToLinear(mix.MusicGainDecibels)
	soundEffectsGroup.Volume = masterVolume * SessionSettings:Get("SoundEffectsVolume")
		* decibelsToLinear(mix.SoundEffectsGainDecibels)
	uiGroup.Volume = masterVolume * SessionSettings:Get("SoundEffectsVolume")
		* SessionSettings:Get("UISoundVolume")
		* decibelsToLinear(mix.UISoundGainDecibels)
	dashGroup.Volume = soundEffectsGroup.Volume
end

function AudioController:Init()
	if isInitialised then
		return
	end

	isInitialised = true
	masterGroup = getOrCreateSoundGroup("BLIKK_Master")
	musicGroup = getOrCreateSoundGroup("BLIKK_Music")
	soundEffectsGroup = getOrCreateSoundGroup("BLIKK_SoundEffects")
	uiGroup = getOrCreateSoundGroup("BLIKK_UI")
	dashGroup = getOrCreateSoundGroup("BLIKK_Dash")
	updateVolumes()
	PlayerPreferencesController.PreferencesApplied.Event:Connect(updateVolumes)

	SessionSettings.Changed.Event:Connect(function(key)
		if key == "MasterVolume" or key == "MusicVolume" or key == "MusicMuted"
			or key == "SoundEffectsVolume" or key == "UISoundVolume" then
			updateVolumes()
		end
	end)
end

return AudioController
