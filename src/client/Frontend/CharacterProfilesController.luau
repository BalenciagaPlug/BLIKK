local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local CharacterPreviewController = require(script.Parent.CharacterPreviewController)
local FrontendLayout = require(script.Parent.FrontendLayout)
local ProfileConfig = require(ReplicatedStorage.Shared.Character.ProfileConfig)

local Controller = {}
Controller.ProfileSelected = Instance.new("BindableEvent")

local profiles = {}
local selectedId = nil
local nextId = 1

local colors = {
	Text = Color3.fromRGB(232, 230, 216),
	Muted = Color3.fromRGB(133, 140, 132),
	Accent = Color3.fromRGB(157, 216, 83),
	Panel = Color3.fromRGB(17, 19, 19),
	Error = Color3.fromRGB(194, 68, 72),
}

local function label(parent, text, size, textSize, color)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.Code
	item.Text = text
	item.TextColor3 = color or colors.Text
	item.TextSize = textSize or 13
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Size = size
	item.Parent = parent
	return item
end

local function button(parent, text, size)
	local item = Instance.new("TextButton")
	item.AutoButtonColor = false
	item.BackgroundColor3 = colors.Panel
	item.Font = Enum.Font.Code
	item.Text = text
	item.TextColor3 = colors.Text
	item.TextSize = 13
	item.Size = size
	item.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(68, 75, 69)
	stroke.Parent = item
	return item
end

local function selectedProfile()
	for _, profile in profiles do
		if profile.Id == selectedId then return profile end
	end
	return nil
end

function Controller:GetProfiles()
	return profiles
end

function Controller:GetSelectedProfile()
	return selectedProfile()
end

function Controller:CreateProfile(data)
	if #profiles >= ProfileConfig.MaximumProfiles then return nil, "MAXIMUM OF FIVE FIGHTERS REACHED" end
	local name = tostring(data.Name or ""):match("^%s*(.-)%s*$")
	if name == "" then return nil, "ENTER A CHARACTER NAME" end
	if #name > ProfileConfig.MaximumNameLength then return nil, "NAME MUST BE 20 CHARACTERS OR FEWER" end
	if not name:match(ProfileConfig.NamePattern) then return nil, "USE LETTERS, NUMBERS, SPACES, - OR _ ONLY" end
	for _, profile in profiles do
		if profile.Name:lower() == name:lower() then return nil, "THAT CHARACTER NAME ALREADY EXISTS" end
	end

	local profile = {
		Id = nextId,
		Name = name,
		BodyType = data.BodyType,
		Level = ProfileConfig.DefaultLevel,
		LastPlayedUnix = 0,
		Appearance = {
			Face = data.Face,
			Hair = data.Hair,
			TopArmour = data.TopArmour,
			Pants = data.Pants,
			Boots = data.Boots,
		},
	}
	nextId += 1
	table.insert(profiles, profile)
	selectedId = profile.Id
	return profile
end

function Controller:DeleteSelected()
	for index, profile in profiles do
		if profile.Id == selectedId then
			table.remove(profiles, index)
			selectedId = profiles[1] and profiles[1].Id or nil
			return true
		end
	end
	return false
end

function Controller:CreatePage(parent, navigation, fighterController)
	local page = Instance.new("Frame")
	page.Name = "CharacterProfiles"
	page.BackgroundColor3 = Color3.fromRGB(7, 8, 8)
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = parent
	local canvas = FrontendLayout:CreateCanvas(page)
	Branding.CreateFullLogo(canvas, {
		Position = UDim2.fromOffset(24, 4),
		Size = Branding.Sizes.CharacterProfiles,
	})
	local header = label(canvas, "CHARACTER PROFILES", UDim2.fromOffset(600, 42), 28)
	header.Position = UDim2.fromOffset(224, 20)
	local sub = label(canvas, "LOCAL OPERATIVE REGISTRY // 5 SLOTS", UDim2.fromOffset(500, 18), 10, colors.Accent)
	sub.Position = UDim2.fromOffset(227, 63)

	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Position = UDim2.new(0.025, 0, 0.17, 0)
	left.Size = UDim2.new(0.48, 0, 0.7, 0)
	left.Parent = canvas
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 1, -60)
	list.Parent = left
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 9)
	listLayout.Parent = list
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(0, 1)
	actions.Position = UDim2.fromScale(0, 1)
	actions.Size = UDim2.new(1, 0, 0, 45)
	actions.Parent = left
	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.Padding = UDim.new(0, 10)
	actionLayout.Parent = actions

	local preview = Instance.new("ViewportFrame")
	preview.BackgroundColor3 = Color3.fromRGB(11, 13, 13)
	preview.Position = UDim2.new(0.54, 0, 0.12, 0)
	preview.Size = UDim2.new(0.435, 0, 0.68, 0)
	preview.Parent = canvas
	local appearanceLabel = label(canvas, "", UDim2.new(0.435, 0, 0.1, 0), 10, colors.Muted)
	appearanceLabel.Position = UDim2.new(0.54, 0, 0.82, 0)
	appearanceLabel.TextWrapped = true
	appearanceLabel.TextYAlignment = Enum.TextYAlignment.Top

	local function updateAppearanceLabel(profile)
		local appearance = profile and profile.Appearance
		appearanceLabel.Text = appearance and string.format(
			"FACE // %s   HAIR // %s\nTOP // %s   PANTS // %s   BOOTS // %s",
			appearance.Face, appearance.Hair, appearance.TopArmour, appearance.Pants, appearance.Boots
		) or ""
	end

	local refresh
	refresh = function()
		for _, child in list:GetChildren() do
			if child ~= listLayout then child:Destroy() end
		end
		for index = 1, ProfileConfig.MaximumProfiles do
			local profile = profiles[index]
			local text = profile
				and string.format("%02d  %s\n%s // LV %d // %s", index, profile.Name:upper(), profile.BodyType:upper(), profile.Level, profile.LastPlayedUnix == 0 and "NEW" or os.date("%Y-%m-%d", profile.LastPlayedUnix))
				or string.format("%02d  EMPTY PROFILE", index)
			local row = button(list, text, UDim2.new(1, 0, 0, 70))
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextWrapped = true
			if profile and profile.Id == selectedId then row.BackgroundColor3 = Color3.fromRGB(44, 65, 34) end
			row.Activated:Connect(function()
				if profile then
					selectedId = profile.Id
					updateAppearanceLabel(profile)
					CharacterPreviewController:Render(preview, profile, false)
					refresh()
				else
					navigation:GoTo("Creation")
				end
			end)
		end
	end

	local play = button(actions, "PLAY", UDim2.new(0.32, 0, 1, 0))
	local create = button(actions, "NEW FIGHTER", UDim2.new(0.32, 0, 1, 0))
	local delete = button(actions, "DELETE", UDim2.new(0.32, 0, 1, 0))
	delete.TextColor3 = colors.Error
	create.Activated:Connect(function() navigation:GoTo("Creation") end)
	delete.Activated:Connect(function()
		self:DeleteSelected()
		refresh()
		local profile = selectedProfile()
		if profile then
			updateAppearanceLabel(profile)
			CharacterPreviewController:Render(preview, profile, false)
		else
			navigation:GoTo("Creation")
		end
	end)
	play.Activated:Connect(function()
		local profile = selectedProfile()
		if not profile then return end
		profile.LastPlayedUnix = os.time()
		fighterController:SetBodyType(profile.BodyType)
		self.ProfileSelected:Fire(profile)
		navigation:GoTo("OperationsHub", profile)
	end)

	local object = {}
	function object:SetVisible(visible)
		page.Visible = visible
		if visible then
			if #profiles == 0 then
				task.defer(function()
					if page.Visible and #profiles == 0 then navigation:GoTo("Creation") end
				end)
				return
			end
			refresh()
			local profile = selectedProfile()
			updateAppearanceLabel(profile)
			CharacterPreviewController:Render(preview, profile, false)
		else
			CharacterPreviewController:Stop()
		end
	end
	return object
end

return Controller
