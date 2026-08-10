local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UIStyle = require(script.Parent.UIStyle)

local UINavigationController = {}

UINavigationController.MenuOwnershipChanged = Instance.new("BindableEvent")
UINavigationController.AudioEvent = Instance.new("BindableEvent")

local ACTION_NAME = "BLIKKFixedUINavigation"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 100
local CHOOSE_ON_FOCUS_SELECTION_MODE = "ChooseOnFocus"
local SELECTION_FILL_TRANSPARENCY = 0.45
local SELECTION_CORNER_RADIUS_PIXELS = 2

local isInitialised = false
local inputManager = nil
local scopesById = {}
local activeScopes = {}
local playerGui = nil
local previousSelectionImageObject = nil
local selectionImageObject = nil
local listSelectionImageObject = nil
local isRepairingSelection = false
local globalConnections = {}

local VALID_AUDIO_ROLES = {
	Activate = true,
	Confirm = true,
	Back = true,
	Denied = true,
	Navigate = true,
	Silent = true,
	SliderStep = true,
}
local AUDIO_DUPLICATE_WINDOW_SECONDS = 0.04

local directionProperties = {
	Up = "NextSelectionUp",
	Down = "NextSelectionDown",
	Left = "NextSelectionLeft",
	Right = "NextSelectionRight",
}

local function topScope()
	return activeScopes[#activeScopes]
end

local function isVisibleWithinRoot(object, root)
	if not object.Parent or not root.Parent then return false end
	if object ~= root and not object:IsDescendantOf(root) then return false end

	local current = object
	while current do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("LayerCollector") and not current.Enabled then return false end
		if current == root then return true end
		current = current.Parent
	end

	return false
end

local function isControlValid(scope, record)
	local object = record.Object
	if not object or not object.Parent or not object:IsA("GuiObject") then return false end
	if not isVisibleWithinRoot(object, scope.Root) then return false end
	if record.IsEnabled and not record.IsEnabled() then return false end
	if not object.Interactable then return false end
	if object:IsA("GuiButton") and not object.Active then return false end
	return true
end

local function emitAudio(role, record)
	if role == "Silent" or not VALID_AUDIO_ROLES[role] then return end
	local now = os.clock()
	if record and record.LastAudioRole == role
		and now - record.LastAudioAt < AUDIO_DUPLICATE_WINDOW_SECONDS then return end
	if record then
		record.LastAudioRole = role
		record.LastAudioAt = now
	end
	UINavigationController.AudioEvent:Fire(role, record and record.Object or nil)
end

local function findRecord(scope, object)
	return object and scope.ControlByObject[object] or nil
end

local function getSelectionIdentity(record)
	return if record.SelectionIdentity ~= nil then record.SelectionIdentity else record.Object
end

local function findRecordByIdentity(scope, identity)
	if identity == nil then return nil end
	for _, record in scope.Controls do
		if getSelectionIdentity(record) == identity then return record end
	end
	return nil
end

local function updateRecordFocusVisual(record)
	if not record.ManagesFocusVisual then return end
	local isVisible = not record.ChoosesOnFocus
		and (not record.IsFocusVisualVisible or record.IsFocusVisualVisible())
	if isVisible then
		if record.Object.SelectionImageObject == listSelectionImageObject then
			record.Object.SelectionImageObject = record.PreviousSelectionImageObject
		end
	else
		record.Object.SelectionImageObject = listSelectionImageObject
	end
end

local function rememberSelection(scope, record)
	updateRecordFocusVisual(record)
	scope.LastSelected = record.Object
	scope.LastSelectionIdentity = getSelectionIdentity(record)
end

local function notifySelectionFocused(scope, record)
	if not record.ChoosesOnFocus then return end
	local identity = getSelectionIdentity(record)
	if scope.LastNotifiedSelectionIdentity == identity then return end
	scope.LastNotifiedSelectionIdentity = identity
	record.OnFocused()
end

local function setSelected(scope, object, playNavigationAudio)
	if scope ~= topScope() then return false end
	local record = findRecord(scope, object)
	if not record or not isControlValid(scope, record) then return false end
	local previousObject = GuiService.SelectedObject
	rememberSelection(scope, record)
	GuiService.SelectedObject = object
	if GuiService.SelectedObject == object then
		notifySelectionFocused(scope, record)
		if playNavigationAudio and previousObject ~= object then emitAudio("Navigate", record) end
	end
	return true
end

local function resolveDefault(scope)
	local candidate = if type(scope.Default) == "function" then scope.Default() else scope.Default
	local record = findRecord(scope, candidate)
	if record and isControlValid(scope, record) then return candidate end

	for _, listedRecord in scope.Controls do
		if isControlValid(scope, listedRecord) then return listedRecord.Object end
	end

	return nil
end

local function candidateScore(origin, candidate, direction)
	local originCenter = origin.AbsolutePosition + origin.AbsoluteSize / 2
	local candidateCenter = candidate.AbsolutePosition + candidate.AbsoluteSize / 2
	local delta = candidateCenter - originCenter
	local primary, secondary

	if direction == "Up" then
		if delta.Y >= -0.5 then return nil end
		primary, secondary = -delta.Y, math.abs(delta.X)
	elseif direction == "Down" then
		if delta.Y <= 0.5 then return nil end
		primary, secondary = delta.Y, math.abs(delta.X)
	elseif direction == "Left" then
		if delta.X >= -0.5 then return nil end
		primary, secondary = -delta.X, math.abs(delta.Y)
	else
		if delta.X <= 0.5 then return nil end
		primary, secondary = delta.X, math.abs(delta.Y)
	end

	return primary + secondary * 2.5
end

local function findDirectional(scope, record, direction)
	local bestObject = nil
	local bestScore = math.huge
	local bestOrder = math.huge

	for order, candidateRecord in scope.Controls do
		if candidateRecord ~= record and isControlValid(scope, candidateRecord) then
			local score = candidateScore(record.Object, candidateRecord.Object, direction)
			if score and (score < bestScore or (score == bestScore and order < bestOrder)) then
				bestObject = candidateRecord.Object
				bestScore = score
				bestOrder = order
			end
		end
	end

	return bestObject
end

local function refreshScope(scope, preferred)
	if not scope.IsActive then return end

	for _, record in scope.Controls do
		if record.Object.Parent then
			for _, propertyName in directionProperties do
				record.Object[propertyName] = nil
			end
		end
	end

	for _, record in scope.Controls do
		if isControlValid(scope, record) then
			for direction, propertyName in directionProperties do
				record.Object[propertyName] = findDirectional(scope, record, direction)
			end
		end
	end

	if scope ~= topScope() then return end
	local current = GuiService.SelectedObject
	local preferredRecord = findRecord(scope, preferred)
	if preferredRecord and isControlValid(scope, preferredRecord) then
		setSelected(scope, preferred)
	elseif current and findRecord(scope, current) and isControlValid(scope, findRecord(scope, current)) then
		setSelected(scope, current)
	elseif scope.LastSelected and findRecord(scope, scope.LastSelected)
		and isControlValid(scope, findRecord(scope, scope.LastSelected)) then
		setSelected(scope, scope.LastSelected)
	else
		local identityRecord = findRecordByIdentity(scope, scope.LastSelectionIdentity)
		if identityRecord and isControlValid(scope, identityRecord) then
			setSelected(scope, identityRecord.Object)
		else
			local defaultObject = resolveDefault(scope)
			if defaultObject then setSelected(scope, defaultObject) else GuiService.SelectedObject = nil end
		end
	end
end

local function updateMenuOwnership()
	local ownsInput = #activeScopes > 0
	local scope = topScope()
	inputManager:SetMenuInputActive(ownsInput, scope and scope.AllowSettingsAction)
	UINavigationController.MenuOwnershipChanged:Fire(ownsInput)

	if scope then
		task.defer(function()
			if scope == topScope() and scope.IsActive then refreshScope(scope) end
		end)
	else
		GuiService.SelectedObject = nil
	end
end

local function removeActiveScope(scope)
	for index = #activeScopes, 1, -1 do
		if activeScopes[index] == scope then
			table.remove(activeScopes, index)
			return
		end
	end
end

local function unregisterControl(scope, object)
	local record = scope.ControlByObject[object]
	if not record then return end
	if record.ManagesFocusVisual and object.SelectionImageObject == listSelectionImageObject then
		object.SelectionImageObject = record.PreviousSelectionImageObject
	end
	for _, connection in record.Connections do connection:Disconnect() end
	table.clear(record.Connections)
	if scope.LastSelected == object or GuiService.SelectedObject == object then
		scope.LastSelectionIdentity = getSelectionIdentity(record)
	end
	scope.ControlByObject[object] = nil
	for index, listedRecord in scope.Controls do
		if listedRecord == record then
			table.remove(scope.Controls, index)
			break
		end
	end
	if scope.LastSelected == object then scope.LastSelected = nil end
	if GuiService.SelectedObject == object then GuiService.SelectedObject = nil end
	if scope.IsActive then task.defer(function() refreshScope(scope) end) end
end

local function registerControl(scope, object, options)
	assert(object and object:IsA("GuiObject"), "UI navigation controls must be GuiObjects")
	if scope.ControlByObject[object] then return scope.ControlByObject[object] end
	options = options or {}
	assert(
		options.SelectionMode == nil or options.SelectionMode == CHOOSE_ON_FOCUS_SELECTION_MODE,
		"Unknown UI navigation selection mode"
	)
	local choosesOnFocus = options.SelectionMode == CHOOSE_ON_FOCUS_SELECTION_MODE
	assert(not choosesOnFocus or type(options.OnFocused) == "function",
		"ChooseOnFocus controls require an OnFocused callback")
	assert(options.IsFocusVisualVisible == nil or type(options.IsFocusVisualVisible) == "function",
		"IsFocusVisualVisible must be a function")
	assert(options.AudioRole == nil or VALID_AUDIO_ROLES[options.AudioRole], "Unknown UI audio role")
	assert(options.AdjustAudioRole == nil or VALID_AUDIO_ROLES[options.AdjustAudioRole],
		"Unknown UI adjustment audio role")
	local managesFocusVisual = choosesOnFocus or options.IsFocusVisualVisible ~= nil
	local record = {
		Object = object,
		Activate = options.Activate,
		Adjust = options.Adjust,
		IsEnabled = options.IsEnabled,
		ChoosesOnFocus = choosesOnFocus,
		OnFocused = options.OnFocused,
		SelectionIdentity = options.SelectionIdentity,
		IsFocusVisualVisible = options.IsFocusVisualVisible,
		ManagesFocusVisual = managesFocusVisual,
		PreviousSelectionImageObject = nil,
		AudioRole = options.AudioRole or "Activate",
		AdjustAudioRole = options.AdjustAudioRole or "Navigate",
		LastAudioRole = nil,
		LastAudioAt = -math.huge,
		Connections = {},
	}
	object.Selectable = true
	if not object:IsA("GuiButton") and not object:IsA("TextBox") then object.Active = true end
	if managesFocusVisual then
		record.PreviousSelectionImageObject = object.SelectionImageObject
		updateRecordFocusVisual(record)
	end
	table.insert(scope.Controls, record)
	scope.ControlByObject[object] = record

	table.insert(record.Connections, object.MouseEnter:Connect(function()
		if not choosesOnFocus and scope.IsActive and scope == topScope() then
			setSelected(scope, object, true)
		end
	end))
	table.insert(record.Connections, object.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if scope.IsActive and scope == topScope() then setSelected(scope, object) end
		end
	end))
	if object:IsA("GuiButton") then
		table.insert(record.Connections, object.Activated:Connect(function()
			-- The application callback was connected before registration and may navigate away.
			-- A control still owned by this scope was valid when Roblox delivered Activated.
			if scope.ControlByObject[object] == record then
				emitAudio(record.AudioRole, record)
			end
		end))
	end
	table.insert(record.Connections, object.Destroying:Connect(function()
		unregisterControl(scope, object)
	end))
	return record
end

local function bindButton(scope, button, callback, options)
	assert(button:IsA("GuiButton"), "BindButton requires a GuiButton")
	button.Activated:Connect(callback)
	options = options or {}
	options.Activate = callback
	return registerControl(scope, button, options)
end

local function setScopeActive(scope, isActive)
	if scope.IsActive == isActive then
		if isActive then refreshScope(scope) end
		return
	end

	if isActive then
		if not scope.Root.Parent then
			warn("[BLIKK UI] Cannot activate navigation scope without a live root: " .. scope.Id)
			return
		end
		scope.IsActive = true
		removeActiveScope(scope)
		table.insert(activeScopes, scope)
	else
		if GuiService.SelectedObject and findRecord(scope, GuiService.SelectedObject) then
			scope.LastSelected = GuiService.SelectedObject
		end
		scope.IsActive = false
		removeActiveScope(scope)
	end

	updateMenuOwnership()
end

local function destroyScope(scope)
	if scopesById[scope.Id] ~= scope then return end
	setScopeActive(scope, false)
	scopesById[scope.Id] = nil
	while scope.Controls[1] do unregisterControl(scope, scope.Controls[1].Object) end
	table.clear(scope.ControlByObject)
end

local function moveSelection(scope, direction)
	local current = GuiService.SelectedObject
	local record = findRecord(scope, current)
	if not record or not isControlValid(scope, record) then
		refreshScope(scope)
		current = GuiService.SelectedObject
		record = findRecord(scope, current)
	end
	if not record then return end

	if record.Adjust and record.Adjust(direction) then
		emitAudio(record.AdjustAudioRole, record)
		task.defer(function()
			if scope == topScope() then refreshScope(scope, record.Object) end
		end)
		return
	end

	local nextObject = current[directionProperties[direction]]
	if nextObject then setSelected(scope, nextObject, true) end
end

local function activateSelection(scope)
	local current = GuiService.SelectedObject
	local record = findRecord(scope, current)
	if not record or not isControlValid(scope, record) then
		refreshScope(scope)
		record = findRecord(scope, GuiService.SelectedObject)
	end
	if not record then return end

	if record.Activate then
		local result = record.Activate()
		emitAudio(if result == false then "Denied" else record.AudioRole, record)
	elseif record.Object:IsA("TextBox") then
		record.Object:CaptureFocus()
	end

	task.defer(function()
		local activeScope = topScope()
		if activeScope then refreshScope(activeScope) end
	end)
end

local function handleNavigationAction(_, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return if topScope() and not UserInputService:GetFocusedTextBox()
			then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end

	local scope = topScope()
	if not scope then return Enum.ContextActionResult.Pass end

	local keyCode = inputObject.KeyCode
	if keyCode == Enum.KeyCode.Up then
		moveSelection(scope, "Up")
	elseif keyCode == Enum.KeyCode.Down then
		moveSelection(scope, "Down")
	elseif keyCode == Enum.KeyCode.Left then
		moveSelection(scope, "Left")
	elseif keyCode == Enum.KeyCode.Right then
		moveSelection(scope, "Right")
	elseif keyCode == Enum.KeyCode.Return or keyCode == Enum.KeyCode.KeypadEnter then
		activateSelection(scope)
	elseif keyCode == Enum.KeyCode.Backspace then
		if scope.Back then
			local result = scope.Back()
			emitAudio(if result == false then "Denied" else "Back", nil)
		end
	end

	return Enum.ContextActionResult.Sink
end

local function updateSelectionVisual()
	if isRepairingSelection then return end
	local scope = topScope()
	local selected = GuiService.SelectedObject
	local record = scope and findRecord(scope, selected) or nil

	if selected and (not record or not isControlValid(scope, record)) then
		isRepairingSelection = true
		GuiService.SelectedObject = nil
		isRepairingSelection = false
		if scope then task.defer(function() refreshScope(scope) end) end
		return
	end

	if scope and record then
		rememberSelection(scope, record)
		notifySelectionFocused(scope, record)
	end
end

function UINavigationController:Init(gameplayInputManager)
	if isInitialised then return end
	isInitialised = true
	inputManager = gameplayInputManager
	playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then error("[BLIKK UI NAV] PlayerGui was unavailable after bootstrap", 0) end
	previousSelectionImageObject = playerGui.SelectionImageObject

	selectionImageObject = Instance.new("Frame")
	selectionImageObject.Name = "BLIKKKeyboardSelection"
	selectionImageObject.Active = false
	selectionImageObject.BackgroundColor3 = UIStyle.Colors.AccentDim
	selectionImageObject.BackgroundTransparency = SELECTION_FILL_TRANSPARENCY
	selectionImageObject.BorderSizePixel = 0
	selectionImageObject.Interactable = false
	selectionImageObject.Selectable = false
	selectionImageObject.Size = UDim2.fromScale(1, 1)
	local selectionCorner = Instance.new("UICorner")
	selectionCorner.CornerRadius = UDim.new(0, SELECTION_CORNER_RADIUS_PIXELS)
	selectionCorner.Parent = selectionImageObject
	playerGui.SelectionImageObject = selectionImageObject

	listSelectionImageObject = Instance.new("Frame")
	listSelectionImageObject.Name = "BLIKKDomainSelection"
	listSelectionImageObject.Active = false
	listSelectionImageObject.BackgroundTransparency = 1
	listSelectionImageObject.BorderSizePixel = 0
	listSelectionImageObject.Interactable = false
	listSelectionImageObject.Selectable = false
	listSelectionImageObject.Size = UDim2.fromScale(1, 1)

	table.insert(globalConnections, GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(updateSelectionVisual))
	table.insert(globalConnections, UserInputService.TextBoxFocused:Connect(function()
		inputManager:SetTextInputActive(true)
	end))
	table.insert(globalConnections, UserInputService.TextBoxFocusReleased:Connect(function()
		task.defer(function()
			inputManager:SetTextInputActive(UserInputService:GetFocusedTextBox() ~= nil)
		end)
	end))
	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		handleNavigationAction,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.Return,
		Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.Backspace
	)
	table.insert(globalConnections, script.Destroying:Connect(function()
		ContextActionService:UnbindAction(ACTION_NAME)
		for _, connection in globalConnections do connection:Disconnect() end
		table.clear(globalConnections)
		for _, scope in scopesById do
			for _, record in scope.Controls do
				for _, connection in record.Connections do connection:Disconnect() end
				table.clear(record.Connections)
				if record.ManagesFocusVisual
					and record.Object.Parent
					and record.Object.SelectionImageObject == listSelectionImageObject then
					record.Object.SelectionImageObject = record.PreviousSelectionImageObject
				end
			end
		end
		table.clear(activeScopes)
		table.clear(scopesById)
		if playerGui and playerGui.SelectionImageObject == selectionImageObject then
			playerGui.SelectionImageObject = previousSelectionImageObject
		end
		if selectionImageObject then selectionImageObject:Destroy() end
		if listSelectionImageObject then listSelectionImageObject:Destroy() end
		UINavigationController.AudioEvent:Destroy()
	end))
end

function UINavigationController:CreateScope(scopeId, config)
	assert(isInitialised, "UINavigationController must be initialised before creating scopes")
	assert(type(scopeId) == "string" and scopeId ~= "", "Navigation scope requires an ID")
	assert(not scopesById[scopeId], "Duplicate UI navigation scope: " .. scopeId)
	assert(config and config.Root and config.Root:IsA("GuiObject"), "Navigation scope requires a GuiObject root")

	local scope = {
		Id = scopeId,
		Root = config.Root,
		Default = config.Default,
		Back = config.Back,
		AllowSettingsAction = config.AllowSettingsAction == true,
		Controls = {},
		ControlByObject = {},
		IsActive = false,
		LastSelected = nil,
		LastSelectionIdentity = nil,
		LastNotifiedSelectionIdentity = nil,
	}
	scopesById[scopeId] = scope

	local handle = {}
	function handle:Register(object, options)
		return registerControl(scope, object, options)
	end
	function handle:BindButton(button, callback, options)
		return bindButton(scope, button, callback, options)
	end
	function handle:Unregister(object)
		unregisterControl(scope, object)
	end
	function handle:SetDefault(defaultObject)
		scope.Default = defaultObject
	end
	function handle:SetBack(callback)
		scope.Back = callback
	end
	function handle:SetActive(isActive)
		setScopeActive(scope, isActive)
	end
	function handle:Refresh(preferred)
		refreshScope(scope, preferred)
	end
	function handle:Select(object)
		return setSelected(scope, object)
	end
	function handle:Destroy()
		destroyScope(scope)
	end
	function handle:IsActive()
		return scope.IsActive
	end

	config.Root.Destroying:Connect(function()
		destroyScope(scope)
	end)
	return handle
end

function UINavigationController:IsMenuActive()
	return #activeScopes > 0
end

function UINavigationController:CanOpenChat()
	return #activeScopes == 0 and UserInputService:GetFocusedTextBox() == nil
end

function UINavigationController:EmitAudioEvent(role, object)
	if not VALID_AUDIO_ROLES[role] then return false end
	local scope = topScope()
	local record = object and scope and findRecord(scope, object) or nil
	if object and (not record or not isControlValid(scope, record)) then return false end
	emitAudio(role, record)
	return true
end

return UINavigationController
