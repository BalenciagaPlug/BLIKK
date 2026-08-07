local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BindingState = require(script.Parent.BindingState)

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before input management")
local ActionBuffer = require(Shared.Input.ActionBuffer)
local ActionCatalogue = require(Shared.Input.ActionCatalogue)
local InputConfig = require(Shared.Input.InputConfig)

local InputManager = {}

local PLAYER_MODULE_OBSERVATION_SECONDS = 5

InputManager.ActionBegan = Instance.new("BindableEvent")
InputManager.ActionEnded = Instance.new("BindableEvent")
InputManager.GameplayEnabledChanged = Instance.new("BindableEvent")
InputManager.InputBegan = Instance.new("BindableEvent")
InputManager.InputEnded = Instance.new("BindableEvent")
InputManager.SuppressionChanged = Instance.new("BindableEvent")

local isInitialised = false
local isGameplayRequestedEnabled = true
local isGameplayEnabled = true
local gameplayBlockers = {}
local isBindingCaptureActive = false
local isTextInputActive = false
local isMenuInputActive = false
local isMenuSettingsActionAllowed = false
local hasWindowFocus = true
local tokenToAction = {}
local dispatchedTokens = {}
local dispatchedRawTokens = {}
local dispatchSequences = {}
local heldTokensByAction = {}
local dispatchSequence = 0
local wheelPulseGeneration = 0
local activeWheelPulses = {}
local fixedMenuTokens = {
	["KeyCode.Up"] = true,
	["KeyCode.Down"] = true,
	["KeyCode.Left"] = true,
	["KeyCode.Right"] = true,
	["KeyCode.Return"] = true,
	["KeyCode.KeypadEnter"] = true,
	["KeyCode.Backspace"] = true,
}
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

local function canDispatchAction(action, token)
	if not action then return false end
	if isMenuInputActive and (action ~= "Settings" or not isMenuSettingsActionAllowed
		or fixedMenuTokens[token]) then return false end
	return isGameplayEnabled or isInterfaceAction(action)
end

local function beginToken(token, dispatchKey)
	InputManager.InputBegan:Fire(token)
	dispatchKey = dispatchKey or token

	if dispatchedTokens[dispatchKey] then
		return
	end

	local action = tokenToAction[token]

	if not canDispatchAction(action, token) then
		return
	end

	local timestamp = os.clock()
	dispatchSequence += 1
	dispatchedTokens[dispatchKey] = action
	dispatchedRawTokens[dispatchKey] = token
	dispatchSequences[dispatchKey] = dispatchSequence
	local heldTokens = heldTokensByAction[action]
	if not heldTokens then
		heldTokens = {}
		heldTokensByAction[action] = heldTokens
	end
	heldTokens[dispatchKey] = true
	ActionBuffer:Push(action, timestamp)
	InputManager.ActionBegan:Fire(action, timestamp)
end

local function finishDispatch(dispatchKey, shouldFireRawEnd)
	local action = dispatchedTokens[dispatchKey]
	if not action then
		return
	end

	local rawToken = dispatchedRawTokens[dispatchKey]
	dispatchedTokens[dispatchKey] = nil
	dispatchedRawTokens[dispatchKey] = nil
	dispatchSequences[dispatchKey] = nil
	if shouldFireRawEnd then
		activeWheelPulses[dispatchKey] = nil
		InputManager.InputEnded:Fire(rawToken)
	end

	local heldTokens = heldTokensByAction[action]
	if not heldTokens then
		return
	end

	heldTokens[dispatchKey] = nil
	if next(heldTokens) == nil then
		heldTokensByAction[action] = nil
		InputManager.ActionEnded:Fire(action, os.clock())
	end
end

local function endToken(token)
	InputManager.InputEnded:Fire(token)
	finishDispatch(token, false)
end

local function flushHeldInputs()
	local activeDispatches = {}
	for dispatchKey in dispatchedTokens do
		table.insert(activeDispatches, {
			Key = dispatchKey,
			Sequence = dispatchSequences[dispatchKey],
		})
	end
	table.sort(activeDispatches, function(left, right)
		return left.Sequence < right.Sequence
	end)

	for _, dispatch in activeDispatches do
		finishDispatch(dispatch.Key, true)
	end

	local remainingWheelPulseGenerations = {}
	for generation in activeWheelPulses do
		table.insert(remainingWheelPulseGenerations, generation)
	end
	table.sort(remainingWheelPulseGenerations)
	for _, generation in remainingWheelPulseGenerations do
		local token = activeWheelPulses[generation]
		activeWheelPulses[generation] = nil
		InputManager.InputEnded:Fire(token)
	end
end

local function refreshGameplayEnabled()
	local nextGameplayEnabled = isGameplayRequestedEnabled and next(gameplayBlockers) == nil
	if isGameplayEnabled == nextGameplayEnabled then
		return
	end

	isGameplayEnabled = nextGameplayEnabled
	if not nextGameplayEnabled then
		ActionBuffer:Clear()
		flushHeldInputs()
	end
	InputManager.GameplayEnabledChanged:Fire(nextGameplayEnabled)
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
		wheelPulseGeneration += 1
		local pulseGeneration = wheelPulseGeneration
		activeWheelPulses[pulseGeneration] = token
		beginToken(token, pulseGeneration)
		task.delay(InputConfig.MouseWheelPulseDurationSeconds, function()
			local activeToken = activeWheelPulses[pulseGeneration]
			if not activeToken then return end
			activeWheelPulses[pulseGeneration] = nil
			InputManager.InputEnded:Fire(activeToken)
			finishDispatch(pulseGeneration, false)
		end)
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		hasWindowFocus = false
		ActionBuffer:Clear()
		flushHeldInputs()
		InputManager.SuppressionChanged:Fire(true)
	end)

	UserInputService.WindowFocused:Connect(function()
		hasWindowFocus = true
		InputManager.SuppressionChanged:Fire(
			isBindingCaptureActive or isTextInputActive or isMenuInputActive
		)
	end)
end

function InputManager:SetGameplayEnabled(isEnabled)
	local nextRequestedEnabled = isEnabled == true
	if isGameplayRequestedEnabled == nextRequestedEnabled then
		return
	end

	isGameplayRequestedEnabled = nextRequestedEnabled
	refreshGameplayEnabled()
end

function InputManager:SetGameplayBlocked(owner, blocked)
	assert(type(owner) == "string" and owner ~= "", "Gameplay blocker owner must be a non-empty string")
	local isBlocked = gameplayBlockers[owner] == true
	local shouldBlock = blocked == true
	if isBlocked == shouldBlock then
		return
	end

	if shouldBlock then
		gameplayBlockers[owner] = true
	else
		gameplayBlockers[owner] = nil
	end
	refreshGameplayEnabled()
end

function InputManager:SetBindingCaptureActive(isActive)
	isBindingCaptureActive = isActive
	if isActive then
		ActionBuffer:Clear()
		flushHeldInputs()
	end
	self.SuppressionChanged:Fire(
		isBindingCaptureActive or isTextInputActive or isMenuInputActive or not hasWindowFocus
	)
end

function InputManager:SetTextInputActive(isActive)
	isTextInputActive = isActive
	if isActive then
		ActionBuffer:Clear()
		flushHeldInputs()
	end
	self.SuppressionChanged:Fire(
		isBindingCaptureActive or isTextInputActive or isMenuInputActive or not hasWindowFocus
	)
end

function InputManager:SetMenuInputActive(isActive, allowsSettingsAction)
	local nextAllowsSettingsAction = isActive and allowsSettingsAction == true
	if isMenuInputActive == isActive
		and isMenuSettingsActionAllowed == nextAllowsSettingsAction then return end
	isMenuInputActive = isActive
	isMenuSettingsActionAllowed = nextAllowsSettingsAction
	if isActive then
		ActionBuffer:Clear()
		flushHeldInputs()
	end
	self.SuppressionChanged:Fire(
		isBindingCaptureActive or isTextInputActive or isMenuInputActive or not hasWindowFocus
	)
end

function InputManager:IsBindingCaptureActive()
	return isBindingCaptureActive
end

return InputManager
