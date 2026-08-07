local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UINavigationController = require(script.Parent.Parent.UI.UINavigationController)

local Controller = {}
local REMOTE_WAIT_SECONDS = 5
local SPECTATOR_BLOCKER_OWNER = "Spectator"
local isInitialised = false
local adoptMatchSnapshot = nil

local function waitForRemote(parent, name, className, deadline)
	local remainingSeconds = math.max(0, deadline - os.clock())
	local remote = parent:FindFirstChild(name)
		or parent:WaitForChild(name, remainingSeconds)
	if not remote or not remote:IsA(className) then
		warn(string.format("[BLIKK SPECTATOR] Missing %s %s; spectator controls are unavailable", className, name))
		return nil
	end
	return remote
end

function Controller:Init(inputManager, gameplayCamera)
	if isInitialised then return end
	local remoteDeadline = os.clock() + REMOTE_WAIT_SECONDS
	local remotes = ReplicatedStorage:FindFirstChild("BLIKKRemotes")
		or ReplicatedStorage:WaitForChild("BLIKKRemotes", REMOTE_WAIT_SECONDS)
	if not remotes then
		warn("[BLIKK SPECTATOR] BLIKKRemotes did not replicate; spectator controls are unavailable")
		return
	end
	local spectatorRequest = waitForRemote(remotes, "SpectatorRequest", "RemoteFunction", remoteDeadline)
	local replayRequest = waitForRemote(remotes, "ReplayRequest", "RemoteFunction", remoteDeadline)
	local reportRequest = waitForRemote(remotes, "ReportRequest", "RemoteFunction", remoteDeadline)
	local matchUpdated = waitForRemote(remotes, "MatchUpdated", "RemoteEvent", remoteDeadline)
	if not spectatorRequest or not replayRequest or not reportRequest or not matchUpdated then return end
	isInitialised = true

	local gui = Instance.new("ScreenGui"); gui.Name = "BLIKKSpectatorReplay"; gui.ResetOnSpawn = false
	local panel = Instance.new("Frame"); panel.AnchorPoint = Vector2.new(0.5, 1); panel.BackgroundColor3 = Color3.fromRGB(12, 13, 16); panel.Position = UDim2.new(0.5, 0, 1, -24); panel.Size = UDim2.fromOffset(560, 90); panel.Visible = false; panel.Parent = gui
	local targetLabel = Instance.new("TextLabel"); targetLabel.BackgroundTransparency = 1; targetLabel.Font = Enum.Font.Code; targetLabel.TextColor3 = Color3.fromRGB(230, 227, 215); targetLabel.Position = UDim2.fromOffset(14, 8); targetLabel.Size = UDim2.new(1, -28, 0, 26); targetLabel.TextSize = 14; targetLabel.Parent = panel
	local function makeButton(text, x)
		local button = Instance.new("TextButton"); button.BackgroundColor3 = Color3.fromRGB(28, 28, 34); button.Font = Enum.Font.Code; button.Text = text; button.TextColor3 = Color3.fromRGB(230, 227, 215); button.Position = UDim2.fromOffset(x, 44); button.Size = UDim2.fromOffset(125, 32); button.Parent = panel; return button
	end
	local previous = makeButton("PREVIOUS", 14); local nextButton = makeButton("NEXT", 148); local replay = makeButton("REPLAY LIST", 282); local report = makeButton("REPORT", 416)
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then error("[BLIKK SPECTATOR] PlayerGui was unavailable after bootstrap", 0) end
	gui.Parent = playerGui
	local targets, targetIndex, currentMatch = {}, 0, nil
	local pendingReportTarget = nil
	local spectatorScope = nil
	local spectatorActive = false
	local spectatorGeneration = 0
	local isDestroyed = false
	local function follow(index)
		if #targets == 0 then targetLabel.Text = "SPECTATING // NO ELIGIBLE TARGET"; return end
		targetIndex = (index - 1) % #targets + 1; local target = targets[targetIndex]; local player = Players:GetPlayerByUserId(target.UserId); local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local currentCamera = Workspace.CurrentCamera
		if humanoid and currentCamera then currentCamera.CameraType = Enum.CameraType.Custom; currentCamera.CameraSubject = humanoid; targetLabel.Text = "SPECTATING // " .. (target.ClanTag and "[" .. target.ClanTag .. "] " or "") .. target.DisplayName end
	end
	local function enterSpectator()
		if spectatorActive then return end
		spectatorActive = true
		spectatorGeneration += 1
		local generation = spectatorGeneration
		panel.Visible = true
		inputManager:SetGameplayBlocked(SPECTATOR_BLOCKER_OWNER, true)
		gameplayCamera:SetGameplayBlocked(SPECTATOR_BLOCKER_OWNER, true)
		if spectatorScope then spectatorScope:SetActive(true); spectatorScope:Refresh(previous) end
		task.spawn(function()
			local ok, result = pcall(spectatorRequest.InvokeServer, spectatorRequest, "Targets")
			if isDestroyed or not spectatorActive or generation ~= spectatorGeneration then return end
			targets = ok and type(result) == "table" and result.Success
				and type(result.Targets) == "table" and result.Targets or {}
			follow(1)
		end)
	end
	local function leaveSpectator()
		if not spectatorActive then return end
		spectatorActive = false
		spectatorGeneration += 1
		panel.Visible = false; targets = {}; pendingReportTarget = nil; report.Text = "REPORT"; if spectatorScope then spectatorScope:SetActive(false) end
		inputManager:SetGameplayBlocked(SPECTATOR_BLOCKER_OWNER, false)
		gameplayCamera:SetGameplayBlocked(SPECTATOR_BLOCKER_OWNER, false)
	end
	local function followPrevious() follow(targetIndex - 1) end
	local function followNext() follow(targetIndex + 1) end
	local function listReplays() local ok, result = pcall(replayRequest.InvokeServer, replayRequest, "List"); targetLabel.Text = ok and result.Success and ("REPLAY V1 // " .. #result.Clips .. " BOUNDED CLIPS AVAILABLE") or "REPLAY UNAVAILABLE" end
	local function submitOrConfirmReport()
		local target = targets[targetIndex]; if not target then return end
		if pendingReportTarget ~= target.UserId then pendingReportTarget = target.UserId; report.Text = "CONFIRM REPORT"; targetLabel.Text = "CONFIRM REPORT // UNSPORTING BEHAVIOR // " .. target.DisplayName; return end
		pendingReportTarget = nil; report.Text = "REPORT"
		local ok, result = pcall(reportRequest.InvokeServer, reportRequest, { TargetUserId = target.UserId, ReasonCode = "UnsportingBehavior", Note = "" })
		targetLabel.Text = ok and result.Success and ("REPORT RECEIVED // " .. result.ReportId) or ("REPORT FAILED // " .. tostring(ok and result.Code or "SERVICE"))
	end
	previous.Activated:Connect(followPrevious); nextButton.Activated:Connect(followNext)
	replay.Activated:Connect(listReplays); report.Activated:Connect(submitOrConfirmReport)
	spectatorScope = UINavigationController:CreateScope("SpectatorControls", {
		Root = panel,
		Default = previous,
		Back = function()
			if pendingReportTarget then
				pendingReportTarget = nil
				report.Text = "REPORT"
				follow(targetIndex)
			end
		end,
	})
	spectatorScope:Register(previous, { Activate = followPrevious })
	spectatorScope:Register(nextButton, { Activate = followNext })
	spectatorScope:Register(replay, { Activate = listReplays })
	spectatorScope:Register(report, { Activate = submitOrConfirmReport })
	local function adoptSnapshot(snapshot)
		if type(snapshot) ~= "table" then return false end
		if snapshot.Cleared then
			if currentMatch and snapshot.MatchId and currentMatch.MatchId ~= snapshot.MatchId then return end
			currentMatch = nil
			if spectatorActive then leaveSpectator() end
			return true
		end
		if currentMatch and currentMatch.MatchId == snapshot.MatchId
			and (tonumber(snapshot.Revision) or 0) < (tonumber(currentMatch.Revision) or 0) then return false end
		currentMatch = snapshot
		local own = nil
		for _, stats in snapshot.Stats or {} do
			if stats.UserId == Players.LocalPlayer.UserId then own = stats end
		end
		local spectatorPhase = own and own.PreparationPhase
		local shouldSpectate = own and own.IsSpectating and (
			spectatorPhase == "Dead"
			or spectatorPhase == "WaitingForRound"
			or spectatorPhase == "TimedOut"
			or spectatorPhase == "Failed"
		)
		if shouldSpectate then enterSpectator() elseif spectatorActive then leaveSpectator() end
		return true
	end
	adoptMatchSnapshot = adoptSnapshot
	local matchUpdatedConnection = matchUpdated.OnClientEvent:Connect(adoptSnapshot)
	script.Destroying:Connect(function()
		isDestroyed = true
		matchUpdatedConnection:Disconnect()
		leaveSpectator()
		if adoptMatchSnapshot == adoptSnapshot then adoptMatchSnapshot = nil end
		if spectatorScope then spectatorScope:Destroy() end
		gui:Destroy()
	end)
end

function Controller:AdoptMatchSnapshot(snapshot)
	return if adoptMatchSnapshot then adoptMatchSnapshot(snapshot) else false
end

return Controller
