local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local Modes = require(ReplicatedStorage.Shared.Multiplayer.GameModeRegistry)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)
local FrontendLayout = require(script.Parent.FrontendLayout)
local UINavigationController = require(script.Parent.Parent.UI.UINavigationController)
local UIStyle = require(script.Parent.Parent.UI.UIStyle)

local Controller = {}

local COLORS = {
	Background = Color3.fromRGB(5, 6, 8),
	Panel = Color3.fromRGB(13, 14, 17),
	Raised = Color3.fromRGB(24, 25, 29),
	Border = Color3.fromRGB(62, 61, 70),
	Text = Color3.fromRGB(230, 227, 215),
	Muted = Color3.fromRGB(135, 136, 143),
	Purple = Color3.fromRGB(153, 75, 220),
	Acid = Color3.fromRGB(154, 213, 83),
	Warning = Color3.fromRGB(180, 61, 67),
}

local function label(parent, text, position, size, textSize, color)
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.Code
	value.Position = position
	value.Size = size
	value.Text = text
	value.TextColor3 = color or COLORS.Text
	value.TextSize = textSize or 13
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Parent = parent
	return value
end

local function button(parent, text, position, size)
	local value = Instance.new("TextButton")
	value.BackgroundColor3 = COLORS.Raised
	value.Font = Enum.Font.Code
	value.Position = position
	value.Size = size
	value.Text = text
	value.TextColor3 = COLORS.Text
	value.TextSize = 12
	value.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Border
	stroke.Parent = value
	FrontendLayout:SkinButton(value)
	return value
end

local function invokeBounded(remote, operation, payload, callback, timeoutSeconds)
	local didComplete = false
	task.delay(timeoutSeconds or MultiplayerConfig.ClientRequestTimeoutSeconds, function()
		if didComplete then return end
		didComplete = true
		callback({ Success = false, Code = "REQUEST_TIMEOUT" })
	end)
	task.spawn(function()
		local ok, result = pcall(remote.InvokeServer, remote, operation, payload)
		if didComplete then return end
		didComplete = true
		if not ok or type(result) ~= "table" then
			warn("[BLIKK ROOM] Client request failed: SERVICE_UNAVAILABLE")
			callback({ Success = false, Code = "SERVICE_UNAVAILABLE" })
			return
		end
		callback(result)
	end)
end

function Controller:CreatePage(parent, navigation, callbacks)
	callbacks = callbacks or {}
	local multiplayerScope = nil
	local activationCallbacks = {}
	local activationAudioRoles = {}
	local adjustCallbacks = {}
	local pendingTransportAudioControl = nil
	local directoryRows = {}
	local directoryRowsById = {}
	local directoryRowEntries = {}
	local function bindActivation(control, callback, audioRole)
		control.Activated:Connect(callback)
		if multiplayerScope then
			multiplayerScope:Register(control, {
				Activate = callback,
				Adjust = adjustCallbacks[control],
				AudioRole = audioRole,
			})
		else
			activationCallbacks[control] = callback
			activationAudioRoles[control] = audioRole
		end
	end
	local player = Players.LocalPlayer
	local page = Instance.new("Frame")
	page.Name = "MultiplayerBrowser"
	page.BackgroundColor3 = COLORS.Background
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = parent
	local canvas = FrontendLayout:CreateCanvas(page)
	Branding.CreateFullLogo(canvas, {
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.fromOffset(235, 105),
	})
	label(canvas, "MULTIPLAYER // ROOMS", UDim2.fromOffset(275, 30), UDim2.fromOffset(520, 32), 24)
	local status = label(
		canvas,
		"READY",
		UDim2.fromOffset(275, 86),
		UDim2.new(1, -300, 0, 24),
		11,
		COLORS.Muted
	)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = COLORS.Panel
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(20, 120)
	list.Size = UDim2.new(0.62, -25, 1, -195)
	list.ScrollBarThickness = 5
	list.Parent = canvas
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = list

	local createPanel = Instance.new("Frame")
	createPanel.BackgroundColor3 = COLORS.Panel
	createPanel.Position = UDim2.new(0.62, 5, 0, 120)
	createPanel.Size = UDim2.new(0.38, -25, 1, -195)
	createPanel.Parent = canvas
	label(createPanel, "CREATE ROOM", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 30), 18, COLORS.Purple)
	local nameBox = Instance.new("TextBox")
	nameBox.BackgroundColor3 = COLORS.Raised
	nameBox.PlaceholderText = "ROOM NAME"
	nameBox.ClearTextOnFocus = false
	nameBox.Font = Enum.Font.Code
	nameBox.Text = ""
	nameBox.TextColor3 = COLORS.Text
	nameBox.Position = UDim2.fromOffset(16, 52)
	nameBox.Size = UDim2.new(1, -32, 0, 40)
	nameBox.Parent = createPanel
	local modeIds = { "Training", "Deathmatch", "TeamDeathmatchExtreme", "Elimination" }
	local modeIndex = 1
	local modeButton = button(
		createPanel,
		"MODE // TRAINING",
		UDim2.fromOffset(16, 105),
		UDim2.new(1, -32, 0, 40)
	)
	local isPublic = true
	local accessButton = button(
		createPanel,
		"ACCESS // PUBLIC",
		UDim2.fromOffset(16, 158),
		UDim2.new(1, -32, 0, 40)
	)
	local createButton = button(
		createPanel,
		"CREATE RESERVED ROOM",
		UDim2.fromOffset(16, 211),
		UDim2.new(1, -32, 0, 42)
	)
	createButton.TextColor3 = COLORS.Acid
	local publicDeathmatchButton = button(
		createPanel,
		"QUICK PLAY // PUBLIC FFA",
		UDim2.fromOffset(16, 267),
		UDim2.new(1, -32, 0, 42)
	)
	publicDeathmatchButton.TextColor3 = COLORS.Purple

	local roomPanel = Instance.new("Frame")
	roomPanel.BackgroundColor3 = COLORS.Panel
	roomPanel.Position = createPanel.Position
	roomPanel.Size = createPanel.Size
	roomPanel.Visible = false
	roomPanel.Parent = canvas
	local roomTitle = label(
		roomPanel,
		"ROOM",
		UDim2.fromOffset(16, 10),
		UDim2.new(1, -32, 0, 30),
		18,
		COLORS.Purple
	)
	local roster = label(
		roomPanel,
		"",
		UDim2.fromOffset(16, 48),
		UDim2.new(1, -32, 1, -310),
		12,
		COLORS.Text
	)
	roster.TextYAlignment = Enum.TextYAlignment.Top
	local readyButton = button(
		roomPanel,
		"READY",
		UDim2.new(0, 16, 1, -150),
		UDim2.new(0.48, -20, 0, 38)
	)
	local teamButton = button(
		roomPanel,
		"TEAM // ALPHA",
		UDim2.new(0.5, 4, 1, -150),
		UDim2.new(0.5, -20, 0, 38)
	)
	local startButton = button(
		roomPanel,
		"START MATCH",
		UDim2.new(0, 16, 1, -98),
		UDim2.new(0.48, -20, 0, 38)
	)
	local leaveButton = button(
		roomPanel,
		"LEAVE ROOM",
		UDim2.new(0.5, 4, 1, -98),
		UDim2.new(0.5, -20, 0, 38)
	)
	local memberBox = Instance.new("TextBox")
	memberBox.BackgroundColor3 = COLORS.Raised
	memberBox.PlaceholderText = "MEMBER USER ID"
	memberBox.Text = ""
	memberBox.Font = Enum.Font.Code
	memberBox.TextColor3 = COLORS.Text
	memberBox.Position = UDim2.new(0, 16, 1, -254)
	memberBox.Size = UDim2.new(1, -32, 0, 36)
	memberBox.Parent = roomPanel
	local kickButton = button(
		roomPanel,
		"KICK MEMBER",
		UDim2.new(0, 16, 1, -206),
		UDim2.new(0.48, -20, 0, 38)
	)
	local transferButton = button(
		roomPanel,
		"TRANSFER LEADER",
		UDim2.new(0.5, 4, 1, -206),
		UDim2.new(0.5, -20, 0, 38)
	)

	local refresh = button(canvas, "REFRESH", UDim2.new(1, -425, 1, -62), UDim2.fromOffset(110, 36))
	local join = button(canvas, "JOIN", UDim2.new(1, -305, 1, -62), UDim2.fromOffset(100, 36))
	local back = button(
		canvas,
		"RETURN TO HUB",
		UDim2.new(1, -195, 1, -62),
		UDim2.fromOffset(175, 36)
	)
	local joinCode = Instance.new("TextBox")
	joinCode.BackgroundColor3 = COLORS.Raised
	joinCode.PlaceholderText = "JOIN CODE"
	joinCode.Text = ""
	joinCode.Font = Enum.Font.Code
	joinCode.TextColor3 = COLORS.Text
	joinCode.Position = UDim2.new(0, 20, 1, -62)
	joinCode.Size = UDim2.fromOffset(150, 36)
	joinCode.Parent = canvas
	local joinCodeButton = button(
		canvas,
		"JOIN CODE",
		UDim2.new(0, 180, 1, -62),
		UDim2.fromOffset(110, 36)
	)

	local remotes = ReplicatedStorage:WaitForChild(
		"BLIKKRemotes",
		MultiplayerConfig.RemoteLookupTimeoutSeconds
	)
	local directoryRequest = remotes and remotes:WaitForChild(
		"DirectoryRequest",
		MultiplayerConfig.RemoteLookupTimeoutSeconds
	)
	local roomRequest = remotes and remotes:WaitForChild(
		"RoomRequest",
		MultiplayerConfig.RemoteLookupTimeoutSeconds
	)
	local roomUpdated = remotes and remotes:WaitForChild(
		"RoomUpdated",
		MultiplayerConfig.RemoteLookupTimeoutSeconds
	)
	local matchUpdated = remotes and remotes:WaitForChild(
		"MatchUpdated",
		MultiplayerConfig.RemoteLookupTimeoutSeconds
	)

	local selectedDirectoryRoomId = nil
	local selectedDirectoryRoomJoinable = false
	local selectedDirectoryRoomIndex = nil
	local currentRoomId = nil
	local currentRoomSnapshot = nil
	local currentRoomRevision = -1
	local currentPlayerRoomState = "NotInRoom"
	local currentMatchSnapshot = nil
	local currentMatchRevision = -1
	local transportState = "Idle"
	local activeTransportAttemptId = nil
	local failedTransportAttemptId = nil
	local requestState = "Idle"
	local frontendState = "Browser"
	local membershipGeneration = 0
	local directoryGeneration = 0
	local departedRoomIds = {}
	local closedRoomIds = {}
	local hasRetryableFailure = false

	local function showStatus(text, color)
		status.Text = text
		status.TextColor3 = color or COLORS.Muted
	end

	local function updateDirectorySelectionPresentation()
		for _, entry in directoryRowEntries do
			local isSelected = entry.Room.RoomId == selectedDirectoryRoomId
			entry.Row.BackgroundColor3 = if isSelected then UIStyle.Colors.AccentDim else COLORS.Raised
			FrontendLayout:SetButtonRegion(entry.Row, if isSelected then "ButtonActivePurple" else "ButtonIdle")
		end
		local canJoin = selectedDirectoryRoomId ~= nil
			and selectedDirectoryRoomJoinable
			and currentRoomId == nil
		join.Active = canJoin
		join.TextColor3 = canJoin and COLORS.Acid or COLORS.Muted
	end

	local function chooseDirectoryRoom(entry)
		selectedDirectoryRoomId = entry.Room.RoomId
		selectedDirectoryRoomJoinable = entry.Room.Joinable == true
		selectedDirectoryRoomIndex = entry.Index
		updateDirectorySelectionPresentation()
		showStatus(
			"SELECTED // " .. entry.Room.Name .. " // "
				.. (selectedDirectoryRoomJoinable and "JOINABLE" or "CLOSED"),
			selectedDirectoryRoomJoinable and COLORS.Purple or COLORS.Warning
		)
	end

	local function restoreDirectoryRoomSelection(entry)
		if entry then
			selectedDirectoryRoomId = entry.Room.RoomId
			selectedDirectoryRoomJoinable = entry.Room.Joinable == true
			selectedDirectoryRoomIndex = entry.Index
		else
			selectedDirectoryRoomId = nil
			selectedDirectoryRoomJoinable = false
			selectedDirectoryRoomIndex = nil
		end
		updateDirectorySelectionPresentation()
	end

	local function selectedDirectoryRow()
		local entry = directoryRowsById[selectedDirectoryRoomId]
		return entry and entry.Row or nil
	end

	local function getCurrentMember(snapshotValue)
		if not snapshotValue or type(snapshotValue.Members) ~= "table" then return nil end
		for _, member in snapshotValue.Members do
			if member.UserId == player.UserId then return member end
		end
		return nil
	end

	local function renderRoom(snapshotValue)
		if type(snapshotValue) ~= "table" or type(snapshotValue.RoomId) ~= "string" then
			roomPanel.Visible = false
			createPanel.Visible = true
			updateDirectorySelectionPresentation()
			if multiplayerScope and multiplayerScope:IsActive() then
				multiplayerScope:Refresh(selectedDirectoryRow() or directoryRows[1] or nameBox)
			end
			return
		end
		roomPanel.Visible = true
		createPanel.Visible = false
		roomTitle.Text = snapshotValue.Name
			.. " // "
			.. snapshotValue.State
			.. (snapshotValue.JoinCode and " // CODE " .. snapshotValue.JoinCode or "")
		local lines = {}
		for _, member in snapshotValue.Members do
			table.insert(lines, string.format(
				"%s%s%s // %s // %s",
				member.IsRoomLeader and "◆ " or "",
				member.ClanTag and "[" .. member.ClanTag .. "] " or "",
				member.DisplayName,
				member.TeamId or "NO TEAM",
				member.IsReady and "READY" or member.State
			))
		end
		roster.Text = table.concat(lines, "\n")
		local ownMember = getCurrentMember(snapshotValue)
		local isSystemRoom = snapshotValue.SystemKind
			== MultiplayerConfig.PublicDeathmatch.SystemKind
		currentPlayerRoomState = ownMember and ownMember.State or "NotInRoom"
		readyButton.Text = ownMember and ownMember.IsReady and "UNREADY" or "READY"
		teamButton.Text = "TEAM // " .. (ownMember and ownMember.TeamId or "ALPHA")
		local canLead = snapshotValue.RoomLeaderUserId == player.UserId
			and snapshotValue.State == "Lobby" and not isSystemRoom
		readyButton.Active = not isSystemRoom
		teamButton.Active = not isSystemRoom
		startButton.Text = if isSystemRoom then "AUTO MATCH" else "START MATCH"
		startButton.Active = canLead
		startButton.TextColor3 = canLead and COLORS.Acid or COLORS.Muted
		kickButton.Active = canLead
		transferButton.Active = canLead
		updateDirectorySelectionPresentation()
		if multiplayerScope and multiplayerScope:IsActive() then multiplayerScope:Refresh(readyButton) end
	end

	local function clearCurrentRoom(roomId, didClose)
		if roomId then departedRoomIds[roomId] = true end
		if roomId and didClose then closedRoomIds[roomId] = true end
		if currentMatchSnapshot and callbacks.MatchUpdated then
			callbacks.MatchUpdated({
				Cleared = true,
				RoomId = roomId or currentMatchSnapshot.RoomId,
				MatchId = currentMatchSnapshot.MatchId,
				Generation = currentMatchSnapshot.Generation,
				Revision = currentMatchRevision + 1,
			})
		end
		currentRoomId = nil
		currentRoomSnapshot = nil
		currentRoomRevision = -1
		currentPlayerRoomState = "NotInRoom"
		currentMatchSnapshot = nil
		currentMatchRevision = -1
		frontendState = "Browser"
		transportState = "Idle"
		renderRoom(nil)
	end

	local function adoptRoomSnapshot(snapshotValue, allowRejoin)
		if type(snapshotValue) ~= "table" or type(snapshotValue.RoomId) ~= "string" then return false end
		local roomId = snapshotValue.RoomId
		if allowRejoin then departedRoomIds[roomId] = nil end
		if departedRoomIds[roomId] then return false end
		if currentRoomId and currentRoomId ~= roomId then return false end
		local revision = tonumber(snapshotValue.Revision) or 0
		if currentRoomId == roomId and revision < currentRoomRevision then return false end
		currentRoomId = roomId
		currentRoomSnapshot = snapshotValue
		currentRoomRevision = revision
		if frontendState ~= "Gameplay" and frontendState ~= "PostMatch" then
			frontendState = "RoomLobby"
		end
		renderRoom(snapshotValue)
		if snapshotValue.State == "Lobby"
			and (frontendState == "Gameplay" or frontendState == "PostMatch") then
			if currentMatchSnapshot and currentMatchSnapshot.MatchId then
				departedRoomIds["MATCH:" .. currentMatchSnapshot.MatchId] = true
			end
			currentMatchSnapshot = nil
			currentMatchRevision = -1
			frontendState = "RoomLobby"
			if callbacks.ShowRoomLobby then callbacks.ShowRoomLobby(snapshotValue) end
		elseif not page.Visible and frontendState == "RoomLobby" and callbacks.ShowRoomLobby then
			callbacks.ShowRoomLobby(snapshotValue)
		end
		return true
	end

	local function adoptMatchSnapshot(snapshotValue)
		if type(snapshotValue) ~= "table" then return false end
		if snapshotValue.Cleared then
			if currentRoomId and snapshotValue.RoomId == currentRoomId then
				if currentMatchSnapshot and snapshotValue.MatchId
					and currentMatchSnapshot.MatchId ~= snapshotValue.MatchId then return false end
				if currentMatchSnapshot and currentMatchSnapshot.MatchId then
					departedRoomIds["MATCH:" .. currentMatchSnapshot.MatchId] = true
				end
				currentMatchSnapshot = nil
				currentMatchRevision = math.max(
					currentMatchRevision,
					tonumber(snapshotValue.Revision) or currentMatchRevision
				)
				if callbacks.MatchUpdated then callbacks.MatchUpdated(snapshotValue) end
			end
			return true
		end
		if requestState == "Leaving" then return false end
		if type(snapshotValue.RoomId) ~= "string" or snapshotValue.RoomId ~= currentRoomId then return false end
		if type(snapshotValue.MatchId) ~= "string"
			or departedRoomIds["MATCH:" .. snapshotValue.MatchId] then return false end
		local revision = tonumber(snapshotValue.Revision) or 0
		if currentMatchSnapshot and currentMatchSnapshot.MatchId == snapshotValue.MatchId
			and revision < currentMatchRevision then return false end
		currentMatchSnapshot = snapshotValue
		currentMatchRevision = revision
		if callbacks.MatchUpdated then callbacks.MatchUpdated(snapshotValue) end
		local ownStats = nil
		for _, stats in snapshotValue.Stats or {} do
			if stats.UserId == player.UserId then ownStats = stats end
		end
		if snapshotValue.Phase == "Preparing" or snapshotValue.Phase == "WaitingForClients"
			or snapshotValue.Phase == "Armed" then
			currentPlayerRoomState = "Loading"
		elseif ownStats and ownStats.IsSpectating then
			currentPlayerRoomState = "Spectating"
		elseif ownStats and ownStats.IsAlive == false then
			currentPlayerRoomState = "Dead"
		elseif snapshotValue.Phase == "Fighting" or snapshotValue.State == "Active" then
			currentPlayerRoomState = "Alive"
		elseif snapshotValue.State == "PostMatch" then
			currentPlayerRoomState = "PostMatch"
		end
		if snapshotValue.Phase == "Preparing" or snapshotValue.Phase == "WaitingForClients"
			or snapshotValue.Phase == "Armed" or snapshotValue.Phase == "Fighting"
			or snapshotValue.Phase == "PostRound" or snapshotValue.State == "Countdown"
			or snapshotValue.State == "Active" or snapshotValue.State == "Intermission" then
			if frontendState ~= "Gameplay" then
				frontendState = "Gameplay"
				if callbacks.EnterGameplay then callbacks.EnterGameplay(snapshotValue) end
			end
		elseif snapshotValue.State == "PostMatch" then
			frontendState = "PostMatch"
		end
		return true
	end

	local function renderRooms(rooms)
		local previousSelectedRoomId = selectedDirectoryRoomId
		local previousSelectedIndex = selectedDirectoryRoomIndex or 1
		table.clear(directoryRows)
		table.clear(directoryRowsById)
		table.clear(directoryRowEntries)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		local visibleCount = 0
		for _, room in rooms or {} do
			if not closedRoomIds[room.RoomId] then
				visibleCount += 1
				local rowIndex = visibleCount
				local availability = room.Joinable and "JOINABLE" or "CLOSED"
				local row = button(
					list,
					string.format(
						"%s  //  %s  //  %s  //  %d/%d  //  %s  //  %s",
						room.Name,
						room.ModeId,
						room.MapId,
						room.CurrentPlayers,
						room.MaximumPlayers,
						room.State,
						availability
					),
					UDim2.new(),
					UDim2.new(1, -8, 0, 42)
				)
				row.LayoutOrder = visibleCount
				table.insert(directoryRows, row)
				local entry = { Row = row, Room = room, Index = rowIndex }
				directoryRowsById[room.RoomId] = entry
				table.insert(directoryRowEntries, entry)
				row.TextXAlignment = Enum.TextXAlignment.Left
				multiplayerScope:Register(row, {
					SelectionMode = "ChooseOnFocus",
					SelectionIdentity = room.RoomId,
					OnFocused = function()
						chooseDirectoryRoom(entry)
					end,
				})
			end
		end
		list.CanvasSize = UDim2.fromOffset(0, visibleCount * 48)
		local selectedEntry = directoryRowsById[previousSelectedRoomId]
		if not selectedEntry and #directoryRowEntries > 0 then
			selectedEntry = directoryRowEntries[math.clamp(previousSelectedIndex, 1, #directoryRowEntries)]
		end
		restoreDirectoryRoomSelection(selectedEntry)
		if multiplayerScope and multiplayerScope:IsActive() and not currentRoomId then
			multiplayerScope:Refresh(selectedEntry and selectedEntry.Row or nameBox)
		end
	end

	local function requestDirectoryRefresh()
		if not directoryRequest then return end
		directoryGeneration += 1
		local generation = directoryGeneration
		invokeBounded(directoryRequest, "List", nil, function(result)
			if generation ~= directoryGeneration then return end
			if result.Success and type(result.Rooms) == "table" then
				renderRooms(result.Rooms)
				if not hasRetryableFailure then showStatus("ROOM DIRECTORY UPDATED", COLORS.Acid) end
			else
				hasRetryableFailure = true
				showStatus(tostring(result.Code or "DIRECTORY_UNAVAILABLE"), COLORS.Warning)
			end
		end)
	end

	local function requestMembershipSnapshot()
		if not roomRequest or requestState == "Leaving" then return end
		membershipGeneration += 1
		local generation = membershipGeneration
		invokeBounded(roomRequest, "Snapshot", nil, function(result)
			if generation ~= membershipGeneration then return end
			if not result.Success then
				hasRetryableFailure = true
				showStatus("ROOM REFRESH FAILED // " .. tostring(result.Code), COLORS.Warning)
				return
			end
			if result.Snapshot then
				adoptRoomSnapshot(result.Snapshot, false)
				if result.MatchSnapshot then adoptMatchSnapshot(result.MatchSnapshot) end
			elseif currentRoomId then
				clearCurrentRoom(currentRoomId, false)
			end
		end)
	end

	local function handleTransportResult(result)
		local function emitTransportAudio(role)
			local control = pendingTransportAudioControl
			pendingTransportAudioControl = nil
			if control then UINavigationController:EmitAudioEvent(role, control) end
		end
		requestState = "Idle"
		if result.TransportAttemptId and result.TransportAttemptId == failedTransportAttemptId then
			transportState = "Failed"
			activeTransportAttemptId = nil
			emitTransportAudio("Denied")
			return
		end
		if not result.Success or result.Transport == "Failure" then
			transportState = "Failed"
			activeTransportAttemptId = nil
			hasRetryableFailure = true
			showStatus("ROOM REQUEST FAILED // " .. tostring(result.Code or "FAILED"), COLORS.Warning)
			emitTransportAudio("Denied")
			return
		end
		if result.Transport == "LocalRoom" and type(result.RoomSnapshot) == "table" then
			transportState = "LocalReady"
			hasRetryableFailure = false
			adoptRoomSnapshot(result.RoomSnapshot, true)
			if result.MatchSnapshot then adoptMatchSnapshot(result.MatchSnapshot) end
			showStatus("LOCAL ROOM READY", COLORS.Acid)
			emitTransportAudio("Confirm")
			return
		end
		if result.Transport == "ReservedServerTeleport" and result.Status == "Teleporting" then
			transportState = "Teleporting"
			activeTransportAttemptId = result.TransportAttemptId
			hasRetryableFailure = false
			showStatus("TELEPORTING TO RESERVED ROOM...", COLORS.Acid)
			emitTransportAudio("Confirm")
			return
		end
		transportState = "Failed"
		activeTransportAttemptId = nil
		hasRetryableFailure = true
		showStatus("ROOM REQUEST FAILED // INVALID_TRANSPORT", COLORS.Warning)
		emitTransportAudio("Denied")
		warn("[BLIKK ROOM] Client request failed: INVALID_TRANSPORT")
	end

	local function beginTransport(operation, payload, nextTransportState, audioControl)
		if requestState ~= "Idle" then return "Busy" end
		if not directoryRequest or currentRoomId or transportState == "Teleporting" then return "Denied" end
		membershipGeneration += 1
		local generation = membershipGeneration
		requestState = operation
		transportState = nextTransportState
		pendingTransportAudioControl = audioControl
		hasRetryableFailure = false
		showStatus(if operation == "Create" then "CREATING ROOM..." else "JOINING ROOM...", COLORS.Muted)
		invokeBounded(directoryRequest, operation, payload, function(result)
			if generation ~= membershipGeneration then return end
			handleTransportResult(result)
		end, MultiplayerConfig.Directory.TransportPrecommitDeadlineSeconds
			+ MultiplayerConfig.Directory.CommittedTransportAbortDelaySeconds
			+ 5)
		return "Started"
	end

	local function mutateRoom(operation, payload)
		if not roomRequest or not currentRoomId or requestState ~= "Idle" then return false end
		membershipGeneration += 1
		local generation = membershipGeneration
		requestState = operation
		invokeBounded(roomRequest, operation, payload, function(result)
			if generation ~= membershipGeneration then return end
			requestState = "Idle"
			if result.Success and result.Snapshot then
				hasRetryableFailure = false
				adoptRoomSnapshot(result.Snapshot, false)
				showStatus(operation == "Start" and "MATCH START CONFIRMED" or "ROOM UPDATED", COLORS.Acid)
			else
				hasRetryableFailure = true
				showStatus(tostring(result.Code or "ROOM_REQUEST_FAILED"), COLORS.Warning)
				if result.Code == "NOT_ROOM_LEADER" then requestMembershipSnapshot() end
			end
		end)
		return true
	end

	local function leaveCurrentRoom()
		if requestState == "Leaving" then return false end
		if not currentRoomId then
			if requestState ~= "Idle" or transportState == "Creating"
				or transportState == "Joining" or transportState == "Teleporting" then
				showStatus("ROOM TRANSPORT IN PROGRESS // WAIT FOR COMPLETION", COLORS.Warning)
				return false
			end
			if callbacks.ReturnToHub then callbacks.ReturnToHub() else navigation:GoTo("OperationsHub") end
			return true
		end
		if not roomRequest then
			showStatus("LEAVE FAILED // SERVICE_UNAVAILABLE", COLORS.Warning)
			return false
		end
		membershipGeneration += 1
		local generation = membershipGeneration
		local leavingRoomId = currentRoomId
		requestState = "Leaving"
		hasRetryableFailure = false
		showStatus("LEAVING ROOM...", COLORS.Muted)
		invokeBounded(roomRequest, "Leave", nil, function(result)
			if generation ~= membershipGeneration then return end
			requestState = "Idle"
			if not result.Success then
				hasRetryableFailure = true
				showStatus("LEAVE FAILED // " .. tostring(result.Code or "RETRY"), COLORS.Warning)
				warn("[BLIKK ROOM] Leave request failed: " .. tostring(result.Code or "FAILED"))
				if not page.Visible and callbacks.ShowRoomLobby then
					callbacks.ShowRoomLobby(currentRoomSnapshot)
				end
				return
			end
			local confirmedRoomId = result.LeftRoomId or leavingRoomId
			clearCurrentRoom(confirmedRoomId, result.RoomClosed == true)
			requestDirectoryRefresh()
			if callbacks.ReturnToHub then callbacks.ReturnToHub() else navigation:GoTo("OperationsHub") end
		end, MultiplayerConfig.LeaveRequestTimeoutSeconds)
		return true
	end

	local function changeMode(offset)
		modeIndex = (modeIndex - 1 + offset) % #modeIds + 1
		modeButton.Text = "MODE // " .. Modes.Get(modeIds[modeIndex]).DisplayName
	end
	bindActivation(modeButton, function() changeMode(1) end)
	adjustCallbacks[modeButton] = function(direction)
		if direction == "Left" then changeMode(-1); return true end
		if direction == "Right" then changeMode(1); return true end
		return false
	end
	local function toggleAccess()
		isPublic = not isPublic
		accessButton.Text = "ACCESS // " .. (isPublic and "PUBLIC" or "PRIVATE")
	end
	bindActivation(accessButton, toggleAccess)
	adjustCallbacks[accessButton] = function(direction)
		if direction == "Left" or direction == "Right" then toggleAccess(); return true end
		return false
	end
	bindActivation(createButton, function()
		local result = beginTransport("Create", {
			Name = nameBox.Text,
			IsPublic = isPublic,
			MapId = "DistrictZero",
			ModeId = modeIds[modeIndex],
			MaximumPlayers = 16,
			SpectatorSlots = 4,
			JoinInProgressEnabled = true,
			Mutators = {},
		}, "Creating", createButton)
		if result == "Denied" then UINavigationController:EmitAudioEvent("Denied", createButton) end
	end, "Silent")
	bindActivation(publicDeathmatchButton, function()
		local result = beginTransport(
			"QuickPlayPublicDeathmatch",
			nil,
			"Joining",
			publicDeathmatchButton
		)
		if result == "Denied" then
			UINavigationController:EmitAudioEvent("Denied", publicDeathmatchButton)
		end
	end, "Silent")
	bindActivation(readyButton, function()
		local member = getCurrentMember(currentRoomSnapshot)
		mutateRoom("SetReady", not (member and member.IsReady))
	end)
	bindActivation(teamButton, function()
		local member = getCurrentMember(currentRoomSnapshot)
		mutateRoom("SetTeam", member and member.TeamId == "ALPHA" and "OMEGA" or "ALPHA")
	end)
	bindActivation(startButton, function()
		if not currentRoomSnapshot
			or currentRoomSnapshot.RoomLeaderUserId ~= player.UserId
			or currentRoomSnapshot.State ~= "Lobby" then
			showStatus("ROOM LEADER CONTROL UNAVAILABLE", COLORS.Warning)
			return
		end
		mutateRoom("Start", nil)
	end)
	bindActivation(leaveButton, leaveCurrentRoom)
	bindActivation(kickButton, function()
		mutateRoom("Kick", tonumber(memberBox.Text))
	end)
	bindActivation(transferButton, function()
		mutateRoom("TransferLeader", tonumber(memberBox.Text))
	end)
	bindActivation(refresh, requestDirectoryRefresh)
	bindActivation(join, function()
		if not selectedDirectoryRoomId then
			showStatus("SELECT A ROOM", COLORS.Warning)
			UINavigationController:EmitAudioEvent("Denied", join)
			return
		end
		if not selectedDirectoryRoomJoinable then
			showStatus("ROOM NOT JOINABLE", COLORS.Warning)
			UINavigationController:EmitAudioEvent("Denied", join)
			return
		end
		local result = beginTransport("Join", {
			RoomId = selectedDirectoryRoomId,
			RequestedRole = "Player",
		}, "Joining", join)
		if result == "Denied" then UINavigationController:EmitAudioEvent("Denied", join) end
	end, "Silent")
	bindActivation(joinCodeButton, function()
		if beginTransport("JoinCode", joinCode.Text, "Joining", joinCodeButton) == "Denied" then
			UINavigationController:EmitAudioEvent("Denied", joinCodeButton)
		end
	end, "Silent")
	bindActivation(back, leaveCurrentRoom)

	if roomUpdated and roomUpdated:IsA("RemoteEvent") then
		roomUpdated.OnClientEvent:Connect(function(value)
			if type(value) ~= "table" then return end
			if value.Warning then
				if value.Warning == "REMOVED_FROM_ROOM" then
					clearCurrentRoom(value.RoomId or currentRoomId, value.RoomClosed == true)
					if callbacks.ReturnToHub then callbacks.ReturnToHub() end
				elseif value.Warning == "TELEPORT_FAILED_RETRY" then
					local failedAttemptId = value.TransportAttemptId
					failedTransportAttemptId = failedAttemptId
					if not activeTransportAttemptId or activeTransportAttemptId == failedAttemptId then
						membershipGeneration += 1
						requestState = "Idle"
						transportState = "Failed"
						activeTransportAttemptId = nil
					end
					showStatus(value.Warning, COLORS.Warning)
				else
					showStatus(value.Warning, COLORS.Warning)
				end
				return
			end
			if requestState ~= "Leaving" then adoptRoomSnapshot(value, false) end
		end)
	end
	if matchUpdated and matchUpdated:IsA("RemoteEvent") then
		matchUpdated.OnClientEvent:Connect(adoptMatchSnapshot)
	end
	if not directoryRequest or not roomRequest or not roomUpdated or not matchUpdated then
		showStatus("MULTIPLAYER SERVICE UNAVAILABLE", COLORS.Warning)
		warn("[BLIKK ROOM] Client routing failed: REMOTE_LOOKUP_FAILED")
	end

	multiplayerScope = UINavigationController:CreateScope("Multiplayer", {
		Root = page,
		Default = function()
			if currentRoomId then return readyButton end
			return selectedDirectoryRow() or directoryRows[1] or nameBox
		end,
		Back = leaveCurrentRoom,
	})
	for control, callback in activationCallbacks do
		multiplayerScope:Register(control, {
			Activate = callback,
			Adjust = adjustCallbacks[control],
			AudioRole = activationAudioRoles[control],
		})
	end
	for _, textBox in { nameBox, memberBox, joinCode } do multiplayerScope:Register(textBox) end

	local object = {}
	function object:SetVisible(visible)
		page.Visible = visible
		if not visible then
			multiplayerScope:SetActive(false)
			for _, textBox in { nameBox, memberBox, joinCode } do
				if textBox:IsFocused() then textBox:ReleaseFocus(false) end
			end
			return
		end
		frontendState = currentRoomId and "RoomLobby" or "Browser"
		renderRoom(currentRoomSnapshot)
		multiplayerScope:SetActive(true)
		multiplayerScope:Refresh(
			if currentRoomId then readyButton else selectedDirectoryRow() or directoryRows[1] or nameBox
		)
		requestMembershipSnapshot()
		requestDirectoryRefresh()
	end
	function object:HasCurrentRoom()
		return currentRoomId ~= nil
	end
	function object:LeaveCurrentRoom()
		return leaveCurrentRoom()
	end
	function object:GetState()
		return {
			Transport = transportState,
			Request = requestState,
			Frontend = frontendState,
			RoomId = currentRoomId,
			PlayerState = currentPlayerRoomState,
		}
	end

	task.defer(requestMembershipSnapshot)
	return object
end

return Controller
