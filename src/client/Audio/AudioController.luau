local SoundService = game:GetService("SoundService")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)

local AudioController = {}

local isInitialised = false
local masterGroup = nil
local musicGroup = nil
local soundEffectsGroup = nil
local dashGroup = nil

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

	SessionSettings.Changed.Event:Connect(function(key)
		if key == "MasterVolume" or key == "MusicVolume" or key == "MusicMuted" or key == "SoundEffectsVolume" then
			updateVolumes()
		end
	end)
end

return AudioController
