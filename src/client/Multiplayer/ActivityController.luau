local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local Controller = {}
local isInitialised = false

function Controller:Init(inputManager)
	if isInitialised then return end
	local remotes = ReplicatedStorage:WaitForChild("BLIKKRemotes", Config.RemoteLookupTimeoutSeconds)
	local remote = remotes and remotes:WaitForChild("RoomActivity", Config.RemoteLookupTimeoutSeconds)
	if not remote or not remote:IsA("RemoteEvent") then
		warn("[BLIKK ACTIVITY] Room activity remote was unavailable; AFK input hints are disabled.")
		return
	end
	isInitialised = true
	local lastSentAt = -math.huge
	inputManager.ActionBegan.Event:Connect(function()
		local now = os.clock()
		if now - lastSentAt >= Config.ActivityPingMinimumIntervalSeconds then lastSentAt = now; remote:FireServer() end
	end)
end

return Controller
