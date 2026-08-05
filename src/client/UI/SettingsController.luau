local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraSettings = require(script.Parent.Parent.Camera.CameraSettings)
local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local UIStyle = require(script.Parent.UIStyle)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraConfig = require(Shared.Camera.CameraConfig)
local SettingsConfig = require(Shared.Settings.SettingsConfig)

local SettingsController = {}

local player = Players.LocalPlayer
local colors = UIStyle.Colors
local isInitialised = false
local isOpen = false
local inputManager = nil
local gameplayCamera = nil
local playerControls = nil
local panel = nil
local panelScale = nil
local backdrop = nil
local gearButton = nil
local activeSlider = nil
local sliderControls = {}
local toggleControls = {}
local tabButtons = {}
local tabPages = {}

local INPUT_BLOCK_ACTION = "BLIKKSettingsInputBlock"
local INPUT_BLOCK_PRIORITY = 3000

local cameraSliders = {
	{
		Key = "FieldOfViewDegrees",
		Label = "FIELD OF VIEW",
		Decimals = 0,
		Suffix = " DEG",
	},
	{
		Key = "CameraDistanceStuds",
		Label = "CAMERA DISTANCE",
		Decimals = 1,
		Suffix = " ST",
	},
	{
		Key = "CameraHeightAboveRootStuds",
		Label = "CAMERA HEIGHT / FRAMING",
		Decimals = 2,
		Suffix = " ST",
	},
	{
		Key = "CameraRightOffsetStuds",
		Label = "HORIZONTAL SHOULDER",
		Decimals = 2,
		Suffix = " ST",
	},
	{
		Key = "MouseSensitivityDegreesPerPixel",
		Label = "MOUSE SENSITIVITY",
		Decimals = 3,
		Suffix = "",
		AllowNumericEntry = true,
	},
}

local soundSliders = {
	{
		Key = "MasterVolume",
		Label = "MASTER VOLUME",
		Decimals = 0,
		Suffix = "%",
		DisplayMultiplier = 100,
	},
	{
		Key = "MusicVolume",
		Label = "BLIKK MUSIC",
		Decimals = 0,
		Suffix = "%",
		DisplayMultiplier = 100,
	},
	{
		Key = "SoundEffectsVolume",
		Label = "BLIKK SOUND EFFECTS",
		Decimals = 0,
		Suffix = "%",
		DisplayMultiplier = 100,
	},
}

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

local function createLabel(parent, name, text, position, size, textSize, color, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = UIStyle.Fonts.Primary
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createButton(parent, name, text, position, size)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundColor3 = colors.Raised
	button.Position = position
	button.Size = size
	button.Font = UIStyle.Fonts.Primary
	button.Text = text
	button.TextColor3 = colors.Text
	button.TextSize = 13
	button.Parent = parent
	addCorner(button, 2)
	addStroke(button, colors.Edge, 1)
	return button
end

local function formatValue(control, value)
	local displayValue = value * (control.DisplayMultiplier or 1)
	return string.format("%." .. control.Decimals .. "f%s", displayValue, control.Suffix)
end

local function updateSliderVisual(control)
	local range = control.Range
	local value = control.Source:Get(control.Key)
	local alpha

	if range.Scale == "Logarithmic" then
		alpha = math.log(value / range.Minimum) / math.log(range.Maximum / range.Minimum)
	else
		alpha = (value - range.Minimum) / (range.Maximum - range.Minimum)
	end

	alpha = math.clamp(alpha, 0, 1)

	control.Fill.Size = UDim2.fromScale(alpha, 1)
	control.Knob.Position = UDim2.fromScale(alpha, 0.5)
	control.ValueLabel.Text = formatValue(control, value)
end

local function setSliderFromScreenX(control, screenX)
	local width = control.HitArea.AbsoluteSize.X

	if width <= 0 then
		return
	end

	local alpha = math.clamp(
		(screenX - control.HitArea.AbsolutePosition.X) / width,
		0,
		1
	)
	local range = control.Range
	local rawValue

	if range.Scale == "Logarithmic" then
		rawValue = range.Minimum * (range.Maximum / range.Minimum) ^ alpha
	else
		rawValue = range.Minimum + (range.Maximum - range.Minimum) * alpha
	end
	local value = range.Minimum
		+ math.round((rawValue - range.Minimum) / range.Step) * range.Step
	value = math.clamp(value, range.Minimum, range.Maximum)

	control.Source:Set(control.Key, value)
	updateSliderVisual(control)
end

local function updateToggleVisual(control)
	local enabled = control.Source:Get(control.Key)
	control.Button.Text = if enabled then "ON" else "OFF"
	control.Button.TextColor3 = if enabled then colors.Accent else colors.TextMuted
	control.Button.BackgroundColor3 = if enabled then colors.AccentDim else colors.Raised
end

local function createSectionHeader(parent, title, subtitle)
	createLabel(
		parent,
		"SectionTitle",
		title,
		UDim2.fromOffset(16, 12),
		UDim2.new(1, -32, 0, 26),
		18,
		colors.Text
	)
	createLabel(
		parent,
		"SectionSubtitle",
		subtitle,
		UDim2.fromOffset(16, 38),
		UDim2.new(1, -32, 0, 18),
		10,
		colors.TextMuted
	)
end

local function createSlider(parent, definition, rowIndex, source, ranges)
	local row = Instance.new("Frame")
	row.Name = definition.Key
	row.BackgroundColor3 = colors.Backdrop
	row.BackgroundTransparency = 0.24
	row.Position = UDim2.fromOffset(16, 68 + (rowIndex - 1) * 61)
	row.Size = UDim2.new(1, -32, 0, 53)
	row.Parent = parent
	addStroke(row, colors.EdgeDark, 1)

	createLabel(
		row,
		"Name",
		definition.Label,
		UDim2.fromOffset(12, 5),
		UDim2.new(1, -128, 0, 18),
		12,
		colors.Text
	)

	local valueLabel

	if definition.AllowNumericEntry then
		valueLabel = Instance.new("TextBox")
		valueLabel.Name = "Value"
		valueLabel.BackgroundColor3 = colors.Raised
		valueLabel.ClearTextOnFocus = false
		valueLabel.Position = UDim2.new(1, -114, 0, 3)
		valueLabel.Size = UDim2.fromOffset(102, 22)
		valueLabel.Font = UIStyle.Fonts.Primary
		valueLabel.TextColor3 = colors.Accent
		valueLabel.TextSize = 12
		valueLabel.TextXAlignment = Enum.TextXAlignment.Center
		valueLabel.Parent = row
		addStroke(valueLabel, colors.Edge, 1)
	else
		valueLabel = createLabel(
			row,
			"Value",
			"",
			UDim2.new(1, -114, 0, 5),
			UDim2.fromOffset(102, 18),
			12,
			colors.Accent,
			Enum.TextXAlignment.Right
		)
	end

	local hitArea = Instance.new("Frame")
	hitArea.Name = "SliderHitArea"
	hitArea.Active = true
	hitArea.BackgroundTransparency = 1
	hitArea.Position = UDim2.fromOffset(12, 25)
	hitArea.Size = UDim2.new(1, -24, 0, 22)
	hitArea.Parent = row

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.BackgroundColor3 = colors.Raised
	track.BorderSizePixel = 0
	track.Position = UDim2.fromScale(0, 0.5)
	track.Size = UDim2.new(1, 0, 0, 4)
	track.Parent = hitArea

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = colors.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = colors.Text
	knob.BorderSizePixel = 0
	knob.Size = UDim2.fromOffset(8, 15)
	knob.Parent = hitArea
	addCorner(knob, 1)

	local control = {
		Key = definition.Key,
		Decimals = definition.Decimals,
		Suffix = definition.Suffix,
		DisplayMultiplier = definition.DisplayMultiplier,
		Source = source,
		Range = ranges[definition.Key],
		HitArea = hitArea,
		Fill = fill,
		Knob = knob,
		ValueLabel = valueLabel,
	}

	table.insert(sliderControls, control)
	updateSliderVisual(control)

	if definition.AllowNumericEntry then
		valueLabel.FocusLost:Connect(function()
			local typedValue = tonumber(valueLabel.Text)

			if typedValue then
				local range = control.Range
				local steppedValue = range.Minimum
					+ math.round((typedValue - range.Minimum) / range.Step) * range.Step
				control.Source:Set(
					control.Key,
					math.clamp(steppedValue, range.Minimum, range.Maximum)
				)
			end

			updateSliderVisual(control)
		end)
	end

	hitArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeSlider = control
			setSliderFromScreenX(control, input.Position.X)
		end
	end)
end

local function createToggle(parent, key, labelText, rowIndex, source, positionYOverride)
	local row = Instance.new("Frame")
	row.Name = key
	row.BackgroundColor3 = colors.Backdrop
	row.BackgroundTransparency = 0.24
	row.Position = UDim2.fromOffset(
		16,
		positionYOverride or 68 + (rowIndex - 1) * 55
	)
	row.Size = UDim2.new(1, -32, 0, 46)
	row.Parent = parent
	addStroke(row, colors.EdgeDark, 1)

	createLabel(
		row,
		"Name",
		labelText,
		UDim2.fromOffset(12, 13),
		UDim2.new(1, -112, 0, 20),
		12,
		colors.Text
	)

	local button = createButton(
		row,
		"Toggle",
		"OFF",
		UDim2.new(1, -86, 0, 8),
		UDim2.fromOffset(74, 30)
	)
	local control = {
		Key = key,
		Source = source,
		Button = button,
	}
	toggleControls[key] = control
	updateToggleVisual(control)

	button.Activated:Connect(function()
		source:Set(key, not source:Get(key))
		updateToggleVisual(control)
	end)
end

local function createCameraPage(parent)
	createSectionHeader(parent, "VIDEO / CAMERA", "LIVE SESSION PREVIEW")

	for index, definition in cameraSliders do
		createSlider(parent, definition, index, CameraSettings, CameraConfig.SettingsRanges)
	end

	createToggle(parent, "InvertY", "INVERT VERTICAL LOOK", 7, CameraSettings, 374)

	local resetButton = createButton(
		parent,
		"ResetCameraDefaults",
		"RESET CAMERA DEFAULTS",
		UDim2.fromOffset(16, 426),
		UDim2.fromOffset(210, 34)
	)
	resetButton.TextColor3 = colors.Accent
	resetButton.Activated:Connect(function()
		CameraSettings:ResetToDefaults()

		for _, control in sliderControls do
			if control.Source == CameraSettings then
				updateSliderVisual(control)
			end
		end

		updateToggleVisual(toggleControls.InvertY)
		gameplayCamera:ResetPitchToNeutral()
	end)

	local sensitivityNote = createLabel(
		parent,
		"SensitivityNote",
		"SENSITIVITY IS IN-GAME DEG/PIXEL // PHYSICAL MOUSE DPI IS NOT DETECTED",
		UDim2.fromOffset(238, 427),
		UDim2.new(1, -254, 0, 31),
		9,
		colors.TextMuted
	)
	sensitivityNote.TextWrapped = true
end

local function createSoundPage(parent)
	createSectionHeader(parent, "SOUND", "BLIKK-OWNED SOUND GROUPS // SESSION ONLY")

	for index, definition in soundSliders do
		createSlider(parent, definition, index, SessionSettings, SettingsConfig.AudioRanges)
	end

	createLabel(
		parent,
		"SoundNote",
		"These controls affect BLIKK_Master, BLIKK_Music and BLIKK_SoundEffects.\nRoblox platform and CoreGui audio are not modified.",
		UDim2.fromOffset(16, 270),
		UDim2.new(1, -32, 0, 54),
		11,
		colors.TextMuted
	).TextWrapped = true
end

local function createControlsPage(parent)
	createSectionHeader(parent, "CONTROLS", "REBINDING ARRIVES IN THE NEXT CONTROLS SPRINT")

	local actions = {
		{ "MOVE FORWARD", "W" },
		{ "MOVE LEFT", "A" },
		{ "MOVE BACKWARD", "S" },
		{ "MOVE RIGHT", "D" },
		{ "JUMP", "SPACE" },
		{ "PRIMARY / SECONDARY", "MOUSE 1 / 2" },
		{ "SETTINGS", "M" },
	}

	for index, action in actions do
		local row = Instance.new("Frame")
		row.Name = "Action" .. index
		row.BackgroundColor3 = colors.Backdrop
		row.BackgroundTransparency = 0.3
		row.Position = UDim2.fromOffset(16, 68 + (index - 1) * 48)
		row.Size = UDim2.new(1, -32, 0, 40)
		row.Parent = parent
		addStroke(row, colors.EdgeDark, 1)
		createLabel(
			row,
			"ActionName",
			action[1],
			UDim2.fromOffset(12, 10),
			UDim2.new(1, -174, 0, 20),
			12,
			colors.Text
		)
		createLabel(
			row,
			"Binding",
			action[2],
			UDim2.new(1, -156, 0, 10),
			UDim2.fromOffset(144, 20),
			12,
			colors.Accent,
			Enum.TextXAlignment.Right
		)
	end
end

local function createExtrasPage(parent)
	createSectionHeader(parent, "EXTRAS", "HONEST PROTOTYPE DISPLAY OPTIONS")
	createToggle(parent, "HudVisible", "GAMEPLAY HUD", 1, SessionSettings)

	local unavailable = Instance.new("Frame")
	unavailable.Name = "ReducedEffectsUnavailable"
	unavailable.BackgroundColor3 = colors.Backdrop
	unavailable.BackgroundTransparency = 0.55
	unavailable.Position = UDim2.fromOffset(16, 123)
	unavailable.Size = UDim2.new(1, -32, 0, 54)
	unavailable.Parent = parent
	addStroke(unavailable, colors.EdgeDark, 1)
	createLabel(
		unavailable,
		"Name",
		"REDUCED EFFECTS",
		UDim2.fromOffset(12, 8),
		UDim2.new(1, -24, 0, 18),
		12,
		colors.TextMuted
	)
	createLabel(
		unavailable,
		"Status",
		"UNAVAILABLE // NO GAMEPLAY EFFECTS EXIST YET",
		UDim2.fromOffset(12, 28),
		UDim2.new(1, -24, 0, 16),
		10,
		colors.TextMuted
	)
end

local function selectTab(tabName)
	for name, page in tabPages do
		local selected = name == tabName
		page.Visible = selected
		tabButtons[name].BackgroundColor3 = if selected then colors.AccentDim else colors.Raised
		tabButtons[name].TextColor3 = if selected then colors.Accent else colors.TextMuted
	end
end

local function blockGameplayInput()
	return Enum.ContextActionResult.Sink
end

local function getPlayerControls()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local playerModuleScript = playerScripts and playerScripts:FindFirstChild("PlayerModule")

	if not playerModuleScript then
		return nil
	end

	local success, controls = pcall(function()
		local playerModule = require(playerModuleScript)
		return playerModule:GetControls()
	end)

	if success then
		return controls
	end

	return nil
end

local function setOpen(nextIsOpen)
	if isOpen == nextIsOpen then
		return
	end

	isOpen = nextIsOpen
	backdrop.Visible = isOpen
	panel.Visible = isOpen
	gearButton.Visible = not isOpen
	inputManager:SetGameplayEnabled(not isOpen)
	gameplayCamera:SetInterfaceOpen(isOpen)

	if isOpen then
		if playerControls then
			playerControls:Disable()
		end

		ContextActionService:BindActionAtPriority(
			INPUT_BLOCK_ACTION,
			blockGameplayInput,
			false,
			INPUT_BLOCK_PRIORITY,
			Enum.KeyCode.W,
			Enum.KeyCode.A,
			Enum.KeyCode.S,
			Enum.KeyCode.D,
			Enum.KeyCode.Space,
			Enum.KeyCode.Q,
			Enum.KeyCode.E,
			Enum.KeyCode.R,
			Enum.UserInputType.MouseButton1,
			Enum.UserInputType.MouseButton2,
			Enum.UserInputType.MouseButton3
		)
	else
		activeSlider = nil
		ContextActionService:UnbindAction(INPUT_BLOCK_ACTION)

		if playerControls then
			playerControls:Enable()
		end
	end
end

local function decorateGear(button)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundColor3 = colors.Accent
	ring.Position = UDim2.fromScale(0.5, 0.44)
	ring.Size = UDim2.fromOffset(17, 17)
	ring.ZIndex = 2
	ring.Parent = button
	addCorner(ring, 9)

	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.BackgroundColor3 = colors.Panel
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(7, 7)
	hub.ZIndex = 3
	hub.Parent = ring
	addCorner(hub, 4)

	for index = 1, 4 do
		local tooth = Instance.new("Frame")
		tooth.Name = "Tooth" .. index
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.BackgroundColor3 = colors.Accent
		tooth.BorderSizePixel = 0
		tooth.Position = UDim2.fromScale(0.5, 0.44)
		tooth.Rotation = (index - 1) * 45
		tooth.Size = UDim2.fromOffset(5, 25)
		tooth.ZIndex = 1
		tooth.Parent = button
	end

	local hotkeyLabel = createLabel(
		button,
		"Hotkey",
		"M",
		UDim2.new(0, 0, 1, -13),
		UDim2.new(1, 0, 0, 12),
		9,
		colors.Text,
		Enum.TextXAlignment.Center
	)
	hotkeyLabel.ZIndex = 4
end

local function updateResponsiveScale()
	local currentCamera = Workspace.CurrentCamera

	if not currentCamera then
		return
	end

	local viewport = currentCamera.ViewportSize
	local scale = math.min(viewport.X / 900, viewport.Y / 680, 1)
	panelScale.Scale = math.clamp(scale, 0.72, 1)
end

local function createInterface()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BLIKKSettings")

	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BLIKKSettings"
	screenGui.DisplayOrder = UIStyle.DisplayOrders.Settings
	screenGui.IgnoreGuiInset = false
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.35
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Visible = false
	backdrop.Parent = screenGui

	gearButton = createButton(
		screenGui,
		"SettingsGear",
		"",
		UDim2.new(0, 18, 1, -60),
		UDim2.fromOffset(42, 42)
	)
	gearButton.BackgroundColor3 = colors.Panel
	gearButton.Text = ""
	decorateGear(gearButton)

	panel = Instance.new("Frame")
	panel.Name = "SettingsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = colors.Panel
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 560)
	panel.Visible = false
	panel.Parent = screenGui
	addCorner(panel, 3)
	addStroke(panel, colors.Edge, 2)
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local accentLine = Instance.new("Frame")
	accentLine.Name = "AcidEdge"
	accentLine.BackgroundColor3 = colors.Accent
	accentLine.BorderSizePixel = 0
	accentLine.Size = UDim2.new(1, 0, 0, 3)
	accentLine.Parent = panel

	createLabel(
		panel,
		"Title",
		"BLIKK // SYSTEM",
		UDim2.fromOffset(18, 14),
		UDim2.fromOffset(360, 28),
		20,
		colors.Text
	)
	createLabel(
		panel,
		"Subtitle",
		"SESSION SETTINGS // PRESS M TO CLOSE",
		UDim2.fromOffset(18, 42),
		UDim2.fromOffset(420, 16),
		10,
		colors.TextMuted
	)

	local closeButton = createButton(
		panel,
		"Close",
		"CLOSE  [M]",
		UDim2.new(1, -130, 0, 17),
		UDim2.fromOffset(112, 32)
	)

	local tabNames = { "VIDEO", "SOUND", "CONTROLS", "EXTRAS" }

	for index, name in tabNames do
		local button = createButton(
			panel,
			name .. "Tab",
			name,
			UDim2.fromOffset(18, 82 + (index - 1) * 48),
			UDim2.fromOffset(152, 38)
		)
		tabButtons[name] = button
		button.Activated:Connect(function()
			selectTab(name)
		end)

		local page = Instance.new("Frame")
		page.Name = name .. "Page"
		page.BackgroundColor3 = colors.Backdrop
		page.BackgroundTransparency = 0.18
		page.Position = UDim2.fromOffset(186, 82)
		page.Size = UDim2.new(1, -204, 1, -100)
		page.Visible = false
		page.Parent = panel
		addStroke(page, colors.EdgeDark, 1)
		tabPages[name] = page
	end

	createCameraPage(tabPages.VIDEO)
	createSoundPage(tabPages.SOUND)
	createControlsPage(tabPages.CONTROLS)
	createExtrasPage(tabPages.EXTRAS)
	selectTab("VIDEO")

	gearButton.Activated:Connect(function()
		setOpen(true)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	screenGui.Parent = playerGui
	updateResponsiveScale()

	local currentCamera = Workspace.CurrentCamera
	if currentCamera then
		currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	end
end

function SettingsController:Init(gameplayInputManager, cameraController)
	if isInitialised then
		return
	end

	isInitialised = true
	inputManager = gameplayInputManager
	gameplayCamera = cameraController
	playerControls = getPlayerControls()
	createInterface()

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.M and not UserInputService:GetFocusedTextBox() then
			setOpen(not isOpen)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if activeSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
			setSliderFromScreenX(activeSlider, input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeSlider = nil
		end
	end)
end

return SettingsController
