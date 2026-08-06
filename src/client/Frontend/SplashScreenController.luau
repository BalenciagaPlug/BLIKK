local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

	local brandGroup = Instance.new("CanvasGroup")
	brandGroup.Name = "BrandPresentation"
	brandGroup.AnchorPoint = Vector2.new(0.5, 0.5)
	brandGroup.BackgroundTransparency = 1
	brandGroup.GroupTransparency = 1
	brandGroup.Position = UDim2.fromScale(0.5, 0.5)
	brandGroup.Size = UDim2.fromScale(0.84, 0.84)
	brandGroup.Parent = page
	Branding.CreateFullLogo(brandGroup)
	local brandScale = Instance.new("UIScale")
	brandScale.Scale = 0.92
	brandScale.Parent = brandGroup

	local sequenceGeneration = 0
	local object = {}
	function object:SetVisible(visible)
		page.Visible = visible
		sequenceGeneration += 1
		local activeGeneration = sequenceGeneration
		if not visible then return end

		brandGroup.GroupTransparency = 1
		brandScale.Scale = 0.92
		local reducedEffects = SessionSettings:Get("ReducedEffects") or SessionSettings:Get("EffectsQuality") == "LOW"
		TweenService:Create(brandGroup, TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
		TweenService:Create(brandScale, TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()

		if not reducedEffects then
			TweenService:Create(brandScale, TweenInfo.new(1.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true, 1), { Scale = 1.025 }):Play()
		end
		task.delay(4.5, function()
			if activeGeneration ~= sequenceGeneration or not page.Visible then return end
			TweenService:Create(brandGroup, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 }):Play()
			TweenService:Create(brandScale, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.94 }):Play()
		end)
		task.delay(5.5, function()
			if activeGeneration == sequenceGeneration and page.Visible then navigation:GoTo("Profiles") end
		end)
	end
	return object
end

return SplashScreenController
