local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)

local NavigationController = {}
NavigationController.Changed = Instance.new("BindableEvent")

local pages = {}
local currentRoute = nil
local transition = nil
local transitionGeneration = 0

function NavigationController:CreateTransition(parent)
	transition = Instance.new("CanvasGroup")
	transition.Name = "BrandTransition"
	transition.BackgroundColor3 = Color3.fromRGB(4, 4, 6)
	transition.BorderSizePixel = 0
	transition.GroupTransparency = 1
	transition.Size = UDim2.fromScale(1, 1)
	transition.Visible = false
	transition.ZIndex = 200
	transition.Parent = parent
	Branding.CreateFullLogo(transition, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = Branding.Sizes.Transition,
		ZIndex = 201,
	})
end

local function showTransition()
	if not transition then return end
	transitionGeneration += 1
	local generation = transitionGeneration
	transition.GroupTransparency = 0.1
	transition.Visible = true
	local tween = TweenService:Create(
		transition,
		TweenInfo.new(Branding.Animation.TransitionFadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 1 }
	)
	tween.Completed:Connect(function()
		if generation == transitionGeneration then
			transition.Visible = false
		end
	end)
	tween:Play()
end

function NavigationController:Register(route, page)
	assert(not pages[route], "Frontend route already registered: " .. route)
	pages[route] = page
	page:SetVisible(false)
end

function NavigationController:GoTo(route, context)
	local destination = pages[route]
	if not destination then return false end
	if currentRoute then pages[currentRoute]:SetVisible(false) end
	currentRoute = route
	destination:SetVisible(true, context)
	if currentRoute ~= "Splash" then
		showTransition()
	end
	self.Changed:Fire(route, context)
	return true
end

function NavigationController:GetCurrentRoute()
	return currentRoute
end

function NavigationController:Suspend()
	if currentRoute then pages[currentRoute]:SetVisible(false) end
end

return NavigationController
