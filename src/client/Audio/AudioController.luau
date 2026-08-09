local SoundService = game:GetService("SoundService")

local PlayerPreferencesController = require(script.Parent.Parent.Settings.PlayerPreferencesController)
local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)

local AudioController = {}

local isInitialised = false
local masterGroup = nil
local musicGroup = nil
local soundEffectsGroup = nil
local dashGroup = nil

local function silenceGroups()
	masterGroup.Volume = 0
	musicGroup.Volume = 0
	soundEffectsGroup.Volume = 0
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
	masterGroup.Volume = masterVolume
	musicGroup.Volume = if SessionSettings:Get("MusicMuted")
		then 0
		else masterVolume * SessionSettings:Get("MusicVolume")
	soundEffectsGroup.Volume = masterVolume * SessionSettings:Get("SoundEffectsVolume")
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
	dashGroup = getOrCreateSoundGroup("BLIKK_Dash")
	updateVolumes()
	PlayerPreferencesController.PreferencesApplied.Event:Connect(updateVolumes)

	SessionSettings.Changed.Event:Connect(function(key)
		if key == "MasterVolume" or key == "MusicVolume" or key == "MusicMuted" or key == "SoundEffectsVolume" then
			updateVolumes()
		end
	end)
end

return AudioController
