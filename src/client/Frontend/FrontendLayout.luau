local Workspace = game:GetService("Workspace")

local FrontendLayout = {}

function FrontendLayout:CreateCanvas(parent)
	local canvas = Instance.new("Frame")
	canvas.Name = "ResponsiveCanvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.BackgroundTransparency = 1
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromOffset(1200, 680)
	canvas.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = canvas
	local function update()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.72, 1.35)
		end
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
	return canvas
end

return FrontendLayout
