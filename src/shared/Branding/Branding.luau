local ContentProvider = game:GetService("ContentProvider")

local Branding = {}

Branding.Assets = {
	FullLogoImage = "rbxassetid://118197165577599",
	IconLogoImage = "rbxassetid://129295702792396",
	Repository = {
		FullLogo = "Branding/BLIKK_Logo_Full.png",
		IconLogo = "Branding/BLIKK_Logo_Icon.png",
	},
	DevelopmentContent = {
		FullLogo = "rbxgameasset://Images/BLIKK_Logo_Full",
		IconLogo = "rbxgameasset://Images/BLIKK_Logo_Icon",
	},
}

Branding.Fallback = {
	FullLogo = "BLIKK",
	IconLogo = "B",
}

Branding.Sizes = {
	Splash = UDim2.fromScale(0.42, 0.42),
	CharacterCreation = UDim2.fromOffset(280, 130),
	CharacterProfiles = UDim2.fromOffset(200, 100),
	OperationsHub = UDim2.fromOffset(270, 120),
	Transition = UDim2.fromScale(0.3, 0.28),
	Settings = UDim2.fromOffset(64, 42),
	Scoreboard = UDim2.fromOffset(62, 42),
	Hud = UDim2.new(1, -12, 1, -12),
}

Branding.Colors = {
	Purple = Color3.fromRGB(139, 72, 218),
	PurpleSoft = Color3.fromRGB(91, 48, 135),
	Silver = Color3.fromRGB(235, 232, 238),
}

Branding.Animation = {
	FadeInSeconds = 0.65,
	BreathSeconds = 2.8,
	BreathScale = 1.025,
	TransitionFadeSeconds = 0.22,
}

local IMAGE_ASPECT_RATIO = 1.5
local diagnosticsEnabled = false

function Branding.SetDiagnosticsEnabled(isEnabled)
	diagnosticsEnabled = isEnabled
end

local function assetIdUri(assetId)
	if assetId == "" then return nil end
	if string.find(assetId, "://", 1, true) then return assetId end
	return "rbxassetid://" .. assetId
end

local function createFallback(holder, text, color, zIndex)
	local fallback = Instance.new("TextLabel")
	fallback.Name = "TextFallback"
	fallback.BackgroundTransparency = 1
	fallback.Font = Enum.Font.GrenzeGotisch
	fallback.Text = text
	fallback.TextColor3 = color
	fallback.TextScaled = true
	fallback.TextStrokeColor3 = Branding.Colors.PurpleSoft
	fallback.TextStrokeTransparency = 0.35
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.ZIndex = zIndex
	fallback.Parent = holder
	return fallback
end

local function createLogo(parent, options, assetKey)
	options = options or {}
	local holder = Instance.new("Frame")
	holder.Name = options.Name or (assetKey .. "Brand")
	holder.AnchorPoint = options.AnchorPoint or Vector2.zero
	holder.BackgroundTransparency = 1
	holder.Position = options.Position or UDim2.fromScale(0, 0)
	holder.Rotation = options.Rotation or 0
	holder.Size = options.Size or UDim2.fromScale(1, 1)
	holder.ZIndex = options.ZIndex or 1
	holder.Parent = parent

	local stateChanged = Instance.new("BindableEvent")
	stateChanged.Name = "LoadStateChanged"
	stateChanged.Parent = holder
	holder:SetAttribute("LoadState", "Loading")

	local configuredImage = if assetKey == "FullLogo"
		then Branding.Assets.FullLogoImage
		else Branding.Assets.IconLogoImage
	local imageSource = assetIdUri(configuredImage)
	local image = nil
	local fallback = nil
	local loadedConnection = nil
	local isDestroyed = false
	local color = options.Color or Color3.new(1, 1, 1)
	local zIndex = options.ZIndex or 1

	local function setState(state)
		if isDestroyed or holder:GetAttribute("LoadState") == state then return end
		holder:SetAttribute("LoadState", state)
		stateChanged:Fire(state)
		if diagnosticsEnabled then print("BLIKK branding " .. assetKey .. " // " .. state) end
	end

	local function showImage()
		if isDestroyed or not image then return end
		image.Visible = true
		if fallback then fallback:Destroy(); fallback = nil end
		setState("Loaded")
		if loadedConnection then loadedConnection:Disconnect(); loadedConnection = nil end
	end

	local function showFallback()
		if isDestroyed or holder:GetAttribute("LoadState") == "Loaded" then return end
		if image then image.Visible = false end
		if not fallback then
			fallback = createFallback(holder, Branding.Fallback[assetKey], options.Color or Branding.Colors.Silver, zIndex)
		end
		setState("Fallback")
	end

	if imageSource then
		image = Instance.new("ImageLabel")
		image.Name = "Image"
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = imageSource
		image.ImageColor3 = color
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(1, 1)
		image.ZIndex = zIndex
		image.Parent = holder
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = IMAGE_ASPECT_RATIO
		aspect.AspectType = Enum.AspectType.FitWithinMaxSize
		aspect.Parent = image
		loadedConnection = image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			if image.IsLoaded then showImage() end
		end)
		task.spawn(function()
			local fetchedSuccessfully = false
			local success = pcall(function()
				ContentProvider:PreloadAsync({ image }, function(_, status)
					if status == Enum.AssetFetchStatus.Success then fetchedSuccessfully = true end
				end)
			end)
			if isDestroyed then return end
			if (success and fetchedSuccessfully) or image.IsLoaded then showImage() else showFallback() end
		end)
	else
		showFallback()
	end

	holder.Destroying:Connect(function()
		isDestroyed = true
		if loadedConnection then loadedConnection:Disconnect(); loadedConnection = nil end
	end)
	return holder
end

function Branding.CreateFullLogo(parent, options)
	return createLogo(parent, options, "FullLogo")
end

function Branding.CreateIconLogo(parent, options)
	return createLogo(parent, options, "IconLogo")
end

return Branding
