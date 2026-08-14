local LoadingScreenView = {}

LoadingScreenView.ScreenGuiName = "BLIKKLoadingScreen"

local function configuredImage(layer, fallback)
	local image = layer and layer.ImageAssetId
	if type(image) == "string" and image ~= "" then return image end
	return fallback or ""
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA(className) then
		existing:Destroy()
		existing = nil
	end
	if existing then return existing end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function getOneScreenGui(playerGui)
	local selected = nil
	for _, child in playerGui:GetChildren() do
		if child.Name == LoadingScreenView.ScreenGuiName then
			if not selected and child:IsA("ScreenGui") then
				selected = child
			else
				child:Destroy()
			end
		end
	end
	return selected
end

function LoadingScreenView.AdoptOrCreate(playerGui, config)
	local colors = config.Presentation
	local gui = getOneScreenGui(playerGui)
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = LoadingScreenView.ScreenGuiName
		gui.Parent = playerGui
	end
	gui.DisplayOrder = colors.DisplayOrder
	gui.Enabled = true
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui:SetAttribute("BLIKK_LoadingViewVersion", 2)

	local root = getOrCreate(gui, "Frame", "Root")
	root.Active = true
	root.BackgroundColor3 = colors.BackgroundColor
	root.BackgroundTransparency = 0
	root.BorderSizePixel = 0
	root.Position = UDim2.fromScale(0, 0)
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = true
	root.ZIndex = 1000

	local backdrop = getOrCreate(root, "CanvasGroup", "Backdrop")
	backdrop.BackgroundColor3 = colors.BackgroundColor
	backdrop.BackgroundTransparency = 0
	backdrop.BorderSizePixel = 0
	backdrop.GroupTransparency = 0
	backdrop.Position = UDim2.fromScale(0, 0)
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Visible = true
	backdrop.ZIndex = 1001

	local artwork = getOrCreate(backdrop, "ImageLabel", "Artwork")
	artwork.BackgroundColor3 = colors.BackgroundColor
	artwork.BackgroundTransparency = 0
	artwork.BorderSizePixel = 0
	artwork.Image = configuredImage(config.Layers and config.Layers.Background, config.Default.ImageAssetId)
	artwork.ImageColor3 = Color3.new(1, 1, 1)
	artwork.ImageTransparency = 0
	artwork.Position = UDim2.fromScale(0, 0)
	artwork.ScaleType = Enum.ScaleType.Crop
	artwork.Size = UDim2.fromScale(1, 1)
	artwork.Visible = true
	artwork.ZIndex = 1002

	local atmosphere = getOrCreate(backdrop, "CanvasGroup", "Atmosphere")
	atmosphere.BackgroundTransparency = 1
	atmosphere.GroupTransparency = 0
	atmosphere.Position = UDim2.fromScale(0, 0)
	atmosphere.Size = UDim2.fromScale(1, 1)
	atmosphere.ZIndex = 1003

	local smokeImage = configuredImage(config.Layers and config.Layers.Smoke)
	local smokeA = getOrCreate(atmosphere, "ImageLabel", "SmokeA")
	smokeA.BackgroundTransparency = 1
	smokeA.Image = smokeImage
	smokeA.ImageColor3 = Color3.fromRGB(220, 208, 235)
	smokeA.ImageTransparency = 0.48
	smokeA.Position = UDim2.fromScale(-0.035, -0.025)
	smokeA.ScaleType = Enum.ScaleType.Stretch
	smokeA.Size = UDim2.fromScale(1.08, 1.06)
	smokeA.Visible = smokeImage ~= ""
	smokeA.ZIndex = 1003

	local smokeB = getOrCreate(atmosphere, "ImageLabel", "SmokeB")
	smokeB.BackgroundTransparency = 1
	smokeB.Image = smokeImage
	smokeB.ImageColor3 = Color3.fromRGB(128, 82, 170)
	smokeB.ImageTransparency = 0.72
	smokeB.Position = UDim2.fromScale(0.015, -0.01)
	smokeB.Rotation = 180
	smokeB.ScaleType = Enum.ScaleType.Stretch
	smokeB.Size = UDim2.fromScale(1.06, 1.04)
	smokeB.Visible = smokeImage ~= ""
	smokeB.ZIndex = 1003

	local glareImage = configuredImage(config.Layers and config.Layers.Glare)
	local glare = getOrCreate(atmosphere, "ImageLabel", "SwordGlare")
	glare.BackgroundTransparency = 1
	glare.Image = glareImage
	glare.ImageTransparency = 0.74
	glare.Position = UDim2.fromScale(-0.01, -0.01)
	glare.ScaleType = Enum.ScaleType.Stretch
	glare.Size = UDim2.fromScale(1.02, 1.02)
	glare.Visible = glareImage ~= ""
	glare.ZIndex = 1004

	local shade = getOrCreate(backdrop, "Frame", "Shade")
	shade.BackgroundColor3 = colors.ShadeColor
	shade.BackgroundTransparency = 0.78
	shade.BorderSizePixel = 0
	shade.Position = UDim2.fromScale(0, 0)
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 1005
	local shadeGradient = getOrCreate(shade, "UIGradient", "Vignette")
	shadeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
		ColorSequenceKeypoint.new(0.48, colors.ShadeColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
	})
	shadeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.5, 0.72),
		NumberSequenceKeypoint.new(1, 0.08),
	})

	local logoGroup = getOrCreate(backdrop, "CanvasGroup", "LogoGroup")
	local logoPosition = colors.LogoPositionScale or Vector2.new(0.51, 0.42)
	local logoSize = colors.LogoSizeScale or Vector2.new(0.54, 0.38)
	logoGroup.AnchorPoint = Vector2.new(0.5, 0.5)
	logoGroup.BackgroundTransparency = 1
	logoGroup.GroupTransparency = 0.02
	logoGroup.Position = UDim2.fromScale(logoPosition.X, logoPosition.Y)
	logoGroup.Size = UDim2.fromScale(logoSize.X, logoSize.Y)
	logoGroup.ZIndex = 1006
	local logoScale = getOrCreate(logoGroup, "UIScale", "BreathScale")
	logoScale.Scale = 1

	local logoImage = configuredImage(config.Layers and config.Layers.Logo)
	local logo = getOrCreate(logoGroup, "ImageLabel", "Logo")
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.BackgroundTransparency = 1
	logo.Image = logoImage
	logo.ImageRectOffset = config.Layers.Logo.ImageRectOffset or Vector2.zero
	logo.ImageRectSize = config.Layers.Logo.ImageRectSize or Vector2.zero
	logo.Position = UDim2.fromScale(0.5, 0.5)
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Size = UDim2.fromScale(1, 1)
	logo.Visible = logoImage ~= ""
	logo.ZIndex = 1006

	local logoShimmer = getOrCreate(logoGroup, "ImageLabel", "LogoShimmer")
	logoShimmer.AnchorPoint = Vector2.new(0.5, 0.5)
	logoShimmer.BackgroundTransparency = 1
	logoShimmer.Image = logoImage
	logoShimmer.ImageRectOffset = logo.ImageRectOffset
	logoShimmer.ImageRectSize = logo.ImageRectSize
	logoShimmer.ImageColor3 = Color3.fromRGB(245, 232, 255)
	logoShimmer.ImageTransparency = 0.1
	logoShimmer.Position = UDim2.fromScale(0.5, 0.5)
	logoShimmer.ScaleType = Enum.ScaleType.Fit
	logoShimmer.Size = UDim2.fromScale(1, 1)
	logoShimmer.Visible = logoImage ~= ""
	logoShimmer.ZIndex = 1007
	local logoShimmerGradient = getOrCreate(logoShimmer, "UIGradient", "Sweep")
	logoShimmerGradient.Offset = Vector2.new(-1.25, 0)
	logoShimmerGradient.Rotation = 18
	logoShimmerGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})

	local accent = getOrCreate(backdrop, "Frame", "Accent")
	accent.AnchorPoint = Vector2.new(0.5, 1)
	accent.BackgroundColor3 = colors.AccentColor
	accent.BorderSizePixel = 0
	accent.Position = UDim2.new(0.5, 0, 1, -50)
	accent.Size = UDim2.new(0.22, 0, 0, 2)
	accent.ZIndex = 1008

	local statusGroup = getOrCreate(backdrop, "CanvasGroup", "StatusGroup")
	statusGroup.AnchorPoint = Vector2.new(0.5, 1)
	statusGroup.BackgroundTransparency = 1
	statusGroup.GroupTransparency = 0
	statusGroup.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
	statusGroup.BackgroundTransparency = 0.18
	statusGroup.Position = UDim2.new(0.5, 0, 1, -42)
	statusGroup.Size = UDim2.new(0.72, 0, 0, 92)
	statusGroup.ZIndex = 1009
	local statusCorner = getOrCreate(statusGroup, "UICorner", "Corner")
	statusCorner.CornerRadius = UDim.new(0, 5)
	local statusStroke = getOrCreate(statusGroup, "UIStroke", "Border")
	statusStroke.Color = colors.AccentSoftColor or colors.AccentColor
	statusStroke.Thickness = 1.5
	statusStroke.Transparency = 0.16

	local status = getOrCreate(statusGroup, "TextLabel", "Status")
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.RobotoMono
	status.Position = UDim2.fromOffset(18, 12)
	status.Size = UDim2.new(1, -36, 0, 28)
	status.Text = "INITIALIZING BLIKK"
	status.TextColor3 = colors.TextColor
	status.TextSize = 18
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.ZIndex = 1010

	local detail = getOrCreate(statusGroup, "TextLabel", "Detail")
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.Code
	detail.Position = UDim2.fromOffset(18, 42)
	detail.Size = UDim2.new(1, -36, 0, 20)
	detail.Text = "PREPARING CLIENT SYSTEMS //"
	detail.TextColor3 = colors.MutedTextColor
	detail.TextSize = 11
	detail.TextXAlignment = Enum.TextXAlignment.Center
	detail.ZIndex = 1010

	local pulse = getOrCreate(statusGroup, "CanvasGroup", "Pulse")
	pulse.AnchorPoint = Vector2.new(0.5, 1)
	pulse.BackgroundTransparency = 1
	pulse.GroupTransparency = 0.15
	pulse.Position = UDim2.new(0.5, 0, 1, -8)
	pulse.Size = UDim2.fromOffset(54, 13)
	pulse.ZIndex = 1010
	local pulseText = getOrCreate(pulse, "TextLabel", "Mark")
	pulseText.BackgroundTransparency = 1
	pulseText.Font = Enum.Font.Code
	pulseText.Size = UDim2.fromScale(1, 1)
	pulseText.Text = "/ / /"
	pulseText.TextColor3 = colors.AccentColor
	pulseText.TextSize = 11
	pulseText.ZIndex = 1007

	local fightGroup = getOrCreate(root, "CanvasGroup", "FightGroup")
	fightGroup.BackgroundTransparency = 1
	fightGroup.GroupTransparency = 1
	fightGroup.Position = UDim2.fromScale(0, 0)
	fightGroup.Size = UDim2.fromScale(1, 1)
	fightGroup.Visible = false
	fightGroup.ZIndex = 1010

	local fightText = getOrCreate(fightGroup, "TextLabel", "FightText")
	fightText.AnchorPoint = Vector2.new(0.5, 0.5)
	fightText.BackgroundTransparency = 1
	fightText.Font = Enum.Font.GrenzeGotisch
	fightText.Position = UDim2.fromScale(0.5, 0.48)
	fightText.Size = UDim2.fromScale(0.72, 0.26)
	fightText.Text = config.Fight.Text
	fightText.TextColor3 = colors.TextColor
	fightText.TextScaled = true
	fightText.TextStrokeColor3 = colors.BackgroundColor
	fightText.TextStrokeTransparency = 0.15
	fightText.ZIndex = 1011
	local textSizeConstraint = getOrCreate(fightText, "UITextSizeConstraint", "TextSizeConstraint")
	textSizeConstraint.MaxTextSize = 176
	textSizeConstraint.MinTextSize = 54
	local fightScale = getOrCreate(fightText, "UIScale", "EntryScale")
	fightScale.Scale = 0.82

	-- The replicated view now covers the frame, so the bootstrap-only cover can go.
	for _, bootstrapName in { "BootstrapBackdrop", "BootstrapStatus" } do
		local bootstrapObject = root:FindFirstChild(bootstrapName)
		if bootstrapObject then bootstrapObject:Destroy() end
	end
	root.BackgroundTransparency = 1

	return {
		Gui = gui,
		Root = root,
		Backdrop = backdrop,
		Artwork = artwork,
		Atmosphere = atmosphere,
		SmokeA = smokeA,
		SmokeB = smokeB,
		Glare = glare,
		LogoGroup = logoGroup,
		LogoScale = logoScale,
		LogoShimmerGradient = logoShimmerGradient,
		StatusGroup = statusGroup,
		Status = status,
		Detail = detail,
		Pulse = pulse,
		FightGroup = fightGroup,
		FightText = fightText,
		FightScale = fightScale,
	}
end

function LoadingScreenView.Reset(view, config, contextName)
	local context = config.Contexts[contextName] or config.Contexts.InitialBoot
	local smokeImage = configuredImage(config.Layers and config.Layers.Smoke)
	local glareImage = configuredImage(config.Layers and config.Layers.Glare)
	view.Gui.Enabled = true
	view.Root.Active = true
	view.Root.Visible = true
	view.Backdrop.GroupTransparency = 0
	view.Backdrop.Visible = true
	view.Artwork.Image = configuredImage(config.Layers and config.Layers.Background, config.Default.ImageAssetId)
	view.Artwork.ImageTransparency = 0
	view.Artwork.Visible = true
	view.Atmosphere.GroupTransparency = 0
	view.SmokeA.Image = smokeImage
	view.SmokeA.Position = UDim2.fromScale(-0.035, -0.025)
	view.SmokeA.Visible = smokeImage ~= ""
	view.SmokeB.Image = smokeImage
	view.SmokeB.Position = UDim2.fromScale(0.015, -0.01)
	view.SmokeB.Visible = smokeImage ~= ""
	view.Glare.Image = glareImage
	view.Glare.ImageTransparency = 0.74
	view.Glare.Visible = glareImage ~= ""
	view.LogoGroup.GroupTransparency = 0.02
	view.LogoScale.Scale = 1
	view.LogoShimmerGradient.Offset = Vector2.new(-1.25, 0)
	view.StatusGroup.GroupTransparency = 0
	view.Status.Text = context.StatusText
	view.Status.TextColor3 = config.Presentation.TextColor
	view.Detail.Text = context.DetailText
	view.Detail.TextColor3 = config.Presentation.MutedTextColor
	view.Pulse.GroupTransparency = 0.15
	view.FightGroup.GroupTransparency = 1
	view.FightGroup.Visible = false
	view.FightScale.Scale = 0.82
end

function LoadingScreenView.SetStatus(view, config, statusText, detailText, isFailure)
	if type(statusText) == "string" and statusText ~= "" then view.Status.Text = statusText end
	if type(detailText) == "string" then view.Detail.Text = detailText end
	view.Status.TextColor3 = if isFailure
		then config.Presentation.FailureColor
		else config.Presentation.TextColor
	view.Detail.TextColor3 = if isFailure
		then config.Presentation.FailureColor
		else config.Presentation.MutedTextColor
end

function LoadingScreenView.SetArtworkAvailable(view, isAvailable)
	view.Artwork.Visible = isAvailable
	view.Artwork.ImageTransparency = if isAvailable then 0 else 1
end

function LoadingScreenView.SetFightVisible(view, isVisible)
	view.FightGroup.Visible = isVisible
	view.FightGroup.GroupTransparency = if isVisible then 0 else 1
end

return LoadingScreenView
