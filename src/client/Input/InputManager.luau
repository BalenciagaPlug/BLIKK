local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BindingState = require(script.Parent.BindingState)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ActionBuffer = require(Shared.Input.ActionBuffer)
local ActionCatalogue = require(Shared.Input.ActionCatalogue)

local InputManager = {}

InputManager.ActionBegan = Instance.new("BindableEvent")
InputManager.ActionEnded = Instance.new("BindableEvent")
InputManager.GameplayEnabledChanged = Instance.new("BindableEvent")
InputManager.InputBegan = Instance.new("BindableEvent")
InputManager.InputEnded = Instance.new("BindableEvent")
InputManager.SuppressionChanged = Instance.new("BindableEvent")

local isInitialised = false
local isGameplayEnabled = true
local isBindingCaptureActive = false
local isTextInputActive = false
local tokenToAction = {}

local function rebuildLookup()
	table.clear(tokenToAction)

	for _, definition in ActionCatalogue.Ordered do
		local slots = BindingState:GetActionBindings(definition.Id)

		for _, token in slots do
			if token then
				tokenToAction[token] = definition.Id
			end
		end
	end
end

local function isInterfaceAction(action)
	local definition = ActionCatalogue.ById[action]
	return definition and definition.Group == "Interface"
end

local function beginToken(token)
	InputManager.InputBegan:Fire(token)

	local action = tokenToAction[token]

	if not action or (not isGameplayEnabled and not isInterfaceAction(action)) then
		return
	end

	ActionBuffer:Push(action)
	InputManager.ActionBegan:Fire(action, os.clock())
end

local function endToken(token)
	InputManager.InputEnded:Fire(token)

	local action = tokenToAction[token]

	if action then
		InputManager.ActionEnded:Fire(action, os.clock())
	end
end

local function disableRobloxControls()
	local player = Players.LocalPlayer
	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModuleScript = playerScripts:WaitForChild("PlayerModule")
	local playerModule = require(playerModuleScript)
	playerModule:GetControls():Disable()
end

function InputManager:Init()
	if isInitialised then
		return
	end

	isInitialised = true
	rebuildLookup()
	task.spawn(disableRobloxControls)

	BindingState.Changed.Event:Connect(rebuildLookup)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if isBindingCaptureActive or isTextInputActive or gameProcessed then
			return
		end

		local token = ActionCatalogue.TokenFromInput(input)

		if token then
			beginToken(token)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local token = ActionCatalogue.TokenFromInput(input)

		if token then
			endToken(token)
		end
	end)

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if isBindingCaptureActive or isTextInputActive or gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end

		local token = if input.Position.Z > 0 then "MouseWheelUp" else "MouseWheelDown"
		beginToken(token)
		task.delay(0.12, function()
			endToken(token)
		end)
	end)
end

function InputManager:SetGameplayEnabled(isEnabled)
	if isGameplayEnabled == isEnabled then
		return
	end

	isGameplayEnabled = isEnabled

	if not isEnabled then
		ActionBuffer:Clear()
	end

	self.GameplayEnabledChanged:Fire(isEnabled)
end

function InputManager:SetBindingCaptureActive(isActive)
	isBindingCaptureActive = isActive
	if isActive then ActionBuffer:Clear() end
	self.SuppressionChanged:Fire(isBindingCaptureActive or isTextInputActive)
end

function InputManager:SetTextInputActive(isActive)
	isTextInputActive = isActive
	if isActive then ActionBuffer:Clear() end
	self.SuppressionChanged:Fire(isBindingCaptureActive or isTextInputActive)
end

return InputManager
