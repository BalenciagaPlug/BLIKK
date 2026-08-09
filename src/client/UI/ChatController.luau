local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local UIStyle = require(script.Parent.UIStyle)
local UINavigationController = require(script.Parent.UINavigationController)
local SettingsConfig = require(ReplicatedStorage.Shared.Settings.SettingsConfig)

local ChatController = {}
local player = Players.LocalPlayer
local inputManager = nil
local gui = nil
local panel = nil
local messageList = nil
local inputBox = nil
local channelLabel = nil
local context = "Hidden"
local collapsed = true
local messageCount = 0
local historyGeneration = 0
local isFollowingNewest = true
local isPointerOverMessages = false
local sessionKey = nil
local activeChannelName = nil
local collapseButton = nil
local setCollapsed
local CHAT_WHEEL_OWNER = "ChatHistoryScroll"

local function addStroke(instance, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Parent = instance
end

local function setPointerOverMessages(isOver)
	isPointerOverMessages = isOver == true
	if inputManager then inputManager:SetMouseWheelBlocked(CHAT_WHEEL_OWNER, isPointerOverMessages) end
end

local function applySettings()
	if not gui then return end
	gui.Enabled = context ~= "Hidden" and SessionSettings:Get("ChatVisible")
	if not gui.Enabled then setPointerOverMessages(false) end
	panel.BackgroundTransparency = SessionSettings:Get("ChatOpacity")
	local scale = panel:FindFirstChildOfClass("UIScale")
	if scale then scale.Scale = SessionSettings:Get("ChatScale") end
end

local function getMessageLabels()
	local messages = {}
	if not messageList then return messages end
	for _, child in messageList:GetChildren() do
		if child:IsA("TextLabel") then table.insert(messages, child) end
	end
	table.sort(messages, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	return messages
end

local function maximumCanvasY()
	if not messageList then return 0 end
	return math.max(0, messageList.AbsoluteCanvasSize.Y - messageList.AbsoluteSize.Y)
end

local function updateFollowState()
	if not messageList then return end
	isFollowingNewest = messageList.CanvasPosition.Y
		>= maximumCanvasY() - SettingsConfig.Chat.AutoFollowThresholdPixels
end

local function updateMessageLayout(shouldFollow, previousCanvasY, removedHeight)
	local messages = getMessageLabels()
	for _, message in messages do message.Visible = true end
	local expectedGeneration = historyGeneration
	task.defer(function()
		if not messageList or expectedGeneration ~= historyGeneration then return end
		if shouldFollow then
			messageList.CanvasPosition = Vector2.new(0, maximumCanvasY())
			isFollowingNewest = true
		elseif removedHeight and removedHeight > 0 then
			messageList.CanvasPosition = Vector2.new(
				0,
				math.clamp((previousCanvasY or 0) - removedHeight, 0, maximumCanvasY())
			)
			updateFollowState()
		end
	end)
end

local function clearMessages()
	historyGeneration += 1
	for _, message in getMessageLabels() do message:Destroy() end
	messageCount = 0
	isFollowingNewest = true
	if messageList then messageList.CanvasPosition = Vector2.zero end
end

local function appendMessage(text, sourceName, isSystem)
	if not messageList then return end
	local shouldFollow = isFollowingNewest
	local previousCanvasY = messageList.CanvasPosition.Y
	messageCount += 1
	local timestamp = if SessionSettings:Get("ChatTimestamps") then os.date("[%H:%M] ") else ""
	local label = Instance.new("TextLabel")
	label.Name = "Message" .. messageCount
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = UIStyle.Fonts.Primary
	label.LayoutOrder = messageCount
	label.Size = UDim2.new(1, -8, 0, 18)
	label.Text = timestamp .. (isSystem and "[SYSTEM] " or "[" .. sourceName .. "] ") .. text
	label.TextColor3 = if isSystem then UIStyle.Colors.Accent else UIStyle.Colors.Text
	label.TextSize = 11
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = messageList
	local messages = getMessageLabels()
	local removedHeight = 0
	if #messages > SettingsConfig.Chat.MaximumStoredMessages then
		removedHeight = messages[1].AbsoluteSize.Y + SettingsConfig.Chat.MessagePaddingPixels
		messages[1]:Destroy()
	end
	updateMessageLayout(shouldFollow, previousCanvasY, removedHeight)
end

local function getActiveChannel()
	local channels = TextChatService:FindFirstChild("TextChannels")
	local channelName = activeChannelName or "RBXGeneral"
	local channel = channels and channels:FindFirstChild(channelName)
	return if channel and channel:IsA("TextChannel") then channel else nil
end

local function sendCurrentMessage()
	local text = inputBox.Text:match("^%s*(.-)%s*$")
	inputBox.Text = ""
	if text == "" then return end
	local channel = getActiveChannel()
	if channel then
		local success = pcall(function() channel:SendAsync(text) end)
		if not success then appendMessage("MESSAGE COULD NOT BE SENT.", "SYSTEM", true) end
	else
		appendMessage("THE ACTIVE TEXT CHANNEL IS UNAVAILABLE.", "SYSTEM", true)
	end
end

local function hasMessageText()
	return inputBox.Text:match("%S") ~= nil
end

local function closeChat()
	inputBox.Text = ""
	setCollapsed(true, false)
end

local function openChat()
	if not UINavigationController:CanOpenChat() then return false end
	setCollapsed(false, true)
	return true
end

setCollapsed = function(isCollapsed, focusInput)
	collapsed = isCollapsed
	if collapsed and inputBox:IsFocused() then inputBox:ReleaseFocus(false) end
	messageList.Visible = true
	inputBox.Visible = not collapsed
	channelLabel.Visible = not collapsed
	panel.Size = if collapsed
		then UDim2.fromOffset(SettingsConfig.Chat.CollapsedWidthPixels, SettingsConfig.Chat.CollapsedHeightPixels)
		else UDim2.fromOffset(SettingsConfig.Chat.ExpandedWidthPixels, SettingsConfig.Chat.ExpandedHeightPixels)
	collapseButton.Text = if collapsed then "BLIKK CHAT // ENTER" else "COLLAPSE"
	collapseButton.Position = if collapsed then UDim2.fromOffset(0, 0) else UDim2.new(1, -82, 0, 5)
	collapseButton.Size = if collapsed then UDim2.new(1, 0, 0, 28) else UDim2.fromOffset(72, 25)
	messageList.Position = if collapsed then UDim2.fromOffset(8, 32) else UDim2.fromOffset(8, 36)
	messageList.Size = if collapsed then UDim2.new(1, -16, 1, -40) else UDim2.new(1, -16, 1, -82)
	messageList.ScrollBarThickness = if collapsed then 0 else 4
	updateMessageLayout(isFollowingNewest)
	if focusInput and not collapsed then task.defer(function() if inputBox.Visible then inputBox:CaptureFocus() end end) end
end

local function createInterface()
	gui = Instance.new("ScreenGui")
	gui.Name = "BLIKKChat"
	gui.DisplayOrder = 15
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then error("[BLIKK CHAT] PlayerGui was unavailable after bootstrap", 0) end
	gui.Parent = playerGui
	panel = Instance.new("Frame")
	panel.Name = "ChatPanel"
	panel.BackgroundColor3 = UIStyle.Colors.Panel
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -18, 0, 18)
	panel.Size = UDim2.fromOffset(150, 34)
	panel.Parent = gui
	addStroke(panel, UIStyle.Colors.Edge)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	channelLabel = Instance.new("TextLabel")
	channelLabel.BackgroundTransparency = 1
	channelLabel.Font = UIStyle.Fonts.Strong
	channelLabel.Position = UDim2.fromOffset(10, 5)
	channelLabel.Size = UDim2.new(1, -80, 0, 26)
	channelLabel.Text = "ALL // SYSTEM"
	channelLabel.TextColor3 = UIStyle.Colors.Accent
	channelLabel.TextSize = 12
	channelLabel.TextXAlignment = Enum.TextXAlignment.Left
	channelLabel.Parent = panel
	collapseButton = Instance.new("TextButton")
	collapseButton.BackgroundColor3 = UIStyle.Colors.Raised
	collapseButton.Font = UIStyle.Fonts.Primary
	collapseButton.Text = "BLIKK CHAT // ENTER"
	collapseButton.TextColor3 = UIStyle.Colors.TextMuted
	collapseButton.TextSize = 10
	collapseButton.Parent = panel
	messageList = Instance.new("ScrollingFrame")
	messageList.Name = "Messages"
	messageList.BackgroundColor3 = UIStyle.Colors.Backdrop
	messageList.BackgroundTransparency = 0.25
	messageList.BorderSizePixel = 0
	messageList.Position = UDim2.fromOffset(8, 36)
	messageList.Size = UDim2.new(1, -16, 1, -82)
	messageList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	messageList.CanvasSize = UDim2.new()
	messageList.Active = true
	messageList.ElasticBehavior = Enum.ElasticBehavior.Never
	messageList.ScrollingDirection = Enum.ScrollingDirection.Y
	messageList.ScrollBarThickness = 4
	messageList.ScrollBarImageColor3 = UIStyle.Colors.AccentDim
	messageList.Visible = false
	messageList.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = messageList
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, SettingsConfig.Chat.MessagePaddingPixels)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = messageList
	messageList:GetPropertyChangedSignal("CanvasPosition"):Connect(updateFollowState)
	messageList.MouseEnter:Connect(function() setPointerOverMessages(true) end)
	messageList.MouseLeave:Connect(function() setPointerOverMessages(false) end)
	inputBox = Instance.new("TextBox")
	inputBox.Name = "Input"
	inputBox.BackgroundColor3 = UIStyle.Colors.Raised
	inputBox.ClearTextOnFocus = false
	inputBox.Font = UIStyle.Fonts.Primary
	inputBox.PlaceholderText = "TYPE A FILTERED MESSAGE..."
	inputBox.Position = UDim2.new(0, 8, 1, -39)
	inputBox.Size = UDim2.new(1, -16, 0, 31)
	inputBox.Text = ""
	inputBox.TextColor3 = UIStyle.Colors.Text
	inputBox.TextSize = 11
	inputBox.Visible = false
	inputBox.Parent = panel
	addStroke(inputBox, UIStyle.Colors.EdgeDark)
	inputBox.Focused:Connect(function() inputManager:SetTextInputActive(true) end)
	inputBox.FocusLost:Connect(function(enterPressed)
		inputManager:SetTextInputActive(false)
		if enterPressed then
			if hasMessageText() then sendCurrentMessage() end
			closeChat()
		end
	end)
	collapseButton.Activated:Connect(function()
		setCollapsed(not collapsed, collapsed)
	end)
	setCollapsed(true, false)
end

function ChatController:Init(gameplayInputManager)
	if gui then return end
	inputManager = gameplayInputManager
	if TextChatService:FindFirstChild("ChatWindowConfiguration") then TextChatService.ChatWindowConfiguration.Enabled = false end
	if TextChatService:FindFirstChild("ChatInputBarConfiguration") then TextChatService.ChatInputBarConfiguration.Enabled = false end
	createInterface()
	TextChatService.MessageReceived:Connect(function(message)
		if context == "Hidden" or not sessionKey then return end
		local messageChannel = message.TextChannel
		local expectedChannelName = activeChannelName or "RBXGeneral"
		if not messageChannel or messageChannel.Name ~= expectedChannelName then return end
		local source = message.TextSource
		local sourcePlayer = source and Players:GetPlayerByUserId(source.UserId)
		local sourceName = sourcePlayer and sourcePlayer.DisplayName or (source and source.Name or "SYSTEM")
		appendMessage(message.Text, sourceName, source == nil)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gui.Enabled then return end
		local focusedTextBox = UserInputService:GetFocusedTextBox()
		if input.KeyCode == Enum.KeyCode.Return then
			if focusedTextBox and focusedTextBox ~= inputBox then return end
			if collapsed then
				if gameProcessed and focusedTextBox then return end
				openChat()
			elseif inputBox:IsFocused() then
				inputBox:ReleaseFocus(true)
			elseif UINavigationController:CanOpenChat() then
				inputBox:CaptureFocus()
			end
		elseif input.KeyCode == Enum.KeyCode.Backspace
			and inputBox:IsFocused()
			and inputBox.Text == ""
		then
			closeChat()
		end
	end)
	inputManager.ActionBegan.Event:Connect(function(action)
		if action == "Chat" and collapsed then openChat() end
	end)
	UINavigationController.MenuOwnershipChanged.Event:Connect(function(menuOwnsInput)
		if menuOwnsInput and not collapsed then closeChat() end
	end)
	SessionSettings.Changed.Event:Connect(function(key)
		if key == "ChatVisible" or key == "ChatOpacity" or key == "ChatScale" then applySettings() end
	end)
	script.Destroying:Connect(function() setPointerOverMessages(false) end)
	applySettings()
end

function ChatController:SetContext(nextContext, nextSessionKey, nextChannelName)
	local sessionChanged = nextSessionKey ~= sessionKey
	if nextContext == "Hidden" then nextSessionKey = nil; nextChannelName = nil end
	if nextSessionKey == sessionKey and nextChannelName == nil then nextChannelName = activeChannelName end
	context = nextContext
	if nextContext == "Hidden" then setPointerOverMessages(false) end
	if nextSessionKey ~= sessionKey then sessionChanged = true end
	sessionKey = nextSessionKey
	activeChannelName = nextChannelName
	if inputBox and inputBox:IsFocused() then inputBox:ReleaseFocus(false) end
	if inputBox then inputBox.Text = ""; setCollapsed(true, false) end
	if sessionChanged then
		clearMessages()
		if sessionKey then
			appendMessage("BLIKK CHAT USES ROBLOX TEXT FILTERING AND PRIVACY CONTROLS.", "SYSTEM", true)
		end
	end
	if channelLabel then channelLabel.Text = if context == "Lobby" then "LOBBY // SYSTEM" elseif context == "Training" then "ALL // SYSTEM" else "SYSTEM" end
	applySettings()
end

return ChatController
