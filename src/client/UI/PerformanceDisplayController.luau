local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)

local Controller = {}

function Controller:Init()
	local gui = Instance.new("ScreenGui"); gui.Name = "BLIKKPerformanceDisplay"; gui.ResetOnSpawn = false
	local value = Instance.new("TextLabel"); value.AnchorPoint = Vector2.new(1, 0); value.BackgroundTransparency = 0.35
	value.BackgroundColor3 = Color3.new(); value.Font = Enum.Font.Code; value.Position = UDim2.new(1, -12, 0, 12)
	value.Size = UDim2.fromOffset(190, 24); value.TextColor3 = Color3.fromRGB(230, 227, 215); value.TextSize = 12
	value.TextXAlignment = Enum.TextXAlignment.Right; value.Parent = gui; gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frames, elapsed, fps, ping = 0, 0, 0, 0
	local function refresh()
		local parts = {}; if SessionSettings:Get("ShowFPS") then table.insert(parts, tostring(fps) .. " FPS") end
		if SessionSettings:Get("ShowPing") then table.insert(parts, tostring(ping) .. " MS") end
		value.Text = table.concat(parts, "  //  "); value.Visible = #parts > 0
	end
	RunService.RenderStepped:Connect(function(deltaTime)
		frames += 1; elapsed += deltaTime
		if elapsed >= 1 then fps = math.floor(frames / elapsed + 0.5); ping = math.floor(Players.LocalPlayer:GetNetworkPing() * 2000 + 0.5); frames = 0; elapsed = 0; refresh() end
	end)
	SessionSettings.Changed.Event:Connect(function(key) if key == "ShowFPS" or key == "ShowPing" then refresh() end end)
	refresh()
end

return Controller
