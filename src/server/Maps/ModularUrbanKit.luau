local ModularUrbanKit = {}
ModularUrbanKit.__index = ModularUrbanKit

ModularUrbanKit.Catalog = {
	WallFamilies = {
		"BrickWall", "DirtyBrickWall", "ConcreteWall", "CrackedConcrete", "RenderWall", "SteelWall",
		"GarageRollerWall", "WarehouseWall", "ApartmentExterior", "ShopExterior", "AlleyWall", "ServiceWall",
	},
	WallVariants = { "Clean", "Damaged", "GraffitiReady", "Window", "Vent" },
	WallWidthsStuds = { 4, 8, 12, 16, 20, 24, 32 },
	WallHeightsStuds = { 10, 14, 18, 24, 32, 40 },
	WindowTypes = { "Apartment", "Warehouse", "Shop", "Broken", "Boarded", "SecurityBars", "Industrial", "Corner" },
	RoofTypes = { "Flat", "Parapet", "Warehouse", "Apartment", "Corner", "Billboard", "Mechanical" },
	MovementModules = { "FireEscapeA", "FireEscapeB", "ExternalStair", "IndustrialStair", "MaintenanceLadder", "BrokenStair", "RoofLadder", "Catwalk", "Bridge", "PipeWalk", "Scaffolding", "ConstructionPlatform" },
	StreetFurniture = { "StreetLight", "TrafficLight", "PowerPole", "PowerBox", "Dumpster", "Bin", "Mailbox", "Hydrant", "ConcreteBarrier", "TrafficBarrier", "Fence", "ChainlinkFence", "WoodFence", "ParkingBarrier", "GuardRail", "BusStop", "PhoneBooth", "Bench", "Tree", "Shrub", "Planter" },
	RooftopDetails = { "ACUnit", "Generator", "VentStack", "Fan", "SolarPanel", "ElectricalCabinet", "MaintenanceDoor", "WaterTower", "CableTray", "SatelliteDish", "RoofLight", "Billboard" },
	AlleyDetails = { "Pallet", "Crate", "OilDrum", "Tyre", "GarbageBag", "CardboardPile", "ShoppingTrolley", "WoodSheet", "ConstructionFence", "Scaffolding", "UtilityPipe", "WallConduit", "ElectricalMeter" },
}

local WALL_STYLES = {
	BrickWall = { Material = Enum.Material.Brick, Color = "Brick" },
	DirtyBrickWall = { Material = Enum.Material.Brick, Color = "BrickDark" },
	ConcreteWall = { Material = Enum.Material.Concrete, Color = "Concrete" },
	CrackedConcrete = { Material = Enum.Material.Concrete, Color = "ConcreteDark" },
	RenderWall = { Material = Enum.Material.SmoothPlastic, Color = "Stone" },
	SteelWall = { Material = Enum.Material.Metal, Color = "Steel" },
	GarageRollerWall = { Material = Enum.Material.CorrodedMetal, Color = "SteelEdge" },
	WarehouseWall = { Material = Enum.Material.Concrete, Color = "ConcreteDark" },
	ApartmentExterior = { Material = Enum.Material.Brick, Color = "Brick" },
	ShopExterior = { Material = Enum.Material.Concrete, Color = "Stone" },
	AlleyWall = { Material = Enum.Material.Brick, Color = "BrickDark" },
	ServiceWall = { Material = Enum.Material.Concrete, Color = "ConcreteDark" },
}

local function contains(values, value)
	return table.find(values, value) ~= nil
end

function ModularUrbanKit.new(context)
	return setmetatable({ Context = context, Palette = context.Palette }, ModularUrbanKit)
end

function ModularUrbanKit:GetCatalogCounts()
	local catalog = self.Catalog
	return {
		WallCombinations = #catalog.WallFamilies * #catalog.WallVariants * #catalog.WallWidthsStuds * #catalog.WallHeightsStuds,
		WindowModules = #catalog.WindowTypes * 2,
		RoofModules = #catalog.RoofTypes,
		MovementModules = #catalog.MovementModules,
		StreetFurniture = #catalog.StreetFurniture,
		RooftopDetails = #catalog.RooftopDetails,
		AlleyDetails = #catalog.AlleyDetails,
	}
end

function ModularUrbanKit:ApplyMovementMetadata(instance, metadata)
	metadata = metadata or {}
	local mappings = {
		WallJumpSurface = "BLIKK_WallJumpSurface", ButterflyChannel = "BLIKK_ButterflyChannel",
		SafeLanding = "BLIKK_SafeLanding", RecoveryDrop = "BLIKK_RecoveryDrop",
		RoofEdge = "BLIKK_RoofEdge", PipeWalk = "BLIKK_PipeWalk",
		ClimbSurface = "BLIKK_ClimbSurface", Parapet = "BLIKK_Parapet",
	}
	for key, attributeName in mappings do
		if metadata[key] ~= nil then instance:SetAttribute(attributeName, metadata[key]) end
	end
	if metadata.WallJumpSurface and self.Context.Tag then self.Context.Tag(instance, "BLIKK_WallSurface") end
	if metadata.RoofEdge or metadata.Parapet then
		if self.Context.Tag then self.Context.Tag(instance, "BLIKK_Ledge") end
	end
	return instance
end

function ModularUrbanKit:WindowModule(parent, windowType, cframe, options)
	options = options or {}
	assert(contains(self.Catalog.WindowTypes, windowType), "Unknown window type: " .. tostring(windowType))
	local model = self.Context.Container("Model", parent, windowType .. "Window")
	local width = options.WidthStuds or (if windowType == "Warehouse" then 8 else 5)
	local height = options.HeightStuds or (if windowType == "Shop" then 7 else 5)
	local thickness = options.ThicknessStuds or 0.4
	local broken = options.Broken == true or windowType == "Broken"
	local frameColor = if windowType == "Industrial" then self.Palette.SteelEdge else self.Palette.Steel
	for _, offset in {
		Vector3.new(0, height * 0.5, 0), Vector3.new(0, -height * 0.5, 0),
		Vector3.new(-width * 0.5, 0, 0), Vector3.new(width * 0.5, 0, 0),
	} do
		local horizontal = offset.Y ~= 0
		self.Context.Part(model, "Frame", if horizontal then Vector3.new(width + 0.5, 0.35, thickness) else Vector3.new(0.35, height, thickness), cframe * CFrame.new(offset), frameColor, Enum.Material.Metal, { CanCollide = false, CanQuery = false, CastShadow = false })
	end
	self.Context.Part(model, "Glass", Vector3.new(width, height, 0.18), cframe, self.Palette.Window, Enum.Material.Glass, { CanCollide = false, CanQuery = false, CastShadow = false, Transparency = if broken then 0.68 else 0.28 })
	local sill = self.Context.Part(model, "PlayableSill", Vector3.new(width + 1.2, 0.55, 1.5), cframe * CFrame.new(0, -height * 0.5 - 0.35, 0.55), self.Palette.Stone, Enum.Material.Concrete, { Tags = { "BLIKK_Ledge" } })
	self:ApplyMovementMetadata(sill, { SafeLanding = true, RoofEdge = true })
	if windowType == "Boarded" then
		for rotation in { -10, 9 } do self.Context.Part(model, "Board", Vector3.new(width + 1, 0.7, 0.25), cframe * CFrame.Angles(0, 0, math.rad(rotation)), self.Palette.BrickDark, Enum.Material.WoodPlanks, { CanCollide = false }) end
	elseif windowType == "SecurityBars" then
		for x = -width * 0.4, width * 0.4, 1.2 do self.Context.Part(model, "SecurityBar", Vector3.new(0.18, height, 0.18), cframe * CFrame.new(x, 0, 0.25), self.Palette.SteelEdge, Enum.Material.Metal, { CanCollide = false, CastShadow = false }) end
	elseif windowType == "Corner" then
		self.Context.Part(model, "CornerPane", Vector3.new(0.18, height, width), cframe * CFrame.new(width * 0.5, 0, width * 0.5), self.Palette.Window, Enum.Material.Glass, { CanCollide = false, CanQuery = false, Transparency = 0.3 })
	end
	return model
end

function ModularUrbanKit:WallModule(parent, family, variant, width, height, cframe, metadata)
	assert(WALL_STYLES[family], "Unknown wall family: " .. tostring(family))
	assert(contains(self.Catalog.WallVariants, variant), "Unknown wall variant: " .. tostring(variant))
	assert(contains(self.Catalog.WallWidthsStuds, width), "Wall width must snap to the kit catalogue")
	assert(contains(self.Catalog.WallHeightsStuds, height), "Wall height must snap to the kit catalogue")
	local style = WALL_STYLES[family]
	local model = self.Context.Container("Model", parent, family .. "_" .. variant .. "_" .. width .. "x" .. height)
	local wall = self.Context.Part(model, "Wall", Vector3.new(width, height, 1), cframe, self.Palette[style.Color], style.Material, { Tags = { "BLIKK_WallSurface" } })
	wall:SetAttribute("BLIKK_WallFamily", family)
	wall:SetAttribute("BLIKK_WallVariant", variant)
	wall:SetAttribute("BLIKK_GraffitiReady", variant == "GraffitiReady")
	self:ApplyMovementMetadata(wall, metadata or { WallJumpSurface = true })
	if variant == "Damaged" or family == "CrackedConcrete" then
		for index = 1, 3 do self.Context.Part(model, "DamageSeam", Vector3.new(width * 0.2, 0.16, 0.08), cframe * CFrame.new((index - 2) * width * 0.22, (index - 2) * height * 0.18, -0.54) * CFrame.Angles(0, 0, math.rad(index * 17)), self.Palette.ConcreteDark, Enum.Material.Slate, { CanCollide = false, CanQuery = false, CastShadow = false }) end
	elseif variant == "Window" then
		self:WindowModule(model, if family == "WarehouseWall" then "Warehouse" elseif family == "ShopExterior" then "Shop" else "Apartment", cframe * CFrame.new(0, 0, -0.6), { Broken = family == "DirtyBrickWall" })
	elseif variant == "Vent" then
		self.Context.Part(model, "Vent", Vector3.new(math.min(5, width - 1), math.min(4, height - 2), 0.22), cframe * CFrame.new(0, 0, -0.62), self.Palette.SteelEdge, Enum.Material.DiamondPlate, { CanCollide = false, CanQuery = false, CastShadow = false })
	end
	return model
end

function ModularUrbanKit:RoofModule(parent, roofType, center, size, height, options)
	options = options or {}
	assert(contains(self.Catalog.RoofTypes, roofType), "Unknown roof type: " .. tostring(roofType))
	local model = self.Context.Container("Model", parent, roofType .. "Roof")
	local roof = self.Context.Part(model, "RoofSurface", Vector3.new(size.X, 1, size.Y), CFrame.new(center.X, height + 0.5, center.Z), self.Palette.Roof, if roofType == "Warehouse" then Enum.Material.Metal else Enum.Material.Concrete, { Tags = { "BLIKK_Ledge" } })
	roof:SetAttribute("BLIKK_RoofType", roofType)
	roof:SetAttribute("BLIKK_RoofHeight", height)
	self:ApplyMovementMetadata(roof, { SafeLanding = true, RoofEdge = true })
	if roofType ~= "Flat" then self:Parapet(model, roof.Position + Vector3.new(0, 0.5, 0), Vector3.new(size.X, 0, size.Y), options.ParapetHeight or 3) end
	for index, detail in options.Details or {} do
		self:RooftopDetail(model, detail, Vector3.new(center.X - size.X * 0.25 + index * 7, height + 2, center.Z))
	end
	return model, roof
end

function ModularUrbanKit:Parapet(parent, center, size, height)
	local part = self.Context.Part
	local color = self.Palette.SteelEdge
	for _, definition in {
		{ "ParapetNorth", Vector3.new(size.X, height, 1), Vector3.new(0, height * 0.5, -size.Z * 0.5) },
		{ "ParapetSouth", Vector3.new(size.X, height, 1), Vector3.new(0, height * 0.5, size.Z * 0.5) },
		{ "ParapetWest", Vector3.new(1, height, size.Z), Vector3.new(-size.X * 0.5, height * 0.5, 0) },
		{ "ParapetEast", Vector3.new(1, height, size.Z), Vector3.new(size.X * 0.5, height * 0.5, 0) },
	} do
		local edge = part(parent, definition[1], definition[2], CFrame.new(center + definition[3]), color, Enum.Material.Concrete, { Tags = { "BLIKK_Ledge" } })
		self:ApplyMovementMetadata(edge, { RoofEdge = true, Parapet = true })
	end
end

function ModularUrbanKit:Windows(parent, center, size, height, frontSign)
	local part = self.Context.Part
	local floors = math.max(1, math.floor(height / 12))
	local columns = math.max(2, math.floor(size.X / 14))
	for floorIndex = 1, floors do
		for column = 1, columns do
			local x = (column - (columns + 1) * 0.5) * math.min(12, size.X / columns)
			local y = math.min(height - 5, 5 + (floorIndex - 1) * 11)
			for _, face in { -1, 1 } do
				part(parent, "Window", Vector3.new(5, 4.5, 0.18), CFrame.new(center.X + x, y, center.Z + face * (size.Y * 0.5 + 0.11)), self.Palette.Window, Enum.Material.Glass, { CanCollide = false, CanQuery = false, CastShadow = false })
			end
		end
	end
	if frontSign then self.Context.Sign(parent, "BuildingSign", frontSign, Vector3.new(center.X, 7.5, center.Z + size.Y * 0.5 + 0.2), 180, math.min(size.X - 6, 28)) end
end

function ModularUrbanKit:Building(parent, name, definition, options)
	options = options or {}
	local model = self.Context.Container("Model", parent, name)
	local center = definition.Center
	local size = definition.Size
	local height = definition.RoofHeight
	local palette = self.Palette
	local wallColor = if definition.Style == "Brick" then palette.Brick elseif definition.Style == "Stone" then palette.Stone elseif definition.Style == "Industrial" then palette.ConcreteDark else palette.Concrete
	local material = if definition.Style == "Brick" then Enum.Material.Brick elseif definition.Style == "Industrial" then Enum.Material.Concrete else Enum.Material.Concrete
	self.Context.Part(model, "SidewalkFoundation", Vector3.new(size.X + 8, 0.5, size.Y + 8), CFrame.new(center.X, 0, center.Z), palette.Stone, Enum.Material.Pavement)
	if definition.Accessible then
		if not options.SkipInteriorFloor then self.Context.Part(model, "InteriorFloor", Vector3.new(size.X, 1, size.Y), CFrame.new(center.X, -0.5, center.Z), palette.ConcreteDark, Enum.Material.Concrete) end
		self.Context.Part(model, "BackWall", Vector3.new(size.X, height, 2), CFrame.new(center.X, height * 0.5, center.Z - size.Y * 0.5), wallColor, material, { Tags = { "BLIKK_WallSurface" } })
		self.Context.Part(model, "WestWall", Vector3.new(2, height, size.Y), CFrame.new(center.X - size.X * 0.5, height * 0.5, center.Z), wallColor, material, { Tags = { "BLIKK_WallSurface" } })
		self.Context.Part(model, "EastWall", Vector3.new(2, height, size.Y), CFrame.new(center.X + size.X * 0.5, height * 0.5, center.Z), wallColor, material, { Tags = { "BLIKK_WallSurface" } })
		local entranceWidth = options.EntranceWidth or 12
		local sideWidth = (size.X - entranceWidth) * 0.5
		for _, side in { -1, 1 } do
			self.Context.Part(model, "FrontWall", Vector3.new(sideWidth, height, 2), CFrame.new(center.X + side * (entranceWidth * 0.5 + sideWidth * 0.5), height * 0.5, center.Z + size.Y * 0.5), wallColor, material, { Tags = { "BLIKK_WallSurface" } })
		end
	else
		self.Context.Part(model, "BuildingMass", Vector3.new(size.X, height, size.Y), CFrame.new(center.X, height * 0.5, center.Z), wallColor, material, { Tags = { "BLIKK_WallSurface" } })
	end
	local _, roof = self:RoofModule(model, options.RoofType or "Parapet", center, size, height, {
		ParapetHeight = options.ParapetHeight,
		Details = options.RoofDetails,
	})
	roof:SetAttribute("BLIKK_RouteDifficulty", options.RouteDifficulty or "M2")
	self:Windows(model, center, Vector2.new(size.X, size.Y), height, options.Sign)
	return model, roof
end

function ModularUrbanKit:Stairs(parent, name, start, direction, steps, width, totalRise)
	local stepRise = totalRise / steps
	local run = math.max(1.5, stepRise * 1.6)
	for index = 1, steps do
		local offset = direction.Unit * run * (index - 1)
		local size = if math.abs(direction.X) > math.abs(direction.Z) then Vector3.new(run + 0.15, stepRise, width) else Vector3.new(width, stepRise, run + 0.15)
		self.Context.Part(parent, name .. index, size, CFrame.new(start + offset + Vector3.new(0, stepRise * (index - 0.5), 0)), self.Palette.Steel, Enum.Material.Metal, { Tags = { "BLIKK_Ledge" } })
	end
end

function ModularUrbanKit:Ladder(parent, position, height, yaw)
	local model = self.Context.Container("Model", parent, "RoofLadder")
	local frame = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	for _, x in { -1.2, 1.2 } do self.Context.Part(model, "Rail", Vector3.new(0.3, height, 0.3), frame * CFrame.new(x, height * 0.5, 0), self.Palette.SteelEdge, Enum.Material.Metal, { CanCollide = false, CastShadow = false }) end
	for y = 1, height - 1, 2 do self.Context.Part(model, "Rung", Vector3.new(2.7, 0.25, 0.25), frame * CFrame.new(0, y, 0), self.Palette.SteelEdge, Enum.Material.Metal, { CanCollide = false, CastShadow = false }) end
	return model
end

function ModularUrbanKit:FireEscape(parent, position, height, width)
	local model = self.Context.Container("Model", parent, "FireEscape")
	local levels = math.max(1, math.floor(height / 10))
	for level = 1, levels do
		local y = level * 9
		self.Context.Part(model, "Landing", Vector3.new(width, 0.5, 4), CFrame.new(position + Vector3.new(0, y, 0)), self.Palette.Steel, Enum.Material.Metal, { Tags = { "BLIKK_Ledge" } })
		self:Stairs(model, "Flight" .. level .. "_", position + Vector3.new(-width * 0.35, y - 8, 2), Vector3.new(1, 0, 0), 6, 3.5, 8)
	end
	return model
end

function ModularUrbanKit:Pipe(parent, position, length, horizontal)
	local size = if horizontal then Vector3.new(length, 0.45, 0.45) else Vector3.new(0.45, length, 0.45)
	return self.Context.Part(parent, "UtilityPipe", size, CFrame.new(position), self.Palette.SteelEdge, Enum.Material.CorrodedMetal, { CanCollide = false, CanQuery = false, CastShadow = false, Tags = { "BLIKK_WallSurface" } })
end

function ModularUrbanKit:ACUnit(parent, position)
	local model = self.Context.Container("Model", parent, "ACUnit")
	self.Context.Part(model, "Housing", Vector3.new(5, 3, 4), CFrame.new(position), self.Palette.Steel, Enum.Material.Metal)
	self.Context.Part(model, "Vent", Vector3.new(3.2, 1.8, 0.2), CFrame.new(position + Vector3.new(0, 0, 2.1)), self.Palette.SteelEdge, Enum.Material.DiamondPlate, { CanCollide = false, CanQuery = false, CastShadow = false })
	return model
end

function ModularUrbanKit:Machinery(parent, position)
	local model = self.Context.Container("Model", parent, "RooftopMachinery")
	self.Context.Part(model, "Base", Vector3.new(9, 3, 7), CFrame.new(position), self.Palette.Steel, Enum.Material.Metal)
	self.Context.Part(model, "Relay", Vector3.new(3, 6, 3), CFrame.new(position + Vector3.new(0, 4, 0)), self.Palette.Purple, Enum.Material.Neon, { CanCollide = false, CanQuery = false, CastShadow = false })
	return model
end

function ModularUrbanKit:UtilityPole(parent, position, height)
	local model = self.Context.Container("Model", parent, "UtilityPole")
	self.Context.Part(model, "Pole", Vector3.new(0.6, height, 0.6), CFrame.new(position + Vector3.new(0, height * 0.5, 0)), self.Palette.Steel, Enum.Material.Metal, { CastShadow = false })
	self.Context.Part(model, "Crossbar", Vector3.new(7, 0.4, 0.4), CFrame.new(position + Vector3.new(0, height - 1, 0)), self.Palette.SteelEdge, Enum.Material.Metal, { CanCollide = false, CastShadow = false })
	return model
end

function ModularUrbanKit:Railings(parent, center, length, alongX)
	local model = self.Context.Container("Model", parent, "Railing")
	for offset = -length * 0.5, length * 0.5, 4 do
		local position = center + (if alongX then Vector3.new(offset, 1.5, 0) else Vector3.new(0, 1.5, offset))
		self.Context.Part(model, "Post", Vector3.new(0.25, 3, 0.25), CFrame.new(position), self.Palette.SteelEdge, Enum.Material.Metal, { CanCollide = false, CastShadow = false })
	end
	local size = if alongX then Vector3.new(length, 0.25, 0.25) else Vector3.new(0.25, 0.25, length)
	self.Context.Part(model, "TopRail", size, CFrame.new(center + Vector3.new(0, 3, 0)), self.Palette.SteelEdge, Enum.Material.Metal, { CanCollide = false, CastShadow = false })
	return model
end

function ModularUrbanKit:Crate(parent, position, size)
	return self.Context.Part(parent, "IndustrialCrate", size or Vector3.new(5, 4, 5), CFrame.new(position), self.Palette.BrickDark, Enum.Material.WoodPlanks)
end

function ModularUrbanKit:Bollard(parent, position)
	return self.Context.Part(parent, "Bollard", Vector3.new(0.8, 3, 0.8), CFrame.new(position + Vector3.new(0, 1.5, 0)), self.Palette.Steel, Enum.Material.Metal)
end

function ModularUrbanKit:ConstructionFence(parent, center, length, alongX)
	local size = if alongX then Vector3.new(length, 7, 0.25) else Vector3.new(0.25, 7, length)
	return self.Context.Part(parent, "ConstructionFence", size, CFrame.new(center + Vector3.new(0, 3.5, 0)), self.Palette.SteelEdge, Enum.Material.Metal, { Transparency = 0.3, Attributes = { BLIKK_WallJumpSurface = false } })
end

function ModularUrbanKit:MovementModule(parent, moduleType, position, options)
	options = options or {}
	assert(contains(self.Catalog.MovementModules, moduleType), "Unknown movement module: " .. tostring(moduleType))
	local model = self.Context.Container("Model", parent, moduleType)
	if moduleType == "FireEscapeA" or moduleType == "FireEscapeB" then
		self:FireEscape(model, position, options.HeightStuds or 24, if moduleType == "FireEscapeA" then 8 else 12)
	elseif moduleType == "ExternalStair" or moduleType == "IndustrialStair" or moduleType == "BrokenStair" then
		self:Stairs(model, "Step", position, options.Direction or Vector3.xAxis, options.Steps or 8, options.WidthStuds or 6, options.RiseStuds or 12)
	elseif moduleType == "MaintenanceLadder" or moduleType == "RoofLadder" then
		self:Ladder(model, position, options.HeightStuds or 18, options.Yaw or 0)
	elseif moduleType == "Catwalk" or moduleType == "Bridge" or moduleType == "ConstructionPlatform" then
		local size = options.Size or (if moduleType == "Bridge" then Vector3.new(20, 1, 6) else Vector3.new(14, 1, 8))
		local platform = self.Context.Part(model, "PlayableDeck", size, CFrame.new(position), self.Palette.Steel, Enum.Material.DiamondPlate, { Tags = { "BLIKK_Ledge" } })
		self:ApplyMovementMetadata(platform, { SafeLanding = true, RecoveryDrop = moduleType == "ConstructionPlatform" })
		self:Railings(model, position - Vector3.new(0, 0.5, size.Z * 0.5), size.X, true)
	elseif moduleType == "PipeWalk" then
		local pipe = self.Context.Part(model, "PlayablePipe", options.Size or Vector3.new(18, 1, 1), CFrame.new(position), self.Palette.SteelEdge, Enum.Material.CorrodedMetal, { Tags = { "BLIKK_WallSurface" } })
		self:ApplyMovementMetadata(pipe, { PipeWalk = true, SafeLanding = true })
	elseif moduleType == "Scaffolding" then
		local height = options.HeightStuds or 18
		for _, x in { -4, 4 } do for _, z in { -2, 2 } do self.Context.Part(model, "Post", Vector3.new(0.35, height, 0.35), CFrame.new(position + Vector3.new(x, height * 0.5, z)), self.Palette.SteelEdge, Enum.Material.Metal) end end
		for y = 5, height, 6 do
			local deck = self.Context.Part(model, "Deck", Vector3.new(9, 0.5, 5), CFrame.new(position + Vector3.new(0, y, 0)), self.Palette.Steel, Enum.Material.DiamondPlate, { Tags = { "BLIKK_Ledge" } })
			self:ApplyMovementMetadata(deck, { SafeLanding = true, RecoveryDrop = true })
		end
	end
	model:SetAttribute("BLIKK_KitCategory", "Movement")
	model:SetAttribute("BLIKK_ModuleType", moduleType)
	self:ApplyMovementMetadata(model, {
		ClimbSurface = contains({ "FireEscapeA", "FireEscapeB", "ExternalStair", "IndustrialStair", "MaintenanceLadder", "BrokenStair", "RoofLadder", "Scaffolding" }, moduleType),
		PipeWalk = moduleType == "PipeWalk",
		SafeLanding = contains({ "Catwalk", "Bridge", "ConstructionPlatform", "Scaffolding" }, moduleType),
		RecoveryDrop = contains({ "ConstructionPlatform", "Scaffolding" }, moduleType),
	})
	return model
end

function ModularUrbanKit:StreetFurniture(parent, furnitureType, position, options)
	options = options or {}
	assert(contains(self.Catalog.StreetFurniture, furnitureType), "Unknown street furniture: " .. tostring(furnitureType))
	local model = self.Context.Container("Model", parent, furnitureType)
	local part = self.Context.Part
	local steel, edge = self.Palette.Steel, self.Palette.SteelEdge
	if furnitureType == "StreetLight" or furnitureType == "TrafficLight" or furnitureType == "PowerPole" then
		local height = options.HeightStuds or 16
		part(model, "Post", Vector3.new(0.5, height, 0.5), CFrame.new(position + Vector3.new(0, height * 0.5, 0)), edge, Enum.Material.Metal)
		part(model, "Head", Vector3.new(if furnitureType == "TrafficLight" then 2 else 4, 2, 1), CFrame.new(position + Vector3.new(0, height, 0)), if furnitureType == "PowerPole" then edge else self.Palette.Purple, Enum.Material.Metal, { CanCollide = false })
	elseif furnitureType == "Fence" or furnitureType == "ChainlinkFence" or furnitureType == "WoodFence" or furnitureType == "GuardRail" or furnitureType == "ParkingBarrier" then
		local material = if furnitureType == "WoodFence" then Enum.Material.WoodPlanks else Enum.Material.Metal
		part(model, "Barrier", options.Size or Vector3.new(12, if furnitureType == "GuardRail" then 2 else 6, 0.4), CFrame.new(position), if material == Enum.Material.Metal then edge else self.Palette.BrickDark, material, { Transparency = if furnitureType == "ChainlinkFence" then 0.35 else 0 })
	elseif furnitureType == "Tree" or furnitureType == "Shrub" or furnitureType == "Planter" then
		if furnitureType ~= "Shrub" then part(model, "Base", Vector3.new(3, 2, 3), CFrame.new(position + Vector3.new(0, 1, 0)), self.Palette.ConcreteDark, Enum.Material.Concrete) end
		part(model, "Foliage", Vector3.new(if furnitureType == "Tree" then 6 else 4, if furnitureType == "Tree" then 7 else 3, if furnitureType == "Tree" then 6 else 4), CFrame.new(position + Vector3.new(0, if furnitureType == "Tree" then 7 else 2, 0)), Color3.fromRGB(42, 54, 39), Enum.Material.Grass, { CanCollide = false })
	else
		local sizes = { Dumpster = Vector3.new(7, 4, 4), BusStop = Vector3.new(10, 7, 3), PhoneBooth = Vector3.new(4, 8, 4), Bench = Vector3.new(8, 3, 3), ConcreteBarrier = Vector3.new(8, 3, 2), TrafficBarrier = Vector3.new(8, 2, 1), PowerBox = Vector3.new(3, 5, 2), Mailbox = Vector3.new(2, 4, 2), Hydrant = Vector3.new(2, 3, 2) }
		part(model, "Body", sizes[furnitureType] or Vector3.new(3, 3, 3), CFrame.new(position), if furnitureType == "Hydrant" then self.Palette.Warning else steel, if furnitureType == "ConcreteBarrier" then Enum.Material.Concrete else Enum.Material.Metal)
	end
	model:SetAttribute("BLIKK_KitCategory", "StreetFurniture")
	model:SetAttribute("BLIKK_ModuleType", furnitureType)
	return model
end

function ModularUrbanKit:RooftopDetail(parent, detailType, position, options)
	options = options or {}
	assert(contains(self.Catalog.RooftopDetails, detailType), "Unknown rooftop detail: " .. tostring(detailType))
	local model = self.Context.Container("Model", parent, detailType)
	local part = self.Context.Part
	if detailType == "ACUnit" then return self:ACUnit(model, position) end
	if detailType == "Generator" then return self:Machinery(model, position) end
	if detailType == "Billboard" then
		part(model, "Board", Vector3.new(14, 7, 0.5), CFrame.new(position + Vector3.new(0, 4, 0)), self.Palette.Purple, Enum.Material.Metal)
		for _, x in { -5, 5 } do part(model, "Support", Vector3.new(0.4, 8, 0.4), CFrame.new(position + Vector3.new(x, 0, 0)), self.Palette.SteelEdge, Enum.Material.Metal) end
	elseif detailType == "VentStack" or detailType == "Fan" or detailType == "SatelliteDish" then
		part(model, "Stack", Vector3.new(2.5, 4, 2.5), CFrame.new(position), self.Palette.SteelEdge, Enum.Material.Metal)
		part(model, "Cap", Vector3.new(4, 0.6, 4), CFrame.new(position + Vector3.new(0, 2.2, 0)), self.Palette.Steel, Enum.Material.Metal, { CanCollide = false })
	elseif detailType == "WaterTower" then
		part(model, "Tank", Vector3.new(9, 8, 9), CFrame.new(position + Vector3.new(0, 7, 0)), self.Palette.Steel, Enum.Material.CorrodedMetal)
		for _, x in { -3, 3 } do for _, z in { -3, 3 } do part(model, "Leg", Vector3.new(0.5, 7, 0.5), CFrame.new(position + Vector3.new(x, 3.5, z)), self.Palette.SteelEdge, Enum.Material.Metal) end end
	else
		local sizes = { SolarPanel = Vector3.new(8, 0.4, 5), ElectricalCabinet = Vector3.new(5, 6, 3), MaintenanceDoor = Vector3.new(7, 8, 5), CableTray = Vector3.new(10, 1, 2), RoofLight = Vector3.new(5, 2, 5) }
		part(model, "Body", sizes[detailType] or Vector3.new(5, 4, 4), CFrame.new(position), if detailType == "SolarPanel" then self.Palette.Window else self.Palette.Steel, Enum.Material.Metal)
	end
	model:SetAttribute("BLIKK_KitCategory", "RooftopDetail")
	model:SetAttribute("BLIKK_ModuleType", detailType)
	return model
end

function ModularUrbanKit:AlleyDetail(parent, detailType, position, options)
	options = options or {}
	assert(contains(self.Catalog.AlleyDetails, detailType), "Unknown alley detail: " .. tostring(detailType))
	if detailType == "Crate" then return self:Crate(parent, position, options.Size) end
	if detailType == "ConstructionFence" then return self:ConstructionFence(parent, position, options.Length or 12, options.AlongX ~= false) end
	if detailType == "Scaffolding" then return self:MovementModule(parent, "Scaffolding", position, options) end
	if detailType == "UtilityPipe" or detailType == "WallConduit" then return self:Pipe(parent, position, options.Length or 10, options.Horizontal ~= false) end
	local model = self.Context.Container("Model", parent, detailType)
	local sizes = { Pallet = Vector3.new(5, 0.6, 4), OilDrum = Vector3.new(2.5, 4, 2.5), Tyre = Vector3.new(3, 1, 3), GarbageBag = Vector3.new(2.5, 3, 2.5), CardboardPile = Vector3.new(5, 2, 4), ShoppingTrolley = Vector3.new(4, 3, 2), WoodSheet = Vector3.new(6, 0.5, 4), ElectricalMeter = Vector3.new(2, 3, 1) }
	self.Context.Part(model, "Body", sizes[detailType] or Vector3.new(3, 3, 2), CFrame.new(position), if detailType == "WoodSheet" or detailType == "CardboardPile" or detailType == "Pallet" then self.Palette.BrickDark else self.Palette.SteelEdge, if detailType == "WoodSheet" or detailType == "Pallet" then Enum.Material.WoodPlanks else Enum.Material.Metal)
	model:SetAttribute("BLIKK_KitCategory", "AlleyDetail")
	model:SetAttribute("BLIKK_ModuleType", detailType)
	return model
end

return ModularUrbanKit
