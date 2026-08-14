local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TechniqueConfig = require(ReplicatedStorage.Shared.Movement.TechniqueConfig)
local UIAtlas = require(script.Parent.UIAtlas)
local UIStyle = require(script.Parent.UIStyle)

local Controller = {}

local player = Players.LocalPlayer
local label
local notificationFrame
local serial = 0
local isInitialised = false

local DISPLAY_NAMES = {
	Butterfly = "BUTTERFLY",
	DoubleButterfly = "DOUBLE BUTTERFLY",
	TripleButterfly = "TRIPLE BUTTERFLY",
	SwapShot = "SWAP SHOT",
	ReloadShot = "RELOAD SHOT",
	SlashShot = "SLASH SHOT",
	HalfStep = "HALF STEP",
}

local function showTechnique(name)
	local displayName = DISPLAY_NAMES[name]
	if not displayName or not label then return end
	serial += 1
	local showSerial = serial
	label.Text = "TECH // " .. displayName
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.30
	if notificationFrame then notificationFrame.ImageTransparency = 0.12 end
	task.delay(TechniqueConfig.Feedback.VisibleSeconds, function()
		if showSerial ~= serial or not label or not label.Parent then return end
		local tween = TweenService:Create(
			label,
			TweenInfo.new(TechniqueConfig.Feedback.FadeSeconds, Enum.EasingStyle.Quad),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		tween:Play()
		if notificationFrame then
			TweenService:Create(
				notificationFrame,
				TweenInfo.new(TechniqueConfig.Feedback.FadeSeconds, Enum.EasingStyle.Quad),
				{ ImageTransparency = 1 }
			):Play()
		end
	end)
end

function Controller:Init(techniqueController)
	if isInitialised then return end
	isInitialised = true
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BLIKKTechniqueFeedback"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = UIStyle.DisplayOrders.Hud + 1
	screenGui.Parent = playerGui
	notificationFrame = UIAtlas:CreateSprite(screenGui, "NotificationCompact", "TechniqueFrame")
	if notificationFrame then
		notificationFrame.AnchorPoint = Vector2.new(0, 1)
		notificationFrame.Position = UDim2.new(
			0,
			TechniqueConfig.Feedback.LeftOffsetPixels - 18,
			1,
			-TechniqueConfig.Feedback.BottomOffsetPixels + 18
		)
		notificationFrame.Size = UDim2.fromOffset(440, 70)
		notificationFrame.ImageTransparency = 1
		notificationFrame.ZIndex = 0
	end

	label = Instance.new("TextLabel")
	label.Name = "TechniqueLabel"
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(
		0,
		TechniqueConfig.Feedback.LeftOffsetPixels,
		1,
		-TechniqueConfig.Feedback.BottomOffsetPixels
	)
	label.Size = UDim2.fromOffset(420, 30)
	label.BackgroundTransparency = 1
	label.Font = UIStyle.Fonts.Strong
	label.Text = ""
	label.TextColor3 = UIStyle.Colors.Technique
	label.TextSize = TechniqueConfig.Feedback.TextSizePixels
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 1
	label.Parent = screenGui

	techniqueController.TechniqueAccepted.Event:Connect(showTechnique)
end

return Controller
