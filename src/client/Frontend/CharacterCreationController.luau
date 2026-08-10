local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local CharacterPreviewController = require(script.Parent.CharacterPreviewController)
local CharacterProfilesController = require(script.Parent.CharacterProfilesController)
local FrontendLayout = require(script.Parent.FrontendLayout)
local ProfileConfig = require(ReplicatedStorage.Shared.Character.ProfileConfig)
local UINavigationController = require(script.Parent.Parent.UI.UINavigationController)

local Controller = {}

local colors = {
	Text = Color3.fromRGB(232, 230, 216),
	Muted = Color3.fromRGB(133, 140, 132),
	Accent = Color3.fromRGB(157, 216, 83),
	Panel = Color3.fromRGB(17, 19, 19),
	Error = Color3.fromRGB(194, 68, 72),
}

local function createButton(parent, text, height)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = colors.Panel
	button.Font = Enum.Font.Code
	button.Text = text
	button.TextColor3 = colors.Text
	button.TextSize = 13
	button.Size = UDim2.new(1, 0, 0, height)
	button.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(68, 75, 69)
	stroke.Parent = button
	return button
end

function Controller:CreatePage(parent, navigation)
	local creationScope = nil
	local activationCallbacks = {}
	local optionAdjusters = {}
	local function bindActivation(control, callback)
		activationCallbacks[control] = callback
		control.Activated:Connect(callback)
	end
	local page = Instance.new("Frame")
	page.Name = "CharacterCreation"
	page.BackgroundColor3 = Color3.fromRGB(7, 8, 8)
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = parent
	local canvas = FrontendLayout:CreateCanvas(page)

	local form = Instance.new("Frame")
	form.BackgroundTransparency = 1
	form.Position = UDim2.new(0.03, 0, 0.05, 0)
	form.Size = UDim2.new(0.44, 0, 0.9, 0)
	form.Parent = canvas
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = form
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = form

	local logoHolder = Instance.new("Frame")
	logoHolder.LayoutOrder = 1
	logoHolder.BackgroundTransparency = 1
	logoHolder.Size = UDim2.new(1, 0, 0, 132)
	logoHolder.Parent = form
	Branding.CreateFullLogo(logoHolder, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = Branding.Sizes.CharacterCreation,
	})
	local title = Instance.new("TextLabel")
	title.LayoutOrder = 2
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.Text = "CREATE FIGHTER"
	title.TextColor3 = colors.Text
	title.TextSize = 24
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Parent = form

	local nameBox = Instance.new("TextBox")
	nameBox.LayoutOrder = 3
	nameBox.BackgroundColor3 = colors.Panel
	nameBox.ClearTextOnFocus = false
	nameBox.Font = Enum.Font.Code
	nameBox.PlaceholderText = "CHARACTER NAME"
	nameBox.Text = ""
	nameBox.TextColor3 = colors.Text
	nameBox.TextSize = 15
	nameBox.SelectionOrder = 1
	nameBox.Size = UDim2.new(1, 0, 0, 42)
	nameBox.Parent = form

	local draft = {
		BodyType = ProfileConfig.BodyTypes[1],
		Face = ProfileConfig.Faces[1],
		Hair = ProfileConfig.StarterHair[1],
		TopArmour = ProfileConfig.StarterTopArmour[1],
		Pants = ProfileConfig.StarterPants[1],
		Boots = ProfileConfig.StarterBoots[1],
	}
	local definitions = {
		{ "BodyType", ProfileConfig.BodyTypes },
		{ "Face", ProfileConfig.Faces },
		{ "Hair", ProfileConfig.StarterHair },
		{ "TopArmour", ProfileConfig.StarterTopArmour },
		{ "Pants", ProfileConfig.StarterPants },
		{ "Boots", ProfileConfig.StarterBoots },
	}

	local preview = Instance.new("ViewportFrame")
	preview.Name = "CreationPreview"
	preview.BackgroundColor3 = Color3.fromRGB(11, 13, 13)
	preview.Position = UDim2.new(0.5, 0, 0.06, 0)
	preview.Size = UDim2.new(0.47, 0, 0.88, 0)
	preview.Parent = canvas
	local previewRequestGeneration = 0
	local viewportSizeConnection = nil
	local function cancelPendingPreviewRequest()
		previewRequestGeneration += 1
		if viewportSizeConnection then viewportSizeConnection:Disconnect(); viewportSizeConnection = nil end
	end
	local function refreshPreview()
		cancelPendingPreviewRequest()
		local requestGeneration = previewRequestGeneration
		local function buildWhenReady()
			if requestGeneration ~= previewRequestGeneration or not page.Visible or not preview.Parent then return end
			local size = preview.AbsoluteSize
			if size.X < 32 or size.Y < 32 then return end
			if viewportSizeConnection then viewportSizeConnection:Disconnect(); viewportSizeConnection = nil end
			CharacterPreviewController:Render(preview, {
				Name = nameBox.Text ~= "" and nameBox.Text or "NEW FIGHTER",
				BodyType = draft.BodyType,
				Appearance = draft,
			}, false)
		end
		if preview.AbsoluteSize.X >= 32 and preview.AbsoluteSize.Y >= 32 then
			buildWhenReady()
		else
			viewportSizeConnection = preview:GetPropertyChangedSignal("AbsoluteSize"):Connect(buildWhenReady)
		end
	end
	local function schedulePreviewRefresh()
		task.defer(refreshPreview)
	end

	for index, definition in definitions do
		local control = createButton(form, definition[1]:upper() .. " // " .. draft[definition[1]], 38)
		control.LayoutOrder = 3 + index
		control.SelectionOrder = 1 + index
		control.NextSelectionUp = if index == 1 then nameBox else nil
		local function cycleOption(offset)
			local optionIndex = table.find(definition[2], draft[definition[1]]) or 0
			draft[definition[1]] = definition[2][(optionIndex - 1 + offset) % #definition[2] + 1]
			control.Text = definition[1]:upper() .. " // " .. draft[definition[1]]
			schedulePreviewRefresh()
		end
		bindActivation(control, function() cycleOption(1) end)
		optionAdjusters[control] = function(direction)
			if direction == "Left" then cycleOption(-1); return true end
			if direction == "Right" then cycleOption(1); return true end
			return false
		end
	end

	local errorLabel = Instance.new("TextLabel")
	errorLabel.LayoutOrder = 10
	errorLabel.BackgroundTransparency = 1
	errorLabel.Font = Enum.Font.Code
	errorLabel.Text = ""
	errorLabel.TextColor3 = colors.Error
	errorLabel.TextSize = 11
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.Size = UDim2.new(1, 0, 0, 22)
	errorLabel.Parent = form
	local actions = Instance.new("Frame")
	actions.LayoutOrder = 11
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.new(1, 0, 0, 44)
	actions.Parent = form
	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.Padding = UDim.new(0, 12)
	actionLayout.Parent = actions
	local confirm = createButton(actions, "CREATE", 44)
	confirm.Size = UDim2.new(0.5, -6, 1, 0)
	confirm.TextColor3 = colors.Accent
	confirm.SelectionOrder = 8
	local cancel = createButton(actions, "CANCEL", 44)
	cancel.Size = UDim2.new(0.5, -6, 1, 0)
	cancel.SelectionOrder = 9

	local isSubmitting = false
	bindActivation(confirm, function()
		if isSubmitting then return end
		isSubmitting = true
		draft.Name = nameBox.Text
		local profile, err = CharacterProfilesController:CreateProfile(draft)
		if not profile then
			errorLabel.Text = err
			isSubmitting = false
			UINavigationController:EmitAudioEvent("Denied", confirm)
			return
		end
		nameBox.Text = ""
		errorLabel.Text = ""
		UINavigationController:EmitAudioEvent("Confirm", confirm)
		navigation:GoTo("Profiles")
		isSubmitting = false
	end)
	local function returnToProfiles()
		if #CharacterProfilesController:GetProfiles() > 0 then navigation:GoTo("Profiles") end
	end
	bindActivation(cancel, returnToProfiles)

	creationScope = UINavigationController:CreateScope("CharacterCreation", {
		Root = page,
		Default = nameBox,
		Back = returnToProfiles,
	})
	creationScope:Register(nameBox)
	for control, callback in activationCallbacks do
		creationScope:Register(control, {
			Activate = callback,
			Adjust = optionAdjusters[control],
			AudioRole = if control == confirm then "Silent"
				elseif control == cancel then "Back" else "Activate",
			IsEnabled = if control == cancel then function() return cancel.Visible end else nil,
		})
	end

	local object = {}
	function object:SetVisible(visible)
		page.Visible = visible
		if visible then
			CharacterPreviewController:BeginScreenSession()
			cancel.Visible = #CharacterProfilesController:GetProfiles() > 0
			errorLabel.Text = ""
			creationScope:SetActive(true)
			creationScope:Refresh(nameBox)
			schedulePreviewRefresh()
			task.defer(function() if page.Visible then nameBox:CaptureFocus() end end)
		else
			creationScope:SetActive(false)
			if nameBox:IsFocused() then nameBox:ReleaseFocus(false) end
			cancelPendingPreviewRequest()
			CharacterPreviewController:Stop()
		end
	end
	return object
end

return Controller
