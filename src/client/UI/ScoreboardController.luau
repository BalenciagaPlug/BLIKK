local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)

local UIStyle = require(script.Parent.UIStyle)

local ScoreboardController = {}

local colors = UIStyle.Colors
local isInitialised = false
local isGameplayEnabled = true
local isScoreboardHeld = false
local panel = nil
local playerList = nil
local elapsedLabel = nil
local startedAt = 0

local function createLabel(parent, text, position, size, textSize, color, alignment)
	local label = Instance.new("TextLabel")
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

local function addStroke(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = instance
end

local function updateVisible()
	panel.Visible = isGameplayEnabled and isScoreboardHeld
end

local function rebuildPlayers()
	for _, child in playerList:GetChildren() do
		child:Destroy()
	end

	local players = Players:GetPlayers()
	table.sort(players, function(left, right)
		local leftTeam = left.Team and left.Team.Name or "NO TEAM"
		local rightTeam = right.Team and right.Team.Name or "NO TEAM"
		return leftTeam == rightTeam and left.DisplayName < right.DisplayName or leftTeam < rightTeam
	end)

	for index, listedPlayer in players do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = if index % 2 == 0 then colors.PanelLight else colors.Panel
		row.BackgroundTransparency = 0.12
		row.Position = UDim2.fromOffset(0, (index - 1) * 36)
		row.Size = UDim2.new(1, 0, 0, 32)
		row.Parent = playerList
		createLabel(row, listedPlayer.DisplayName, UDim2.fromOffset(10, 6), UDim2.new(0.42, -10, 0, 20), 12, colors.Text)
		createLabel(
			row,
			listedPlayer.Team and listedPlayer.Team.Name or "NO TEAM",
			UDim2.new(0.42, 0, 0, 6),
			UDim2.new(0.22, 0, 0, 20),
			10,
			colors.TextMuted
		)
		createLabel(row, "--", UDim2.new(0.68, 0, 0, 6), UDim2.new(0.09, 0, 0, 20), 11, colors.TextMuted)
		createLabel(row, "--", UDim2.new(0.77, 0, 0, 6), UDim2.new(0.09, 0, 0, 20), 11, colors.TextMuted)
		createLabel(row, "--", UDim2.new(0.86, 0, 0, 6), UDim2.new(0.14, -8, 0, 20), 11, colors.TextMuted)
	end

	playerList.CanvasSize = UDim2.fromOffset(0, #players * 36)
end

local function createInterface()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BLIKKScoreboard"
	screenGui.DisplayOrder = UIStyle.DisplayOrders.Settings - 1
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false

	panel = Instance.new("Frame")
	panel.Name = "Scoreboard"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = colors.Panel
	panel.BackgroundTransparency = 0.06
	panel.Position = UDim2.fromScale(0.5, 0.48)
	panel.Size = UDim2.fromOffset(720, 430)
	panel.Visible = false
	panel.Parent = screenGui
	local panelScale = Instance.new("UIScale")
	panelScale.Scale = SessionSettings:Get("UIScale")
	panelScale.Parent = panel
	SessionSettings.Changed.Event:Connect(function(key, value)
		if key == "UIScale" then panelScale.Scale = value end
	end)
	addStroke(panel, colors.Edge, 2)

	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = colors.Accent
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(1, 0, 0, 3)
	accent.Parent = panel
	createLabel(panel, "BLIKK // MOVEMENT LAB", UDim2.fromOffset(18, 15), UDim2.fromOffset(390, 26), 20, colors.Text)
	createLabel(panel, "MODE // TRAINING", UDim2.fromOffset(18, 45), UDim2.fromOffset(220, 18), 10, colors.TextMuted)
	createLabel(panel, "MAP // MOVEMENT LAB", UDim2.fromOffset(244, 45), UDim2.fromOffset(230, 18), 10, colors.TextMuted)
	elapsedLabel = createLabel(
		panel,
		"ELAPSED // 00:00",
		UDim2.new(1, -218, 0, 18),
		UDim2.fromOffset(198, 24),
		14,
		colors.Accent,
		Enum.TextXAlignment.Right
	)

	local columns = { { "PLAYER", 0 }, { "TEAM", 0.42 }, { "K", 0.68 }, { "D", 0.77 }, { "PING", 0.86 } }
	for _, column in columns do
		createLabel(panel, column[1], UDim2.new(column[2], 10, 0, 76), UDim2.fromOffset(110, 18), 10, colors.TextMuted)
	end

	playerList = Instance.new("ScrollingFrame")
	playerList.Name = "Players"
	playerList.BackgroundTransparency = 1
	playerList.BorderSizePixel = 0
	playerList.Position = UDim2.fromOffset(18, 100)
	playerList.Size = UDim2.new(1, -36, 1, -126)
	playerList.ScrollBarThickness = 5
	playerList.ScrollBarImageColor3 = colors.AccentDim
	playerList.Parent = panel

	createLabel(
		panel,
		"K / D / PING ARE PLACEHOLDER-READY // NO MATCH STATISTICS EXIST",
		UDim2.fromOffset(18, 405),
		UDim2.new(1, -36, 0, 16),
		9,
		colors.TextMuted
	)
	screenGui.Parent = playerGui
	rebuildPlayers()
end

function ScoreboardController:Init(inputManager)
	if isInitialised then
		return
	end

	isInitialised = true
	startedAt = os.clock()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	createInterface()

	inputManager.ActionBegan.Event:Connect(function(action)
		if action == "Scoreboard" then
			isScoreboardHeld = true
			updateVisible()
		end
	end)
	inputManager.ActionEnded.Event:Connect(function(action)
		if action == "Scoreboard" then
			isScoreboardHeld = false
			updateVisible()
		end
	end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		isGameplayEnabled = enabled
		if not enabled then
			isScoreboardHeld = false
		end
		updateVisible()
	end)
	Players.PlayerAdded:Connect(rebuildPlayers)
	Players.PlayerRemoving:Connect(rebuildPlayers)

	task.spawn(function()
		while true do
			local elapsed = math.floor(os.clock() - startedAt)
			elapsedLabel.Text = string.format("ELAPSED // %02d:%02d", math.floor(elapsed / 60), elapsed % 60)
			task.wait(1)
		end
	end)
end

return ScoreboardController
