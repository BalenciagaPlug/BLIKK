local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local Controller = {}

function Controller:Init(inputManager)
	local remote = ReplicatedStorage:WaitForChild("BLIKKRemotes"):WaitForChild("RoomActivity")
	local lastSentAt = -math.huge
	inputManager.ActionBegan.Event:Connect(function()
		local now = os.clock()
		if now - lastSentAt >= Config.ActivityPingMinimumIntervalSeconds then lastSentAt = now; remote:FireServer() end
	end)
end

return Controller
