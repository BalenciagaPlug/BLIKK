local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Controller = {}

function Controller:Init(inputManager, gameplayCamera)
	local remotes = ReplicatedStorage:WaitForChild("BLIKKRemotes")
	local spectatorRequest = remotes:WaitForChild("SpectatorRequest")
	local replayRequest = remotes:WaitForChild("ReplayRequest")
	local reportRequest = remotes:WaitForChild("ReportRequest")
	local gui = Instance.new("ScreenGui"); gui.Name = "BLIKKSpectatorReplay"; gui.ResetOnSpawn = false
	local panel = Instance.new("Frame"); panel.AnchorPoint = Vector2.new(0.5, 1); panel.BackgroundColor3 = Color3.fromRGB(12, 13, 16); panel.Position = UDim2.new(0.5, 0, 1, -24); panel.Size = UDim2.fromOffset(560, 90); panel.Visible = false; panel.Parent = gui
	local targetLabel = Instance.new("TextLabel"); targetLabel.BackgroundTransparency = 1; targetLabel.Font = Enum.Font.Code; targetLabel.TextColor3 = Color3.fromRGB(230, 227, 215); targetLabel.Position = UDim2.fromOffset(14, 8); targetLabel.Size = UDim2.new(1, -28, 0, 26); targetLabel.TextSize = 14; targetLabel.Parent = panel
	local function makeButton(text, x)
		local button = Instance.new("TextButton"); button.BackgroundColor3 = Color3.fromRGB(28, 28, 34); button.Font = Enum.Font.Code; button.Text = text; button.TextColor3 = Color3.fromRGB(230, 227, 215); button.Position = UDim2.fromOffset(x, 44); button.Size = UDim2.fromOffset(125, 32); button.Parent = panel; return button
	end
	local previous = makeButton("PREVIOUS", 14); local nextButton = makeButton("NEXT", 148); local replay = makeButton("REPLAY LIST", 282); local report = makeButton("REPORT", 416)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local targets, targetIndex, currentMatch = {}, 0, nil
	local pendingReportTarget = nil
	local function follow(index)
		if #targets == 0 then targetLabel.Text = "SPECTATING // NO ELIGIBLE TARGET"; return end
		targetIndex = (index - 1) % #targets + 1; local target = targets[targetIndex]; local player = Players:GetPlayerByUserId(target.UserId); local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom; Workspace.CurrentCamera.CameraSubject = humanoid; targetLabel.Text = "SPECTATING // " .. (target.ClanTag and "[" .. target.ClanTag .. "] " or "") .. target.DisplayName end
	end
	local function enterSpectator()
		local ok, result = pcall(spectatorRequest.InvokeServer, spectatorRequest, "Targets")
		targets = ok and result.Success and result.Targets or {}; panel.Visible = true; inputManager:SetGameplayEnabled(false); gameplayCamera:SetGameplayActive(false); follow(1)
	end
	local function leaveSpectator()
		panel.Visible = false; targets = {}; gameplayCamera:SetGameplayActive(true); inputManager:SetGameplayEnabled(true)
	end
	previous.Activated:Connect(function() follow(targetIndex - 1) end); nextButton.Activated:Connect(function() follow(targetIndex + 1) end)
	replay.Activated:Connect(function() local ok, result = pcall(replayRequest.InvokeServer, replayRequest, "List"); targetLabel.Text = ok and result.Success and ("REPLAY V1 // " .. #result.Clips .. " BOUNDED CLIPS AVAILABLE") or "REPLAY UNAVAILABLE" end)
	report.Activated:Connect(function()
		local target = targets[targetIndex]; if not target then return end
		if pendingReportTarget ~= target.UserId then pendingReportTarget = target.UserId; report.Text = "CONFIRM REPORT"; targetLabel.Text = "CONFIRM REPORT // UNSPORTING BEHAVIOR // " .. target.DisplayName; return end
		pendingReportTarget = nil; report.Text = "REPORT"
		local ok, result = pcall(reportRequest.InvokeServer, reportRequest, { TargetUserId = target.UserId, ReasonCode = "UnsportingBehavior", Note = "" })
		targetLabel.Text = ok and result.Success and ("REPORT RECEIVED // " .. result.ReportId) or ("REPORT FAILED // " .. tostring(ok and result.Code or "SERVICE"))
	end)
	remotes.MatchUpdated.OnClientEvent:Connect(function(snapshot)
		currentMatch = snapshot; local own = nil; for _, stats in snapshot.Stats do if stats.UserId == Players.LocalPlayer.UserId then own = stats end end
		if own and own.IsSpectating then enterSpectator() elseif panel.Visible then leaveSpectator() end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function() if panel.Visible then leaveSpectator() end end)
end

return Controller
