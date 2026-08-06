local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local UIStyle = require(script.Parent.UIStyle)
local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local MeleeConfig = require(ReplicatedStorage.Shared.Combat.MeleePresentationConfig)

local HUDController = {}

local player = Players.LocalPlayer
local colors = UIStyle.Colors
local style = UIStyle.HUD
local isInitialised = false
local screenGui = nil
local healthFill = nil
local healthValue = nil
local healthConnection = nil
local statusRoot = nil
local weaponRoot = nil
local weaponSlotLabel = nil
local weaponNameLabel = nil
local weaponStatsLabel = nil
local ammoTrack = nil
local ammoLabel = nil
local weaponSilhouette = nil
local dataStateLabel = nil

local function applyHudScale()
	local scale = SessionSettings:Get("UIScale") * SessionSettings:Get("HudScale")
	for _, target in { statusRoot, weaponRoot } do
		if target then
			local scaler = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scaler.Scale = scale
			scaler.Parent = target
		end
	end
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
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.25
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

local function createRivet(parent, position)
	local rivet = Instance.new("Frame")
	rivet.AnchorPoint = Vector2.new(0.5, 0.5)
	rivet.BackgroundColor3 = colors.Backdrop
	rivet.Position = position
	rivet.Size = UDim2.fromOffset(14, 14)
	rivet.ZIndex = 5
	rivet.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = rivet
	addStroke(rivet, colors.Metal, 2)
	createLine(rivet, "Slot", UDim2.fromOffset(3, 6), UDim2.fromOffset(8, 2), colors.Metal, -22)
end

local function createEmblem(parent)
	local holder = Instance.new("Frame")
	holder.Name = "BLIKKEmblem"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 10)
	holder.Size = UDim2.fromOffset(style.EmblemSizePixels, style.EmblemSizePixels)
	holder.ZIndex = 4
	holder.Parent = parent

	local diamond = Instance.new("Frame")
	diamond.Name = "MetalDiamond"
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.BackgroundColor3 = colors.Metal
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Rotation = 45
	diamond.Size = UDim2.fromOffset(88, 88)
	diamond.ZIndex = 4
	diamond.Parent = holder
	addStroke(diamond, colors.EdgeDark, 4)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colors.TextMuted, colors.PanelLight)
	gradient.Rotation = 90
	gradient.Parent = diamond

	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundColor3 = colors.Panel
	inner.BackgroundTransparency = 0.12
	inner.ClipsDescendants = true
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromOffset(70, 70)
	inner.ZIndex = 5
	inner.Parent = diamond
	addStroke(inner, colors.Backdrop, 2)

	Branding.CreateIconLogo(inner, {
		Name = "Brand",
		Color = colors.Text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.57),
		Rotation = -45,
		Size = UDim2.fromScale(3.0375, 3.0375),
		ZIndex = 6,
	})

	createRivet(holder, UDim2.fromOffset(63, 4))
	createRivet(holder, UDim2.fromOffset(122, 63))
	createRivet(holder, UDim2.fromOffset(63, 122))
	createRivet(holder, UDim2.fromOffset(4, 63))
end

local function createMeter(parent, name, positionY, height, fillColor, darkColor, initialScale)
	local railStart = style.StatusRailStartPixels
	local track = Instance.new("Frame")
	track.Name = name .. "Track"
	track.BackgroundColor3 = colors.Backdrop
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(railStart, positionY)
	track.Size = UDim2.fromOffset(style.StatusRailWidthPixels, height)
	track.Parent = parent
	addStroke(track, colors.Metal, 2)

	local inset = Instance.new("Frame")
	inset.Name = "Inset"
	inset.BackgroundColor3 = colors.EdgeDark
	inset.BorderSizePixel = 0
	inset.Position = UDim2.fromOffset(4, 4)
	inset.Size = UDim2.new(1, -8, 1, -8)
	inset.ClipsDescendants = true
	inset.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(initialScale, 1)
	fill.Parent = inset
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(darkColor, fillColor)
	gradient.Rotation = 90
	gradient.Parent = fill

	createLine(
		track,
		"LowerWear",
		UDim2.new(0, 4, 1, -5),
		UDim2.new(1, -8, 0, 1),
		colors.TextDark
	)
	for index = 1, 5 do
		createLine(
			track,
			"Wear" .. index,
			UDim2.fromOffset(28 + index * 67, 4 + (index % 2) * 7),
			UDim2.fromOffset(18 + (index % 3) * 5, 1),
			colors.TextMuted,
			-8 + index * 3
		).BackgroundTransparency = 0.72
	end
	createLine(
		track,
		"EndCap",
		UDim2.new(1, -12, 0, 2),
		UDim2.fromOffset(8, height - 4),
		colors.Metal,
		-20
	)

	return fill, track
end

local function createStatusBlock(parent)
	local root = Instance.new("Frame")
	root.Name = "PlayerStatus"
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromOffset(8, 5)
	root.Size = UDim2.fromOffset(style.StatusSize.X, style.StatusSize.Y)
	root.Parent = parent
	statusRoot = root
	Instance.new("UIScale").Parent = root

	createLine(
		root,
		"TopBrace",
		UDim2.fromOffset(style.StatusRailStartPixels - 9, 25),
		UDim2.fromOffset(style.StatusRailWidthPixels + 18, 5),
		colors.Metal
	)
	local level = createLabel(
		root,
		"Level",
		"LV. --",
		UDim2.fromOffset(style.StatusRailStartPixels + 8, 0),
		UDim2.fromOffset(78, 27),
		22,
		colors.TextMuted
	)
	level.Font = UIStyle.Fonts.Gothic
	createLabel(
		root,
		"PlayerName",
		string.upper(player.DisplayName),
		UDim2.fromOffset(style.StatusRailStartPixels + 94, 4),
		UDim2.fromOffset(280, 23),
		15,
		colors.Text
	)

	healthFill = createMeter(
		root,
		"Health",
		31,
		style.PrimaryBarHeightPixels,
		Color3.fromRGB(31, 142, 221),
		Color3.fromRGB(13, 66, 118),
		1
	)
	createMeter(
		root,
		"Armour",
		61,
		style.PrimaryBarHeightPixels,
		colors.Accent,
		colors.TechniqueDark,
		0
	)

	healthValue = createLabel(
		root,
		"HealthValue",
		"-- / --",
		UDim2.fromOffset(style.StatusRailStartPixels, 33),
		UDim2.fromOffset(style.StatusRailWidthPixels, 18),
		13,
		colors.Text,
		Enum.TextXAlignment.Center
	)
	createLabel(
		root,
		"ArmourValue",
		"ARMOUR // --",
		UDim2.fromOffset(style.StatusRailStartPixels, 63),
		UDim2.fromOffset(style.StatusRailWidthPixels, 18),
		12,
		colors.TextMuted,
		Enum.TextXAlignment.Center
	)
	createLabel(
		root,
		"PrototypeState",
		"MOVEMENT LAB // LOCAL PROTOTYPE",
		UDim2.fromOffset(style.StatusRailStartPixels + 4, 91),
		UDim2.fromOffset(340, 15),
		9,
		colors.TextMuted
	)
	createEmblem(root)
end

local function createWeaponSilhouette(parent)
	local metal = colors.Metal
	createLine(parent, "Receiver", UDim2.fromOffset(28, 18), UDim2.fromOffset(150, 14), metal, -2)
	createLine(parent, "Rail", UDim2.fromOffset(52, 10), UDim2.fromOffset(92, 5), colors.TextMuted, -2)
	createLine(parent, "Barrel", UDim2.fromOffset(174, 20), UDim2.fromOffset(104, 6), metal, -2)
	createLine(parent, "Stock", UDim2.fromOffset(2, 20), UDim2.fromOffset(45, 10), colors.TextMuted, 10)
	createLine(parent, "Grip", UDim2.fromOffset(119, 30), UDim2.fromOffset(16, 31), metal, -14)
end

local function createKatanaSilhouette(parent)
	createLine(parent, "Blade", UDim2.fromOffset(69, 27), UDim2.fromOffset(202, 7), colors.TextMuted, -8)
	createLine(parent, "Edge", UDim2.fromOffset(72, 24), UDim2.fromOffset(198, 2), colors.Text, -8)
	createLine(parent, "Guard", UDim2.fromOffset(54, 27), UDim2.fromOffset(31, 5), colors.Accent, -8)
	createLine(parent, "Grip", UDim2.fromOffset(7, 33), UDim2.fromOffset(55, 9), colors.Metal, -8)
	createLine(parent, "Pommel", UDim2.fromOffset(3, 36), UDim2.fromOffset(10, 13), colors.TechniqueDark, -8)
end

local function createWeaponBlock(parent)
	local size = style.WeaponSize
	local root = Instance.new("Frame")
	root.Name = "WeaponStatus"
	root.BackgroundTransparency = 1
	root.Position = UDim2.new(1, -(size.X + 20), 1, -(size.Y + 18))
	root.Size = UDim2.fromOffset(size.X, size.Y)
	root.Parent = parent
	weaponRoot = root
	Instance.new("UIScale").Parent = root

	weaponSlotLabel = createLabel(root, "Slot", "SLOT --", UDim2.fromOffset(4, 0), UDim2.fromOffset(110, 18), 10, colors.Accent)
	weaponNameLabel = createLabel(
		root,
		"WeaponName",
		"UNARMED",
		UDim2.fromOffset(4, 17),
		UDim2.fromOffset(250, 24),
		style.WeaponNameTextSize,
		colors.Text
	)
	weaponNameLabel.Font = UIStyle.Fonts.Strong
	weaponNameLabel.TextStrokeTransparency = 0
	weaponNameLabel.TextColor3 = Color3.fromRGB(255, 252, 235)
	weaponStatsLabel = createLabel(
		root,
		"WeaponStats",
		"DAMAGE --  |  DELAY --",
		UDim2.fromOffset(4, 42),
		UDim2.fromOffset(260, 18),
		11,
		colors.TextMuted
	)

	ammoTrack = Instance.new("Frame")
	ammoTrack.Name = "AmmoTrack"
	ammoTrack.BackgroundColor3 = colors.Text
	ammoTrack.BorderSizePixel = 0
	ammoTrack.Position = UDim2.fromOffset(4, 66)
	ammoTrack.Size = UDim2.fromOffset(218, 13)
	ammoTrack.Parent = root
	addStroke(ammoTrack, colors.EdgeDark, 2)
	ammoLabel = createLabel(
		root,
		"Ammo",
		"-- / --",
		UDim2.fromOffset(233, 62),
		UDim2.fromOffset(103, 22),
		15,
		colors.Text,
		Enum.TextXAlignment.Right
	)

	weaponSilhouette = Instance.new("Frame")
	weaponSilhouette.Name = "WeaponIconPlaceholder"
	weaponSilhouette.BackgroundTransparency = 1
	weaponSilhouette.Position = UDim2.fromOffset(34, 88)
	weaponSilhouette.Size = UDim2.fromOffset(288, 62)
	weaponSilhouette.Parent = root
	createWeaponSilhouette(weaponSilhouette)
	dataStateLabel = createLabel(
		root,
		"DataState",
		"WEAPON DATA // PLACEHOLDER READY",
		UDim2.fromOffset(4, 136),
		UDim2.fromOffset(250, 14),
		8,
		colors.TextMuted
	)
end

local function clearSilhouette()
	for _, child in weaponSilhouette:GetChildren() do child:Destroy() end
end

local function updateWeapon(fighterController)
	local fighter = fighterController:GetFighter()
	local slotId = fighter.ActiveWeaponSlot
	local definition = fighterController:GetWeaponDefinition(slotId)
	if not definition then return end
	weaponSlotLabel.Text = "SLOT // " .. (slotId == "Melee" and "MELEE" or string.upper(slotId))
	weaponNameLabel.Text = definition.DisplayName
	clearSilhouette()
	if slotId == "Melee" and definition.Id == "TrainingKatana" then
		local total = MeleeConfig.Slash.AnticipationSeconds + MeleeConfig.Slash.ActiveSeconds + MeleeConfig.Slash.RecoverySeconds
		weaponStatsLabel.Text = string.format("DAMAGE --  |  SLASH %.0f MS", total * 1000)
		ammoTrack.Visible = false
		ammoLabel.Visible = false
		dataStateLabel.Text = "PRESENTATION ONLY // NO HITBOX"
		createKatanaSilhouette(weaponSilhouette)
	else
		weaponStatsLabel.Text = "DAMAGE --  |  DELAY --"
		ammoTrack.Visible = true
		ammoLabel.Visible = true
		ammoLabel.Text = "-- / --"
		dataStateLabel.Text = "WEAPON DATA // PLACEHOLDER READY"
		createWeaponSilhouette(weaponSilhouette)
	end
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

function HUDController:Init(fighterController)
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
	createWeaponBlock(screenGui)
	updateWeapon(fighterController)
	applyHudScale()
	screenGui.Enabled = SessionSettings:Get("HudVisible")
	screenGui.Parent = playerGui

	SessionSettings.Changed.Event:Connect(function(key, value)
		if key == "HudVisible" then
			screenGui.Enabled = value
		elseif key == "UIScale" or key == "HudScale" then
			applyHudScale()
		end
	end)

	player.CharacterAdded:Connect(bindCharacter)
	fighterController.LoadoutChanged.Event:Connect(function(changeType)
		if changeType == "ActiveWeaponSlot" or changeType == "Weapon" then updateWeapon(fighterController) end
	end)

	if player.Character then
		bindCharacter(player.Character)
	end
end

return HUDController
