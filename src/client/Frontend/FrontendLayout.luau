local Workspace = game:GetService("Workspace")

local UIAtlas = require(script.Parent.Parent.UI.UIAtlas)

local FrontendLayout = {}
local SAFE_FRAME_INSET_PIXELS = 18

function FrontendLayout:CreateCanvas(parent)
	parent.BackgroundColor3 = Color3.fromRGB(4, 4, 7)
	local backdropGradient = parent:FindFirstChild("BLIKKBackdropGradient") or Instance.new("UIGradient")
	backdropGradient.Name = "BLIKKBackdropGradient"
	backdropGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 7, 25)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(5, 5, 8)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 9, 6)),
	})
	backdropGradient.Rotation = 18
	backdropGradient.Parent = parent
	-- The shell belongs to the full page, not the fixed logical canvas. This is
	-- what makes the authored border consistently reach every viewport edge.
	local existingShell = parent:FindFirstChild("BLIKKFullscreenShell")
	if existingShell then existingShell:Destroy() end
	local fullscreenShell = UIAtlas:CreateSprite(parent, "MenuPanelWide", "BLIKKFullscreenShell")
	if fullscreenShell then
		fullscreenShell.AnchorPoint = Vector2.new(0.5, 0.5)
		fullscreenShell.Position = UDim2.fromScale(0.5, 0.5)
		fullscreenShell.Size = UDim2.new(1, -(SAFE_FRAME_INSET_PIXELS * 2), 1, -(SAFE_FRAME_INSET_PIXELS * 2))
		fullscreenShell.ImageTransparency = 0.04
		fullscreenShell.ZIndex = 0
	end

	local canvas = Instance.new("Frame")
	canvas.Name = "ResponsiveCanvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.BackgroundTransparency = 1
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromOffset(1200, 680)
	canvas.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = canvas
	local topSignal = Instance.new("Frame")
	topSignal.Name = "BLIKKSignalRail"
	topSignal.BackgroundColor3 = Color3.fromRGB(157, 69, 232)
	topSignal.BackgroundTransparency = 0.18
	topSignal.BorderSizePixel = 0
	topSignal.Position = UDim2.fromOffset(0, 0)
	topSignal.Size = UDim2.new(1, 0, 0, 2)
	topSignal.ZIndex = 0
	topSignal.Parent = canvas
	local acidSignal = Instance.new("Frame")
	acidSignal.BackgroundColor3 = Color3.fromRGB(159, 231, 66)
	acidSignal.BorderSizePixel = 0
	acidSignal.Position = UDim2.fromOffset(0, 0)
	acidSignal.Size = UDim2.new(0.16, 0, 1, 0)
	acidSignal.Parent = topSignal
	local function update()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.46, 1.35)
		end
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
	return canvas
end

function FrontendLayout:SkinButton(button, options)
	return UIAtlas:SkinTextButton(button, options)
end

function FrontendLayout:SetButtonRegion(button, regionName)
	local image = button:FindFirstChild("BLIKKAtlasSurface")
	if image and image:IsA("ImageLabel") then UIAtlas:SetRegion(image, regionName) end
end

function FrontendLayout:SetButtonSelected(button, isSelected)
	UIAtlas:SetButtonSelected(button, isSelected)
end

return FrontendLayout
