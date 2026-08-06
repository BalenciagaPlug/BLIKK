local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BindingState = require(script.Parent.BindingState)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ActionBuffer = require(Shared.Input.ActionBuffer)
local ActionCatalogue = require(Shared.Input.ActionCatalogue)

local InputManager = {}

local PLAYER_MODULE_OBSERVATION_SECONDS = 5

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
local hasWarnedControlsUnavailable = false
local playerModuleConnections = {}
local playerModuleObservationGeneration = 0

local function warnControlsUnavailable(reason)
	if hasWarnedControlsUnavailable then
		return
	end

	hasWarnedControlsUnavailable = true
	warn("[BLIKK INPUT] Standard Roblox controls could not be disabled: " .. reason)
end

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

	local timestamp = os.clock()
	ActionBuffer:Push(action, timestamp)
	InputManager.ActionBegan:Fire(action, timestamp)
end

local function endToken(token)
	InputManager.InputEnded:Fire(token)

	local action = tokenToAction[token]

	if action then
		InputManager.ActionEnded:Fire(action, os.clock())
	end
end

local function disconnectPlayerModuleObservers()
	for _, connection in playerModuleConnections do connection:Disconnect() end
	table.clear(playerModuleConnections)
end

local function disableDiscoveredPlayerModule(playerModuleScript)
	playerModuleObservationGeneration += 1
	disconnectPlayerModuleObservers()
	if not playerModuleScript:IsA("ModuleScript") then
		warnControlsUnavailable("discovered PlayerModule was not a ModuleScript")
		return
	end
	local didDisable, disableError = pcall(function()
		local playerModule = require(playerModuleScript)
		local controls = playerModule:GetControls()
		controls:Disable()
	end)
	if not didDisable then warnControlsUnavailable(tostring(disableError)) end

end

local function observePlayerModule()
	playerModuleObservationGeneration += 1
	local generation = playerModuleObservationGeneration
	local player = Players.LocalPlayer
	local isComplete = false

	local function complete(playerModuleScript)
		if isComplete or generation ~= playerModuleObservationGeneration then return end
		isComplete = true
		task.spawn(disableDiscoveredPlayerModule, playerModuleScript)
	end

	local function observePlayerScripts(playerScripts)
		local existing = playerScripts:FindFirstChild("PlayerModule")
		if existing then complete(existing); return end
		table.insert(playerModuleConnections, playerScripts.ChildAdded:Connect(function(child)
			if child.Name == "PlayerModule" then complete(child) end
		end))
	end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	if playerScripts then
		observePlayerScripts(playerScripts)
	else
		table.insert(playerModuleConnections, player.ChildAdded:Connect(function(child)
			if child.Name == "PlayerScripts" then observePlayerScripts(child) end
		end))
	end

	task.delay(PLAYER_MODULE_OBSERVATION_SECONDS, function()
		if generation ~= playerModuleObservationGeneration or isComplete then return end
		playerModuleObservationGeneration += 1
		disconnectPlayerModuleObservers()
	end)
end

function InputManager:Init()
	if isInitialised then
		return
	end

	isInitialised = true
	rebuildLookup()
	observePlayerModule()
	table.insert(playerModuleConnections, script.Destroying:Connect(function()
		playerModuleObservationGeneration += 1
		disconnectPlayerModuleObservers()
	end))

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
