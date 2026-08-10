local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Maps.DistrictZero.DistrictZeroConfig)
local ModularUrbanKit = require(script.Parent.ModularUrbanKit)

local Builder = {}
local counts = { Parts = 0, Collidable = 0, Decorative = 0, Lights = 0, Surfaces = 0, Instances = 0 }

local function tag(instance, tagName)
	CollectionService:AddTag(instance, tagName)
end

local function makePart(parent, name, size, cframe, color, material, options)
	options = options or {}
	local object = Instance.new(options.ClassName or "Part")
	object.Name = name
	object.Anchored = true
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material
	object.CanCollide = options.CanCollide ~= false
	object.CanQuery = options.CanQuery ~= false
	object.CanTouch = options.CanTouch == true
	object.CastShadow = options.CastShadow ~= false
	object.Transparency = options.Transparency or 0
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in options.Attributes or {} do object:SetAttribute(key, value) end
	object.Parent = parent
	for _, tagName in options.Tags or {} do tag(object, tagName) end
	counts.Parts += 1
	counts.Instances += 1
	if object.CanCollide then counts.Collidable += 1 else counts.Decorative += 1 end
	if table.find(options.Tags or {}, "BLIKK_WallSurface") or table.find(options.Tags or {}, "BLIKK_Ledge") then counts.Surfaces += 1 end
	return object
end

local function makeContainer(className, parent, name)
	local object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	counts.Instances += 1
	return object
end

local function makeSign(parent, name, text, position, yaw, width)
	local plate = makePart(parent, name, Vector3.new(width or 18, 3.5, 0.35), CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0), Config.Palette.Steel, Enum.Material.Metal, { CanCollide = false, CanQuery = false, CastShadow = false })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DistrictSign"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.4
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(9, 10, 12)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Code
	label.Text = text
	label.TextColor3 = Config.Palette.Text
	label.TextSize = 25
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = gui
	counts.Instances += 2
	return plate
end

local function configureLight(light, owner, tier, purpose, brightness, range, castsShadowsAtHigh)
	light:SetAttribute("BLIKK_QualityTier", tier)
	light:SetAttribute("BLIKK_BaseBrightness", brightness)
	light:SetAttribute("BLIKK_BaseRange", range)
	owner:SetAttribute("BLIKK_QualityTier", tier)
	owner:SetAttribute("BLIKK_LightPurpose", purpose)
	owner:SetAttribute("BLIKK_CastsShadowsAtHigh", castsShadowsAtHigh == true)
	tag(owner, "BLIKK_EnvironmentLight")
	counts.Lights += 1
	counts.Instances += 1
end

local function makeLamp(parent, position, tier, profile, castsShadowsAtHigh, name)
	if counts.Lights >= Config.Lighting.LightCountLimits.MaximumTotal then return end
	makePart(parent, "StreetLampPost", Vector3.new(0.45, 12, 0.45), CFrame.new(position + Vector3.new(0, 6, 0)), Config.Palette.Steel, Enum.Material.Metal, { CastShadow = false })
	local head = makePart(parent, name or "StreetLampHead", Vector3.new(1.7, 0.55, 1.7), CFrame.new(position + Vector3.new(0, 12, 0)), profile.FixtureColor, Enum.Material.Neon, { CanCollide = false, CanQuery = false, CastShadow = false })
	local light = Instance.new("PointLight")
	light.Name = "DistrictPractical"
	light.Brightness = profile.Brightness
	light.Color = profile.LightColor
	light.Range = profile.RangeStuds
	light.Shadows = castsShadowsAtHigh == true
	light.Parent = head
	configureLight(light, head, tier, if tier == "ESSENTIAL" then "STREET" else "LANDMARK", profile.Brightness, profile.RangeStuds, castsShadowsAtHigh)
end

local function makeRouteFill(parent, definition)
	if counts.Lights >= Config.Lighting.LightCountLimits.MaximumTotal then return end
	local profile = Config.Lighting.RouteFillLights
	local anchor = makePart(parent, definition.Name .. "FillAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(definition.Position), Color3.new(), Enum.Material.SmoothPlastic, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
	})
	local brightness = definition.Brightness or profile.DefaultBrightness
	local range = definition.RangeStuds or profile.DefaultRangeStuds
	local light = Instance.new("PointLight")
	light.Name = "DistrictRouteFill"
	light.Brightness = brightness
	light.Color = definition.Color or profile.DefaultColor
	light.Range = range
	light.Shadows = false
	light.Parent = anchor
	configureLight(light, anchor, "ESSENTIAL", definition.Purpose, brightness, range, false)
end

local kit = ModularUrbanKit.new({ Part = makePart, Container = makeContainer, Sign = makeSign, Tag = tag, Palette = Config.Palette })

local function isInRect(x, z, center, width, length)
	return math.abs(x - center.X) < width * 0.5 and math.abs(z - center.Z) < length * 0.5
end

local function buildGround(parent)
	local ground = makeContainer("Folder", parent, "StreetsAndGround")
	local unit = Config.Dimensions.GridUnitStuds
	for row = 1, Config.Dimensions.GridRows do
		for column = 1, Config.Dimensions.GridColumns do
			local x = -250 + unit * (column - 0.5)
			local z = -250 + unit * (row - 0.5)
			local canalHole = isInRect(x, z, Vector3.new(-12, 0, 205), 126, 90)
			local stationHole = isInRect(x, z, Vector3.new(108, 0, 28), 48, 78)
			if not canalHole and not stationHole then
				local tile = makePart(ground, string.format("Grid_%02d_%02d", column, row), Vector3.new(unit, 1, unit), CFrame.new(x, -0.5, z), Config.Palette.Asphalt, Enum.Material.Asphalt)
				tile:SetAttribute("BLIKK_GridColumn", column)
				tile:SetAttribute("BLIKK_GridRow", row)
				local onClockLoop = (x >= -110 and x <= 70 and (math.abs(z + 140) <= 10 or math.abs(z - 10) <= 10))
					or (z >= -140 and z <= 10 and (math.abs(x + 110) <= 10 or math.abs(x - 70) <= 10))
				local onSpawnApproach = math.abs(z + 110) <= 10 and x >= -230 and x <= -110
				if onClockLoop or onSpawnApproach then
					tile:SetAttribute("BLIKK_RouteName", "BeginnerGroundLoop")
					tile:SetAttribute("BLIKK_RouteDifficulty", "M1")
					tag(tile, "BLIKK_MovementRoute")
				end
			end
		end
	end
	makePart(ground, "DeepSafetyFoundation", Vector3.new(500, 2, 500), CFrame.new(0, -26, 0), Config.Palette.ConcreteDark, Enum.Material.Concrete)
	for _, data in {
		{ "NorthBoundary", Vector3.new(500, 96, 2), Vector3.new(0, 48, -250) }, { "SouthBoundary", Vector3.new(500, 96, 2), Vector3.new(0, 48, 250) },
		{ "WestBoundary", Vector3.new(2, 96, 500), Vector3.new(-250, 48, 0) }, { "EastBoundary", Vector3.new(2, 96, 500), Vector3.new(250, 48, 0) },
	} do makePart(ground, data[1], data[2], CFrame.new(data[3]), Config.Palette.ConcreteDark, Enum.Material.Brick, { Tags = { "BLIKK_WallSurface" } }) end
	return ground
end

local function setRoute(instance, routeName, futureTechnique)
	local definition = Config.Routes[routeName]
	instance:SetAttribute("BLIKK_RouteName", routeName)
	instance:SetAttribute("BLIKK_RouteDifficulty", definition.Difficulty)
	if futureTechnique then instance:SetAttribute("BLIKK_FutureTechnique", futureTechnique) end
	tag(instance, "BLIKK_MovementRoute")
end

local function buildClockTower(parent)
	local definition = Config.Buildings.ClockTower
	local model = makeContainer("Model", parent, "ClockTower")
	model:SetAttribute("BLIKK_ZoneName", "CLOCK")
	local center = definition.Center
	makePart(model, "CivicBase", Vector3.new(66, 52, 64), CFrame.new(center.X, 26, center.Z), Config.Palette.Stone, Enum.Material.Brick, { Tags = { "BLIKK_WallSurface" } })
	local clockRoof = makePart(model, "ClockRoomRoof", Vector3.new(68, 1, 66), CFrame.new(center.X, 52.5, center.Z), Config.Palette.Roof, Enum.Material.Concrete, { Tags = { "BLIKK_Ledge" }, Attributes = { BLIKK_RoofHeight = 52 } })
	kit:Parapet(model, clockRoof.Position + Vector3.new(0, 0.5, 0), Vector3.new(68, 0, 66), 3.5)
	kit:Windows(model, center, Vector2.new(66, 64), 52)
	makePart(model, "BellTower", Vector3.new(28, 42, 28), CFrame.new(center.X, 73, center.Z), Config.Palette.Stone, Enum.Material.Brick, { Tags = { "BLIKK_WallSurface" } })
	local bellRoof = makePart(model, "BellTowerRoof", Vector3.new(31, 1, 31), CFrame.new(center.X, 94.5, center.Z), Config.Palette.SteelEdge, Enum.Material.Metal, { Tags = { "BLIKK_Ledge" }, Attributes = { BLIKK_RoofHeight = 94 } })
	makePart(model, "UpperSpire", Vector3.new(14, 27, 14), CFrame.new(center.X, 108, center.Z), Config.Palette.Steel, Enum.Material.Metal, { Tags = { "BLIKK_WallSurface" } })
	makePart(model, "SpirePlatform", Vector3.new(18, 1, 18), CFrame.new(center.X, 122, center.Z), Config.Palette.SteelEdge, Enum.Material.Metal, { Tags = { "BLIKK_Ledge" }, Attributes = { BLIKK_RoofHeight = 122 } })
	local spire = makePart(model, "ClockSpire", Vector3.new(3, 20, 3), CFrame.new(center.X, 132, center.Z), Config.Palette.Purple, Enum.Material.Neon, { CanCollide = false, CanQuery = false, CastShadow = false })
	spire:SetAttribute("BLIKK_HighestPointStuds", 142)
	for _, face in { Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) } do
		local size = if face.X == 0 then Vector3.new(10, 10, 0.2) else Vector3.new(0.2, 10, 10)
		makePart(model, "ClockFace", size, CFrame.new(center + Vector3.new(face.X * 14.1, 74, face.Z * 14.1)), Config.Palette.Text, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CastShadow = false })
	end
	for _, position in { Vector3.new(-57, 0, -113), Vector3.new(21, 0, -113), Vector3.new(-57, 0, -31), Vector3.new(21, 0, -31) } do
		makePart(model, "CivicPlanter", Vector3.new(16, 2, 12), CFrame.new(position + Vector3.new(0, 1, 0)), Config.Palette.Stone, Enum.Material.Brick)
		makePart(model, "PlanterColumn", Vector3.new(2, 9, 2), CFrame.new(position + Vector3.new(0, 6.5, 0)), Config.Palette.BrickDark, Enum.Material.Wood, { CanCollide = false, CanQuery = false, CastShadow = false })
	end
	kit:Stairs(model, "ClockApproach", center + Vector3.new(-44, 0, 22), Vector3.new(1, 0, 0), 12, 9, 14)
	local groundLadder = kit:Ladder(model, center + Vector3.new(33.2, 0, 0), 52, 90)
	groundLadder:SetAttribute("BLIKK_BeginnerRoofAccess", true)
	local clockLadder = kit:Ladder(model, center + Vector3.new(14.2, 52, 0), 42, 90)
	clockLadder:SetAttribute("BLIKK_FutureTechnique", "VERTICAL CHAIN")
	local spireLadder = kit:Ladder(model, center + Vector3.new(7.2, 94, 0), 28, 90)
	spireLadder:SetAttribute("BLIKK_BeginnerRoofAccess", true)
	makeSign(model, "ClockCallout", "CLOCK // DISTRICT ZERO", center + Vector3.new(0, 42, 32.2), 180, 27)
	setRoute(clockRoof, "MarketRun")
	setRoute(bellRoof, "MasterRooftopHighway", "ADVANCED CLOCK ASCENT")
	return model
end

local function buildStandardBuildings(parent)
	local roofs = {}
	local ordered = { "ConstructionSite", "ParkingGarage", "MarketStreet", "ApartmentA", "ApartmentB", "GeneratorStation", "Billboard", "TransitStation", "ApartmentC", "ApartmentD", "ServiceYard" }
	local signs = {
		ConstructionSite = "CONSTRUCTION", ParkingGarage = "PARKING GARAGE", MarketStreet = "MARKET",
		ApartmentA = "APARTMENTS A", ApartmentB = "APARTMENTS B", GeneratorStation = "GENERATOR",
		Billboard = "BLIKK // MOVEMENT", TransitStation = "TRANSIT STATION", ApartmentC = "APARTMENTS C",
		ApartmentD = "APARTMENTS D", ServiceYard = "SERVICE YARD",
	}
	for _, name in ordered do
		local definition = Config.Buildings[name]
		local model, roof = kit:Building(parent, name, definition, {
			Sign = signs[name], ParapetHeight = if name == "ServiceYard" then 4 else 3,
			RouteDifficulty = if definition.RoofHeight >= 40 then "M4" else "M3",
			SkipInteriorFloor = name == "TransitStation",
			RoofType = if name == "Billboard" then "Billboard" elseif name == "GeneratorStation" then "Mechanical" elseif string.find(name, "Apartment") then "Apartment" else "Parapet",
			RoofDetails = if string.find(name, "Apartment") then { "ACUnit", "VentStack" } elseif name == "TransitStation" then { "MaintenanceDoor", "CableTray" } else nil,
		})
		model:SetAttribute("BLIKK_ZoneName", signs[name])
		roofs[name] = roof
		if string.find(name, "Apartment") then
			kit:MovementModule(model, "FireEscapeB", Vector3.new(definition.Center.X - definition.Size.X * 0.5 - 3, 0, definition.Center.Z), { HeightStuds = definition.RoofHeight })
			kit:Pipe(model, Vector3.new(definition.Center.X + definition.Size.X * 0.5 + 0.3, definition.RoofHeight * 0.5, definition.Center.Z), definition.RoofHeight, false)
			local ladder = kit:MovementModule(model, "RoofLadder", Vector3.new(definition.Center.X + definition.Size.X * 0.5 + 0.3, 0, definition.Center.Z - 10), { HeightStuds = definition.RoofHeight, Yaw = 90 })
			ladder:SetAttribute("BLIKK_FutureTechnique", "VERTICAL CHAIN")
		else
			local ladder = kit:MovementModule(model, "RoofLadder", Vector3.new(
				definition.Center.X + definition.Size.X * 0.5 + 0.3,
				0,
				definition.Center.Z - math.min(10, definition.Size.Y * 0.2)
			), { HeightStuds = definition.RoofHeight, Yaw = 90 })
			ladder:SetAttribute("BLIKK_BeginnerRoofAccess", true)
		end
		if name == "ConstructionSite" then
			model:SetAttribute("BLIKK_PracticePocket", true)
			kit:AlleyDetail(model, "ConstructionFence", Vector3.new(definition.Center.X, 0, definition.Center.Z + definition.Size.Y * 0.5 + 4), { Length = definition.Size.X })
			for offset = -30, 30, 15 do kit:StreetFurniture(model, "PowerPole", Vector3.new(definition.Center.X + offset, 0, definition.Center.Z), { HeightStuds = 18 }) end
			for offset = -30, 30, 20 do kit:MovementModule(model, "Scaffolding", Vector3.new(definition.Center.X + offset, 0, definition.Center.Z + definition.Size.Y * 0.5 + 3), { HeightStuds = definition.RoofHeight - 8 }) end
		end
		if name == "GeneratorStation" then
			kit:RooftopDetail(model, "Generator", Vector3.new(definition.Center.X, definition.RoofHeight + 2, definition.Center.Z))
			makeLamp(model, Vector3.new(definition.Center.X, definition.RoofHeight + 1, definition.Center.Z), "HIGH", Config.Lighting.LandmarkAccents, false, "GeneratorAccentHead")
		end
		if name == "ParkingGarage" then
			model:SetAttribute("BLIKK_CombatPocket", true)
			kit:Stairs(model, "GarageRampStep", Vector3.new(-232, 0, -72), Vector3.new(1, 0, 0), 30, 12, definition.RoofHeight)
		end
		if name == "Billboard" then kit:Railings(model, Vector3.new(definition.Center.X, definition.RoofHeight, definition.Center.Z + definition.Size.Y * 0.5), definition.Size.X, true) end
	end
	setRoute(roofs.ConstructionSite, "MasterRooftopHighway")
	setRoute(roofs.ParkingGarage, "MasterRooftopHighway")
	setRoute(roofs.ApartmentA, "ApartmentChain")
	setRoute(roofs.ApartmentB, "ApartmentChain")
	setRoute(roofs.GeneratorStation, "GeneratorLoop")
	setRoute(roofs.Billboard, "SkylineRoute")
	setRoute(roofs.TransitStation, "GeneratorLoop")
	setRoute(roofs.ApartmentC, "ApartmentChain")
	setRoute(roofs.ApartmentD, "ApartmentChain")
	setRoute(roofs.ServiceYard, "MasterRooftopHighway")
	return roofs
end

local function buildCourt(parent)
	local definition = Config.Buildings.BasketballCourt
	local model, roof = kit:Building(parent, "BasketballCourt", definition, { Sign = "COURT", ParapetHeight = 4, RouteDifficulty = "M2" })
	model:SetAttribute("BLIKK_ZoneName", "COURT")
	local y = definition.RoofHeight + 1.03
	makePart(model, "CourtSurface", Vector3.new(66, 0.08, 56), CFrame.new(definition.Center.X, y, definition.Center.Z), Color3.fromRGB(78, 91, 81), Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CastShadow = false })
	makePart(model, "CentreLine", Vector3.new(0.25, 0.1, 52), CFrame.new(definition.Center.X, y + 0.05, definition.Center.Z), Config.Palette.Text, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CastShadow = false })
	makePart(model, "HalfCourtLine", Vector3.new(62, 0.1, 0.25), CFrame.new(definition.Center.X, y + 0.05, definition.Center.Z), Config.Palette.Text, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CastShadow = false })
	for _, z in { definition.Center.Z - 30, definition.Center.Z + 30 } do kit:Railings(model, Vector3.new(definition.Center.X, definition.RoofHeight + 1, z), 72, true) end
	kit:Stairs(model, "CourtClimb", Vector3.new(-71, 0, 92), Vector3.new(1, 0, 0), math.ceil(definition.RoofHeight / 2), 9, definition.RoofHeight)
	local ladder = kit:MovementModule(model, "RoofLadder", Vector3.new(
		definition.Center.X + definition.Size.X * 0.5 + 0.3,
		0,
		definition.Center.Z
	), { HeightStuds = definition.RoofHeight, Yaw = 90 })
	ladder:SetAttribute("BLIKK_BeginnerRoofAccess", true)
	setRoute(roof, "CourtClimb")
	return roof
end

local function buildParkingLot(parent)
	local definition = Config.Buildings.ParkingLot
	local model = makeContainer("Model", parent, "ParkingLot")
	model:SetAttribute("BLIKK_ZoneName", "PARKING LOT")
	makePart(model, "ParkingSurface", Vector3.new(definition.Size.X, 0.12, definition.Size.Y), CFrame.new(definition.Center.X, 0.07, definition.Center.Z), Config.Palette.Asphalt, Enum.Material.Asphalt, { CanCollide = false, CanQuery = false, CastShadow = false })
	for x = definition.Center.X - 36, definition.Center.X + 36, 12 do makePart(model, "ParkingStripe", Vector3.new(0.18, 0.03, 22), CFrame.new(x, 0.145, definition.Center.Z), Config.Palette.Text, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CastShadow = false }) end
	for _, position in { Vector3.new(-205, 2, 189), Vector3.new(-154, 2, 220), Vector3.new(-126, 2, 190) } do kit:Crate(model, position) end
	return model
end

local function buildCanal(parent)
	local definition = Config.Buildings.CanalDrain
	local model = makeContainer("Model", parent, "CanalDrain")
	model:SetAttribute("BLIKK_ZoneName", "CANAL")
	makePart(model, "CanalBottom", Vector3.new(definition.Size.X, 1, definition.Size.Y), CFrame.new(definition.Center.X, -24.5, definition.Center.Z), Config.Palette.ConcreteDark, Enum.Material.Concrete)
	makePart(model, "CanalWater", Vector3.new(definition.Size.X - 14, 0.5, definition.Size.Y - 12), CFrame.new(definition.Center.X, -23.7, definition.Center.Z), Config.Palette.Canal, Enum.Material.Glass, { CanCollide = false, CanTouch = false, Transparency = 0.35 })
	for _, x in { definition.Center.X - definition.Size.X * 0.5, definition.Center.X + definition.Size.X * 0.5 } do
		makePart(model, "CanalWall", Vector3.new(2, 25, definition.Size.Y), CFrame.new(x, -12, definition.Center.Z), Config.Palette.Stone, Enum.Material.Concrete, { Tags = { "BLIKK_WallSurface" }, Attributes = { BLIKK_FutureTechnique = "WALL JUMP", BLIKK_RouteDifficulty = "M3" } })
	end
	for _, z in { definition.Center.Z - definition.Size.Y * 0.5, definition.Center.Z + definition.Size.Y * 0.5 } do
		makePart(model, "CanalWall", Vector3.new(definition.Size.X, 25, 2), CFrame.new(definition.Center.X, -12, z), Config.Palette.Stone, Enum.Material.Concrete, { Tags = { "BLIKK_WallSurface" } })
	end
	kit:Stairs(model, "CanalWestAccess", Vector3.new(-80, -24, 168), Vector3.new(1, 0, 0), 12, 10, 24)
	kit:Stairs(model, "CanalEastAccess", Vector3.new(56, -24, 225), Vector3.new(-1, 0, 0), 12, 10, 24)
	local bridge = makePart(model, "CanalBridge", Vector3.new(16, 1, definition.Size.Y + 12), CFrame.new(-12, 1, definition.Center.Z), Config.Palette.Steel, Enum.Material.Metal, { Tags = { "BLIKK_Ledge" } })
	setRoute(bridge, "CanalExpress")
	makeSign(model, "CanalSign", "CANAL // DRAIN", Vector3.new(-12, 6, 154), 0, 19)
	return model
end

local function buildStationSublevel(parent)
	local model = makeContainer("Model", parent, "StationSublevel")
	makePart(model, "TunnelFloor", Vector3.new(38, 1, 70), CFrame.new(108, -12.5, 28), Config.Palette.ConcreteDark, Enum.Material.Concrete)
	makePart(model, "TunnelWestWall", Vector3.new(2, 12, 70), CFrame.new(89, -6, 28), Config.Palette.Stone, Enum.Material.Concrete, { Tags = { "BLIKK_WallSurface" } })
	makePart(model, "TunnelEastWall", Vector3.new(2, 12, 70), CFrame.new(127, -6, 28), Config.Palette.Stone, Enum.Material.Concrete, { Tags = { "BLIKK_WallSurface" } })
	kit:Stairs(model, "StationDown", Vector3.new(96, -12, -4), Vector3.new(0, 0, 1), 10, 14, 12)
	kit:Stairs(model, "StationUp", Vector3.new(120, -12, 60), Vector3.new(0, 0, -1), 10, 14, 12)
	makeSign(model, "StationLowerSign", "TRANSIT // SERVICE", Vector3.new(108, -4, -6), 0, 20)
	return model
end

local function buildAlleys(parent)
	local model = makeContainer("Model", parent, "AlleyNetwork")
	model:SetAttribute("BLIKK_ZoneName", "ALLEYS")
	local walls = {
		{ Vector3.new(-112, 8, -60), Vector3.new(2, 16, 62) }, { Vector3.new(-99, 8, -60), Vector3.new(2, 16, 62) },
		{ Vector3.new(47, 9, -175), Vector3.new(2, 18, 55) }, { Vector3.new(57, 9, -175), Vector3.new(2, 18, 55) },
		{ Vector3.new(50, 7, 124), Vector3.new(2, 14, 67) }, { Vector3.new(62, 7, 124), Vector3.new(2, 14, 67) },
		{ Vector3.new(-96, 6, 148), Vector3.new(66, 12, 2) }, { Vector3.new(-96, 6, 164), Vector3.new(66, 12, 2) },
	}
	for index, data in walls do
		local wall = makePart(model, "AlleyWall" .. index, data[2], CFrame.new(data[1]), if index % 2 == 0 then Config.Palette.BrickDark else Config.Palette.ConcreteDark, Enum.Material.Brick, { Tags = { "BLIKK_WallSurface" }, Attributes = { BLIKK_FutureTechnique = "BUTTERFLY CHANNEL", BLIKK_RouteDifficulty = if index <= 4 then "M4" else "M3" } })
		if index % 2 == 0 then setRoute(wall, "AlleyConnectors", "BUTTERFLY CHANNEL") end
	end
	for _, position in { Vector3.new(-105, 2, -40), Vector3.new(54, 2, 109), Vector3.new(-83, 2, 156) } do kit:AlleyDetail(model, "Crate", position, { Size = Vector3.new(6, 4, 5) }) end
	for _, position in { Vector3.new(-101, 7, -75), Vector3.new(54, 8, -190), Vector3.new(58, 6, 145) } do kit:AlleyDetail(model, "WallConduit", position, { Length = 12, Horizontal = false }) end
	for index, position in { Vector3.new(-106, 1, -48), Vector3.new(52, 1, 116), Vector3.new(-90, 1, 157) } do kit:AlleyDetail(model, if index == 2 then "OilDrum" else "Pallet", position) end
	return model
end

local function buildRoofConnections(parent, roofs, courtRoof)
	local model = makeContainer("Model", parent, "ArchitecturalRouteConnections")
	local function catwalk(name, center, size, route, future)
		local platform = makePart(model, name, size, CFrame.new(center), Config.Palette.Steel, Enum.Material.Metal, { Tags = { "BLIKK_Ledge" } })
		setRoute(platform, route, future)
		if size.X > size.Z then kit:Railings(model, center + Vector3.new(0, 0, size.Z * 0.5), size.X, true) else kit:Railings(model, center + Vector3.new(size.X * 0.5, 0, 0), size.Z, false) end
		return platform
	end
	catwalk("AptABridge", Vector3.new(20, 58.5, -190), Vector3.new(72, 1, 7), "ApartmentChain")
	local generatorLedge = catwalk("GeneratorGapLedge", Vector3.new(160, 53, -86), Vector3.new(10, 1, 7), "GeneratorLoop", "SLASH JUMP GAP")
	local billboardLedge = catwalk("BillboardGapLedge", Vector3.new(176.5, 53, -86), Vector3.new(12, 1, 7), "GeneratorLoop", "SLASH JUMP GAP")
	generatorLedge:SetAttribute("BLIKK_RoofGapStuds", 11)
	billboardLedge:SetAttribute("BLIKK_RoofGapStuds", 11)
	catwalk("MarketGarageLink", Vector3.new(-127, 52.5, -58), Vector3.new(11, 1, 55), "MarketRun")
	catwalk("CourtApartmentDLink", Vector3.new(53, 48.5, 102), Vector3.new(20, 1, 7), "CourtClimb")
	catwalk("SouthHighwayWest", Vector3.new(-106, 51, 166), Vector3.new(12, 1, 48), "MasterRooftopHighway")
	catwalk("SouthHighwayEast", Vector3.new(74, 43, 172), Vector3.new(12, 1, 35), "MasterRooftopHighway")
	catwalk("NorthHighwayWest", Vector3.new(-124, 56, -226), Vector3.new(14, 1, 48), "MasterRooftopHighway")
	catwalk("NorthHighwayEast", Vector3.new(166, 52, -226), Vector3.new(42, 1, 8), "MasterRooftopHighway")
	for name, roof in roofs do roof:SetAttribute("BLIKK_RecoveryDrop", name ~= "Billboard") end
	courtRoof:SetAttribute("BLIKK_CombatPocket", true)
	return model
end

local function buildStreetProps(parent)
	local props = makeContainer("Folder", parent, "StreetProps")
	for index, definition in Config.Lighting.StreetLights.Placements do
		makeLamp(
			props,
			definition.Position,
			"ESSENTIAL",
			Config.Lighting.StreetLights,
			definition.CastsShadowsAtHigh,
			string.format("StreetLampHead%02d", index)
		)
	end
	for _, position in { Vector3.new(-126, 0, -55), Vector3.new(48, 0, -120), Vector3.new(182, 0, 110), Vector3.new(-93, 0, 90) } do kit:StreetFurniture(props, "PowerPole", position, { HeightStuds = 20 }) end
	for index, position in { Vector3.new(-72, 0, -130), Vector3.new(-58, 0, -130), Vector3.new(43, 0, -135), Vector3.new(60, 0, -135), Vector3.new(44, 0, 153), Vector3.new(60, 0, 153) } do
		kit:Bollard(props, position)
		if index % 2 == 0 then kit:StreetFurniture(props, "Bin", position + Vector3.new(3, 1.5, 3)) end
	end
	for _, definition in {
		{ "Dumpster", Vector3.new(-108, 2, -87) }, { "Bench", Vector3.new(-28, 1.5, -107) },
		{ "Hydrant", Vector3.new(67, 1.5, -112) }, { "ConcreteBarrier", Vector3.new(196, 1.5, 155) },
		{ "Planter", Vector3.new(-73, 0, 72) },
	} do kit:StreetFurniture(props, definition[1], definition[2]) end
	return props
end

local function buildRouteLighting(parent)
	local lighting = makeContainer("Folder", parent, "RouteLighting")
	lighting:SetAttribute("BLIKK_LightingOwner", "DistrictZero")
	for _, definition in Config.Lighting.RouteFillLights.Placements do
		makeRouteFill(lighting, definition)
	end
	return lighting
end

local function buildDevelopmentCalibration(parent)
	local definition = Config.DevelopmentCalibration
	if not definition.Enabled then return end
	local development = makeContainer("Folder", parent, "Development")
	development:SetAttribute("BLIKK_DevelopmentOnly", true)
	local chamber = makeContainer("Model", development, "WallCalibrationStrip")
	chamber:SetAttribute("BLIKK_DevelopmentOnly", true)
	local totalLength = definition.BaySpacingStuds * #definition.WallHeightsStuds
	makePart(chamber, "SafeFloor", Vector3.new(totalLength, 1, 32), CFrame.new(definition.Origin), Config.Palette.ConcreteDark, Enum.Material.Concrete, { Tags = { "BLIKK_Ledge" }, Attributes = { BLIKK_SafeLanding = true, BLIKK_RecoveryDrop = true } })
	for index, height in definition.WallHeightsStuds do
		local bayX = definition.Origin.X - totalLength * 0.5 + definition.BaySpacingStuds * (index - 0.5)
		local gap = definition.ChannelGapsStuds[index]
		for _, side in { -1, 1 } do
			makePart(chamber, string.format("Wall_%02d_%s", index, if side < 0 then "L" else "R"), Vector3.new(definition.BaySpacingStuds - 2, height, 1), CFrame.new(bayX, definition.Origin.Y + height * 0.5 + 0.5, definition.Origin.Z + side * gap * 0.5), Config.Palette.Brick, Enum.Material.Brick, { Tags = { "BLIKK_WallSurface" }, Attributes = { BLIKK_WallJumpSurface = true, BLIKK_ButterflyChannel = true } })
		end
	end
	makePart(chamber, "CalibrationSpawnMarker", Vector3.new(6, 0.12, 6), CFrame.new(definition.Origin + Vector3.new(-totalLength * 0.5 + 5, 0.57, 0)), Config.Palette.Purple, Enum.Material.Neon, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Attributes = { BLIKK_DevelopmentMarker = true } })
end

local function buildSpawnPoints(parent)
	local folder = makeContainer("Folder", parent, "SpawnPoints")
	for index, definition in Config.SpawnGroups.Training do
		local spawn = makePart(folder, definition.Id, Vector3.new(10, 1, 10), CFrame.lookAt(definition.Position, definition.Position + definition.Facing), Config.Palette.Steel, Enum.Material.Metal, { ClassName = "SpawnLocation", Attributes = { BLIKK_SpawnId = definition.Id, BLIKK_SpawnGroup = "Training", BLIKK_SpawnIndex = index, BLIKK_SpawnLabel = definition.Label }, Tags = { "BLIKK_SafeSpawn" } })
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.AllowTeamChangeOnTouch = false
	end
	return folder
end

local function applyLighting()
	local profile = Config.Lighting.GlobalNightFill
	Lighting.ClockTime = profile.ClockTime
	Lighting.Brightness = profile.Brightness
	Lighting.ExposureCompensation = profile.ExposureCompensation
	Lighting.Ambient = profile.Ambient
	Lighting.OutdoorAmbient = profile.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = profile.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = profile.EnvironmentSpecularScale
	Lighting.ShadowSoftness = profile.ShadowSoftness
	Lighting.FogColor = profile.FogColor
	Lighting.FogStart = profile.FogStartStuds
	Lighting.FogEnd = profile.FogEndStuds
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChild("BLIKK_DistrictZeroAtmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "BLIKK_DistrictZeroAtmosphere"
	atmosphere.Density = profile.AtmosphereDensity
	atmosphere.Haze = profile.AtmosphereHaze
	atmosphere.Color = profile.AtmosphereColor
	atmosphere.Decay = profile.AtmosphereDecay
	atmosphere.Parent = Lighting
	local post = Config.Lighting.PostProcessing
	local grade = Lighting:FindFirstChild("BLIKK_DistrictZeroGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "BLIKK_DistrictZeroGrade"
	grade.Brightness = post.ColorCorrectionBrightness
	grade.Contrast = post.ColorCorrectionContrast
	grade.Saturation = post.ColorCorrectionSaturation
	grade.TintColor = post.ColorCorrectionTint
	grade.Parent = Lighting
	local bloom = Lighting:FindFirstChild("BLIKK_DistrictZeroBloom") or Instance.new("BloomEffect")
	bloom.Name = "BLIKK_DistrictZeroBloom"
	bloom.Intensity = post.BloomIntensity
	bloom.Size = post.BloomSize
	bloom.Threshold = post.BloomThreshold
	bloom.Parent = Lighting
end

function Builder:Build()
	for key in counts do counts[key] = 0 end
	local existing = Workspace:FindFirstChild(Config.Identity.WorkspaceRootName)
	if existing then existing:Destroy() end
	local root = makeContainer("Model", Workspace, Config.Identity.WorkspaceRootName)
	local district = makeContainer("Model", root, Config.Identity.ModelName)
	district:SetAttribute("BLIKK_MapId", "DistrictZero")
	district:SetAttribute("BLIKK_MapVersion", Config.Identity.Version)
	district:SetAttribute("BLIKK_WidthStuds", Config.Dimensions.WidthStuds)
	district:SetAttribute("BLIKK_LengthStuds", Config.Dimensions.LengthStuds)
	district:SetAttribute("BLIKK_Blueprint", "DZ-001 / DZ-002 / DZ-003 V1")
	applyLighting()
	buildGround(district)
	local architecture = makeContainer("Folder", district, "Architecture")
	local roofs = buildStandardBuildings(architecture)
	buildClockTower(architecture)
	local courtRoof = buildCourt(architecture)
	buildParkingLot(architecture)
	buildCanal(architecture)
	buildStationSublevel(architecture)
	buildAlleys(architecture)
	buildRoofConnections(district, roofs, courtRoof)
	buildStreetProps(district)
	buildRouteLighting(district)
	buildDevelopmentCalibration(district)
	buildSpawnPoints(district)
	local audio = makeContainer("Folder", district, "AudioHooks")
	for _, name in { "Ambience", "DistantIndustrial", "LampBuzz", "Wind", "StationHum", "CanalDrain" } do
		local hook = makeContainer("Folder", audio, name)
		hook:SetAttribute("BLIKK_AudioAssetId", "")
	end
	for key, value in counts do district:SetAttribute("BLIKK_" .. key .. "Count", value) end
	return district
end

return Builder
