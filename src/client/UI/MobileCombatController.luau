local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UIAssetConfig = require(ReplicatedStorage.Shared.UI.UIAssetConfig)
local UIAtlas = require(script.Parent.UIAtlas)
local UIStyle = require(script.Parent.UIStyle)

local Controller = {}
local isInitialised = false

local STICK_ZONE_WIDTH_SCALE = 0.42
local STICK_ZONE_TOP_SCALE = 0.43
local STICK_RADIUS_PIXELS = 48
local STICK_DEAD_ZONE = 0.18
local STICK_RELEASE_ZONE = 0.12
local STICK_BASE_SIZE_PIXELS = 118

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0.18
	stroke.Parent = instance
	return stroke
end

local function createButton(parent, name, label, position, size, accent, inputManager, action, hold, atlasOptions)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.AutoButtonColor = false
	button.BackgroundColor3 = UIStyle.Colors.MobileSurface
	button.BackgroundTransparency = 0.22
	button.Position = position
	button.Size = size
	button.Font = UIStyle.Fonts.Strong
	button.Text = label
	button.TextColor3 = UIStyle.Colors.Text
	button.TextSize = 12
	button.TextStrokeTransparency = 0.4
	button.ZIndex = 3
	button.Parent = parent
	addCorner(button, math.floor(math.min(size.X.Offset, size.Y.Offset) * 0.24))
	addStroke(button, accent, 2)

	local atlasImage = if atlasOptions then UIAtlas:SkinTextButton(button, atlasOptions) else nil
	local owner = "MobileCombat:" .. name
	local activeInputs = {}
	local function releaseInput(input)
		if not activeInputs[input] then return end
		activeInputs[input] = nil
		button.BackgroundTransparency = 0.22
		if atlasImage then atlasImage.ImageColor3 = Color3.new(1, 1, 1) end
		if hold then inputManager:EndVirtualAction(owner) end
	end
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		activeInputs[input] = true
		button.BackgroundTransparency = 0.06
		if atlasImage then atlasImage.ImageColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.72) end
		inputManager:BeginVirtualAction(action, owner)
		if not hold then task.defer(function() inputManager:EndVirtualAction(owner) end) end
	end)
	button.InputEnded:Connect(releaseInput)
	-- GuiObject.InputEnded can be missed after a thumb slides outside the art.
	-- The global release prevents held fire/block from sticking in that case.
	UserInputService.InputEnded:Connect(releaseInput)
	return button
end

local function setButtonVisible(button, visible, inputManager)
	if button.Visible == visible then return end
	button.Visible = visible
	if not visible then inputManager:EndVirtualAction("MobileCombat:" .. button.Name) end
end

function Controller:Init(inputManager, fighterController)
	if isInitialised then return end
	isInitialised = true
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then error("[BLIKK MOBILE] PlayerGui unavailable", 0) end
	local existing = playerGui:FindFirstChild("BLIKKMobileCombat")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BLIKKMobileCombat"
	gui.DisplayOrder = UIStyle.DisplayOrders.Hud + 4
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "TouchControls"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	-- The left side is a floating analog surface. It deliberately ends before the
	-- right-side camera region, so moving never steals an aiming touch.
	local movementZone = Instance.new("Frame")
	movementZone.Name = "MovementTouchZone"
	movementZone.Active = true
	movementZone.BackgroundTransparency = 1
	movementZone.Position = UDim2.fromScale(0, STICK_ZONE_TOP_SCALE)
	movementZone.Size = UDim2.fromScale(STICK_ZONE_WIDTH_SCALE, 1 - STICK_ZONE_TOP_SCALE)
	movementZone.ZIndex = 1
	movementZone.Parent = root

	local movementBase = Instance.new("Frame")
	movementBase.Name = "FloatingMovementStick"
	movementBase.AnchorPoint = Vector2.new(0.5, 0.5)
	movementBase.BackgroundColor3 = UIStyle.Colors.MobileSurface
	movementBase.BackgroundTransparency = 0.68
	movementBase.Size = UDim2.fromOffset(STICK_BASE_SIZE_PIXELS, STICK_BASE_SIZE_PIXELS)
	movementBase.ZIndex = 1
	movementBase.Parent = root
	addCorner(movementBase, STICK_BASE_SIZE_PIXELS)
	addStroke(movementBase, UIStyle.Colors.Purple, 2, 0.42)

	local movementRing = UIAtlas:CreateSprite(movementBase, "MobileCombatRing", "MovementRing")
	if movementRing then
		movementRing.AnchorPoint = Vector2.new(0.5, 0.5)
		movementRing.Position = UDim2.fromScale(0.5, 0.5)
		movementRing.Size = UDim2.fromScale(1, 1)
		movementRing.ImageTransparency = 0.48
		movementRing.ZIndex = 1
	end

	local movementKnob = Instance.new("Frame")
	movementKnob.Name = "Knob"
	movementKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	movementKnob.BackgroundColor3 = UIStyle.Colors.MobileSurface
	movementKnob.BackgroundTransparency = 0.12
	movementKnob.Position = UDim2.fromScale(0.5, 0.5)
	movementKnob.Size = UDim2.fromOffset(42, 42)
	movementKnob.ZIndex = 2
	movementKnob.Parent = movementBase
	addCorner(movementKnob, 42)
	addStroke(movementKnob, UIStyle.Colors.Acid, 2, 0.15)

	local activeMovementTouch = nil
	local movementCenter = Vector2.zero
	local heldDirections = {}

	local function setDirection(action, shouldHold)
		if heldDirections[action] == shouldHold then return end
		heldDirections[action] = shouldHold or nil
		local owner = "MobileStick:" .. action
		if shouldHold then inputManager:BeginVirtualAction(action, owner)
		else inputManager:EndVirtualAction(owner) end
	end

	local function clearMovement()
		for _, action in { "Forward", "Backward", "Left", "Right" } do setDirection(action, false) end
		activeMovementTouch = nil
		movementKnob.Position = UDim2.fromScale(0.5, 0.5)
		movementBase.BackgroundTransparency = 0.68
		if movementRing then movementRing.ImageTransparency = 0.48 end
	end

	local function applyStickPosition(screenPosition)
		local delta = screenPosition - movementCenter
		local magnitude = delta.Magnitude
		local clamped = if magnitude > STICK_RADIUS_PIXELS
			then delta.Unit * STICK_RADIUS_PIXELS else delta
		movementKnob.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)
		local normalized = clamped / STICK_RADIUS_PIXELS

		local function desired(axisValue, directionSign, action)
			local signed = axisValue * directionSign
			local threshold = if heldDirections[action] then STICK_RELEASE_ZONE else STICK_DEAD_ZONE
			return signed > threshold
		end
		setDirection("Right", desired(normalized.X, 1, "Right"))
		setDirection("Left", desired(normalized.X, -1, "Left"))
		setDirection("Backward", desired(normalized.Y, 1, "Backward"))
		setDirection("Forward", desired(normalized.Y, -1, "Forward"))
	end

	local function defaultMovementCenter()
		local size = root.AbsoluteSize
		return Vector2.new(
			math.clamp(size.X * 0.13, 72, 126),
			math.max(72, size.Y - math.clamp(size.Y * 0.13, 74, 112))
		)
	end

	local function placeMovementBase(center)
		local size = root.AbsoluteSize
		local radius = STICK_BASE_SIZE_PIXELS * 0.5
		local maximumX = math.max(radius + 8, size.X * STICK_ZONE_WIDTH_SCALE - radius - 8)
		local minimumY = size.Y * STICK_ZONE_TOP_SCALE + radius + 8
		movementCenter = Vector2.new(
			math.clamp(center.X, radius + 8, maximumX),
			math.clamp(center.Y, minimumY, math.max(minimumY, size.Y - radius - 8))
		)
		movementBase.Position = UDim2.fromOffset(movementCenter.X, movementCenter.Y)
	end

	local function beginMovementTouch(input)
		if activeMovementTouch or input.UserInputType ~= Enum.UserInputType.Touch then return end
		activeMovementTouch = input
		local screenPosition = Vector2.new(input.Position.X, input.Position.Y) - root.AbsolutePosition
		placeMovementBase(screenPosition)
		movementBase.BackgroundTransparency = 0.34
		if movementRing then movementRing.ImageTransparency = 0.18 end
		applyStickPosition(screenPosition)
	end
	movementZone.InputBegan:Connect(beginMovementTouch)
	movementBase.InputBegan:Connect(beginMovementTouch)
	movementKnob.InputBegan:Connect(beginMovementTouch)
	UserInputService.InputChanged:Connect(function(input)
		if input ~= activeMovementTouch then return end
		applyStickPosition(Vector2.new(input.Position.X, input.Position.Y) - root.AbsolutePosition)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == activeMovementTouch then clearMovement() end
	end)

	-- Three large inputs form the fast-tech triangle. The smaller context row stays
	-- within the same thumb arc and changes with the equipped weapon.
	local combat = Instance.new("Frame")
	combat.Name = "CombatCluster"
	combat.AnchorPoint = Vector2.new(1, 1)
	combat.BackgroundTransparency = 1
	combat.Position = UDim2.new(1, -10, 1, -10)
	combat.Size = UDim2.fromOffset(254, 190)
	combat.Parent = root

	local attackPosition = UDim2.fromOffset(211, 139)
	local attackSize = UDim2.fromOffset(72, 68)
	local fireButton = createButton(combat, "Fire", "FIRE", attackPosition, attackSize,
		UIStyle.Colors.PurpleBright, inputManager, "Primary", true, {
			IdleRegion = "MobileFire", SelectedRegion = "MobileFire", PressedRegion = "MobileFire",
		})
	local slashButton = createButton(combat, "Slash", "SLASH", attackPosition, attackSize,
		UIStyle.Colors.Purple, inputManager, "Primary", false, {
			IdleRegion = "MobileSlash", SelectedRegion = "MobileSlash", PressedRegion = "MobileSlash",
		})
	createButton(combat, "Jump", "JUMP", UDim2.fromOffset(139, 159), UDim2.fromOffset(68, 62),
		UIStyle.Colors.Acid, inputManager, "Jump", false, {
			IdleRegion = "MobileJump", SelectedRegion = "MobileJump", PressedRegion = "MobileJump",
		})
	createButton(combat, "Dash", "DASH", UDim2.fromOffset(73, 143), UDim2.fromOffset(62, 58),
		UIStyle.Colors.Acid, inputManager, "Dash", false, {
			IdleRegion = "MobileDashDiamond", SelectedRegion = "MobileDashDiamond", PressedRegion = "MobileDashDiamond",
		})
	local blockButton = createButton(combat, "Block", "BLOCK", UDim2.fromOffset(214, 64), UDim2.fromOffset(54, 50),
		UIStyle.Colors.Defence, inputManager, "Block", true, {
			IdleRegion = "MobileBlock", SelectedRegion = "MobileBlock", PressedRegion = "MobileBlock",
		})
	local altButton = createButton(combat, "Alt", "ALT", UDim2.fromOffset(151, 75), UDim2.fromOffset(52, 48),
		UIStyle.Colors.Purple, inputManager, "Secondary", false, {
			IdleRegion = "MobileAltFire", SelectedRegion = "MobileAltFire", PressedRegion = "MobileAltFire",
		})
	local reloadButton = createButton(combat, "Reload", "RLD", UDim2.fromOffset(151, 75), UDim2.fromOffset(52, 48),
		UIStyle.Colors.Acid, inputManager, "Reload", false)
	createButton(combat, "Swap", "SWAP", UDim2.fromOffset(91, 72), UDim2.fromOffset(54, 48),
		UIStyle.Colors.Metal, inputManager, "NextWeapon", false, {
			IdleRegion = "MobileSwap", SelectedRegion = "MobileSwap", PressedRegion = "MobileSwap",
		})

	local function refreshWeaponContext()
		local fighter = fighterController and fighterController:GetFighter()
		local meleeEquipped = not fighter or fighter.ActiveWeaponSlot == "Melee"
		setButtonVisible(slashButton, meleeEquipped, inputManager)
		setButtonVisible(fireButton, not meleeEquipped, inputManager)
		setButtonVisible(blockButton, meleeEquipped, inputManager)
		setButtonVisible(altButton, meleeEquipped, inputManager)
		setButtonVisible(reloadButton, not meleeEquipped, inputManager)
	end
	if fighterController then
		fighterController.LoadoutChanged.Event:Connect(function(changeType)
			if changeType == "ActiveWeaponSlot" then refreshWeaponContext() end
		end)
	end
	refreshWeaponContext()

	local standardTouchGuiStates = {}
	local function setStandardTouchGuiHidden(hidden)
		local touchGui = playerGui:FindFirstChild("TouchGui")
		if not touchGui or not touchGui:IsA("ScreenGui") then return end
		if hidden then
			if standardTouchGuiStates[touchGui] == nil then standardTouchGuiStates[touchGui] = touchGui.Enabled end
			touchGui.Enabled = false
		elseif standardTouchGuiStates[touchGui] ~= nil then
			touchGui.Enabled = standardTouchGuiStates[touchGui]
			standardTouchGuiStates[touchGui] = nil
		end
	end

	local gameplayEnabled = inputManager:IsGameplayEnabled()
	local function refresh()
		local customTouchMode = UIAssetConfig.CustomTouchControlsEnabled
			and UserInputService.TouchEnabled
			and UserInputService.PreferredInput == Enum.PreferredInput.Touch
		gui.Enabled = customTouchMode and gameplayEnabled
		setStandardTouchGuiHidden(customTouchMode)
		if not gui.Enabled then clearMovement() end

		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local shortestSide = math.min(viewport.X, viewport.Y)
		local scale = if shortestSide < 560 then 0.82 elseif shortestSide < 760 then 0.9 else 0.96
		local scaler = combat:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scaler.Scale = scale
		scaler.Parent = combat
		if activeMovementTouch == nil then placeMovementBase(defaultMovementCenter()) end
	end
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		gameplayEnabled = enabled
		refresh()
	end)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refresh)
	local camera = Workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh) end
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "TouchGui" then task.defer(refresh) end
	end)
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if activeMovementTouch == nil then placeMovementBase(defaultMovementCenter()) end
	end)
	task.defer(refresh)
end

return Controller
