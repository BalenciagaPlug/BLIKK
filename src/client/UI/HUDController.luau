local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local UIAtlas = require(script.Parent.UIAtlas)
local UIStyle = require(script.Parent.UIStyle)
local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local CharacterDependency = require(ReplicatedStorage.Shared.Character.CharacterDependency)
local FighterVitalsConfig = require(ReplicatedStorage.Shared.Combat.FighterVitalsConfig)
local MeleeConfig = require(ReplicatedStorage.Shared.Combat.MeleePresentationConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)
local RecoveryConfig = require(ReplicatedStorage.Shared.Recovery.RecoveryConfig)

local HUDController = {}

local player = Players.LocalPlayer
local colors = UIStyle.Colors
local style = UIStyle.HUD
local isInitialised = false
local screenGui = nil
local healthFill = nil
local healthValue = nil
local armourFill = nil
local armourValue = nil
local healthConnection = nil
local maximumHealthConnection = nil
local armourConnection = nil
local maximumArmourConnection = nil
local characterGeneration = 0
local healthCharacter = nil
local characterBindingTarget = nil
local cancelDependencyWatch = nil
local statusRoot = nil
local weaponRoot = nil
local weaponSlotLabel = nil
local weaponNameLabel = nil
local weaponStatsLabel = nil
local ammoTrack = nil
local ammoLabel = nil
local weaponSilhouette = nil
local dataStateLabel = nil
local recoveryRoot = nil
local recoveryLabels = {}
local recoverySlots = {}
local recoveryAttributeConnections = {}
local addStroke
local createLabel

local function applyHudScale()
	local baseScale = SessionSettings:Get("UIScale") * SessionSettings:Get("HudScale")
	local touch = UserInputService.TouchEnabled
		and UserInputService.PreferredInput == Enum.PreferredInput.Touch
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local shortestSide = math.min(viewport.X, viewport.Y)
	local deviceScale = if not touch then 1 elseif shortestSide < 560 then 0.46 elseif shortestSide < 760 then 0.52 else 0.58
	if touch then baseScale = math.clamp(baseScale, 0.75, 1.12) end
	for _, target in { statusRoot, weaponRoot } do
		if target then
			local scaler = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scaler.Scale = baseScale * deviceScale
			scaler.Parent = target
		end
	end
	if recoveryRoot then recoveryRoot.Visible = not touch end
	if statusRoot then
		local prototypeState = statusRoot:FindFirstChild("PrototypeState")
		if prototypeState then prototypeState.Visible = not touch end
	end
	if weaponSilhouette then weaponSilhouette.Visible = not touch end
	if weaponRoot then
		weaponRoot.Position = if touch
			then UDim2.fromOffset(8, math.floor(style.StatusSize.Y * deviceScale) + 10)
			else UDim2.new(1, -(style.WeaponSize.X + 20), 1, -(style.WeaponSize.Y + 18))
	end
end

local function createRecoveryBlock(parent)
	local root = Instance.new("Frame")
	root.Name = "RecoveryBelt"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.BackgroundColor3 = colors.Backdrop
	root.BackgroundTransparency = 0.18
	root.BorderSizePixel = 0
	root.Position = UDim2.new(0.5, 0, 1, -18)
	root.Size = UDim2.fromOffset(500, 52)
	root.Parent = parent
	recoveryRoot = root
	Instance.new("UIScale").Parent = root
	addStroke(root, colors.Metal, 2)

	for index, itemId in RecoveryConfig.InventoryOrder do
		local definition = RecoveryConfig.Definitions[itemId]
		local slot = Instance.new("Frame")
		slot.Name = itemId
		slot.BackgroundColor3 = colors.Panel
		slot.BackgroundTransparency = 0.12
		slot.BorderSizePixel = 0
		slot.Position = UDim2.fromOffset(5 + (index - 1) * 123, 5)
		slot.Size = UDim2.fromOffset(118, 42)
		slot.Parent = root
		recoverySlots[itemId] = slot
		local edge = Instance.new("Frame")
		edge.BackgroundColor3 = definition.Color
		edge.BorderSizePixel = 0
		edge.Size = UDim2.fromOffset(4, 42)
		edge.Parent = slot
		local label = createLabel(
			slot,
			"Status",
			string.format("%d // %s\nX--", index + 3, definition.ShortName),
			UDim2.fromOffset(9, 3),
			UDim2.fromOffset(105, 36),
			11,
			colors.Text
		)
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		label.TextYAlignment = Enum.TextYAlignment.Center
		recoveryLabels[itemId] = label
	end
end

local function updateRecovery(recoveryController)
	for index, itemId in RecoveryConfig.InventoryOrder do
		local definition = RecoveryConfig.Definitions[itemId]
		local count = recoveryController:GetCount(itemId)
		local label = recoveryLabels[itemId]
		local slot = recoverySlots[itemId]
		local equipped = recoveryController:GetEquippedItem() == itemId
		if label then
			label.Text = string.format("%d // %s%s\nX%d", index + 3, definition.ShortName,
				if equipped then " // READY" else "", count)
			label.TextColor3 = if count > 0 then colors.Text else colors.TextMuted
		end
		if slot then
			slot.BackgroundColor3 = if equipped then definition.Color:Lerp(colors.Panel, 0.72) else colors.Panel
		end
	end
end

local function disconnectRecoveryAttributes()
	for _, connection in recoveryAttributeConnections do connection:Disconnect() end
	table.clear(recoveryAttributeConnections)
end

addStroke = function(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = instance
end

createLabel = function(parent, name, text, position, size, textSize, color, alignment)
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
	if UIAtlas:IsAvailable("HudVitals") then
		-- The production vitals image already owns the metal octagon. Only place the
		-- approved mark in its clear center; a second procedural shell caused the old
		-- HUD to sit on top of the new artwork.
		Branding.CreateIconLogo(holder, {
			Name = "Brand",
			Color = colors.Text,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.84, 0.84),
			ZIndex = 6,
		})
		return
	end

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
	local usingProductionVitals = UIAtlas:IsAvailable("HudVitals")
	local track = Instance.new("Frame")
	track.Name = name .. "Track"
	track.BackgroundColor3 = colors.Backdrop
	track.BackgroundTransparency = if usingProductionVitals then 1 else 0
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(railStart, positionY)
	track.Size = UDim2.fromOffset(style.StatusRailWidthPixels, height)
	track.ClipsDescendants = true
	track.ZIndex = 1
	track.Parent = parent
	if not usingProductionVitals then addStroke(track, colors.Metal, 2) end

	local inset = Instance.new("Frame")
	inset.Name = "Inset"
	inset.BackgroundColor3 = colors.EdgeDark
	inset.BackgroundTransparency = if usingProductionVitals then 1 else 0
	inset.BorderSizePixel = 0
	inset.Position = UDim2.fromOffset(3, 3)
	inset.Size = UDim2.new(1, -6, 1, -6)
	inset.ClipsDescendants = true
	inset.ZIndex = 1
	inset.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "FillClip"
	fill.BackgroundTransparency = 1
	fill.BorderSizePixel = 0
	fill.ClipsDescendants = true
	fill.Size = UDim2.fromScale(initialScale, 1)
	fill.ZIndex = 1
	fill.Parent = inset

	local fillRegion = if name == "Armour" then "HudArmourFill" else "HudHealthFill"
	local texture = UIAtlas:CreateSprite(fill, fillRegion, "AuthoredMeterFill")
	if texture then
		texture.Position = UDim2.fromOffset(0, 0)
		texture.Size = UDim2.new(0, style.StatusRailWidthPixels - 6, 1, 0)
		texture.ZIndex = fill.ZIndex
	else
		-- Safe fallback while a newly imported fill is moderating. The shape and
		-- metalwork still come from the authored frame; this layer only carries data.
		local fallback = Instance.new("Frame")
		fallback.Name = "FallbackFill"
		fallback.BackgroundColor3 = fillColor
		fallback.BorderSizePixel = 0
		fallback.Size = UDim2.new(0, style.StatusRailWidthPixels - 6, 1, 0)
		fallback.Parent = fill
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(darkColor, fillColor)
		gradient.Rotation = 90
		gradient.Parent = fallback
	end

	if not usingProductionVitals then
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
	end

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
	local authoredFrame = UIAtlas:SkinPanel(root, "HudVitals", 0.02)
	if authoredFrame then
		-- The authored metalwork is a mask over the live AP/HP fills. Keeping the
		-- frame above the clipped meters prevents either fill escaping its slot.
		authoredFrame.ZIndex = 3
	end
	Instance.new("UIScale").Parent = root

	if not UIAtlas:IsAvailable("HudVitals") then
		createLine(
			root,
			"TopBrace",
			UDim2.fromOffset(style.StatusRailStartPixels - 9, 25),
			UDim2.fromOffset(style.StatusRailWidthPixels + 18, 5),
			colors.Metal
		)
	end
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
	level.ZIndex = 4
	local playerName = createLabel(
		root,
		"PlayerName",
		string.upper(player.DisplayName),
		UDim2.fromOffset(style.StatusRailStartPixels + 94, 4),
		UDim2.fromOffset(280, 23),
		15,
		colors.Text
	)
	playerName.ZIndex = 4

	armourFill = createMeter(
		root,
		"Armour",
		31,
		style.PrimaryBarHeightPixels,
		colors.Defence,
		colors.DefenceDark,
		1
	)
	healthFill = createMeter(
		root,
		"Health",
		61,
		style.PrimaryBarHeightPixels,
		colors.Health,
		colors.HealthDark,
		1
	)

	armourValue = createLabel(
		root,
		"ArmourValue",
		"AP // -- / --",
		UDim2.fromOffset(style.StatusRailStartPixels, 33),
		UDim2.fromOffset(style.StatusRailWidthPixels, 18),
		13,
		colors.Text,
		Enum.TextXAlignment.Center
	)
	armourValue.ZIndex = 4
	healthValue = createLabel(
		root,
		"HealthValue",
		"HP // -- / --",
		UDim2.fromOffset(style.StatusRailStartPixels, 63),
		UDim2.fromOffset(style.StatusRailWidthPixels, 18),
		12,
		colors.TextMuted,
		Enum.TextXAlignment.Center
	)
	healthValue.ZIndex = 4
	local prototypeState = createLabel(
		root,
		"PrototypeState",
		"MOVEMENT LAB // LOCAL PROTOTYPE",
		UDim2.fromOffset(style.StatusRailStartPixels + 4, 91),
		UDim2.fromOffset(340, 15),
		9,
		colors.TextMuted
	)
	prototypeState.ZIndex = 4
	createEmblem(root)
end

local function createWeaponSilhouette(parent)
	local metal = colors.Metal
	createLine(parent, "Receiver", UDim2.fromOffset(25, 14), UDim2.fromOffset(140, 12), metal, -2)
	createLine(parent, "Rail", UDim2.fromOffset(48, 7), UDim2.fromOffset(84, 4), colors.TextMuted, -2)
	createLine(parent, "Barrel", UDim2.fromOffset(160, 16), UDim2.fromOffset(96, 5), metal, -2)
	createLine(parent, "Stock", UDim2.fromOffset(1, 16), UDim2.fromOffset(40, 8), colors.TextMuted, 10)
	createLine(parent, "Grip", UDim2.fromOffset(108, 24), UDim2.fromOffset(14, 21), metal, -14)
end

local function createKatanaSilhouette(parent)
	createLine(parent, "Blade", UDim2.fromOffset(67, 21), UDim2.fromOffset(194, 6), colors.TextMuted, -6)
	createLine(parent, "Edge", UDim2.fromOffset(69, 19), UDim2.fromOffset(190, 2), colors.Text, -6)
	createLine(parent, "Guard", UDim2.fromOffset(51, 22), UDim2.fromOffset(28, 4), colors.Accent, -6)
	createLine(parent, "Grip", UDim2.fromOffset(8, 26), UDim2.fromOffset(50, 8), colors.Metal, -6)
	createLine(parent, "Pommel", UDim2.fromOffset(3, 29), UDim2.fromOffset(9, 11), colors.TechniqueDark, -6)
end

local function createRecoverySilhouette(parent, definition)
	if definition.Delivery == "Self" then
		createLine(parent, "Ampoule", UDim2.fromOffset(82, 25), UDim2.fromOffset(142, 16), definition.Color, -7)
		createLine(parent, "Core", UDim2.fromOffset(112, 27), UDim2.fromOffset(78, 10),
			definition.Color:Lerp(colors.Text, 0.55), -7)
		createLine(parent, "Injector", UDim2.fromOffset(214, 23), UDim2.fromOffset(32, 5), colors.Metal, -7)
	else
		local body = createLine(parent, "Patch", UDim2.fromOffset(104, 8), UDim2.fromOffset(92, 48), definition.Color, -5)
		addStroke(body, colors.Metal, 2)
		createLine(parent, "StatusStrip", UDim2.fromOffset(124, 26), UDim2.fromOffset(52, 6), colors.Text, -5)
	end
end

local function createWeaponBlock(parent)
	local size = style.WeaponSize
	local contentLeft = style.WeaponContentLeftPixels
	local contentWidth = size.X - contentLeft - style.WeaponContentRightPixels
	local ammoRailWidth = style.WeaponAmmoRailWidthPixels
	local root = Instance.new("Frame")
	root.Name = "WeaponStatus"
	root.BackgroundTransparency = 1
	root.Position = UDim2.new(1, -(size.X + 20), 1, -(size.Y + 18))
	root.Size = UDim2.fromOffset(size.X, size.Y)
	root.Parent = parent
	weaponRoot = root
	UIAtlas:SkinPanel(root, "HudWeapon", 0.04)
	Instance.new("UIScale").Parent = root

	weaponSlotLabel = createLabel(root, "Slot", "SLOT --", UDim2.fromOffset(contentLeft, 18), UDim2.fromOffset(130, 16), 9, colors.Accent)
	weaponNameLabel = createLabel(
		root,
		"WeaponName",
		"UNARMED",
		UDim2.fromOffset(contentLeft, 34),
		UDim2.fromOffset(contentWidth, 22),
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
		UDim2.fromOffset(contentLeft, 57),
		UDim2.fromOffset(contentWidth, 16),
		11,
		colors.TextMuted
	)

	ammoTrack = Instance.new("Frame")
	ammoTrack.Name = "AmmoTrack"
	ammoTrack.BackgroundColor3 = colors.Text
	ammoTrack.BorderSizePixel = 0
	ammoTrack.Position = UDim2.fromOffset(contentLeft, 78)
	ammoTrack.Size = UDim2.fromOffset(ammoRailWidth, 11)
	ammoTrack.Parent = root
	addStroke(ammoTrack, colors.EdgeDark, 2)
	ammoLabel = createLabel(
		root,
		"Ammo",
		"-- / --",
		UDim2.fromOffset(contentLeft + ammoRailWidth + 8, 73),
		UDim2.fromOffset(contentWidth - ammoRailWidth - 8, 20),
		15,
		colors.Text,
		Enum.TextXAlignment.Right
	)

	weaponSilhouette = Instance.new("Frame")
	weaponSilhouette.Name = "WeaponIconPlaceholder"
	weaponSilhouette.BackgroundTransparency = 1
	weaponSilhouette.Position = UDim2.fromOffset(style.WeaponSilhouettePosition.X, style.WeaponSilhouettePosition.Y)
	weaponSilhouette.Size = UDim2.fromOffset(style.WeaponSilhouetteSize.X, style.WeaponSilhouetteSize.Y)
	weaponSilhouette.ClipsDescendants = true
	weaponSilhouette.Parent = root
	createWeaponSilhouette(weaponSilhouette)
	dataStateLabel = createLabel(
		root,
		"DataState",
		"WEAPON DATA // PLACEHOLDER READY",
		UDim2.fromOffset(contentLeft, style.WeaponStatePositionY),
		UDim2.fromOffset(contentWidth, 12),
		8,
		colors.TextMuted
	)
end

local function clearSilhouette()
	for _, child in weaponSilhouette:GetChildren() do child:Destroy() end
end

local function updateWeapon(fighterController, firearmController, recoveryController)
	local recoveryItemId = recoveryController and recoveryController:GetEquippedItem() or nil
	local recoveryDefinition = recoveryItemId and RecoveryConfig.Definitions[recoveryItemId] or nil
	if recoveryDefinition then
		local count = recoveryController:GetCount(recoveryItemId)
		weaponSlotLabel.Text = "SLOT // EQUIPMENT"
		weaponNameLabel.Text = recoveryDefinition.DisplayName
		weaponStatsLabel.Text = string.format("+%d %s  |  STOCK X%d",
			recoveryDefinition.Recovery,
			if recoveryDefinition.Resource == "Health" then "HP" else "AP",
			count
		)
		ammoTrack.Visible = true
		ammoLabel.Visible = true
		ammoLabel.Text = string.format("X%d", count)
		ammoTrack.Size = UDim2.fromOffset(style.WeaponAmmoRailWidthPixels * math.clamp(count / recoveryDefinition.StockPerLife, 0, 1), 11)
		ammoTrack.BackgroundColor3 = if count > 0 then recoveryDefinition.Color else colors.Blood
		dataStateLabel.Text = if recoveryDefinition.Delivery == "Self" then "LMB // APPLY" else "LMB // DEPLOY"
		clearSilhouette()
		createRecoverySilhouette(weaponSilhouette, recoveryDefinition)
		return
	end
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
		local status = firearmController and firearmController:GetActiveStatus() or nil
		weaponStatsLabel.Text = "12 × 9 DAMAGE  |  1.00 S FIRE"
		ammoTrack.Visible = true
		ammoLabel.Visible = true
		if status then
			ammoLabel.Text = if status.UnlimitedReserve
				then string.format("%d / ∞", status.Chambered)
				else string.format("%d / %d", status.Chambered, status.Reserve)
			ammoTrack.Size = UDim2.fromOffset(style.WeaponAmmoRailWidthPixels * status.Chambered / 5, 11)
			ammoTrack.BackgroundColor3 = if status.Chambered == 0 then colors.Blood else colors.Text
			dataStateLabel.Text = if status.Chambered == 0 and status.State == "Ready"
				then "EMPTY // RELOAD"
				else "STATE // " .. string.upper(status.State)
		else
			ammoLabel.Text = "-- / --"
			dataStateLabel.Text = "WEAPON DATA // INITIALIZING"
		end
		createWeaponSilhouette(weaponSilhouette)
	end
end

local function updateHealth(humanoid)
	local maximumHealth = math.max(humanoid.MaxHealth, 1)
	local health = math.clamp(humanoid.Health, 0, maximumHealth)
	healthFill.Size = UDim2.fromScale(health / maximumHealth, 1)
	healthValue.Text = string.format(
		"HP // %d / %d",
		math.round(health),
		math.round(maximumHealth)
	)
end

local function updateArmour(character)
	local maximumArmour = character:GetAttribute(FighterVitalsConfig.Attributes.MaximumArmour)
	local armour = character:GetAttribute(FighterVitalsConfig.Attributes.Armour)
	maximumArmour = if type(maximumArmour) == "number" then math.max(maximumArmour, 1) else 1
	armour = if type(armour) == "number" then math.clamp(armour, 0, maximumArmour) else 0
	armourFill.Size = UDim2.fromScale(armour / maximumArmour, 1)
	armourValue.Text = string.format(
		"AP // %d / %d",
		math.round(armour),
		math.round(maximumArmour)
	)
end

local function disconnectVitals()
	if healthConnection then healthConnection:Disconnect() end
	if maximumHealthConnection then maximumHealthConnection:Disconnect() end
	if armourConnection then armourConnection:Disconnect() end
	if maximumArmourConnection then maximumArmourConnection:Disconnect() end
	healthConnection = nil
	maximumHealthConnection = nil
	armourConnection = nil
	maximumArmourConnection = nil
end

local function bindCharacter(character, recoveryController)
	characterGeneration += 1
	local bindGeneration = characterGeneration
	characterBindingTarget = character
	if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
	disconnectVitals()
	disconnectRecoveryAttributes()
	healthCharacter = nil
	cancelDependencyWatch = CharacterDependency.ObserveHumanoidAndRoot(
		character,
		MultiplayerConfig.CharacterDependencyTimeoutSeconds,
		function(humanoid)
			if bindGeneration ~= characterGeneration or characterBindingTarget ~= character
				or character ~= player.Character then return end
			updateHealth(humanoid)
			updateArmour(character)
			healthConnection = humanoid.HealthChanged:Connect(function()
				if bindGeneration == characterGeneration then updateHealth(humanoid) end
			end)
			maximumHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
				if bindGeneration == characterGeneration then updateHealth(humanoid) end
			end)
			armourConnection = character:GetAttributeChangedSignal(
				FighterVitalsConfig.Attributes.Armour
			):Connect(function()
				if bindGeneration == characterGeneration then updateArmour(character) end
			end)
			maximumArmourConnection = character:GetAttributeChangedSignal(
				FighterVitalsConfig.Attributes.MaximumArmour
			):Connect(function()
				if bindGeneration == characterGeneration then updateArmour(character) end
			end)
			healthCharacter = character
			updateRecovery(recoveryController)
			for _, itemId in RecoveryConfig.InventoryOrder do
				table.insert(recoveryAttributeConnections, character:GetAttributeChangedSignal(
					RecoveryConfig.Attributes.CountPrefix .. itemId
				):Connect(function()
					if bindGeneration == characterGeneration then updateRecovery(recoveryController) end
				end))
			end
			character:SetAttribute("BLIKK_ClientHudReady", true)
		end,
		function()
			if bindGeneration == characterGeneration and character == player.Character then
				warn("[BLIKK HUD] Character dependencies remain incomplete; continuing to observe the current character.")
			end
		end
	)
end

function HUDController:Init(fighterController, firearmController, recoveryController)
	if isInitialised then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui", MultiplayerConfig.CharacterDependencyTimeoutSeconds)
	if not playerGui then error("PlayerGui was unavailable during HUD initialization") end
	isInitialised = true
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
	updateWeapon(fighterController, firearmController, recoveryController)
	updateRecovery(recoveryController)
	applyHudScale()
	screenGui.Enabled = SessionSettings:Get("HudVisible")
	screenGui.Parent = playerGui
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(applyHudScale)
	local currentCamera = Workspace.CurrentCamera
	if currentCamera then currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyHudScale) end

	SessionSettings.Changed.Event:Connect(function(key, value)
		if key == "HudVisible" then
			screenGui.Enabled = value
		elseif key == "UIScale" or key == "HudScale" then
			applyHudScale()
		end
	end)

	player.CharacterAdded:Connect(function(character)
		bindCharacter(character, recoveryController)
	end)
	player.CharacterRemoving:Connect(function(removingCharacter)
		if removingCharacter ~= characterBindingTarget then return end
		characterGeneration += 1
		characterBindingTarget = nil
		if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
		disconnectVitals()
		disconnectRecoveryAttributes()
		healthCharacter = nil
	end)
	fighterController.LoadoutChanged.Event:Connect(function(changeType)
		if changeType == "ActiveWeaponSlot" or changeType == "Weapon" then
			updateWeapon(fighterController, firearmController, recoveryController)
		end
	end)
	if firearmController then
		firearmController.StateChanged.Event:Connect(function()
			updateWeapon(fighterController, firearmController, recoveryController)
		end)
	end
	recoveryController.InventoryChanged.Event:Connect(function()
		updateRecovery(recoveryController)
		updateWeapon(fighterController, firearmController, recoveryController)
	end)
	recoveryController.EquippedItemChanged.Event:Connect(function()
		updateRecovery(recoveryController)
		updateWeapon(fighterController, firearmController, recoveryController)
	end)

	if player.Character then
		bindCharacter(player.Character, recoveryController)
	end
end

return HUDController
