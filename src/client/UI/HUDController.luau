local Players = game:GetService("Players")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local UIStyle = require(script.Parent.UIStyle)

local HUDController = {}

local player = Players.LocalPlayer
local colors = UIStyle.Colors
local style = UIStyle.HUD
local isInitialised = false
local screenGui = nil
local healthFill = nil
local healthValue = nil
local healthConnection = nil

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
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createLine(parent, name, position, size, color, rotation)
	local line = Instance.new("Frame")
	line.Name = name
	line.BackgroundColor3 = color
	line.BorderSizePixel = 0
	line.Position = position
	line.Rotation = rotation or 0
	line.Size = size
	line.Parent = parent
	return line
end

local function createCornerBracket(parent, name, horizontalPosition, verticalPosition, xDirection, yDirection)
	local length = style.BracketLengthPixels
	local thickness = style.BracketThicknessPixels

	local horizontal = createLine(
		parent,
		name .. "Horizontal",
		horizontalPosition,
		UDim2.fromOffset(length, thickness),
		colors.Metal
	)
	horizontal.AnchorPoint = Vector2.new(if xDirection < 0 then 1 else 0, 0)

	local vertical = createLine(
		parent,
		name .. "Vertical",
		verticalPosition,
		UDim2.fromOffset(thickness, length),
		colors.Metal
	)
	vertical.AnchorPoint = Vector2.new(0, if yDirection < 0 then 1 else 0)
end

local function createPanel(parent, name, position, size, accentColor)
	local shadow = Instance.new("Frame")
	shadow.Name = name .. "Shadow"
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.35
	shadow.BorderSizePixel = 0
	shadow.Position = position + UDim2.fromOffset(style.ShadowOffsetPixels, style.ShadowOffsetPixels)
	shadow.Size = size
	shadow.Parent = parent

	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundColor3 = colors.Panel
	panel.BackgroundTransparency = style.PanelTransparency
	panel.BorderSizePixel = 0
	panel.Position = position
	panel.Size = size
	panel.Parent = parent
	addStroke(panel, colors.EdgeDark, style.EdgeThicknessPixels)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colors.PanelLight, colors.Panel)
	gradient.Rotation = 115
	gradient.Parent = panel

	createLine(
		panel,
		"TopSignal",
		UDim2.fromOffset(0, 0),
		UDim2.new(0.68, 0, 0, style.AccentLineThicknessPixels),
		accentColor
	)
	createLine(
		panel,
		"TopDeadZone",
		UDim2.new(0.68, 5, 0, 0),
		UDim2.new(0.22, 0, 0, 1),
		colors.Edge
	)
	createLine(
		panel,
		"BloodNotch",
		UDim2.new(1, -30, 0, 5),
		UDim2.fromOffset(23, 4),
		colors.Blood,
		-12
	)

	createCornerBracket(
		panel,
		"TopLeft",
		UDim2.fromOffset(-4, -4),
		UDim2.fromOffset(-4, -4),
		1,
		1
	)
	createCornerBracket(
		panel,
		"BottomRight",
		UDim2.new(1, 4, 1, 2),
		UDim2.new(1, 2, 1, 4),
		-1,
		-1
	)

	return panel
end

local function addMeterSegments(track)
	for index = 1, style.MeterSegmentCount - 1 do
		createLine(
			track,
			"Segment" .. index,
			UDim2.fromScale(index / style.MeterSegmentCount, 0),
			UDim2.fromOffset(1, track.Size.Y.Offset),
			colors.Backdrop
		).ZIndex = 3
	end
end

local function createMeter(parent, name, labelText, positionY, color, darkColor, height)
	local label = createLabel(
		parent,
		name .. "Label",
		labelText,
		UDim2.fromOffset(16, positionY - 2),
		UDim2.fromOffset(54, height + 4),
		10,
		colors.TextMuted
	)
	label.Font = UIStyle.Fonts.Strong

	local track = Instance.new("Frame")
	track.Name = name .. "Track"
	track.BackgroundColor3 = colors.Backdrop
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(70, positionY)
	track.Size = UDim2.new(1, -86, 0, height)
	track.Parent = parent
	addStroke(track, colors.EdgeDark, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 2
	fill.Parent = track

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(darkColor, color)
	gradient.Parent = fill
	addMeterSegments(track)

	return fill
end

local function createStatusBlock(parent)
	local size = style.StatusSize
	local panel = createPanel(
		parent,
		"PlayerStatus",
		UDim2.fromOffset(style.ScreenMarginPixels, style.ScreenMarginPixels),
		UDim2.fromOffset(size.X, size.Y),
		colors.Accent
	)

	local identityPlate = Instance.new("Frame")
	identityPlate.Name = "IdentityPlate"
	identityPlate.BackgroundColor3 = colors.Backdrop
	identityPlate.BackgroundTransparency = 0.1
	identityPlate.BorderSizePixel = 0
	identityPlate.Position = UDim2.fromOffset(10, 11)
	identityPlate.Size = UDim2.new(1, -20, 0, 43)
	identityPlate.Parent = panel
	addStroke(identityPlate, colors.EdgeDark, 1)

	createLabel(
		identityPlate,
		"BrandMark",
		"B//",
		UDim2.fromOffset(8, 4),
		UDim2.fromOffset(42, 31),
		21,
		colors.AccentBright
	).Font = UIStyle.Fonts.Strong
	createLine(
		identityPlate,
		"IdentityDivider",
		UDim2.fromOffset(50, 7),
		UDim2.fromOffset(2, 27),
		colors.Blood
	)
	createLabel(
		identityPlate,
		"PlayerName",
		string.upper(player.DisplayName),
		UDim2.fromOffset(62, 2),
		UDim2.new(1, -126, 0, 25),
		style.PlayerNameTextSize,
		colors.Text
	).Font = UIStyle.Fonts.Strong
	createLabel(
		identityPlate,
		"PrototypeStatus",
		"MOVEMENT LAB // LOCAL",
		UDim2.fromOffset(63, 25),
		UDim2.new(1, -126, 0, 14),
		9,
		colors.TextMuted
	)
	createLabel(
		identityPlate,
		"Level",
		"LV --",
		UDim2.new(1, -61, 0, 8),
		UDim2.fromOffset(50, 24),
		13,
		colors.Accent,
		Enum.TextXAlignment.Right
	)

	healthFill = createMeter(
		panel,
		"Health",
		"HEALTH",
		66,
		colors.Health,
		colors.HealthDark,
		style.HealthMeterHeightPixels
	)
	createMeter(
		panel,
		"Defence",
		"DEF",
		96,
		colors.Defence,
		colors.DefenceDark,
		style.SecondaryMeterHeightPixels
	)
	createMeter(
		panel,
		"Technique",
		"TECH",
		121,
		colors.Technique,
		colors.TechniqueDark,
		style.SecondaryMeterHeightPixels
	)

	healthValue = createLabel(
		panel,
		"HealthValue",
		"-- / --",
		UDim2.new(1, -112, 0, 63),
		UDim2.fromOffset(96, 18),
		11,
		colors.Text,
		Enum.TextXAlignment.Right
	)
	createLabel(
		panel,
		"DefenceValue",
		"READY // --",
		UDim2.new(1, -104, 0, 91),
		UDim2.fromOffset(88, 16),
		9,
		colors.TextMuted,
		Enum.TextXAlignment.Right
	)
	createLabel(
		panel,
		"TechniqueValue",
		"READY // --",
		UDim2.new(1, -104, 0, 116),
		UDim2.fromOffset(88, 16),
		9,
		colors.TextMuted,
		Enum.TextXAlignment.Right
	)
end

local function createMatchBlock(parent)
	local size = style.MatchSize
	local panel = createPanel(
		parent,
		"MatchStatus",
		UDim2.new(1, -(size.X + style.ScreenMarginPixels), 0, style.ScreenMarginPixels),
		UDim2.fromOffset(size.X, size.Y),
		colors.Accent
	)

	createLabel(
		panel,
		"ModeCode",
		"LAB_01 // SESSION",
		UDim2.fromOffset(13, 9),
		UDim2.new(1, -26, 0, 15),
		9,
		colors.TextMuted
	)
	createLabel(
		panel,
		"Mode",
		"MOVEMENT LAB",
		UDim2.fromOffset(13, 23),
		UDim2.new(1, -26, 0, 22),
		15,
		colors.Text
	).Font = UIStyle.Fonts.Strong
	createLine(
		panel,
		"Divider",
		UDim2.fromOffset(13, 48),
		UDim2.new(1, -26, 0, 1),
		colors.EdgeDark
	)
	createLabel(
		panel,
		"Timer",
		"--:--",
		UDim2.fromOffset(13, 50),
		UDim2.fromOffset(112, 34),
		style.TimerTextSize,
		colors.AccentBright
	).Font = UIStyle.Fonts.Strong
	createLabel(
		panel,
		"Round",
		"ROUND // --",
		UDim2.new(1, -111, 0, 53),
		UDim2.fromOffset(98, 17),
		10,
		colors.TextMuted,
		Enum.TextXAlignment.Right
	)
	createLabel(
		panel,
		"Score",
		"SCORE // -- : --",
		UDim2.new(1, -137, 0, 73),
		UDim2.fromOffset(124, 17),
		10,
		colors.TextMuted,
		Enum.TextXAlignment.Right
	)
	createLine(
		panel,
		"PendingMark",
		UDim2.new(1, -44, 1, -12),
		UDim2.fromOffset(31, 3),
		colors.Blood
	)
end

local function createWeaponSilhouette(parent)
	local silhouetteColor = colors.Metal
	createLine(
		parent,
		"Receiver",
		UDim2.fromOffset(15, 25),
		UDim2.fromOffset(77, 13),
		silhouetteColor,
		-3
	)
	createLine(
		parent,
		"UpperRail",
		UDim2.fromOffset(27, 19),
		UDim2.fromOffset(52, 4),
		colors.TextMuted,
		-3
	)
	createLine(
		parent,
		"Barrel",
		UDim2.fromOffset(87, 27),
		UDim2.fromOffset(42, 5),
		silhouetteColor,
		-3
	)
	createLine(
		parent,
		"Grip",
		UDim2.fromOffset(58, 37),
		UDim2.fromOffset(14, 27),
		silhouetteColor,
		-15
	)
	createLine(
		parent,
		"Stock",
		UDim2.fromOffset(5, 29),
		UDim2.fromOffset(23, 8),
		colors.TextMuted,
		12
	)
end

local function createWeaponBlock(parent)
	local size = style.WeaponSize
	local panel = createPanel(
		parent,
		"WeaponStatus",
		UDim2.new(1, -(size.X + style.ScreenMarginPixels), 1, -(size.Y + style.ScreenMarginPixels)),
		UDim2.fromOffset(size.X, size.Y),
		colors.Blood
	)

	local iconArea = Instance.new("Frame")
	iconArea.Name = "WeaponIconPlaceholder"
	iconArea.BackgroundColor3 = colors.Backdrop
	iconArea.BackgroundTransparency = 0.16
	iconArea.BorderSizePixel = 0
	iconArea.Position = UDim2.fromOffset(12, 15)
	iconArea.Size = UDim2.fromOffset(142, 74)
	iconArea.Parent = panel
	addStroke(iconArea, colors.EdgeDark, 1)
	createLine(
		iconArea,
		"ScanLine",
		UDim2.fromOffset(8, 10),
		UDim2.new(1, -16, 0, 1),
		colors.AccentDim
	)
	createWeaponSilhouette(iconArea)
	createLabel(
		iconArea,
		"Placeholder",
		"ICON // READY",
		UDim2.fromOffset(8, 57),
		UDim2.new(1, -16, 0, 12),
		8,
		colors.TextDark
	)

	local slotChip = Instance.new("Frame")
	slotChip.Name = "SlotChip"
	slotChip.BackgroundColor3 = colors.AccentDim
	slotChip.BorderSizePixel = 0
	slotChip.Position = UDim2.fromOffset(166, 14)
	slotChip.Size = UDim2.fromOffset(66, 19)
	slotChip.Parent = panel
	createLabel(
		slotChip,
		"Slot",
		"SLOT --",
		UDim2.fromOffset(6, 1),
		UDim2.new(1, -12, 1, -2),
		10,
		colors.AccentBright
	)
	createLabel(
		panel,
		"WeaponName",
		"UNARMED",
		UDim2.fromOffset(166, 35),
		UDim2.new(1, -178, 0, 25),
		style.WeaponNameTextSize,
		colors.Text
	).Font = UIStyle.Fonts.Strong
	createLabel(
		panel,
		"AmmoCurrent",
		"--",
		UDim2.fromOffset(164, 59),
		UDim2.fromOffset(68, 35),
		style.AmmoCurrentTextSize,
		colors.Text
	).Font = UIStyle.Fonts.Strong
	createLabel(
		panel,
		"AmmoDivider",
		"/",
		UDim2.fromOffset(230, 67),
		UDim2.fromOffset(18, 24),
		18,
		colors.Blood
	)
	createLabel(
		panel,
		"AmmoReserve",
		"--",
		UDim2.fromOffset(248, 71),
		UDim2.fromOffset(58, 21),
		style.AmmoReserveTextSize,
		colors.TextMuted
	)
	createLine(
		panel,
		"FooterDivider",
		UDim2.fromOffset(12, 101),
		UDim2.new(1, -24, 0, 1),
		colors.EdgeDark
	)
	createLabel(
		panel,
		"DataState",
		"WEAPON LINK // PLACEHOLDER READY",
		UDim2.fromOffset(12, 108),
		UDim2.new(1, -24, 0, 17),
		9,
		colors.TextMuted
	)
end

local function updateHealth(humanoid)
	local maximumHealth = math.max(humanoid.MaxHealth, 1)
	local health = math.clamp(humanoid.Health, 0, maximumHealth)
	healthFill.Size = UDim2.fromScale(health / maximumHealth, 1)
	healthValue.Text = string.format("%d / %d", math.round(health), math.round(maximumHealth))
end

local function bindCharacter(character)
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end

	local humanoid = character:WaitForChild("Humanoid")
	updateHealth(humanoid)
	healthConnection = humanoid.HealthChanged:Connect(function()
		updateHealth(humanoid)
	end)
end

function HUDController:Init()
	if isInitialised then
		return
	end

	isInitialised = true
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BLIKKHud")

	if existing then
		existing:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BLIKKHud"
	screenGui.DisplayOrder = UIStyle.DisplayOrders.Hud
	screenGui.IgnoreGuiInset = false
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	createStatusBlock(screenGui)
	createMatchBlock(screenGui)
	createWeaponBlock(screenGui)
	screenGui.Enabled = SessionSettings:Get("HudVisible")
	screenGui.Parent = playerGui

	SessionSettings.Changed.Event:Connect(function(key, value)
		if key == "HudVisible" then
			screenGui.Enabled = value
		end
	end)

	player.CharacterAdded:Connect(bindCharacter)

	if player.Character then
		bindCharacter(player.Character)
	end
end

return HUDController
