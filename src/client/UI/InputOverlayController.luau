local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BindingState = require(script.Parent.Parent.Input.BindingState)
local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local UIStyle = require(script.Parent.UIStyle)

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before the input overlay")
local ActionCatalogue = require(Shared.Input.ActionCatalogue)

local InputOverlayController = {}

local colors = UIStyle.Colors
local style = UIStyle.InputOverlay
local isInitialised = false
local screenGui = nil
local root = nil
local visualsByToken = {}
local pressedTokens = {}
local rootScale = nil

local function shouldShowOverlay()
	return SessionSettings:Get("InputOverlayVisible")
		and not (UserInputService.TouchEnabled
			and UserInputService.PreferredInput == Enum.PreferredInput.Touch)
end

local keyboardKeys = {
	{ Token = "KeyCode.One", Label = "1", X = 48, Y = 0 },
	{ Token = "KeyCode.Two", Label = "2", X = 92, Y = 0 },
	{ Token = "KeyCode.Three", Label = "3", X = 136, Y = 0 },
	{ Token = "KeyCode.Four", Label = "4", X = 180, Y = 0 },
	{ Token = "KeyCode.Five", Label = "5", X = 224, Y = 0 },
	{ Token = "KeyCode.Q", Label = "Q", X = 58, Y = 40 },
	{ Token = "KeyCode.W", Label = "W", X = 102, Y = 40 },
	{ Token = "KeyCode.E", Label = "E", X = 146, Y = 40 },
	{ Token = "KeyCode.R", Label = "R", X = 190, Y = 40 },
	{ Token = "KeyCode.LeftShift", Label = "SHIFT", X = 0, Y = 80, Width = 58 },
	{ Token = "KeyCode.A", Label = "A", X = 64, Y = 80 },
	{ Token = "KeyCode.S", Label = "S", X = 108, Y = 80 },
	{ Token = "KeyCode.D", Label = "D", X = 152, Y = 80 },
	{ Token = "KeyCode.LeftControl", Label = "CTRL", X = 0, Y = 120, Width = 58 },
	{ Token = "KeyCode.Space", Label = "SPACE", X = 64, Y = 120, Width = 132 },
}

local mouseTokens = {
	MouseButton1 = true,
	MouseButton2 = true,
	MouseButton3 = true,
	MouseWheelUp = true,
	MouseWheelDown = true,
}

local physicalTokens = {}
for _, key in keyboardKeys do
	physicalTokens[key.Token] = true
end
for token in mouseTokens do
	physicalTokens[token] = true
end

local function addCorner(instance, radiusPixels)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radiusPixels)
	corner.Parent = instance
end

local function addStroke(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = instance
end

local function createLabel(parent, name, text, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = UIStyle.Fonts.Primary
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextStrokeColor3 = colors.Backdrop
	label.TextStrokeTransparency = 0.35
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local function getActionForToken(token)
	for _, definition in ActionCatalogue.Ordered do
		if definition.Group ~= "Interface" then
			local bindings = BindingState:GetActionBindings(definition.Id)
			if bindings.Primary == token or bindings.Secondary == token then
				return definition
			end
		end
	end

	return nil
end

local function getActionCaption(token)
	local definition = getActionForToken(token)
	return if definition then string.upper(definition.Name) else ""
end

local function updateVisual(token)
	local visual = visualsByToken[token]
	if not visual then
		return
	end

	local pressed = pressedTokens[token] == true
	visual.Frame.BackgroundColor3 = if pressed then colors.AccentDim else visual.InactiveColor
	visual.Frame.BackgroundTransparency = if pressed
		then style.ActiveTransparency
		else math.clamp(1 - SessionSettings:Get("InputOverlayOpacity"), 0.4, 0.82)
	visual.Binding.TextColor3 = if pressed then colors.AccentBright else colors.Text
	if visual.Action then
		visual.Action.TextColor3 = if pressed then colors.Text else colors.TextMuted
	end
end

local function registerVisual(token, frame, bindingLabel, actionLabel, inactiveColor)
	visualsByToken[token] = {
		Frame = frame,
		Binding = bindingLabel,
		Action = actionLabel,
		InactiveColor = inactiveColor or colors.Panel,
	}
	updateVisual(token)
end

local function createKeyboardKey(parent, key)
	local width = key.Width or style.StandardKeySize.X
	local frame = Instance.new("Frame")
	frame.Name = key.Token
	frame.BackgroundColor3 = colors.Panel
	frame.Position = UDim2.fromOffset(key.X, key.Y)
	frame.Size = UDim2.fromOffset(width, style.StandardKeySize.Y)
	frame.Parent = parent
	addCorner(frame, 2)
	addStroke(frame, colors.Edge, 1)

	local binding = createLabel(
		frame,
		"Binding",
		key.Label,
		UDim2.fromOffset(3, 2),
		UDim2.new(1, -6, 0, 21),
		if width > style.StandardKeySize.X then 12 else 15,
		colors.Text
	)
	local action = createLabel(
		frame,
		"Action",
		getActionCaption(key.Token),
		UDim2.fromOffset(3, 23),
		UDim2.new(1, -6, 0, 10),
		6,
		colors.TextMuted
	)
	registerVisual(key.Token, frame, binding, action)
end

local function createMouseZone(parent, token, name, labelText, position, size, cornerRadius, showAction)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = colors.PanelLight
	frame.Position = position
	frame.Size = size
	frame.Parent = parent
	if cornerRadius then
		addCorner(frame, cornerRadius)
	end
	addStroke(frame, colors.EdgeDark, 1)

	local binding = createLabel(
		frame,
		"Binding",
		labelText,
		UDim2.fromOffset(2, if showAction == false then 1 else 4),
		UDim2.new(1, -4, 0, if showAction == false then size.Y.Offset - 2 else 18),
		if showAction == false then 7 else 10,
		colors.Text
	)
	local action = nil
	if showAction ~= false then
		action = createLabel(
			frame,
			"Action",
			getActionCaption(token),
			UDim2.fromOffset(2, 22),
			UDim2.new(1, -4, 0, 9),
			6,
			colors.TextMuted
		)
	end
	registerVisual(token, frame, binding, action, colors.PanelLight)
end

local function createMouse(parent)
	local body = Instance.new("Frame")
	body.Name = "Mouse"
	body.BackgroundColor3 = colors.Panel
	body.BackgroundTransparency = 0.25
	body.ClipsDescendants = true
	body.Position = UDim2.fromOffset(style.MouseOffsetPixels.X, style.MouseOffsetPixels.Y)
	body.Size = UDim2.fromOffset(style.MouseSize.X, style.MouseSize.Y)
	body.Parent = parent
	addCorner(body, 31)
	addStroke(body, colors.Metal, 2)

	local bodyGradient = Instance.new("UIGradient")
	bodyGradient.Color = ColorSequence.new(colors.Raised, colors.Backdrop)
	bodyGradient.Rotation = 90
	bodyGradient.Parent = body

	local deck = Instance.new("Frame")
	deck.Name = "ButtonDeck"
	deck.BackgroundTransparency = 1
	deck.ClipsDescendants = true
	deck.Position = UDim2.fromOffset(10, 8)
	deck.Size = UDim2.fromOffset(90, 74)
	deck.Parent = body
	addCorner(deck, 13)
	createMouseZone(deck, "MouseButton1", "LeftButton", "LMB", UDim2.fromOffset(0, 0), UDim2.fromOffset(34, 54), 10)
	createMouseZone(deck, "MouseButton2", "RightButton", "RMB", UDim2.fromOffset(56, 0), UDim2.fromOffset(34, 54), 10)
	createMouseZone(deck, "MouseWheelUp", "WheelUp", "UP", UDim2.fromOffset(36, 3), UDim2.fromOffset(18, 17), 5, false)
	createMouseZone(deck, "MouseButton3", "MiddleButton", "MMB", UDim2.fromOffset(36, 22), UDim2.fromOffset(18, 27), 5, false)
	createMouseZone(deck, "MouseWheelDown", "WheelDown", "DN", UDim2.fromOffset(36, 51), UDim2.fromOffset(18, 17), 5, false)

	local palm = Instance.new("Frame")
	palm.Name = "PalmPlate"
	palm.BackgroundColor3 = colors.PanelLight
	palm.BackgroundTransparency = 0.55
	palm.BorderSizePixel = 0
	palm.Position = UDim2.fromOffset(9, 84)
	palm.Size = UDim2.fromOffset(92, 46)
	palm.Parent = body
	addCorner(palm, 20)

	createLabel(body, "Device", "MOUSE", UDim2.fromOffset(28, 118), UDim2.fromOffset(54, 13), 7, colors.TextMuted)
end

local function createOverflow(parent)
	local items = {}
	local seen = {}

	for _, definition in ActionCatalogue.Ordered do
		if definition.Group ~= "Interface" then
			for _, token in BindingState:GetActionBindings(definition.Id) do
				if token and not physicalTokens[token] and not seen[token] then
					seen[token] = true
					table.insert(items, { Token = token, Action = definition.Name })
				end
			end
		end
	end

	if #items == 0 then
		return
	end

	createLabel(parent, "OverflowTitle", "CUSTOM", UDim2.fromOffset(0, 168), UDim2.fromOffset(54, 12), 7, colors.Blood)
	for index, item in items do
		local width = style.OverflowKeySize.X
		local column = (index - 1) % style.OverflowColumns
		local row = math.floor((index - 1) / style.OverflowColumns)
		local frame = Instance.new("Frame")
		frame.Name = item.Token
		frame.BackgroundColor3 = colors.Panel
		frame.Position = UDim2.fromOffset(58 + column * (width + 3), 164 + row * 29)
		frame.Size = UDim2.fromOffset(width, style.OverflowKeySize.Y)
		frame.Parent = parent
		addCorner(frame, 2)
		addStroke(frame, colors.Blood, 1)
		local binding = createLabel(
			frame,
			"Binding",
			ActionCatalogue.GetDisplayName(item.Token),
			UDim2.fromOffset(2, 1),
			UDim2.new(1, -4, 0, 14),
			8,
			colors.Text
		)
		local action = createLabel(
			frame,
			"Action",
			string.upper(item.Action),
			UDim2.fromOffset(2, 14),
			UDim2.new(1, -4, 0, 9),
			6,
			colors.TextMuted
		)
		registerVisual(item.Token, frame, binding, action)
	end
end

local function rebuild()
	for _, child in root:GetChildren() do
		child:Destroy()
	end
	table.clear(visualsByToken)

	local keyboard = Instance.new("Frame")
	keyboard.Name = "Keyboard"
	keyboard.BackgroundTransparency = 1
	keyboard.Position = UDim2.fromOffset(0, 0)
	keyboard.Size = UDim2.fromOffset(style.KeyboardSize.X, style.KeyboardSize.Y)
	keyboard.Parent = root
	for _, key in keyboardKeys do
		createKeyboardKey(keyboard, key)
	end

	createMouse(root)
	createOverflow(root)
end

function InputOverlayController:Init(inputManager)
	if isInitialised then
		return
	end

	isInitialised = true
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then error("[BLIKK INPUT OVERLAY] PlayerGui was unavailable after bootstrap", 0) end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BLIKKInputOverlay"
	screenGui.DisplayOrder = UIStyle.DisplayOrders.Hud + 1
	screenGui.IgnoreGuiInset = false
	screenGui.ResetOnSpawn = false
	root = Instance.new("Frame")
	root.Name = "InputOverlay"
	root.BackgroundTransparency = 1
	root.Position = UDim2.new(0, style.ScreenOffsetPixels.X, 1, -style.ScreenOffsetPixels.Y)
	root.Size = UDim2.fromOffset(style.TotalSize.X, style.TotalSize.Y)
	root.Parent = screenGui
	rootScale = Instance.new("UIScale")
	rootScale.Scale = SessionSettings:Get("UIScale") * SessionSettings:Get("InputOverlayScale")
	rootScale.Parent = root
	screenGui.Enabled = shouldShowOverlay()
	screenGui.Parent = playerGui
	rebuild()

	BindingState.Changed.Event:Connect(rebuild)
	inputManager.InputBegan.Event:Connect(function(token)
		pressedTokens[token] = true
		updateVisual(token)
	end)
	inputManager.InputEnded.Event:Connect(function(token)
		pressedTokens[token] = nil
		updateVisual(token)
	end)
	SessionSettings.Changed.Event:Connect(function(key, value)
		if key == "InputOverlayVisible" then
			screenGui.Enabled = shouldShowOverlay()
		elseif key == "InputOverlayOpacity" then
			for token in visualsByToken do
				updateVisual(token)
			end
		elseif key == "UIScale" or key == "InputOverlayScale" then
			rootScale.Scale = SessionSettings:Get("UIScale") * SessionSettings:Get("InputOverlayScale")
		end
	end)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		screenGui.Enabled = shouldShowOverlay()
	end)
end

return InputOverlayController
