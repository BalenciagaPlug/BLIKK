local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraSettings = require(script.Parent.Parent.Camera.CameraSettings)
local BindingState = require(script.Parent.Parent.Input.BindingState)
local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local PlayerPreferencesController = require(script.Parent.Parent.Settings.PlayerPreferencesController)
local UIStyle = require(script.Parent.UIStyle)
local UINavigationController = require(script.Parent.UINavigationController)

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before settings")
local CameraConfig = require(Shared.Camera.CameraConfig)
local ActionCatalogue = require(Shared.Input.ActionCatalogue)
local SettingsConfig = require(Shared.Settings.SettingsConfig)
local Branding = require(Shared.Branding.Branding)

local SettingsController = {}

local player = Players.LocalPlayer
local colors = UIStyle.Colors
local isInitialised = false
local isOpen = false
local inputManager = nil
local gameplayCamera = nil
local panel = nil
local panelScale = nil
local backdrop = nil
local gearButton = nil
local activeSlider = nil
local sliderControls = {}
local toggleControls = {}
local tabButtons = {}
local tabPages = {}
local bindingButtons = {}
local captureAction = nil
local captureSlot = nil
local conflictFrame = nil
local conflictLabel = nil
local pendingConflict = nil
local gearHotkeyLabel = nil
local effectsQualityButton = nil
local viewportLabel = nil
local aspectLabel = nil
local confirmationFrame = nil
local returnToMenuCallback = nil
local isFrontendActive = false
local returnButton = nil
local openContext = "Gameplay"
local settingsGui = nil
local settingsScope = nil
local conflictScope = nil
local confirmationScope = nil
local captureScope = nil
local activationCallbacks = {}
local sliderKeyboardCommitGeneration = {}
local conflictReplaceButton = nil
local conflictCancelButton = nil
local confirmationYesButton = nil
local confirmationNoButton = nil
local cancelCapture = nil
local tabOrder = { "VIDEO", "SOUND", "CONTROLS", "EXTRAS" }
local activeTabName = "VIDEO"

local function bindActivation(button, callback)
	activationCallbacks[button] = callback
	button.Activated:Connect(callback)
end

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
	{
		Key = "UISoundVolume",
		Label = "BLIKK UI SOUNDS",
		Decimals = 0,
		Suffix = "%",
		DisplayMultiplier = 100,
	},
}

local displaySliders = {
	{ Key = "UIScale", Label = "BLIKK UI SCALE", Decimals = 0, Suffix = "%", DisplayMultiplier = 100 },
	{ Key = "HudScale", Label = "GAMEPLAY HUD SCALE", Decimals = 0, Suffix = "%", DisplayMultiplier = 100 },
	{ Key = "InputOverlayScale", Label = "INPUT OVERLAY SCALE", Decimals = 0, Suffix = "%", DisplayMultiplier = 100 },
	{ Key = "InputOverlayOpacity", Label = "INPUT OVERLAY OPACITY", Decimals = 0, Suffix = "%", DisplayMultiplier = 100 },
	{ Key = "ChatOpacity", Label = "CHAT OPACITY", Decimals = 0, Suffix = "%", DisplayMultiplier = 100 },
	{ Key = "ChatScale", Label = "CHAT SCALE", Decimals = 0, Suffix = "%", DisplayMultiplier = 100 },
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

	local previousValue = control.Source:Get(control.Key)
	control.Source:Set(control.Key, value)
	updateSliderVisual(control)
	if value ~= previousValue then
		UINavigationController:EmitAudioEvent("SliderStep", control.Row)
	end
end

local function cancelPendingSliderCommit(control)
	sliderKeyboardCommitGeneration[control] = (sliderKeyboardCommitGeneration[control] or 0) + 1
end

local function scheduleSliderCommit(control, value)
	cancelPendingSliderCommit(control)
	local generation = sliderKeyboardCommitGeneration[control]
	task.delay(SettingsConfig.KeyboardSliderCommitDelaySeconds, function()
		if sliderKeyboardCommitGeneration[control] ~= generation then return end
		sliderKeyboardCommitGeneration[control] = nil
		PlayerPreferencesController:SetPreference(control.Key, value)
	end)
end

local function adjustSlider(control, direction)
	if direction ~= "Left" and direction ~= "Right" then return false end
	local range = control.Range
	local directionMultiplier = if direction == "Left" then -1 else 1
	local value = math.clamp(
		control.Source:Get(control.Key) + range.Step * directionMultiplier,
		range.Minimum,
		range.Maximum
	)
	if value == control.Source:Get(control.Key) then return false end
	control.Source:Set(control.Key, value)
	updateSliderVisual(control)
	scheduleSliderCommit(control, value)
	return true
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
		Row = row,
		AllowNumericEntry = definition.AllowNumericEntry == true,
	}

	table.insert(sliderControls, control)
	updateSliderVisual(control)

	if definition.AllowNumericEntry then
		valueLabel.FocusLost:Connect(function(enterPressed)
			cancelPendingSliderCommit(control)
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
			PlayerPreferencesController:SetPreference(control.Key, control.Source:Get(control.Key))
			if enterPressed and settingsScope then
				task.defer(function()
					if settingsScope and settingsScope:IsActive() then settingsScope:Refresh(control.Row) end
				end)
			end
		end)
	end

	hitArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			cancelPendingSliderCommit(control)
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

	bindActivation(button, function()
		PlayerPreferencesController:SetPreference(key, not source:Get(key))
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
	bindActivation(resetButton, function()
		PlayerPreferencesController:ResetPreferenceGroup("Camera")

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
	createSectionHeader(parent, "SOUND", "BLIKK-OWNED SOUND GROUPS // ACCOUNT PERSISTENT")

	for index, definition in soundSliders do
		createSlider(parent, definition, index, SessionSettings, SettingsConfig.AudioRanges)
	end
	createToggle(parent, "MusicMuted", "MUTE MUSIC", 1, SessionSettings, 313)

	createLabel(
		parent,
		"SoundNote",
		"Combat cues use BLIKK_SoundEffects; menu feedback has its own BLIKK_UI trim.\nRoblox platform and CoreGui audio are not modified.",
		UDim2.fromOffset(16, 373),
		UDim2.new(1, -32, 0, 54),
		11,
		colors.TextMuted
	).TextWrapped = true
end

local function createControlsPage(parent)
	createSectionHeader(parent, "CONTROLS", "TWO SLOTS // ESC CANCELS // RESET CLEARS")

	local list = Instance.new("ScrollingFrame")
	list.Name = "ActionList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(8, 64)
	list.Size = UDim2.new(1, -16, 1, -112)
	list.CanvasSize = UDim2.fromOffset(0, #ActionCatalogue.Ordered * 45)
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = colors.AccentDim
	list.Parent = parent

	for index, definition in ActionCatalogue.Ordered do
		local row = Instance.new("Frame")
		row.Name = definition.Id
		row.BackgroundColor3 = colors.Backdrop
		row.BackgroundTransparency = 0.3
		row.Position = UDim2.fromOffset(8, (index - 1) * 45)
		row.Size = UDim2.new(1, -18, 0, 39)
		row.Parent = list
		addStroke(row, colors.EdgeDark, 1)
		createLabel(
			row,
			"ActionName",
			string.upper(definition.Name),
			UDim2.fromOffset(9, 4),
			UDim2.new(1, -268, 0, 18),
			10,
			colors.Text
		)
		createLabel(
			row,
			"Group",
			string.upper(definition.Group),
			UDim2.fromOffset(9, 21),
			UDim2.fromOffset(110, 13),
			8,
			colors.TextMuted
		)

		bindingButtons[definition.Id] = {}
		for slotIndex, slot in { "Primary", "Secondary" } do
			local button = createButton(
				row,
				slot,
				"",
				UDim2.new(1, -252 + (slotIndex - 1) * 102, 0, 6),
				UDim2.fromOffset(96, 27)
			)
			button.TextSize = 9
			bindingButtons[definition.Id][slot] = button
			bindActivation(button, function()
				captureAction = definition.Id
				captureSlot = slot
				inputManager:SetBindingCaptureActive(true)
				if captureScope then captureScope:SetActive(true) end
				button.Text = "PRESS INPUT..."
				button.TextColor3 = colors.Blood
			end)
		end

		local reset = createButton(
			row,
			"Reset",
			"RST",
			UDim2.new(1, -45, 0, 6),
			UDim2.fromOffset(38, 27)
		)
		reset.TextSize = 9
		bindActivation(reset, function()
			PlayerPreferencesController:ResetBinding(definition.Id)
		end)
	end

	local resetAll = createButton(
		parent,
		"ResetAllControls",
		"RESET ALL CONTROLS",
		UDim2.fromOffset(16, 420),
		UDim2.fromOffset(180, 30)
	)
	resetAll.TextColor3 = colors.Accent
	bindActivation(resetAll, function()
		PlayerPreferencesController:ResetAllBindings()
	end)

	conflictFrame = Instance.new("Frame")
	conflictFrame.Name = "Conflict"
	conflictFrame.BackgroundColor3 = colors.PanelLight
	conflictFrame.Position = UDim2.fromOffset(58, 152)
	conflictFrame.Size = UDim2.new(1, -116, 0, 145)
	conflictFrame.Visible = false
	conflictFrame.ZIndex = 10
	conflictFrame.Parent = parent
	addStroke(conflictFrame, colors.Blood, 2)
	conflictLabel = createLabel(
		conflictFrame,
		"Message",
		"",
		UDim2.fromOffset(14, 14),
		UDim2.new(1, -28, 0, 68),
		11,
		colors.Text
	)
	conflictLabel.TextWrapped = true
	conflictLabel.ZIndex = 11
	local replaceButton = createButton(
		conflictFrame,
		"Replace",
		"REPLACE OLD BIND",
		UDim2.fromOffset(14, 96),
		UDim2.fromOffset(152, 32)
	)
	replaceButton.ZIndex = 11
	local cancelButton = createButton(
		conflictFrame,
		"Cancel",
		"CANCEL",
		UDim2.new(1, -112, 0, 96),
		UDim2.fromOffset(98, 32)
	)
	cancelButton.ZIndex = 11
	conflictReplaceButton = replaceButton
	conflictCancelButton = cancelButton
	bindActivation(replaceButton, function()
		if pendingConflict then
			local replaced = PlayerPreferencesController:SetBinding(
				pendingConflict.Action,
				pendingConflict.Slot,
				pendingConflict.Token
			)

			if not replaced then
				conflictLabel.Text = "THAT BIND IS THE LAST ACCESS PATH FOR A PROTECTED ACTION. ASSIGN A SECONDARY BIND FIRST."
				return
			end
		end
		pendingConflict = nil
		conflictFrame.Visible = false
		if conflictScope then conflictScope:SetActive(false) end
	end)
	bindActivation(cancelButton, function()
		pendingConflict = nil
		conflictFrame.Visible = false
		if conflictScope then conflictScope:SetActive(false) end
	end)
end

local function createExtrasPage(parent)
	local content = Instance.new("ScrollingFrame")
	content.Name = "DisplayOptions"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Size = UDim2.fromScale(1, 1)
	content.CanvasSize = UDim2.fromOffset(0, 1310)
	content.ScrollBarThickness = 5
	content.ScrollBarImageColor3 = colors.AccentDim
	content.Parent = parent
	createSectionHeader(content, "DISPLAY / EXTRAS", "VIEWPORT IS READ-ONLY // SESSION PREVIEW")
	viewportLabel = createLabel(content, "Viewport", "CURRENT VIEWPORT // --", UDim2.fromOffset(16, 48), UDim2.fromOffset(260, 16), 10, colors.Text)
	aspectLabel = createLabel(content, "Aspect", "ASPECT // --", UDim2.new(1, -190, 0, 48), UDim2.fromOffset(170, 16), 10, colors.TextMuted, Enum.TextXAlignment.Right)
	for index, definition in displaySliders do
		createSlider(content, definition, index, SessionSettings, SettingsConfig.ExtrasRanges)
	end
	createToggle(content, "HudVisible", "GAMEPLAY HUD", 1, SessionSettings, 444)
	createToggle(content, "InputOverlayVisible", "LIVE INPUT OVERLAY", 1, SessionSettings, 495)
	createToggle(content, "ReducedEffects", "REDUCED DASH EFFECTS", 1, SessionSettings, 546)
	createToggle(content, "ChatVisible", "BLIKK CHAT", 1, SessionSettings, 597)
	createToggle(content, "ChatTimestamps", "CHAT TIMESTAMPS", 1, SessionSettings, 648)
	local quality = createButton(content, "EffectsQuality", "EFFECTS QUALITY // " .. SessionSettings:Get("EffectsQuality"), UDim2.fromOffset(16, 700), UDim2.new(1, -32, 0, 38))
	effectsQualityButton = quality
	bindActivation(quality, function()
		local current = SessionSettings:Get("EffectsQuality")
		local nextValue = if current == "HIGH" then "MEDIUM" elseif current == "MEDIUM" then "LOW" else "HIGH"
		PlayerPreferencesController:SetPreference("EffectsQuality", nextValue)
		quality.Text = "EFFECTS QUALITY // " .. SessionSettings:Get("EffectsQuality")
	end)
	local preset = createButton(content, "RenderPreset", "RENDER PRESET // " .. SessionSettings:Get("RenderPreset"), UDim2.fromOffset(16, 752), UDim2.new(1, -32, 0, 38))
	bindActivation(preset, function()
		local current = SessionSettings:Get("RenderPreset")
		local nextValue = if current == "COMPETITIVE" then "BALANCED" elseif current == "BALANCED" then "CINEMATIC" elseif current == "CINEMATIC" then "CUSTOM" else "COMPETITIVE"
		PlayerPreferencesController:SetPreference("RenderPreset", nextValue)
		preset.Text = "RENDER PRESET // " .. SessionSettings:Get("RenderPreset")
	end)
	createToggle(content, "ShowFPS", "SHOW FPS", 1, SessionSettings, 803)
	createToggle(content, "ShowPing", "SHOW PING", 1, SessionSettings, 854)
	createToggle(content, "LocalLightShadows", "CUSTOM // LOCAL LIGHT SHADOWS", 1, SessionSettings, 905)
	createToggle(content, "BloomEnabled", "CUSTOM // BLOOM", 1, SessionSettings, 956)
	createToggle(content, "ColorCorrectionEnabled", "CUSTOM // COLOR CORRECTION", 1, SessionSettings, 1007)
	createToggle(content, "AtmosphereEnabled", "CUSTOM // ATMOSPHERE", 1, SessionSettings, 1058)
	createToggle(content, "WeaponTrailsEnabled", "CUSTOM // WEAPON TRAILS", 1, SessionSettings, 1109)
	local particleDensity = createButton(content, "ParticleDensity", "CUSTOM // PARTICLE DENSITY // " .. SessionSettings:Get("ParticleDensity"), UDim2.fromOffset(16, 1160), UDim2.new(1, -32, 0, 38))
	bindActivation(particleDensity, function()
		local current = SessionSettings:Get("ParticleDensity")
		local nextValue = if current < 0.35 then 0.35 elseif current < 0.7 then 0.7 elseif current < 1 then 1 else 0
		PlayerPreferencesController:SetPreference("ParticleDensity", nextValue)
		particleDensity.Text = "CUSTOM // PARTICLE DENSITY // " .. SessionSettings:Get("ParticleDensity")
	end)
	local shake = createButton(content, "ScreenShakeScale", "CUSTOM // SCREEN IMPULSE // " .. SessionSettings:Get("ScreenShakeScale"), UDim2.fromOffset(16, 1211), UDim2.new(1, -32, 0, 38))
	bindActivation(shake, function()
		local current = SessionSettings:Get("ScreenShakeScale")
		local nextValue = if current < 0.35 then 0.35 elseif current < 0.7 then 0.7 elseif current < 1 then 1 else 0
		PlayerPreferencesController:SetPreference("ScreenShakeScale", nextValue)
		shake.Text = "CUSTOM // SCREEN IMPULSE // " .. SessionSettings:Get("ScreenShakeScale")
	end)
	createLabel(content, "ResolutionNote", "ROBLOX CONTROLS RESOLUTION, ENGINE AA, TEXTURE QUALITY AND NATIVE AO. BLIKK PRESETS CONTROL ONLY BLIKK-OWNED EFFECTS.", UDim2.fromOffset(16, 1262), UDim2.new(1, -32, 0, 34), 9, colors.TextMuted).TextWrapped = true
end

local function selectTab(tabName)
	activeTabName = tabName
	for name, page in tabPages do
		local selected = name == tabName
		page.Visible = selected
		tabButtons[name].BackgroundColor3 = if selected then colors.AccentDim else colors.Raised
		tabButtons[name].TextColor3 = if selected then colors.Accent else colors.TextMuted
	end
	if settingsScope and settingsScope:IsActive() then
		task.defer(function()
			if settingsScope and settingsScope:IsActive() then
				settingsScope:Refresh(tabButtons[tabName])
			end
		end)
	end
end

local function setOpen(nextIsOpen)
	if isOpen == nextIsOpen then
		return
	end

	isOpen = nextIsOpen
	backdrop.Visible = isOpen
	panel.Visible = isOpen
	gearButton.Visible = not isOpen and not isFrontendActive
	inputManager:SetGameplayEnabled(not isOpen and not isFrontendActive)
	gameplayCamera:SetInterfaceOpen(isOpen or isFrontendActive)
	if not isOpen and confirmationFrame then confirmationFrame.Visible = false end
	if returnButton then returnButton.Visible = isOpen and openContext == "Gameplay" end

	if not isOpen then
		activeSlider = nil
		if cancelCapture then cancelCapture() end
		if conflictScope then conflictScope:SetActive(false) end
		if confirmationScope then confirmationScope:SetActive(false) end
		if captureScope then captureScope:SetActive(false) end
		if conflictFrame then conflictFrame.Visible = false end
		local focusedTextBox = UserInputService:GetFocusedTextBox()
		if focusedTextBox and focusedTextBox:IsDescendantOf(panel) then
			focusedTextBox:ReleaseFocus(false)
		end
	end
	if settingsScope then settingsScope:SetActive(isOpen) end
end

local function decorateGear(button)
	button.BackgroundColor3 = colors.PanelLight
	button.BackgroundTransparency = 0.08
	local edgeStroke = button:FindFirstChildOfClass("UIStroke")
	if edgeStroke then
		edgeStroke.Color = colors.Metal
		edgeStroke.Thickness = 2
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colors.Metal, colors.Panel)
	gradient.Rotation = 120
	gradient.Parent = button

	local topWear = Instance.new("Frame")
	topWear.Name = "TopWear"
	topWear.BackgroundColor3 = colors.TextMuted
	topWear.BackgroundTransparency = 0.62
	topWear.BorderSizePixel = 0
	topWear.Position = UDim2.fromOffset(5, 4)
	topWear.Rotation = -4
	topWear.Size = UDim2.fromOffset(24, 1)
	topWear.Parent = button

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundColor3 = colors.TextMuted
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
		tooth.BackgroundColor3 = colors.TextMuted
		tooth.BorderSizePixel = 0
		tooth.Position = UDim2.fromScale(0.5, 0.44)
		tooth.Rotation = (index - 1) * 45
		tooth.Size = UDim2.fromOffset(5, 25)
		tooth.ZIndex = 1
		tooth.Parent = button
	end

	gearHotkeyLabel = createLabel(
		button,
		"Hotkey",
		"M",
		UDim2.new(0, 0, 1, -13),
		UDim2.new(1, 0, 0, 12),
		9,
		colors.Text,
		Enum.TextXAlignment.Center
	)
	gearHotkeyLabel.ZIndex = 4
	gearHotkeyLabel.TextStrokeColor3 = colors.Backdrop
	gearHotkeyLabel.TextStrokeTransparency = 0
end

local function refreshBindingButtons()
	for _, definition in ActionCatalogue.Ordered do
		local buttons = bindingButtons[definition.Id]

		if buttons then
			buttons.Primary.Text = ActionCatalogue.GetDisplayName(BindingState:Get(definition.Id, "Primary"))
			buttons.Secondary.Text = ActionCatalogue.GetDisplayName(BindingState:Get(definition.Id, "Secondary"))
			buttons.Primary.TextColor3 = colors.Accent
			buttons.Secondary.TextColor3 = colors.TextMuted
		end
	end

	if gearHotkeyLabel then
		gearHotkeyLabel.Text = ActionCatalogue.GetDisplayName(BindingState:Get("Settings", "Primary"))
	end
end

cancelCapture = function()
	if not captureAction then
		return
	end

	captureAction = nil
	captureSlot = nil
	inputManager:SetBindingCaptureActive(false)
	if captureScope then captureScope:SetActive(false) end
	refreshBindingButtons()
end

local function acceptCapturedToken(token)
	if not captureAction or not captureSlot then
		return
	end

	local action = captureAction
	local slot = captureSlot
	captureAction = nil
	captureSlot = nil
	inputManager:SetBindingCaptureActive(false)
	if captureScope then captureScope:SetActive(false) end

	local oldAction, oldSlot = BindingState:FindOwner(token, action, slot)

	if oldAction then
		pendingConflict = {
			Action = action,
			Slot = slot,
			Token = token,
			OldAction = oldAction,
			OldSlot = oldSlot,
		}
		conflictLabel.Text = string.format(
			"%s IS ALREADY BOUND TO %s (%s). REPLACE IT?",
			ActionCatalogue.GetDisplayName(token),
			string.upper(ActionCatalogue.ById[oldAction].Name),
			string.upper(oldSlot)
		)
		conflictFrame.Visible = true
		if conflictScope then conflictScope:SetActive(true) end
	else
		PlayerPreferencesController:SetBinding(action, slot, token)
	end

	refreshBindingButtons()
end

local function updateResponsiveScale()
	local currentCamera = Workspace.CurrentCamera

	if not currentCamera then
		return
	end

	local viewport = currentCamera.ViewportSize
	local scale = math.min(viewport.X / 900, viewport.Y / 680, 1)
	panelScale.Scale = math.clamp(scale, 0.72, 1) * SessionSettings:Get("UIScale")
	if viewportLabel and aspectLabel then
		viewportLabel.Text = string.format("CURRENT VIEWPORT // %d x %d", math.round(viewport.X), math.round(viewport.Y))
		local ratio = viewport.X / math.max(viewport.Y, 1)
		local aspect = if math.abs(ratio - 16 / 9) < 0.04 then "16:9" elseif math.abs(ratio - 16 / 10) < 0.04 then "16:10" elseif math.abs(ratio - 4 / 3) < 0.04 then "4:3" elseif ratio >= 2 then "ULTRAWIDE" else "CUSTOM"
		aspectLabel.Text = "ASPECT // " .. aspect
	end
end

local function createInterface()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then error("[BLIKK SETTINGS] PlayerGui was unavailable after bootstrap", 0) end
	local existing = playerGui:FindFirstChild("BLIKKSettings")

	if existing then
		existing:Destroy()
	end

	settingsGui = Instance.new("ScreenGui")
	settingsGui.Name = "BLIKKSettings"
	settingsGui.DisplayOrder = UIStyle.DisplayOrders.Settings
	settingsGui.IgnoreGuiInset = false
	settingsGui.ResetOnSpawn = false
	settingsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.35
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Visible = false
	backdrop.Parent = settingsGui

	gearButton = createButton(
		settingsGui,
		"SettingsGear",
		"",
		UDim2.new(0, 18, 1, -62),
		UDim2.fromOffset(46, 46)
	)
	gearButton.Text = ""
	decorateGear(gearButton)
	local gearScale = Instance.new("UIScale")
	gearScale.Name = "BLIKKScale"
	gearScale.Scale = SessionSettings:Get("UIScale")
	gearScale.Parent = gearButton

	panel = Instance.new("Frame")
	panel.Name = "SettingsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = colors.Panel
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 560)
	panel.Visible = false
	panel.Parent = settingsGui
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

	Branding.CreateIconLogo(panel, {
		Name = "SettingsBrand",
		Position = UDim2.fromOffset(18, 9),
		Size = Branding.Sizes.Settings,
		Color = colors.TextMuted,
		ZIndex = 2,
	})
	createLabel(
		panel,
		"Subtitle",
		"SESSION SETTINGS // USE YOUR SETTINGS BIND TO CLOSE",
		UDim2.fromOffset(94, 23),
		UDim2.fromOffset(420, 16),
		10,
		colors.TextMuted
	)

	local closeButton = createButton(
		panel,
		"Close",
		"CLOSE",
		UDim2.new(1, -130, 0, 17),
		UDim2.fromOffset(112, 32)
	)
	returnButton = createButton(
		panel,
		"ReturnToMenu",
		"RETURN TO MENU",
		UDim2.new(1, -154, 0, 54),
		UDim2.fromOffset(136, 24)
	)
	returnButton.TextSize = 10
	returnButton.TextColor3 = colors.Blood

	for index, name in tabOrder do
		local button = createButton(
			panel,
			name .. "Tab",
			name,
			UDim2.fromOffset(18, 82 + (index - 1) * 48),
			UDim2.fromOffset(152, 38)
		)
		tabButtons[name] = button
		bindActivation(button, function()
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
	refreshBindingButtons()

	bindActivation(gearButton, function()
		if UINavigationController:IsMenuActive() then return end
		openContext = "Gameplay"
		settingsGui.DisplayOrder = UIStyle.DisplayOrders.Settings
		setOpen(true)
	end)
	bindActivation(closeButton, function()
		setOpen(false)
	end)

	confirmationFrame = Instance.new("Frame")
	confirmationFrame.Name = "ReturnConfirmation"
	confirmationFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	confirmationFrame.BackgroundColor3 = colors.PanelLight
	confirmationFrame.Position = UDim2.fromScale(0.5, 0.5)
	confirmationFrame.Size = UDim2.fromOffset(430, 210)
	confirmationFrame.Visible = false
	confirmationFrame.ZIndex = 20
	confirmationFrame.Parent = panel
	addStroke(confirmationFrame, colors.Blood, 2)
	local confirmationTitle = createLabel(
		confirmationFrame, "Title", "RETURN TO MENU?", UDim2.fromOffset(22, 22),
		UDim2.new(1, -44, 0, 30), 20, colors.Text, Enum.TextXAlignment.Center
	)
	confirmationTitle.ZIndex = 21
	local confirmationCopy = createLabel(
		confirmationFrame, "Copy", "Current Movement Lab progress for this session may be lost.",
		UDim2.fromOffset(30, 68), UDim2.new(1, -60, 0, 48), 12, colors.TextMuted,
		Enum.TextXAlignment.Center
	)
	confirmationCopy.TextWrapped = true
	confirmationCopy.ZIndex = 21
	local yesButton = createButton(
		confirmationFrame, "Yes", "YES", UDim2.fromOffset(38, 142), UDim2.fromOffset(166, 42)
	)
	yesButton.ZIndex = 21
	yesButton.TextColor3 = colors.Blood
	local noButton = createButton(
		confirmationFrame, "No", "NO", UDim2.new(1, -204, 0, 142), UDim2.fromOffset(166, 42)
	)
	noButton.ZIndex = 21
	confirmationYesButton = yesButton
	confirmationNoButton = noButton
	bindActivation(returnButton, function()
		confirmationFrame.Visible = true
		if confirmationScope then confirmationScope:SetActive(true) end
	end)
	bindActivation(noButton, function()
		confirmationFrame.Visible = false
		if confirmationScope then confirmationScope:SetActive(false) end
	end)
	bindActivation(yesButton, function()
		if not returnToMenuCallback then return end
		confirmationFrame.Visible = false
		if confirmationScope then confirmationScope:SetActive(false) end
		returnToMenuCallback()
	end)

	settingsGui.Parent = playerGui
	settingsScope = UINavigationController:CreateScope("SettingsModal", {
		Root = panel,
		Default = tabButtons.VIDEO,
		Back = function() setOpen(false) end,
		AllowSettingsAction = true,
	})
	for button, callback in activationCallbacks do
		if button:IsDescendantOf(panel)
			and not button:IsDescendantOf(conflictFrame)
			and not button:IsDescendantOf(confirmationFrame) then
			local tabName = nil
			for name, tabButton in tabButtons do
				if tabButton == button then tabName = name; break end
			end
			settingsScope:Register(button, {
				Activate = callback,
				IsFocusVisualVisible = if tabName then function()
					return activeTabName ~= tabName
				end else nil,
				Adjust = if tabName then function(direction)
					if direction ~= "Left" and direction ~= "Right" then return false end
					local index = table.find(tabOrder, tabName)
					local offset = if direction == "Left" then -1 else 1
					local nextName = tabOrder[(index - 1 + offset) % #tabOrder + 1]
					selectTab(nextName)
					settingsScope:Refresh(tabButtons[nextName])
					return true
				end else nil,
			})
		end
	end
	for _, control in sliderControls do
		settingsScope:Register(control.Row, {
			Adjust = function(direction) return adjustSlider(control, direction) end,
			AdjustAudioRole = "SliderStep",
		})
		if control.AllowNumericEntry then settingsScope:Register(control.ValueLabel) end
	end
	conflictScope = UINavigationController:CreateScope("SettingsConflictModal", {
		Root = conflictFrame,
		Default = conflictCancelButton,
		Back = function()
			pendingConflict = nil
			conflictFrame.Visible = false
			conflictScope:SetActive(false)
		end,
		AllowSettingsAction = true,
	})
	conflictScope:Register(conflictReplaceButton, {
		Activate = activationCallbacks[conflictReplaceButton],
		AudioRole = "Confirm",
	})
	conflictScope:Register(conflictCancelButton, {
		Activate = activationCallbacks[conflictCancelButton],
		AudioRole = "Back",
	})
	confirmationScope = UINavigationController:CreateScope("SettingsReturnConfirmation", {
		Root = confirmationFrame,
		Default = confirmationNoButton,
		Back = function()
			confirmationFrame.Visible = false
			confirmationScope:SetActive(false)
		end,
		AllowSettingsAction = true,
	})
	confirmationScope:Register(confirmationYesButton, {
		Activate = activationCallbacks[confirmationYesButton],
		AudioRole = "Confirm",
	})
	confirmationScope:Register(confirmationNoButton, {
		Activate = activationCallbacks[confirmationNoButton],
		AudioRole = "Back",
	})
	captureScope = UINavigationController:CreateScope("SettingsBindingCapture", {
		Root = panel,
		Back = function() cancelCapture() end,
		AllowSettingsAction = true,
	})
	updateResponsiveScale()

	local currentCamera = Workspace.CurrentCamera
	if currentCamera then
		currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	end
	SessionSettings.Changed.Event:Connect(function(key)
		if key == "UIScale" then
			updateResponsiveScale()
			gearScale.Scale = SessionSettings:Get("UIScale")
		end
		for _, control in sliderControls do
			if control.Source == SessionSettings then updateSliderVisual(control) end
		end
		if toggleControls[key] then updateToggleVisual(toggleControls[key]) end
		if key == "EffectsQuality" and effectsQualityButton then
			effectsQualityButton.Text = "EFFECTS QUALITY // " .. SessionSettings:Get("EffectsQuality")
		end
	end)
end

function SettingsController:Init(gameplayInputManager, cameraController)
	if isInitialised then
		return
	end

	isInitialised = true
	inputManager = gameplayInputManager
	gameplayCamera = cameraController
	createInterface()

	UserInputService.InputBegan:Connect(function(input)
		if confirmationFrame and confirmationFrame.Visible and input.KeyCode == Enum.KeyCode.Escape then
			confirmationFrame.Visible = false
			if confirmationScope then confirmationScope:SetActive(false) end
			return
		end
		if not captureAction then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape then
			cancelCapture()
		else
			local token = ActionCatalogue.TokenFromInput(input)
			if token then
				acceptCapturedToken(token)
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if captureAction and input.UserInputType == Enum.UserInputType.MouseWheel then
			acceptCapturedToken(if input.Position.Z > 0 then "MouseWheelUp" else "MouseWheelDown")
			return
		end

		if activeSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
			setSliderFromScreenX(activeSlider, input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if activeSlider then
				PlayerPreferencesController:SetPreference(
					activeSlider.Key,
					activeSlider.Source:Get(activeSlider.Key)
				)
			end
			activeSlider = nil
		end
	end)

	BindingState.Changed.Event:Connect(refreshBindingButtons)
	CameraSettings.Changed.Event:Connect(function()
		for _, control in sliderControls do
			if control.Source == CameraSettings then updateSliderVisual(control) end
		end
		if toggleControls.InvertY then updateToggleVisual(toggleControls.InvertY) end
	end)
	inputManager.ActionBegan.Event:Connect(function(action)
		if (action == "Settings" or action == "Cancel") and confirmationFrame and confirmationFrame.Visible then
			confirmationFrame.Visible = false
			if confirmationScope then confirmationScope:SetActive(false) end
		elseif action == "Settings" and not captureAction then
			if isOpen then
				setOpen(false)
			elseif not isFrontendActive then
				openContext = "Gameplay"
				settingsGui.DisplayOrder = UIStyle.DisplayOrders.Settings
				setOpen(true)
			end
		end
	end)
end

function SettingsController:SetReturnToMenuCallback(callback)
	returnToMenuCallback = callback
end

function SettingsController:OpenFromFrontend()
	if not isFrontendActive then return false end
	openContext = "Frontend"
	settingsGui.DisplayOrder = 110
	setOpen(true)
	return true
end

function SettingsController:SetFrontendActive(isActive)
	isFrontendActive = isActive
	if isActive and isOpen then
		setOpen(false)
	elseif gearButton then
		gearButton.Visible = not isActive
	end
	if inputManager and gameplayCamera then
		inputManager:SetGameplayEnabled(not isActive and not isOpen)
		gameplayCamera:SetInterfaceOpen(isActive or isOpen)
	end
	if not isActive and settingsGui then settingsGui.DisplayOrder = UIStyle.DisplayOrders.Settings end
	if returnButton then returnButton.Visible = isOpen and openContext == "Gameplay" end
end

return SettingsController
