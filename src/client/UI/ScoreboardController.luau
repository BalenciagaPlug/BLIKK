local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)

local UIStyle = require(script.Parent.UIStyle)
local Branding = require(ReplicatedStorage.Shared.Branding.Branding)

local ScoreboardController = {}

local colors = UIStyle.Colors
local isInitialised = false
local isGameplayEnabled = true
local isScoreboardHeld = false
local panel = nil
local playerList = nil
local elapsedLabel = nil
local startedAt = 0
local latestMatch = nil
local latestRoom = nil
local modeLabel = nil
local mapLabel = nil
local scoreLabel = nil
local scoreboardStatus = nil
local pendingReportUserId = nil

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

	local players = latestMatch and latestMatch.Stats or {}
	if not latestMatch and latestRoom then
		for _, member in latestRoom.Members do table.insert(players, { UserId = member.UserId, DisplayName = member.DisplayName, TeamId = member.TeamId, Kills = 0, Deaths = 0, Score = 0, PingMilliseconds = member.PingMilliseconds, RoomLeader = member.IsRoomLeader, ClanTag = member.ClanTag, State = member.IsReady and "READY" or member.State }) end
	elseif not latestMatch then
		for _, player in Players:GetPlayers() do table.insert(players, { UserId = player.UserId, DisplayName = player.DisplayName, TeamId = "NO TEAM", Kills = 0, Deaths = 0, PingMilliseconds = 0 }) end
	end

	for index, listedPlayer in players do
		local row = Instance.new("TextButton")
		row.Text = ""
		row.BackgroundColor3 = if index % 2 == 0 then colors.PanelLight else colors.Panel
		row.BackgroundTransparency = 0.12
		row.Position = UDim2.fromOffset(0, (index - 1) * 36)
		row.Size = UDim2.new(1, 0, 0, 32)
		row.Parent = playerList
		row.Activated:Connect(function()
			if listedPlayer.UserId == Players.LocalPlayer.UserId then return end
			if pendingReportUserId ~= listedPlayer.UserId then pendingReportUserId = listedPlayer.UserId; scoreboardStatus.Text = "CLICK PLAYER AGAIN TO CONFIRM UNSPORTING-BEHAVIOR REPORT // " .. listedPlayer.DisplayName; return end
			pendingReportUserId = nil
			local reportRemote = ReplicatedStorage:WaitForChild("BLIKKRemotes"):WaitForChild("ReportRequest")
			local ok, result = pcall(reportRemote.InvokeServer, reportRemote, { TargetUserId = listedPlayer.UserId, ReasonCode = "UnsportingBehavior", Note = "" })
			scoreboardStatus.Text = ok and result.Success and ("REPORT RECEIVED // " .. result.ReportId) or ("REPORT FAILED // " .. tostring(ok and result.Code or "SERVICE"))
		end)
		local identity = (listedPlayer.RoomLeader and "◆ " or "") .. (listedPlayer.ClanTag and "[" .. listedPlayer.ClanTag .. "] " or "") .. listedPlayer.DisplayName
		createLabel(row, identity, UDim2.fromOffset(10, 6), UDim2.new(0.30, -10, 0, 20), 12, colors.Text)
		createLabel(
			row,
			listedPlayer.TeamId or "NO TEAM",
			UDim2.new(0.30, 0, 0, 6),
			UDim2.new(0.12, 0, 0, 20),
			10,
			colors.TextMuted
		)
		local kills, deaths = listedPlayer.Kills or 0, listedPlayer.Deaths or 0
		createLabel(row, tostring(kills), UDim2.new(0.42, 0, 0, 6), UDim2.new(0.06, 0, 0, 20), 11, colors.TextMuted)
		createLabel(row, tostring(deaths), UDim2.new(0.48, 0, 0, 6), UDim2.new(0.06, 0, 0, 20), 11, colors.TextMuted)
		createLabel(row, string.format("%.2f", deaths > 0 and kills / deaths or kills), UDim2.new(0.54, 0, 0, 6), UDim2.new(0.08, 0, 0, 20), 11, colors.TextMuted)
		createLabel(row, tostring(listedPlayer.Score or 0), UDim2.new(0.62, 0, 0, 6), UDim2.new(0.10, 0, 0, 20), 11, colors.TextMuted)
		local state = listedPlayer.State or (listedPlayer.IsSpectating and "SPECTATING" or listedPlayer.IsAlive == false and "DEAD" or "ALIVE")
		createLabel(row, state, UDim2.new(0.72, 0, 0, 6), UDim2.new(0.16, 0, 0, 20), 9, colors.TextMuted)
		createLabel(row, tostring(listedPlayer.PingMilliseconds or 0), UDim2.new(0.88, 0, 0, 6), UDim2.new(0.12, -8, 0, 20), 11, colors.TextMuted)
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
	Branding.CreateIconLogo(panel, {
		Name = "ScoreboardBrand",
		Position = UDim2.fromOffset(18, 10),
		Size = Branding.Sizes.Scoreboard,
	})
	createLabel(panel, "MOVEMENT LAB", UDim2.fromOffset(92, 17), UDim2.fromOffset(294, 26), 18, colors.Text)
	modeLabel = createLabel(panel, "MODE // TRAINING", UDim2.fromOffset(18, 45), UDim2.fromOffset(220, 18), 10, colors.TextMuted)
	mapLabel = createLabel(panel, "MAP // DISTRICT ZERO", UDim2.fromOffset(244, 45), UDim2.fromOffset(230, 18), 10, colors.TextMuted)
	scoreLabel = createLabel(panel, "", UDim2.fromOffset(474, 45), UDim2.fromOffset(220, 18), 10, colors.TextMuted, Enum.TextXAlignment.Right)
	elapsedLabel = createLabel(
		panel,
		"ELAPSED // 00:00",
		UDim2.new(1, -218, 0, 18),
		UDim2.fromOffset(198, 24),
		14,
		colors.Accent,
		Enum.TextXAlignment.Right
	)

	local columns = { { "PLAYER", 0 }, { "TEAM", 0.30 }, { "K", 0.42 }, { "D", 0.48 }, { "KD", 0.54 }, { "SCORE", 0.62 }, { "STATE", 0.72 }, { "PING", 0.88 } }
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

	scoreboardStatus = createLabel(
		panel,
		"SERVER-CONFIRMED MATCH STATISTICS",
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
	ReplicatedStorage:WaitForChild("BLIKKRemotes"):WaitForChild("MatchUpdated").OnClientEvent:Connect(function(snapshot)
		latestMatch = snapshot
		modeLabel.Text = "MODE // " .. snapshot.ModeId:upper()
		mapLabel.Text = "MAP // " .. snapshot.MapId:upper()
		scoreLabel.Text = string.format("ROUND %d // %d-%d", snapshot.Round or 1, snapshot.TeamScores.ALPHA or 0, snapshot.TeamScores.OMEGA or 0)
		rebuildPlayers()
	end)
	ReplicatedStorage.BLIKKRemotes:WaitForChild("RoomUpdated").OnClientEvent:Connect(function(snapshot)
		if snapshot.Warning or not snapshot.RoomId then return end
		latestRoom = snapshot
		if snapshot.State == "Lobby" then latestMatch = nil end
		modeLabel.Text = "MODE // " .. snapshot.Config.ModeId:upper(); mapLabel.Text = "MAP // " .. snapshot.Config.MapId:upper(); scoreLabel.Text = snapshot.State:upper(); rebuildPlayers()
	end)

	task.spawn(function()
		while true do
			local elapsed = math.floor(os.clock() - startedAt)
			if latestMatch and latestMatch.EndsAtUnix and latestMatch.EndsAtUnix > 0 then
				local remaining = math.max(0, latestMatch.EndsAtUnix - os.time())
				elapsedLabel.Text = string.format("TIME // %02d:%02d", math.floor(remaining / 60), remaining % 60)
			else elapsedLabel.Text = string.format("ELAPSED // %02d:%02d", math.floor(elapsed / 60), elapsed % 60) end
			task.wait(1)
		end
	end)
end

return ScoreboardController
