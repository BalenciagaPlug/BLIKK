local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)

local SplashScreenController = {}

function SplashScreenController:Create(parent, navigation)
	local page = Instance.new("Frame")
	page.Name = "Splash"
	page.BackgroundColor3 = Color3.fromRGB(4, 5, 5)
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(4, 5, 5), Color3.fromRGB(24, 38, 22), Color3.fromRGB(4, 5, 5))
	gradient.Rotation = -18
	gradient.Parent = page
	TweenService:Create(gradient, TweenInfo.new(8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(0.35, 0) }):Play()
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = Branding.Colors.Purple
	glow.BackgroundTransparency = 0.82
	glow.BorderSizePixel = 0
	glow.Position = UDim2.fromScale(0.5, 0.47)
	glow.Size = UDim2.fromScale(0.48, 0.34)
	glow.Parent = page
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow

	local brandGroup = Instance.new("CanvasGroup")
	brandGroup.Name = "BrandPresentation"
	brandGroup.AnchorPoint = Vector2.new(0.5, 0.5)
	brandGroup.BackgroundTransparency = 1
	brandGroup.GroupTransparency = 1
	brandGroup.Position = UDim2.fromScale(0.5, 0.47)
	brandGroup.Size = Branding.Sizes.Splash
	brandGroup.Parent = page
	Branding.CreateFullLogo(brandGroup)
	local brandScale = Instance.new("UIScale")
	brandScale.Parent = brandGroup
	TweenService:Create(
		brandGroup,
		TweenInfo.new(Branding.Animation.FadeInSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 0 }
	):Play()
	TweenService:Create(
		brandScale,
		TweenInfo.new(Branding.Animation.BreathSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = Branding.Animation.BreathScale }
	):Play()
	local prompt = Instance.new("TextLabel")
	prompt.BackgroundTransparency = 1; prompt.Size = UDim2.new(1, 0, 0, 30); prompt.Position = UDim2.new(0, 0, 0.73, 0)
	prompt.Font = Enum.Font.Code; prompt.Text = "PRESS ANY KEY"; prompt.TextColor3 = Color3.fromRGB(168, 222, 92); prompt.TextSize = 17; prompt.Parent = page
	local connection = nil
	local object = {}
	function object:SetVisible(visible)
		page.Visible = visible
		if connection then connection:Disconnect(); connection = nil end
		if visible then
			connection = UserInputService.InputBegan:Connect(function()
				if connection then connection:Disconnect(); connection = nil end
				navigation:GoTo("Profiles")
			end)
		end
	end
	return object
end

return SplashScreenController
