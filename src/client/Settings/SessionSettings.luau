local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SettingsConfig = require(Shared.Settings.SettingsConfig)

local SessionSettings = {}

SessionSettings.Changed = Instance.new("BindableEvent")

local values = {}

local function copyDefaults(defaults)
	for key, value in defaults do
		values[key] = value
	end
end

copyDefaults(SettingsConfig.AudioDefaults)
copyDefaults(SettingsConfig.ExtrasDefaults)

function SessionSettings:Get(key)
	return values[key]
end

function SessionSettings:Set(key, value)
	if values[key] == nil or values[key] == value then
		return
	end

	values[key] = value
	self.Changed:Fire(key, value)
end

return SessionSettings
