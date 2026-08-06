local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local UIStyle = require(script.Parent.UIStyle)

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
local MAX_VISIBLE_MESSAGES = 80
local collapseButton = nil
local setCollapsed

local function addStroke(instance, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Parent = instance
end

local function applySettings()
	if not gui then return end
	gui.Enabled = context ~= "Hidden" and SessionSettings:Get("ChatVisible")
	panel.BackgroundTransparency = SessionSettings:Get("ChatOpacity")
	local scale = panel:FindFirstChildOfClass("UIScale")
	if scale then scale.Scale = SessionSettings:Get("ChatScale") end
end

local function appendMessage(text, sourceName, isSystem)
	if not messageList then return end
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
	local messages = {}
	for _, child in messageList:GetChildren() do if child:IsA("TextLabel") then table.insert(messages, child) end end
	if #messages > MAX_VISIBLE_MESSAGES then
		table.sort(messages, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		messages[1]:Destroy()
	end
	task.defer(function() messageList.CanvasPosition = Vector2.new(0, math.max(0, messageList.AbsoluteCanvasSize.Y - messageList.AbsoluteSize.Y)) end)
end

local function sendCurrentMessage()
	local text = inputBox.Text:match("^%s*(.-)%s*$")
	inputBox.Text = ""
	if text == "" then return end
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		local success = pcall(function() general:SendAsync(text) end)
		if not success then appendMessage("MESSAGE COULD NOT BE SENT.", "SYSTEM", true) end
	else
		appendMessage("TEXTCHATSERVICE GENERAL CHANNEL IS UNAVAILABLE.", "SYSTEM", true)
	end
end

local function hasMessageText()
	return inputBox.Text:match("%S") ~= nil
end

local function closeChat()
	inputBox.Text = ""
	setCollapsed(true, false)
end

setCollapsed = function(isCollapsed, focusInput)
	collapsed = isCollapsed
	if collapsed and inputBox:IsFocused() then inputBox:ReleaseFocus(false) end
	messageList.Visible = not collapsed
	inputBox.Visible = not collapsed
	channelLabel.Visible = not collapsed
	panel.Size = if collapsed then UDim2.fromOffset(150, 34) else UDim2.fromOffset(430, 245)
	collapseButton.Text = if collapsed then "BLIKK CHAT // ENTER" else "COLLAPSE"
	collapseButton.Position = if collapsed then UDim2.fromOffset(0, 0) else UDim2.new(1, -82, 0, 5)
	collapseButton.Size = if collapsed then UDim2.fromScale(1, 1) else UDim2.fromOffset(72, 25)
	if focusInput and not collapsed then task.defer(function() if inputBox.Visible then inputBox:CaptureFocus() end end) end
end

local function createInterface()
	gui = Instance.new("ScreenGui")
	gui.Name = "BLIKKChat"
	gui.DisplayOrder = 15
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
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
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = messageList
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
		local source = message.TextSource
		appendMessage(message.Text, source and source.Name or "SYSTEM", source == nil)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if not gui.Enabled then return end
		if input.KeyCode == Enum.KeyCode.Return then
			if collapsed then
				setCollapsed(false, true)
			elseif inputBox:IsFocused() then
				inputBox:ReleaseFocus(true)
			else
				inputBox:CaptureFocus()
			end
		elseif input.KeyCode == Enum.KeyCode.Backspace
			and inputBox:IsFocused()
			and inputBox.Text == ""
		then
			closeChat()
		end
	end)
	SessionSettings.Changed.Event:Connect(function(key)
		if key == "ChatVisible" or key == "ChatOpacity" or key == "ChatScale" then applySettings() end
	end)
	appendMessage("BLIKK CHAT USES ROBLOX TEXT FILTERING AND PRIVACY CONTROLS.", "SYSTEM", true)
	applySettings()
end

function ChatController:SetContext(nextContext)
	context = nextContext
	if inputBox and inputBox:IsFocused() then inputBox:ReleaseFocus(false) end
	if inputBox then inputBox.Text = ""; setCollapsed(true, false) end
	if channelLabel then channelLabel.Text = if context == "Lobby" then "LOBBY // SYSTEM" elseif context == "Training" then "ALL // SYSTEM" else "SYSTEM" end
	applySettings()
end

return ChatController
