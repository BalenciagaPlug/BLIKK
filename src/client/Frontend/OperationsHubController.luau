local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local CharacterPreviewController = require(script.Parent.CharacterPreviewController)
local FrontendLayout = require(script.Parent.FrontendLayout)

local OperationsHubController = {}

local COLORS = {
	Background = Color3.fromRGB(6, 7, 7),
	Panel = Color3.fromRGB(10, 12, 12),
	Surface = Color3.fromRGB(17, 19, 19),
	Border = Color3.fromRGB(55, 61, 56),
	Text = Color3.fromRGB(235, 232, 218),
	Muted = Color3.fromRGB(142, 146, 137),
	Accent = Color3.fromRGB(154, 213, 83),
}

local function makeLabel(parent, text, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.Text = text
	label.TextColor3 = color or COLORS.Text
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Position = position
	label.Size = size
	label.Parent = parent
	return label
end

local function stylePanel(panel)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Border
	stroke.Parent = panel
end

local function makeButton(parent, text, order)
	local button = Instance.new("TextButton")
	button.Name = text:gsub(" ", "")
	button.LayoutOrder = order
	button.AutoButtonColor = false
	button.BackgroundColor3 = COLORS.Surface
	button.Font = Enum.Font.Code
	button.Text = "  " .. text
	button.TextColor3 = COLORS.Text
	button.TextSize = 16
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Size = UDim2.new(1, 0, 0, 48)
	button.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Border
	stroke.Parent = button
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Color3.fromRGB(25, 29, 27)
		stroke.Color = COLORS.Accent
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = COLORS.Surface
		stroke.Color = COLORS.Border
	end)
	return button
end

function OperationsHubController:CreatePage(parent, enterMovementLab, openSettings, openMultiplayer, openClans, inputManager)
	local page = Instance.new("Frame")
	page.Name = "OperationsHub"
	page.BackgroundColor3 = COLORS.Background
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = parent

	local canvas = FrontendLayout:CreateCanvas(page)
	Branding.CreateFullLogo(canvas, {
		Position = UDim2.fromOffset(20, 0),
		Size = Branding.Sizes.OperationsHub,
	})

	local menu = Instance.new("Frame")
	menu.Name = "OperationsMenu"
	menu.Position = UDim2.fromOffset(24, 124)
	menu.Size = UDim2.new(0.25, -30, 1, -150)
	stylePanel(menu)
	menu.Parent = canvas

	local menuPadding = Instance.new("UIPadding")
	menuPadding.PaddingTop = UDim.new(0, 18)
	menuPadding.PaddingBottom = UDim.new(0, 18)
	menuPadding.PaddingLeft = UDim.new(0, 16)
	menuPadding.PaddingRight = UDim.new(0, 16)
	menuPadding.Parent = menu
	local menuLayout = Instance.new("UIListLayout")
	menuLayout.Padding = UDim.new(0, 10)
	menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	menuLayout.Parent = menu

	local content = Instance.new("Frame")
	content.Name = "OperationDetails"
	content.Position = UDim2.new(0.25, 6, 0, 124)
	content.Size = UDim2.new(0.3, -12, 1, -150)
	stylePanel(content)
	content.Parent = canvas
	local contentTitle = makeLabel(content, "", UDim2.fromOffset(20, 24), UDim2.new(1, -40, 0, 56), 24)
	local contentText = makeLabel(content, "", UDim2.fromOffset(20, 92), UDim2.new(1, -40, 1, -116), 14, COLORS.Muted)

	local showcase = Instance.new("Frame")
	showcase.Name = "FighterShowcase"
	showcase.Position = UDim2.new(0.55, 6, 0, 124)
	showcase.Size = UDim2.new(0.45, -30, 1, -150)
	stylePanel(showcase)
	showcase.Parent = canvas
	local preview = Instance.new("ViewportFrame")
	preview.Name = "FighterViewport"
	preview.BackgroundColor3 = Color3.fromRGB(12, 14, 14)
	preview.BorderSizePixel = 0
	preview.Position = UDim2.fromOffset(12, 12)
	preview.Size = UDim2.new(1, -24, 1, -70)
	preview.Ambient = Color3.fromRGB(100, 105, 100)
	preview.LightColor = Color3.fromRGB(220, 220, 208)
	preview.Parent = showcase
	local previewCaption = makeLabel(showcase, "ACTIVE FIGHTER", UDim2.new(0, 12, 1, -48), UDim2.new(1, -24, 0, 30), 13, COLORS.Muted)

	local exitOverlay = Instance.new("Frame")
	exitOverlay.Name = "LeaveInstructions"
	exitOverlay.Active = true
	exitOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	exitOverlay.BackgroundTransparency = 0.28
	exitOverlay.Size = UDim2.fromScale(1, 1)
	exitOverlay.Visible = false
	exitOverlay.ZIndex = 40
	exitOverlay.Parent = canvas
	local exitDialog = Instance.new("Frame")
	exitDialog.AnchorPoint = Vector2.new(0.5, 0.5)
	exitDialog.BackgroundColor3 = COLORS.Panel
	exitDialog.Position = UDim2.fromScale(0.5, 0.5)
	exitDialog.Size = UDim2.fromOffset(500, 260)
	exitDialog.ZIndex = 41
	exitDialog.Parent = exitOverlay
	local exitStroke = Instance.new("UIStroke")
	exitStroke.Color = Color3.fromRGB(113, 48, 126)
	exitStroke.Thickness = 2
	exitStroke.Parent = exitDialog
	local exitTitle = makeLabel(exitDialog, "LEAVE BLIKK?", UDim2.fromOffset(24, 22), UDim2.new(1, -48, 0, 34), 24, COLORS.Text)
	exitTitle.TextXAlignment = Enum.TextXAlignment.Center
	exitTitle.ZIndex = 42
	local exitInstructions = makeLabel(
		exitDialog,
		"Roblox controls session exit.\nPress ESC, then choose Leave.",
		UDim2.fromOffset(36, 72),
		UDim2.new(1, -72, 0, 72),
		15,
		COLORS.Muted
	)
	exitInstructions.TextXAlignment = Enum.TextXAlignment.Center
	exitInstructions.ZIndex = 42
	local returnButton = makeButton(exitDialog, "RETURN", 1)
	returnButton.Position = UDim2.fromOffset(36, 190)
	returnButton.Size = UDim2.fromOffset(200, 44)
	returnButton.TextXAlignment = Enum.TextXAlignment.Center
	returnButton.ZIndex = 42
	local howButton = makeButton(exitDialog, "HOW TO LEAVE", 2)
	howButton.Position = UDim2.new(1, -236, 0, 190)
	howButton.Size = UDim2.fromOffset(200, 44)
	howButton.TextXAlignment = Enum.TextXAlignment.Center
	howButton.ZIndex = 42

	local function closeExitInstructions()
		exitOverlay.Visible = false
		exitInstructions.Text = "Roblox controls session exit.\nPress ESC, then choose Leave."
		exitInstructions.TextColor3 = COLORS.Muted
	end
	local function openExitInstructions()
		if exitOverlay.Visible then return end
		exitOverlay.Visible = true
	end
	returnButton.Activated:Connect(closeExitInstructions)
	howButton.Activated:Connect(function()
		exitInstructions.Text = "ESC  →  LEAVE\nUse Roblox's own menu to exit safely."
		exitInstructions.TextColor3 = COLORS.Accent
	end)
	UserInputService.InputBegan:Connect(function(input)
		if exitOverlay.Visible and input.KeyCode == Enum.KeyCode.Escape then closeExitInstructions() end
	end)
	inputManager.ActionBegan.Event:Connect(function(action)
		if exitOverlay.Visible and (action == "Settings" or action == "Cancel") then closeExitInstructions() end
	end)

	local sections = {}
	local function register(name, description, action)
		sections[name] = { Description = description, Action = action }
	end
	register("MULTIPLAYER", "BROWSE PUBLIC ROOMS OR CREATE A RESERVED MATCH SERVER.", openMultiplayer)
	register("MOVEMENT LAB", "TRAIN CAMERA-RELATIVE MOVEMENT AND DASH TIMING.", enterMovementLab)
	register("SHOP", "SHOP SYSTEMS ARE NOT IMPLEMENTED.")
	register("INVENTORY", "INVENTORY MANAGEMENT IS NOT IMPLEMENTED. STARTER LOADOUT IS ACTIVE.")
	register("CHARACTER", "CHARACTER APPEARANCE EDITING AFTER CREATION IS PLANNED.")
	register("CLANS", "CREATE AND MANAGE YOUR BLIKK CLAN.", openClans)
	register("SETTINGS", "OPEN THE SHARED BLIKK SESSION SETTINGS.", openSettings)

	for index, name in { "MULTIPLAYER", "MOVEMENT LAB", "CLANS", "SHOP", "INVENTORY", "CHARACTER", "SETTINGS", "EXIT" } do
		local button = makeButton(menu, name, index)
		button.Activated:Connect(function()
			if name == "EXIT" then openExitInstructions(); return end
			local section = sections[name]
			contentTitle.Text = name
			contentText.Text = section.Description
			if section.Action then
				section.Action()
			end
		end)
	end

	local currentProfile = nil
	local object = {}
	function object:SetVisible(visible, profile)
		page.Visible = visible
		if visible then
			currentProfile = profile or currentProfile
			contentTitle.Text = currentProfile and currentProfile.Name:upper() or "OPERATIONS HUB"
			if currentProfile then
				local appearance = currentProfile.Appearance
				contentText.Text = string.format(
					"%s FIGHTER // LEVEL %d\n\nFACE // %s\nHAIR // %s\nTOP // %s\nPANTS // %s\nBOOTS // %s\n\nIDLE HOOK READY // 8-20 SECONDS",
					currentProfile.BodyType:upper(), currentProfile.Level, appearance.Face, appearance.Hair,
					appearance.TopArmour, appearance.Pants, appearance.Boots
				)
			else
				contentText.Text = "NO FIGHTER SELECTED"
			end
			previewCaption.Text = currentProfile and (currentProfile.Name:upper() .. " // PROFILE") or "ACTIVE FIGHTER"
			CharacterPreviewController:Render(preview, currentProfile, true)
		else
			closeExitInstructions()
			CharacterPreviewController:Stop()
		end
	end
	return object
end

return OperationsHubController
