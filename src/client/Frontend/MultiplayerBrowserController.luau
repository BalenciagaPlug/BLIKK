local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local LobbyConfig = require(ReplicatedStorage.Shared.Multiplayer.LobbyConfig)
local FrontendLayout = require(script.Parent.FrontendLayout)

local Controller = {}
local COLORS = {
	Background = Color3.fromRGB(5, 6, 8), Panel = Color3.fromRGB(13, 14, 17),
	Raised = Color3.fromRGB(24, 25, 29), Border = Color3.fromRGB(62, 61, 70),
	Text = Color3.fromRGB(230, 227, 215), Muted = Color3.fromRGB(135, 136, 143),
	Purple = Color3.fromRGB(153, 75, 220), Acid = Color3.fromRGB(154, 213, 83),
	Warning = Color3.fromRGB(180, 61, 67),
}

local function stroke(instance, color)
	local value = Instance.new("UIStroke")
	value.Color = color or COLORS.Border
	value.Parent = instance
	return value
end

local function label(parent, text, position, size, textSize, color, alignment)
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.Code
	value.Position = position
	value.Size = size
	value.Text = text
	value.TextColor3 = color or COLORS.Text
	value.TextSize = textSize or 13
	value.TextXAlignment = alignment or Enum.TextXAlignment.Left
	value.TextYAlignment = Enum.TextYAlignment.Center
	value.Parent = parent
	return value
end

local function button(parent, text, position, size)
	local value = Instance.new("TextButton")
	value.AutoButtonColor = false
	value.BackgroundColor3 = COLORS.Raised
	value.Font = Enum.Font.Code
	value.Position = position
	value.Size = size
	value.Text = text
	value.TextColor3 = COLORS.Text
	value.TextSize = 12
	value.Parent = parent
	stroke(value)
	local scale = Instance.new("UIScale")
	scale.Parent = value
	value.MouseEnter:Connect(function()
		TweenService:Create(value, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { BackgroundColor3 = Color3.fromRGB(34, 31, 40) }):Play()
	end)
	value.MouseLeave:Connect(function()
		TweenService:Create(value, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { BackgroundColor3 = COLORS.Raised }):Play()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 1 }):Play()
	end)
	value.MouseButton1Down:Connect(function() TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.975 }):Play() end)
	value.MouseButton1Up:Connect(function() TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 1 }):Play() end)
	return value
end

function Controller:CreatePage(parent, navigation)
	local page = Instance.new("Frame")
	page.Name = "MultiplayerBrowser"
	page.BackgroundColor3 = COLORS.Background
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = parent
	local canvas = FrontendLayout:CreateCanvas(page)
	Branding.CreateFullLogo(canvas, { Position = UDim2.fromOffset(18, 8), Size = UDim2.fromOffset(235, 105) })
	label(canvas, "MULTIPLAYER // LOBBY BROWSER", UDim2.fromOffset(275, 30), UDim2.fromOffset(520, 32), 24)
	label(canvas, "LOCAL PROTOTYPE DATA // NO CROSS-SERVER DISCOVERY", UDim2.fromOffset(277, 65), UDim2.fromOffset(520, 22), 11, COLORS.Warning)

	local browser = Instance.new("Frame")
	browser.BackgroundColor3 = COLORS.Panel
	browser.Position = UDim2.fromOffset(20, 120)
	browser.Size = UDim2.new(1, -40, 1, -195)
	browser.Parent = canvas
	stroke(browser)
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(14, 12)
	tabs.Size = UDim2.new(1, -28, 0, 34)
	tabs.Parent = browser
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabs
	for _, category in LobbyConfig.Categories do
		local tab = button(tabs, category, UDim2.new(), UDim2.fromOffset(130, 32))
		tab.TextColor3 = if category == "PINNED" then COLORS.Purple else COLORS.Muted
	end

	local columns = { { "ROOM NAME", 0.31 }, { "MODE", 0.15 }, { "MAP", 0.15 }, { "PLAYERS", 0.1 }, { "PING", 0.07 }, { "PASSWORD", 0.1 }, { "STATUS", 0.12 } }
	local header = Instance.new("Frame")
	header.BackgroundColor3 = COLORS.Raised
	header.Position = UDim2.fromOffset(14, 55)
	header.Size = UDim2.new(1, -28, 0, 32)
	header.Parent = browser
	local x = 0
	for _, definition in columns do
		label(header, definition[1], UDim2.fromScale(x, 0), UDim2.new(definition[2], -6, 1, 0), 10, COLORS.Muted)
		x += definition[2]
	end

	local selectedListing = nil
	local selectedRow = nil
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(14, 92)
	list.Size = UDim2.new(1, -28, 1, -145)
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.fromOffset(0, #LobbyConfig.PrototypeListings * 47)
	list.Parent = browser
	local status = label(canvas, "SELECT A LOCAL PROTOTYPE LISTING", UDim2.fromOffset(20, 646), UDim2.fromOffset(520, 22), 11, COLORS.Muted)
	for index, listing in LobbyConfig.PrototypeListings do
		local row = button(list, "", UDim2.fromOffset(0, (index - 1) * 47), UDim2.new(1, -5, 0, 41))
		row.Name = "LobbyRow" .. index
		local values = { listing.Name, listing.Mode, listing.Map, listing.Players, listing.Ping, if listing.Password then "LOCKED" else "OPEN", listing.Status }
		x = 0
		for columnIndex, definition in columns do
			label(row, values[columnIndex], UDim2.fromScale(x, 0), UDim2.new(definition[2], -6, 1, 0), 10, if columnIndex == 1 then COLORS.Text else COLORS.Muted)
			x += definition[2]
		end
		row.MouseLeave:Connect(function()
			if selectedRow == row then
				row.BackgroundColor3 = Color3.fromRGB(38, 28, 47)
				row:FindFirstChildOfClass("UIStroke").Color = COLORS.Purple
			end
		end)
		row.Activated:Connect(function()
			if selectedRow then
				selectedRow.BackgroundColor3 = COLORS.Raised
				selectedRow:FindFirstChildOfClass("UIStroke").Color = COLORS.Border
			end
			selectedListing = listing
			selectedRow = row
			row.BackgroundColor3 = Color3.fromRGB(38, 28, 47)
			row:FindFirstChildOfClass("UIStroke").Color = COLORS.Purple
			status.Text = "SELECTED // " .. listing.Name .. " // " .. listing.Status
			status.TextColor3 = COLORS.Purple
		end)
	end

	local createPanel = Instance.new("Frame")
	createPanel.Name = "CreateLobby"
	createPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	createPanel.BackgroundColor3 = COLORS.Panel
	createPanel.Position = UDim2.fromScale(0.5, 0.5)
	createPanel.Size = UDim2.fromOffset(620, 520)
	createPanel.Visible = false
	createPanel.ZIndex = 20
	createPanel.Parent = canvas
	stroke(createPanel, COLORS.Purple)
	label(createPanel, "CREATE LOCAL PROTOTYPE LOBBY", UDim2.fromOffset(20, 14), UDim2.new(1, -40, 0, 34), 20, COLORS.Purple)
	local lobbyName = Instance.new("TextBox")
	lobbyName.BackgroundColor3 = COLORS.Raised
	lobbyName.ClearTextOnFocus = false
	lobbyName.Font = Enum.Font.Code
	lobbyName.PlaceholderText = "LOBBY NAME"
	lobbyName.Position = UDim2.fromOffset(20, 62)
	lobbyName.Size = UDim2.new(1, -40, 0, 40)
	lobbyName.Text = ""
	lobbyName.TextColor3 = COLORS.Text
	lobbyName.TextSize = 13
	lobbyName.ZIndex = 21
	lobbyName.Parent = createPanel
	stroke(lobbyName)
	local selections = { Map = 1, Mode = 1, Capacity = 3, Access = 1, VoteKick = 1, TeamBalance = 1, Spectators = 1, FriendlyFire = 1, TimeLimit = 1, ScoreLimit = 1 }
	local optionValues = {
		Map = LobbyConfig.Maps, Mode = { "TRAINING", "DUEL // FUTURE", "TEAM DEATHMATCH // FUTURE", "FREE FOR ALL // FUTURE" },
		Capacity = { "2", "4", "8", "12", "16" }, Access = { "PUBLIC", "PASSWORD" },
		VoteKick = { "ENABLED", "DISABLED" }, TeamBalance = { "OFF", "ON // FUTURE" }, Spectators = { "OFF", "ON // FUTURE" },
		FriendlyFire = { "OFF", "ON // FUTURE" }, TimeLimit = { "NONE", "10 MIN // FUTURE", "20 MIN // FUTURE" }, ScoreLimit = { "NONE", "20 // FUTURE", "50 // FUTURE" },
	}
	local optionButtons = {}
	local ordered = { "Map", "Mode", "Capacity", "Access", "VoteKick", "TeamBalance", "Spectators", "FriendlyFire", "TimeLimit", "ScoreLimit" }
	for index, key in ordered do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local control = button(createPanel, string.upper(key) .. " // " .. optionValues[key][selections[key]], UDim2.fromOffset(20 + column * 295, 118 + row * 52), UDim2.fromOffset(275, 40))
		control.ZIndex = 21
		control.Activated:Connect(function()
			selections[key] = selections[key] % #optionValues[key] + 1
			control.Text = string.upper(key) .. " // " .. optionValues[key][selections[key]]
		end)
		optionButtons[key] = control
	end
	local password = Instance.new("TextBox")
	password.BackgroundColor3 = COLORS.Raised
	password.Font = Enum.Font.Code
	password.PlaceholderText = "PASSWORD (REQUIRED WHEN PASSWORD ACCESS IS SELECTED)"
	password.Position = UDim2.fromOffset(20, 382)
	password.Size = UDim2.new(1, -40, 0, 38)
	password.Text = ""
	password.TextColor3 = COLORS.Text
	password.TextSize = 11
	password.Visible = false
	password.ZIndex = 21
	password.Parent = createPanel
	stroke(password)
	optionButtons.Access.Activated:Connect(function() password.Visible = selections.Access == 2 end)
	local createStatus = label(createPanel, "TRAINING IS THE ONLY PLAYABLE MODE IN V1.", UDim2.fromOffset(20, 428), UDim2.new(1, -40, 0, 24), 11, COLORS.Muted)
	createStatus.ZIndex = 21
	local confirm = button(createPanel, "CREATE SESSION LISTING", UDim2.fromOffset(20, 466), UDim2.fromOffset(280, 36))
	confirm.ZIndex = 21
	confirm.TextColor3 = COLORS.Acid
	local cancel = button(createPanel, "CANCEL", UDim2.new(1, -160, 0, 466), UDim2.fromOffset(140, 36))
	cancel.ZIndex = 21
	confirm.Activated:Connect(function()
		local name = lobbyName.Text:match("^%s*(.-)%s*$")
		if name == "" then createStatus.Text = "LOBBY NAME IS REQUIRED."; createStatus.TextColor3 = COLORS.Warning; return end
		if selections.Access == 2 and password.Text == "" then createStatus.Text = "PASSWORD ACCESS REQUIRES A PASSWORD."; createStatus.TextColor3 = COLORS.Warning; return end
		if selections.Mode ~= 1 then createStatus.Text = "SELECTED MODE IS NOT PLAYABLE YET."; createStatus.TextColor3 = COLORS.Warning; return end
		createStatus.Text = "LOCAL LISTING PREPARED // NO RESERVED SERVER OR TELEPORT ROUTING YET."
		createStatus.TextColor3 = COLORS.Acid
	end)
	cancel.Activated:Connect(function() createPanel.Visible = false end)

	local refresh = button(canvas, "REFRESH", UDim2.new(1, -520, 1, -62), UDim2.fromOffset(110, 36))
	local create = button(canvas, "CREATE LOBBY", UDim2.new(1, -400, 1, -62), UDim2.fromOffset(135, 36))
	local join = button(canvas, "JOIN", UDim2.new(1, -255, 1, -62), UDim2.fromOffset(100, 36))
	local back = button(canvas, "RETURN TO HUB", UDim2.new(1, -145, 1, -62), UDim2.fromOffset(125, 36))
	local loadingGeneration = 0
	refresh.Activated:Connect(function()
		loadingGeneration += 1
		local activeGeneration = loadingGeneration
		status.Text = "REFRESHING LOCAL PROTOTYPE DATA..."
		status.TextColor3 = COLORS.Purple
		task.delay(0.35, function()
			if activeGeneration ~= loadingGeneration or not page.Visible then return end
			status.Text = "LOCAL PROTOTYPE LISTINGS REFRESHED"
			status.TextColor3 = COLORS.Acid
		end)
	end)
	create.Activated:Connect(function() createPanel.Visible = true end)
	join.Activated:Connect(function()
		if not selectedListing then status.Text = "SELECT A LISTING FIRST"; status.TextColor3 = COLORS.Warning; return end
		loadingGeneration += 1
		local activeGeneration = loadingGeneration
		status.Text = "CHECKING LOCAL PROTOTYPE LISTING..."
		status.TextColor3 = COLORS.Purple
		task.delay(0.3, function()
			if activeGeneration ~= loadingGeneration or not page.Visible then return end
			status.Text = "JOIN ROUTING IS NOT IMPLEMENTED // LOCAL SHELL ONLY"
			status.TextColor3 = COLORS.Warning
		end)
	end)
	back.Activated:Connect(function() navigation:GoTo("OperationsHub") end)
	local object = {}
	function object:SetVisible(visible)
		page.Visible = visible
		if not visible then createPanel.Visible = false end
	end
	return object
end

return Controller
