local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FighterVitalsConfig = require(ReplicatedStorage.Shared.Combat.FighterVitalsConfig)
local DistrictZeroConfig = require(ReplicatedStorage.Shared.Maps.DistrictZero.DistrictZeroConfig)
local RecoveryConfig = require(ReplicatedStorage.Shared.Recovery.RecoveryConfig)
local RateLimiter = require(script.Parent.Parent.Networking.RateLimiter)

local RecoveryService = {}

local states = {}
local worldConnections = {}
local requestLimiter = RateLimiter.New()
local recoveryIntentRemote = nil
local recoveryResultRemote = nil
local matchService = nil
local roomService = nil
local mapGeneration = 0
local isInitialised = false

local function finiteInteger(value)
	return type(value) == "number" and value == value and value > -math.huge
		and value < math.huge and value % 1 == 0
end

local function disconnectWorldConnections()
	for _, connection in worldConnections do connection:Disconnect() end
	table.clear(worldConnections)
end

local function snapshotCounts(state)
	local counts = {}
	for _, itemId in RecoveryConfig.InventoryOrder do
		counts[itemId] = state and state.Counts[itemId] or 0
	end
	return counts
end

local function sendResult(player, operation, accepted, code, details)
	if player.Parent ~= Players then return end
	local state = states[player]
	local payload = {
		Operation = operation,
		Accepted = accepted,
		Code = code,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
		Counts = snapshotCounts(state),
		ServerTime = Workspace:GetServerTimeNow(),
	}
	for key, value in details or {} do payload[key] = value end
	recoveryResultRemote:FireClient(player, payload)
end

local function isEligible(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local spawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
	local context = player:GetAttribute("BLIKK_CharacterContext")
	local match = matchService:GetMatch(player)
	local room = roomService:GetRoom(player)
	local contextEligible = (context == "MovementLab" and not match and not room) or match ~= nil
	return character ~= nil and humanoid ~= nil and humanoid.Health > 0
		and root ~= nil and root:IsA("BasePart")
		and player:GetAttribute("BLIKK_GameplayReleased") == true
		and character:GetAttribute("BLIKK_GameplayReleased") == true
		and finiteInteger(spawnGeneration)
		and spawnGeneration == character:GetAttribute("BLIKK_SpawnGeneration")
		and player:GetAttribute("BLIKK_CharacterMatchId")
			== character:GetAttribute("BLIKK_CharacterMatchId")
		and contextEligible,
		character, humanoid, root
end

local function contextIdentity(player)
	return {
		Context = player:GetAttribute("BLIKK_CharacterContext"),
		RoomId = player:GetAttribute("BLIKK_CharacterRoomId"),
		MatchId = player:GetAttribute("BLIKK_CharacterMatchId"),
	}
end

local function sharesContext(player, identity)
	return player:GetAttribute("BLIKK_CharacterContext") == identity.Context
		and player:GetAttribute("BLIKK_CharacterRoomId") == identity.RoomId
		and player:GetAttribute("BLIKK_CharacterMatchId") == identity.MatchId
end

local function applyRecovery(character, humanoid, resource, amount)
	if resource == "Health" then
		local before = humanoid.Health
		local after = math.clamp(before + amount, 0, humanoid.MaxHealth)
		if after <= before then return 0 end
		humanoid.Health = after
		return after - before
	end

	local maximum = character:GetAttribute(FighterVitalsConfig.Attributes.MaximumArmour)
	local before = character:GetAttribute(FighterVitalsConfig.Attributes.Armour)
	if type(maximum) ~= "number" or type(before) ~= "number" then return 0 end
	local after = math.clamp(before + amount, 0, maximum)
	if after <= before then return 0 end
	character:SetAttribute(FighterVitalsConfig.Attributes.Armour, after)
	return after - before
end

local function hasRecoveryCapacity(character, humanoid, resource)
	if resource == "Health" then
		return humanoid.Health < humanoid.MaxHealth
	end
	local maximum = character:GetAttribute(FighterVitalsConfig.Attributes.MaximumArmour)
	local current = character:GetAttribute(FighterVitalsConfig.Attributes.Armour)
	return type(maximum) == "number" and type(current) == "number" and current < maximum
end

local function publishObserverEffect(character, root, resource, color)
	local highlight = Instance.new("Highlight")
	highlight.Name = "BLIKK" .. resource .. "RecoveryPulse"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = color
	highlight.FillTransparency = 0.35
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0.2
	highlight.Parent = character
	Debris:AddItem(highlight, RecoveryConfig.ObserverEffectSeconds)

	local attachment = Instance.new("Attachment")
	attachment.Name = "BLIKKRecoveryBurst"
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = resource .. "RecoveryParticles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 0.8
	emitter.Lifetime = NumberRange.new(0.2, 0.45)
	emitter.Speed = NumberRange.new(5, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(22)
	Debris:AddItem(attachment, RecoveryConfig.ObserverEffectSeconds + 0.25)
end

local function createPart(parent, name, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	part:SetAttribute("BLIKK_BaseTransparency", part.Transparency)
	part.Parent = parent
	return part
end

local function buildPickupModel(parent, name, resource, position, amount, color)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("BLIKK_RecoveryResource", resource)
	model:SetAttribute("BLIKK_RecoveryAmount", amount)
	model.Parent = parent

	local hitbox = createPart(
		model,
		"PickupCore",
		Vector3.new(RecoveryConfig.WorldPickupTouchRadiusStuds, RecoveryConfig.WorldPickupTouchRadiusStuds,
			RecoveryConfig.WorldPickupTouchRadiusStuds),
		CFrame.new(position),
		color,
		Enum.Material.Neon,
		0.42
	)
	hitbox.Shape = Enum.PartType.Ball
	hitbox.CanTouch = true
	hitbox.CanQuery = true
	local light = Instance.new("PointLight")
	light.Name = "RecoveryGlow"
	light.Color = color
	light.Brightness = 1.8
	light.Range = 13
	light.Parent = hitbox

	if resource == "Health" then
		createPart(model, "VitalMarkVertical", Vector3.new(0.52, 2.2, 0.52), CFrame.new(position),
			Color3.new(1, 1, 1), Enum.Material.Neon)
		createPart(model, "VitalMarkHorizontal", Vector3.new(2.2, 0.52, 0.52), CFrame.new(position),
			Color3.new(1, 1, 1), Enum.Material.Neon)
	else
		createPart(model, "AegisMark", Vector3.new(1.55, 1.55, 0.5),
			CFrame.new(position) * CFrame.Angles(0, 0, math.rad(45)), Color3.new(1, 1, 1), Enum.Material.Neon)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "AmbientRecoveryParticles"
	attachment.Parent = hitbox
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.7
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(0.5, 1.8)
	emitter.Rate = 7
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = attachment

	model.PrimaryPart = hitbox
	return model, hitbox
end

local function setPickupActive(model, active)
	model:SetAttribute("BLIKK_RecoveryAvailable", active)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if active
				then descendant:GetAttribute("BLIKK_BaseTransparency") or 0
				else 1
			descendant.CanTouch = active and descendant == model.PrimaryPart
			descendant.CanQuery = active and descendant == model.PrimaryPart
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = active
		elseif descendant:IsA("PointLight") or descendant:IsA("BillboardGui") then
			descendant.Enabled = active
		end
	end
end

local function playerFromTouch(hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character) or nil
end

local function updateInventoryAttributes(player, state)
	local character = player.Character
	if not character or character:GetAttribute("BLIKK_SpawnGeneration") ~= state.SpawnGeneration then return end
	character:SetAttribute(RecoveryConfig.Attributes.InventoryGeneration, state.SpawnGeneration)
	for _, itemId in RecoveryConfig.InventoryOrder do
		local definition = RecoveryConfig.Definitions[itemId]
		character:SetAttribute(RecoveryConfig.Attributes.CountPrefix .. itemId, state.Counts[itemId])
		character:SetAttribute(RecoveryConfig.Attributes.MaximumPrefix .. itemId, definition.StockPerLife)
	end
end

local function destroyDrops(state)
	if not state or not state.Drops then return end
	for model in state.Drops do
		if model.Parent then model:Destroy() end
	end
	table.clear(state.Drops)
end

local function resetLifeInventory(player, identity, character)
	if not identity or not finiteInteger(identity.SpawnGeneration) or player.Character ~= character then return end
	destroyDrops(states[player])
	local counts = {}
	for _, itemId in RecoveryConfig.InventoryOrder do
		counts[itemId] = RecoveryConfig.Definitions[itemId].StockPerLife
	end
	local state = {
		SpawnGeneration = identity.SpawnGeneration,
		Counts = counts,
		LastSequence = 0,
		NextUseAt = 0,
		Drops = {},
	}
	states[player] = state
	updateInventoryAttributes(player, state)
end

local function collectPickup(player, resource, amount, color, operation, itemId)
	local eligible, character, humanoid, root = isEligible(player)
	if not eligible then return false end
	local recovered = applyRecovery(character, humanoid, resource, amount)
	if recovered <= 0 then return false end
	publishObserverEffect(character, root, resource, color)
	sendResult(player, operation, true, nil, {
		ItemId = itemId,
		Resource = resource,
		Recovered = recovered,
	})
	return true
end

local function spawnDroppedPickup(owner, state, definition, root)
	local folder = Workspace:FindFirstChild("BLIKK_RecoveryDrops")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BLIKK_RecoveryDrops"
		folder.Parent = Workspace
	end
	local position = root.Position + root.CFrame.LookVector * 3.8 - Vector3.new(0, 1.5, 0)
	local model, hitbox = buildPickupModel(
		folder,
		definition.Id .. "Drop",
		definition.Resource,
		position,
		definition.Recovery,
		definition.Color
	)
	model:SetAttribute("BLIKK_RecoveryOwnerUserId", owner.UserId)
	state.Drops[model] = true
	model.Destroying:Connect(function()
		state.Drops[model] = nil
	end)
	local identity = contextIdentity(owner)
	local availableAt = os.clock() + RecoveryConfig.DroppedPickupClaimDelaySeconds
	local consumed = false
	local connection
	connection = hitbox.Touched:Connect(function(hit)
		if consumed or os.clock() < availableAt then return end
		local collector = playerFromTouch(hit)
		if not collector or not sharesContext(collector, identity) then return end
		if not collectPickup(collector, definition.Resource, definition.Recovery, definition.Color,
			"DroppedPickup", definition.Id) then return end
		consumed = true
		if connection then connection:Disconnect() end
		model:Destroy()
	end)
	Debris:AddItem(model, RecoveryConfig.DroppedPickupLifetimeSeconds)
end

local function handleIntent(player, payload)
	if type(payload) ~= "table" or payload.Operation ~= "Use"
		or type(payload.ItemId) ~= "string" or #payload.ItemId > 32
		or not finiteInteger(payload.Sequence) or payload.Sequence <= 0
		or not finiteInteger(payload.SpawnGeneration) then return end
	if not RateLimiter.Allow(requestLimiter, player, "RecoveryIntent", 1,
		RecoveryConfig.MaximumRequestsPerSecond) then return end

	local definition = RecoveryConfig.Definitions[payload.ItemId]
	local state = states[player]
	if not definition or not state or payload.Sequence <= state.LastSequence then return end
	state.LastSequence = payload.Sequence
	local eligible, character, humanoid, root = isEligible(player)
	if not eligible or payload.SpawnGeneration ~= state.SpawnGeneration
		or payload.SpawnGeneration ~= player:GetAttribute("BLIKK_SpawnGeneration") then
		sendResult(player, "Use", false, "STALE_LIFE", { ItemId = payload.ItemId })
		return
	end
	if state.Counts[payload.ItemId] <= 0 then
		sendResult(player, "Use", false, "EMPTY", { ItemId = payload.ItemId })
		return
	end
	local now = os.clock()
	if now < state.NextUseAt then
		sendResult(player, "Use", false, "COOLDOWN", { ItemId = payload.ItemId })
		return
	end
	-- Capacity is authoritative for both self-use and deployable patches. A full
	-- owner cannot spend inventory merely to create a pickup for later use.
	if not hasRecoveryCapacity(character, humanoid, definition.Resource) then
		sendResult(player, "Use", false, "RESOURCE_FULL", { ItemId = payload.ItemId })
		return
	end

	if definition.Delivery == "Self" then
		local recovered = applyRecovery(character, humanoid, definition.Resource, definition.Recovery)
		if recovered <= 0 then
			sendResult(player, "Use", false, "RESOURCE_FULL", { ItemId = payload.ItemId })
			return
		end
		state.Counts[payload.ItemId] -= 1
		state.NextUseAt = now + RecoveryConfig.UseDelaySeconds
		updateInventoryAttributes(player, state)
		publishObserverEffect(character, root, definition.Resource, definition.Color)
		sendResult(player, "Use", true, nil, {
			ItemId = payload.ItemId,
			Resource = definition.Resource,
			Recovered = recovered,
		})
		return
	end

	state.Counts[payload.ItemId] -= 1
	state.NextUseAt = now + RecoveryConfig.UseDelaySeconds
	updateInventoryAttributes(player, state)
	spawnDroppedPickup(player, state, definition, root)
	sendResult(player, "Use", true, nil, {
		ItemId = payload.ItemId,
		Resource = definition.Resource,
		Deployed = true,
		Recovered = 0,
	})
end

function RecoveryService:Init(remoteRegistry, resolvedMatchService, resolvedRoomService, characterLifecycleService)
	if isInitialised then return end
	isInitialised = true
	recoveryIntentRemote = remoteRegistry.RecoveryIntent
	recoveryResultRemote = remoteRegistry.RecoveryResult
	matchService = resolvedMatchService
	roomService = resolvedRoomService
	recoveryIntentRemote.OnServerEvent:Connect(handleIntent)
	characterLifecycleService.CharacterPrepared.Event:Connect(resetLifeInventory)
	characterLifecycleService.CharacterDied.Event:Connect(function(player)
		destroyDrops(states[player])
	end)
	Players.PlayerRemoving:Connect(function(player)
		destroyDrops(states[player])
		states[player] = nil
		RateLimiter.Clear(requestLimiter, player)
	end)
end

function RecoveryService:OnMapRebuilt()
	mapGeneration += 1
	local generation = mapGeneration
	disconnectWorldConnections()
	local root = Workspace:FindFirstChild(DistrictZeroConfig.Identity.WorkspaceRootName)
	local district = root and root:FindFirstChild(DistrictZeroConfig.Identity.ModelName)
	if not district then
		warn("[BLIKK RECOVERY] District Zero was unavailable while building recovery pickups.")
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RecoveryPickups"
	folder.Parent = district

	for _, placement in DistrictZeroConfig.RecoveryPickups do
		local color = if placement.Kind == "Health"
			then RecoveryConfig.Definitions.VitalPatch.Color
			else RecoveryConfig.Definitions.AegisPatch.Color
		local model, hitbox = buildPickupModel(
			folder,
			placement.Id,
			placement.Kind,
			placement.Position,
			RecoveryConfig.WorldPickupRecovery,
			color
		)
		model:SetAttribute("BLIKK_RecoveryIsWorldCore", true)
		local busy = false
		table.insert(worldConnections, hitbox.Touched:Connect(function(hit)
			if busy or generation ~= mapGeneration or model.Parent == nil
				or model:GetAttribute("BLIKK_RecoveryAvailable") == false then return end
			local player = playerFromTouch(hit)
			if not player then return end
			busy = true
			local collected = collectPickup(
				player,
				placement.Kind,
				RecoveryConfig.WorldPickupRecovery,
				color,
				"WorldPickup",
				placement.Id
			)
			if not collected then busy = false; return end
			setPickupActive(model, false)
			task.delay(RecoveryConfig.WorldPickupRespawnSeconds, function()
				if generation ~= mapGeneration or model.Parent == nil then return end
				setPickupActive(model, true)
				busy = false
			end)
		end))
		setPickupActive(model, true)
	end
end

return RecoveryService
