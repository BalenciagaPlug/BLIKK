local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)

local SplashScreenController = {}

function SplashScreenController:Create(parent, navigation)
	local page = Instance.new("Frame")
	page.Name = "Splash"
	page.BackgroundColor3 = Color3.new(0, 0, 0)
	page.BorderSizePixel = 0
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = parent

	local glow = Instance.new("Frame")
	glow.Name = "PurpleAmbientGlow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = Branding.Colors.Purple
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Position = UDim2.fromScale(0.5, 0.48)
	glow.Size = UDim2.fromScale(0.52, 0.4)
	glow.Parent = page
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow

	local brandGroup = Instance.new("CanvasGroup")
	brandGroup.Name = "BrandPresentation"
	brandGroup.AnchorPoint = Vector2.new(0.5, 0.5)
	brandGroup.BackgroundTransparency = 1
	brandGroup.GroupTransparency = 1
	brandGroup.Position = UDim2.fromScale(0.5, 0.48)
	brandGroup.Size = Branding.Sizes.Splash
	brandGroup.Parent = page
	Branding.CreateFullLogo(brandGroup)
	local brandScale = Instance.new("UIScale")
	brandScale.Scale = 0.92
	brandScale.Parent = brandGroup

	local prompt = Instance.new("TextLabel")
	prompt.BackgroundTransparency = 1
	prompt.Font = Enum.Font.Code
	prompt.Position = UDim2.new(0, 0, 0.75, 0)
	prompt.Size = UDim2.new(1, 0, 0, 30)
	prompt.Text = ""
	prompt.TextColor3 = Color3.fromRGB(168, 222, 92)
	prompt.TextSize = 15
	prompt.Parent = page

	local connection = nil
	local sequenceGeneration = 0
	local object = {}
	function object:SetVisible(visible)
		page.Visible = visible
		sequenceGeneration += 1
		local activeGeneration = sequenceGeneration
		if connection then connection:Disconnect(); connection = nil end
		if not visible then return end

		brandGroup.GroupTransparency = 1
		brandScale.Scale = 0.92
		glow.BackgroundTransparency = 1
		prompt.Text = ""
		local reducedEffects = SessionSettings:Get("ReducedEffects") or SessionSettings:Get("EffectsQuality") == "LOW"
		TweenService:Create(glow, TweenInfo.new(1, Enum.EasingStyle.Quad), { BackgroundTransparency = if reducedEffects then 0.94 else 0.82 }):Play()
		TweenService:Create(brandGroup, TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
		TweenService:Create(brandScale, TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()

		if not reducedEffects then
			TweenService:Create(brandScale, TweenInfo.new(1.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true, 1), { Scale = 1.025 }):Play()
		end
		task.delay(1, function()
			if activeGeneration == sequenceGeneration and page.Visible then prompt.Text = "PRESS ANY KEY" end
		end)
		connection = UserInputService.InputBegan:Connect(function()
			prompt.Text = "INPUT RECEIVED // INITIALIZING"
		end)
		task.delay(4.5, function()
			if activeGeneration ~= sequenceGeneration or not page.Visible then return end
			if connection then connection:Disconnect(); connection = nil end
			prompt.Text = ""
			TweenService:Create(brandGroup, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 }):Play()
			TweenService:Create(brandScale, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.94 }):Play()
			TweenService:Create(glow, TweenInfo.new(1, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		end)
		task.delay(5.5, function()
			if activeGeneration == sequenceGeneration and page.Visible then navigation:GoTo("Profiles") end
		end)
	end
	return object
end

return SplashScreenController
