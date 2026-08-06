local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local Modes = require(ReplicatedStorage.Shared.Multiplayer.GameModeRegistry)
local FrontendLayout = require(script.Parent.FrontendLayout)

local Controller = {}
local COLORS = { Background = Color3.fromRGB(5, 6, 8), Panel = Color3.fromRGB(13, 14, 17), Raised = Color3.fromRGB(24, 25, 29), Border = Color3.fromRGB(62, 61, 70), Text = Color3.fromRGB(230, 227, 215), Muted = Color3.fromRGB(135, 136, 143), Purple = Color3.fromRGB(153, 75, 220), Acid = Color3.fromRGB(154, 213, 83), Warning = Color3.fromRGB(180, 61, 67) }

local function label(parent, text, position, size, textSize, color)
	local value = Instance.new("TextLabel"); value.BackgroundTransparency = 1; value.Font = Enum.Font.Code
	value.Position = position; value.Size = size; value.Text = text; value.TextColor3 = color or COLORS.Text
	value.TextSize = textSize or 13; value.TextXAlignment = Enum.TextXAlignment.Left; value.Parent = parent; return value
end

local function button(parent, text, position, size)
	local value = Instance.new("TextButton"); value.BackgroundColor3 = COLORS.Raised; value.Font = Enum.Font.Code
	value.Position = position; value.Size = size; value.Text = text; value.TextColor3 = COLORS.Text; value.TextSize = 12; value.Parent = parent
	local stroke = Instance.new("UIStroke"); stroke.Color = COLORS.Border; stroke.Parent = value; return value
end

local function invoke(remote, operation, payload)
	local ok, result = pcall(remote.InvokeServer, remote, operation, payload)
	return if ok and type(result) == "table" then result else { Success = false, Code = "SERVICE_UNAVAILABLE" }
end

function Controller:CreatePage(parent, navigation)
	local page = Instance.new("Frame"); page.Name = "MultiplayerBrowser"; page.BackgroundColor3 = COLORS.Background; page.Size = UDim2.fromScale(1, 1); page.Parent = parent
	local canvas = FrontendLayout:CreateCanvas(page)
	Branding.CreateFullLogo(canvas, { Position = UDim2.fromOffset(18, 8), Size = UDim2.fromOffset(235, 105) })
	label(canvas, "MULTIPLAYER // ROOMS", UDim2.fromOffset(275, 30), UDim2.fromOffset(520, 32), 24)
	local remotes = ReplicatedStorage:WaitForChild("BLIKKRemotes")
	local directoryRequest = remotes:WaitForChild("DirectoryRequest")
	local roomRequest = remotes:WaitForChild("RoomRequest")
	local roomUpdated = remotes:WaitForChild("RoomUpdated")
	local status = label(canvas, "READY", UDim2.fromOffset(275, 86), UDim2.new(1, -300, 0, 24), 11, COLORS.Muted)

	local list = Instance.new("ScrollingFrame"); list.BackgroundColor3 = COLORS.Panel; list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(20, 120); list.Size = UDim2.new(0.62, -25, 1, -195); list.ScrollBarThickness = 5; list.Parent = canvas
	local listLayout = Instance.new("UIListLayout"); listLayout.Padding = UDim.new(0, 6); listLayout.Parent = list
	local selectedRoomId = nil
	local function renderRooms(rooms)
		for _, child in list:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
		for index, room in rooms or {} do
			local row = button(list, string.format("%s  //  %s  //  %s  //  %d/%d  //  %s", room.Name, room.ModeId, room.MapId, room.CurrentPlayers, room.MaximumPlayers, room.State), UDim2.new(), UDim2.new(1, -8, 0, 42))
			row.LayoutOrder = index; row.TextXAlignment = Enum.TextXAlignment.Left
			row.Activated:Connect(function() selectedRoomId = room.RoomId; status.Text = "SELECTED // " .. room.Name; status.TextColor3 = COLORS.Purple end)
		end
		list.CanvasSize = UDim2.fromOffset(0, #(rooms or {}) * 48)
	end

	local createPanel = Instance.new("Frame"); createPanel.BackgroundColor3 = COLORS.Panel; createPanel.Position = UDim2.new(0.62, 5, 0, 120); createPanel.Size = UDim2.new(0.38, -25, 1, -195); createPanel.Parent = canvas
	label(createPanel, "CREATE ROOM", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 30), 18, COLORS.Purple)
	local nameBox = Instance.new("TextBox"); nameBox.BackgroundColor3 = COLORS.Raised; nameBox.PlaceholderText = "ROOM NAME"; nameBox.ClearTextOnFocus = false; nameBox.Font = Enum.Font.Code; nameBox.Text = ""; nameBox.TextColor3 = COLORS.Text; nameBox.Position = UDim2.fromOffset(16, 52); nameBox.Size = UDim2.new(1, -32, 0, 40); nameBox.Parent = createPanel
	local modeIds = { "Training", "Deathmatch", "TeamDeathmatchExtreme", "Elimination" }; local modeIndex = 1
	local modeButton = button(createPanel, "MODE // TRAINING", UDim2.fromOffset(16, 105), UDim2.new(1, -32, 0, 40))
	modeButton.Activated:Connect(function() modeIndex = modeIndex % #modeIds + 1; modeButton.Text = "MODE // " .. Modes.Get(modeIds[modeIndex]).DisplayName end)
	local public = true; local accessButton = button(createPanel, "ACCESS // PUBLIC", UDim2.fromOffset(16, 158), UDim2.new(1, -32, 0, 40))
	accessButton.Activated:Connect(function() public = not public; accessButton.Text = "ACCESS // " .. (public and "PUBLIC" or "PRIVATE") end)
	local createButton = button(createPanel, "CREATE RESERVED ROOM", UDim2.fromOffset(16, 211), UDim2.new(1, -32, 0, 42)); createButton.TextColor3 = COLORS.Acid
	createButton.Activated:Connect(function()
		status.Text = "CREATING ROOM..."; local result = invoke(directoryRequest, "Create", { Name = nameBox.Text, IsPublic = public, MapId = "DistrictZero", ModeId = modeIds[modeIndex], MaximumPlayers = 16, SpectatorSlots = 4, JoinInProgress = true, Mutators = {} })
		status.Text = result.Success and "TELEPORTING TO RESERVED ROOM..." or ("CREATE FAILED // " .. tostring(result.Code)); status.TextColor3 = result.Success and COLORS.Acid or COLORS.Warning
	end)

	local roomPanel = Instance.new("Frame"); roomPanel.BackgroundColor3 = COLORS.Panel; roomPanel.Position = createPanel.Position; roomPanel.Size = createPanel.Size; roomPanel.Visible = false; roomPanel.Parent = canvas
	local roomTitle = label(roomPanel, "ROOM", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 30), 18, COLORS.Purple)
	local roster = label(roomPanel, "", UDim2.fromOffset(16, 48), UDim2.new(1, -32, 1, -310), 12, COLORS.Text)
	roster.TextYAlignment = Enum.TextYAlignment.Top
	local readyButton = button(roomPanel, "READY", UDim2.new(0, 16, 1, -150), UDim2.new(0.48, -20, 0, 38))
	local teamButton = button(roomPanel, "TEAM // ALPHA", UDim2.new(0.5, 4, 1, -150), UDim2.new(0.5, -20, 0, 38))
	local startButton = button(roomPanel, "START MATCH", UDim2.new(0, 16, 1, -98), UDim2.new(0.48, -20, 0, 38)); startButton.TextColor3 = COLORS.Acid
	local leaveButton = button(roomPanel, "LEAVE ROOM", UDim2.new(0.5, 4, 1, -98), UDim2.new(0.5, -20, 0, 38))
	local memberBox = Instance.new("TextBox"); memberBox.BackgroundColor3 = COLORS.Raised; memberBox.PlaceholderText = "MEMBER USER ID"; memberBox.Text = ""; memberBox.Font = Enum.Font.Code; memberBox.TextColor3 = COLORS.Text; memberBox.Position = UDim2.new(0, 16, 1, -254); memberBox.Size = UDim2.new(1, -32, 0, 36); memberBox.Parent = roomPanel
	local kickButton = button(roomPanel, "KICK MEMBER", UDim2.new(0, 16, 1, -206), UDim2.new(0.48, -20, 0, 38))
	local transferButton = button(roomPanel, "TRANSFER LEADER", UDim2.new(0.5, 4, 1, -206), UDim2.new(0.5, -20, 0, 38))
	local isReady, teamId = false, "ALPHA"
	local function renderRoom(snapshot)
		if type(snapshot) ~= "table" or not snapshot.RoomId then roomPanel.Visible = false; createPanel.Visible = true; return end
		roomPanel.Visible = true; createPanel.Visible = false; roomTitle.Text = snapshot.Name .. " // " .. snapshot.State .. (snapshot.JoinCode and " // CODE " .. snapshot.JoinCode or "")
		local lines = {}; for _, member in snapshot.Members do table.insert(lines, string.format("%s%s%s // %s // %s", member.IsRoomLeader and "◆ " or "", member.ClanTag and "[" .. member.ClanTag .. "] " or "", member.DisplayName, member.TeamId or "NO TEAM", member.IsReady and "READY" or member.State)) end; roster.Text = table.concat(lines, "\n")
	end
	readyButton.Activated:Connect(function() isReady = not isReady; local result = invoke(roomRequest, "SetReady", isReady); if result.Success then renderRoom(result.Snapshot) end end)
	teamButton.Activated:Connect(function() teamId = teamId == "ALPHA" and "OMEGA" or "ALPHA"; teamButton.Text = "TEAM // " .. teamId; local result = invoke(roomRequest, "SetTeam", teamId); if result.Success then renderRoom(result.Snapshot) else status.Text = result.Code end end)
	startButton.Activated:Connect(function() local result = invoke(roomRequest, "Start"); if result.Success then renderRoom(result.Snapshot) else status.Text = result.Code end end)
	leaveButton.Activated:Connect(function() invoke(roomRequest, "Leave"); renderRoom(nil) end)
	kickButton.Activated:Connect(function() local result = invoke(roomRequest, "Kick", tonumber(memberBox.Text)); if result.Success then renderRoom(result.Snapshot) else status.Text = result.Code end end)
	transferButton.Activated:Connect(function() local result = invoke(roomRequest, "TransferLeader", tonumber(memberBox.Text)); if result.Success then renderRoom(result.Snapshot) else status.Text = result.Code end end)
	roomUpdated.OnClientEvent:Connect(function(value) if value.Warning then status.Text = value.Warning; status.TextColor3 = COLORS.Warning else renderRoom(value) end end)

	local refresh = button(canvas, "REFRESH", UDim2.new(1, -425, 1, -62), UDim2.fromOffset(110, 36))
	local join = button(canvas, "JOIN", UDim2.new(1, -305, 1, -62), UDim2.fromOffset(100, 36))
	local back = button(canvas, "RETURN TO HUB", UDim2.new(1, -195, 1, -62), UDim2.fromOffset(175, 36))
	local joinCode = Instance.new("TextBox"); joinCode.BackgroundColor3 = COLORS.Raised; joinCode.PlaceholderText = "JOIN CODE"; joinCode.Text = ""; joinCode.Font = Enum.Font.Code; joinCode.TextColor3 = COLORS.Text; joinCode.Position = UDim2.new(0, 20, 1, -62); joinCode.Size = UDim2.fromOffset(150, 36); joinCode.Parent = canvas
	local joinCodeButton = button(canvas, "JOIN CODE", UDim2.new(0, 180, 1, -62), UDim2.fromOffset(110, 36))
	refresh.Activated:Connect(function() local result = invoke(directoryRequest, "List"); if result.Success then renderRooms(result.Rooms); status.Text = "ROOM DIRECTORY UPDATED"; status.TextColor3 = COLORS.Acid else status.Text = result.Code; status.TextColor3 = COLORS.Warning end end)
	join.Activated:Connect(function() if not selectedRoomId then status.Text = "SELECT A ROOM"; return end; local result = invoke(directoryRequest, "Join", { RoomId = selectedRoomId, RequestedRole = "Player" }); status.Text = result.Success and "TELEPORTING..." or result.Code end)
	joinCodeButton.Activated:Connect(function() local result = invoke(directoryRequest, "JoinCode", joinCode.Text); status.Text = result.Success and "TELEPORTING..." or result.Code end)
	back.Activated:Connect(function() navigation:GoTo("OperationsHub") end)
	local object = {}
	function object:SetVisible(visible) page.Visible = visible; if visible then local roomResult = invoke(roomRequest, "Snapshot"); renderRoom(roomResult.Snapshot); local result = invoke(directoryRequest, "List"); if result.Success then renderRooms(result.Rooms) end end end
	return object
end

return Controller
