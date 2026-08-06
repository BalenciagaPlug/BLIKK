local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraSettings = require(script.Parent.Parent.Camera.CameraSettings)
local BindingState = require(script.Parent.Parent.Input.BindingState)
local SessionSettings = require(script.Parent.SessionSettings)
local PlayerPreferencesConfig = require(
	ReplicatedStorage.Shared.Settings.PlayerPreferencesConfig
)

local Controller = {}

local accountController = nil
local isInitialised = false

local function applySettings(settings)
	if type(settings) ~= "table" then return end
	BindingState:ApplyConfirmed(settings.Bindings)
	if type(settings.Preferences) ~= "table" then return end
	for key, value in settings.Preferences do
		local definition = PlayerPreferencesConfig.Definitions[key]
		if definition and definition.Owner == "Camera" then
			CameraSettings:Set(key, value)
		elseif definition and definition.Owner == "Session" then
			SessionSettings:Set(key, value)
		end
	end
end

local function mutate(operation, payload)
	if not accountController then return false, "ACCOUNT STORAGE IS NOT READY" end
	local result, message = accountController:RequestAccountMutation(operation, payload)
	return result ~= nil, message
end

function Controller:Init(characterProfilesController)
	if isInitialised then return end
	isInitialised = true
	accountController = characterProfilesController
	characterProfilesController.AccountSnapshotChanged.Event:Connect(applySettings)
	applySettings(characterProfilesController:GetAccountSettings())
end

function Controller:SetBinding(actionId, slot, token)
	return mutate("SetBinding", { Action = actionId, Slot = slot, Token = token })
end

function Controller:ClearBinding(actionId, slot)
	return mutate("ClearBinding", { Action = actionId, Slot = slot })
end

function Controller:ResetBinding(actionId)
	return mutate("ResetBinding", actionId)
end

function Controller:ResetAllBindings()
	return mutate("ResetAllBindings", nil)
end

function Controller:SetPreference(key, value)
	return mutate("SetPreference", { Key = key, Value = value })
end

function Controller:ResetPreferenceGroup(group)
	return mutate("ResetPreferenceGroup", group)
end

return Controller
