local MeleePresentationConfig = require(script.Parent.MeleePresentationConfig)

local TrainingKatanaPresentation = {}

local function makePart(parent, name, size, color, material, cframe, castsShadow)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CFrame = cframe or CFrame.identity
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = castsShadow
	part.Parent = parent
	return part
end

local function weld(handle, part)
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = handle
	weldConstraint.Part1 = part
	weldConstraint.Parent = part
end

function TrainingKatanaPresentation.Build(castsShadow)
	local dimensions = MeleePresentationConfig.TrainingKatana.Dimensions
	local geometry = MeleePresentationConfig.TrainingKatana.Geometry
	local handleHalfLength = dimensions.Handle.Y * 0.5
	local guardCenterY = handleHalfLength + dimensions.Guard.Y * 0.5
	local bladeStartY = handleHalfLength + dimensions.Guard.Y + geometry.BladeGuardGapStuds
	local bladeCenterY = bladeStartY + dimensions.Blade.Y * 0.5
	local bladeEndY = bladeStartY + dimensions.Blade.Y
	local pommelCenterY = -handleHalfLength - dimensions.Pommel.Y * 0.5
	local trailRootY = bladeStartY + dimensions.Blade.Y * geometry.TrailRootBladeFraction
	local trailTipY = bladeEndY - dimensions.Blade.Y * geometry.TrailTipInsetBladeFraction

	-- The handle is the model origin. Grip-to-tip is local +Y, and the blade's visible
	-- edge sits on local -X. Equipped and holstered orientation belongs to attachment config.
	local model = Instance.new("Model")
	model.Name = "TrainingKatana"
	model:SetAttribute("BLIKK_WeaponDefinition", "TrainingKatana")
	model:SetAttribute("BLIKK_PresentationOnly", true)
	local handle = makePart(
		model,
		"Handle",
		dimensions.Handle,
		Color3.fromRGB(25, 25, 29),
		Enum.Material.Metal,
		nil,
		castsShadow
	)
	local grip = makePart(
		model,
		"Grip",
		dimensions.Grip,
		Color3.fromRGB(53, 42, 61),
		Enum.Material.Fabric,
		CFrame.new(0, geometry.GripCenterYStuds, 0),
		castsShadow
	)
	local guard = makePart(
		model,
		"Guard",
		dimensions.Guard,
		Color3.fromRGB(92, 66, 115),
		Enum.Material.Metal,
		CFrame.new(0, guardCenterY, 0),
		castsShadow
	)
	local blade = makePart(
		model,
		"Blade",
		dimensions.Blade,
		Color3.fromRGB(92, 98, 108),
		Enum.Material.Metal,
		CFrame.new(0, bladeCenterY, 0),
		castsShadow
	)
	local edge = makePart(
		model,
		"BladeEdge",
		dimensions.BladeEdge,
		Color3.fromRGB(229, 226, 213),
		Enum.Material.SmoothPlastic,
		CFrame.new(geometry.EdgeOffsetXStuds, bladeCenterY, 0),
		castsShadow
	)
	local pommel = makePart(
		model,
		"Pommel",
		dimensions.Pommel,
		Color3.fromRGB(106, 71, 135),
		Enum.Material.Metal,
		CFrame.new(0, pommelCenterY, 0),
		castsShadow
	)
	for _, part in { grip, guard, blade, edge, pommel } do weld(handle, part) end

	local trailStart = Instance.new("Attachment")
	trailStart.Name = "TrailAttachmentStart"
	trailStart.Position = Vector3.new(0, trailRootY, 0)
	trailStart.Parent = handle
	local trailEnd = Instance.new("Attachment")
	trailEnd.Name = "TrailAttachmentEnd"
	trailEnd.Position = Vector3.new(0, trailTipY, 0)
	trailEnd.Parent = handle
	local bladeTrail = Instance.new("Trail")
	bladeTrail.Name = "BladeTrail"
	bladeTrail.Attachment0 = trailStart
	bladeTrail.Attachment1 = trailEnd
	bladeTrail.Color = ColorSequence.new(
		Color3.fromRGB(224, 218, 230),
		Color3.fromRGB(118, 63, 166)
	)
	bladeTrail.LightEmission = 0.25
	bladeTrail.Enabled = false
	bladeTrail.Parent = handle
	model.PrimaryPart = handle
	return model, bladeTrail
end

return TrainingKatanaPresentation
