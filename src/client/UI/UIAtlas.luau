local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIAssetConfig = require(ReplicatedStorage.Shared.UI.UIAssetConfig)

local UIAtlas = {}

local function getAtlasRegion(regionName)
	local region = UIAssetConfig.Regions[regionName]
	return region
end

local function getIndividualImage(regionName)
	local assetKey = UIAssetConfig.IndividualRegions[regionName]
	local image = assetKey and UIAssetConfig.IndividualAssets[assetKey] or nil
	return if type(image) == "string" and image ~= "" then image else nil
end

function UIAtlas:IsAvailable(regionName)
	if regionName and getIndividualImage(regionName) then return true end
	return type(UIAssetConfig.AtlasImage) == "string" and UIAssetConfig.AtlasImage ~= ""
end

function UIAtlas:SetRegion(image, regionName)
	local individualImage = getIndividualImage(regionName)
	local rendering
	if individualImage then
		image.Image = individualImage
		image.ImageRectOffset = Vector2.zero
		image.ImageRectSize = Vector2.zero
		rendering = UIAssetConfig.IndividualRendering[regionName]
	else
		local region = getAtlasRegion(regionName)
		if not region or not self:IsAvailable() then return false end
		image.Image = UIAssetConfig.AtlasImage
		image.ImageRectOffset = region.Offset
		image.ImageRectSize = region.Size
		rendering = UIAssetConfig.Rendering[regionName]
	end
	image.ScaleType = rendering and rendering.ScaleType or Enum.ScaleType.Stretch
	if rendering and rendering.SliceCenter then
		image.SliceCenter = rendering.SliceCenter
	end
	image.SliceScale = rendering and rendering.SliceScale or 1
	image:SetAttribute("BLIKKAtlasRegion", regionName)
	return true
end

function UIAtlas:CreateSprite(parent, regionName, name)
	if not self:IsAvailable(regionName) then return nil end
	local image = Instance.new("ImageLabel")
	image.Name = name or ("Atlas_" .. regionName)
	image.Active = false
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ResampleMode = Enum.ResamplerMode.Default
	if not self:SetRegion(image, regionName) then image:Destroy(); return nil end
	image.Parent = parent
	return image
end

function UIAtlas:SkinPanel(panel, regionName, transparency)
	local image = self:CreateSprite(panel, regionName, "BLIKKAtlasSurface")
	if not image then return nil end
	image.AnchorPoint = Vector2.zero
	image.Position = UDim2.fromScale(0, 0)
	image.Size = UDim2.fromScale(1, 1)
	image.ImageTransparency = transparency or 0
	-- Decorative art must stay behind live labels, meters and viewport content.
	image.ZIndex = math.max(0, panel.ZIndex - 1)
	panel.BackgroundTransparency = 1
	return image
end

function UIAtlas:SkinTextButton(button, options)
	options = options or {}
	local usesSideAccent = options.SelectionAccent == "Side"
	local idleRegion = options.IdleRegion or "ButtonIdle"
	local selectedRegion = options.SelectedRegion or "ButtonActivePurple"
	local pressedRegion = options.PressedRegion or "ButtonActiveAcid"
	if not self:IsAvailable(idleRegion) then return nil end
	for _, childName in { "BLIKKAtlasSurface", "BLIKKAtlasText", "BLIKKSelectionAccent" } do
		local existing = button:FindFirstChild(childName)
		if existing then existing:Destroy() end
	end
	local originalTextTransparency = button.TextTransparency
	local originalStrokeTransparency = button.TextStrokeTransparency

	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.ClipsDescendants = false
	button.TextTransparency = 1
	button.TextStrokeTransparency = 1
	for _, child in button:GetChildren() do
		if child:IsA("UIStroke") then child.Enabled = false end
	end

	local image = self:CreateSprite(button, idleRegion, "BLIKKAtlasSurface")
	if not image then return nil end
	image.AnchorPoint = Vector2.zero
	image.Position = UDim2.fromScale(0, 0)
	image.Size = UDim2.fromScale(1, 1)
	image.ZIndex = button.ZIndex

	local accent = nil
	local accentGradient = nil
	if usesSideAccent then
		accent = Instance.new("Frame")
		accent.Name = "BLIKKSelectionAccent"
		accent.AnchorPoint = Vector2.new(0, 0.5)
		accent.BackgroundColor3 = Color3.fromRGB(178, 76, 255)
		accent.BorderSizePixel = 0
		accent.Position = UDim2.new(0, 11, 0.5, 0)
		accent.Size = UDim2.new(0, 4, 0.58, 0)
		accent.Visible = false
		accent.ZIndex = button.ZIndex + 2
		accent.Parent = button
		accentGradient = Instance.new("UIGradient")
		accentGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(101, 34, 159)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(224, 153, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(101, 34, 159)),
		})
		accentGradient.Rotation = 90
		accentGradient.Parent = accent
	end

	local text = Instance.new("TextLabel")
	text.Name = "BLIKKAtlasText"
	text.Active = false
	text.BackgroundTransparency = 1
	local horizontalInset = options.HorizontalTextInset or (if usesSideAccent then 30 else 20)
	local verticalInset = options.VerticalTextInset or 6
	text.Position = UDim2.fromOffset(horizontalInset, verticalInset)
	text.Size = UDim2.new(1, -(horizontalInset * 2), 1, -(verticalInset * 2))
	text.ZIndex = button.ZIndex + 1
	text.TextTransparency = originalTextTransparency
	text.TextStrokeTransparency = originalStrokeTransparency
	text.Parent = button

	local function syncText()
		text.Font = button.Font
		text.FontFace = button.FontFace
		text.RichText = button.RichText
		text.Text = button.Text
		text.TextColor3 = button.TextColor3
		text.TextScaled = button.TextScaled
		text.TextSize = button.TextSize
		text.TextStrokeColor3 = button.TextStrokeColor3
		text.TextWrapped = button.TextWrapped
		text.TextXAlignment = button.TextXAlignment
		text.TextYAlignment = button.TextYAlignment
	end
	syncText()
	for _, property in {
		"Font", "FontFace", "RichText", "Text", "TextColor3", "TextScaled", "TextSize",
		"TextStrokeColor3", "TextWrapped", "TextXAlignment", "TextYAlignment",
	} do
		button:GetPropertyChangedSignal(property):Connect(syncText)
	end
	button:GetPropertyChangedSignal("ZIndex"):Connect(function()
		image.ZIndex = button.ZIndex
		text.ZIndex = button.ZIndex + 1
		if accent then accent.ZIndex = button.ZIndex + 2 end
	end)

	local hovered = false
	local selected = false
	local pressed = false
	local function refresh()
		local forcedSelected = button:GetAttribute("BLIKKForcedSelected") == true
		local isHighlighted = hovered or selected or forcedSelected
		local regionName = if usesSideAccent then idleRegion
			elseif pressed then pressedRegion
			elseif isHighlighted then selectedRegion
			else idleRegion
		self:SetRegion(image, regionName)
		if accent then
			accentGradient.Color = if pressed then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(78, 122, 29)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(213, 255, 124)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(78, 122, 29)),
			}) else ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(101, 34, 159)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(224, 153, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(101, 34, 159)),
			})
			accent.Visible = isHighlighted or pressed
		end
	end
	button:GetAttributeChangedSignal("BLIKKForcedSelected"):Connect(refresh)
	button.MouseEnter:Connect(function() hovered = true; refresh() end)
	button.MouseLeave:Connect(function() hovered = false; pressed = false; refresh() end)
	button.SelectionGained:Connect(function() selected = true; refresh() end)
	button.SelectionLost:Connect(function() selected = false; pressed = false; refresh() end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressed = true
			refresh()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressed = false
			refresh()
		end
	end)
	return image, text
end

function UIAtlas:SetButtonSelected(button, isSelected)
	button:SetAttribute("BLIKKForcedSelected", isSelected == true)
end

return UIAtlas
