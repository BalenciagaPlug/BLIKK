local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.FirearmCombatConfig)
local FeedbackConfig = require(ReplicatedStorage.Shared.Combat.FirearmShotFeedbackConfig)

local FirearmShotEffects = {}
local Effects = {}
Effects.__index = Effects
local WeaponMuzzleEffect = {}
WeaponMuzzleEffect.__index = WeaponMuzzleEffect

local localPlayer = Players.LocalPlayer
local VALID_SLOTS = { Primary1 = true, Primary2 = true }
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function finiteNumber(value)
	return type(value) == "number" and value == value
		and value > -math.huge and value < math.huge
end

local function finiteInteger(value)
	return finiteNumber(value) and value % 1 == 0
end

local function finiteVector(value)
	return typeof(value) == "Vector3" and finiteNumber(value.X)
		and finiteNumber(value.Y) and finiteNumber(value.Z)
end

local function makeEffectPart(parent, name, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function makeSparkEmitter(parent)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparks"
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = SPARK_TEXTURE
	emitter.Color = ColorSequence.new(
		FeedbackConfig.PelletVisual.MuzzleColor,
		Color3.fromRGB(255, 157, 66)
	)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.035, 0.075)
	emitter.Speed = NumberRange.new(6, 11)
	emitter.Drag = 5
	emitter.SpreadAngle = Vector2.new(22, 22)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.075),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.05, 1)
	emitter.Parent = parent
	return emitter
end

local function makeSmokeEmitter(parent)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = SMOKE_TEXTURE
	emitter.Color = ColorSequence.new(
		Color3.fromRGB(175, 177, 181),
		Color3.fromRGB(88, 91, 96)
	)
	emitter.Lifetime = NumberRange.new(FeedbackConfig.Muzzle.SmokeLifetimeSeconds)
	emitter.Speed = NumberRange.new(0.8, 1.5)
	emitter.Drag = 2
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.10),
		NumberSequenceKeypoint.new(0.4, 0.22),
		NumberSequenceKeypoint.new(1, 0.34),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.38),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
	return emitter
end

function WeaponMuzzleEffect:Disable()
	if self.IsDestroyed then return end
	self.Serial += 1
	self.FlashPart.Transparency = 1
	self.Light.Enabled = false
	self.Sparks:Clear()
	self.Smoke:Clear()
end

function WeaponMuzzleEffect:Trigger(isCurrent)
	if self.IsDestroyed then return end
	self.Serial += 1
	local serial = self.Serial
	self.FlashPart.Color = FeedbackConfig.PelletVisual.MuzzleColor
	self.FlashPart.Transparency = 0.05
	self.Light.Enabled = true
	self.Sparks:Emit(FeedbackConfig.Muzzle.SparkCount)
	task.delay(FeedbackConfig.Muzzle.FlashLifetimeSeconds, function()
		if self.IsDestroyed or self.Serial ~= serial or not isCurrent() then return end
		self.FlashPart.Transparency = 1
		self.Light.Enabled = false
		self.Smoke:Emit(FeedbackConfig.Muzzle.SmokeCount)
		task.delay(FeedbackConfig.Muzzle.SmokeLifetimeSeconds, function()
			if self.IsDestroyed or self.Serial ~= serial or not isCurrent() then return end
			self.Smoke:Clear()
		end)
	end)
end

function WeaponMuzzleEffect:Destroy()
	if self.IsDestroyed then return end
	self:Disable()
	self.IsDestroyed = true
	self.Light:Destroy()
	self.Sparks:Destroy()
	self.Smoke:Destroy()
	self.FlashPart:Destroy()
end

local function createPellet(folder, groupIndex, pelletIndex)
	local carrier = makeEffectPart(
		folder,
		string.format("Shot%dPellet%d", groupIndex, pelletIndex),
		Vector3.new(0.05, 0.05, 0.05)
	)
	local tail = Instance.new("Attachment")
	tail.Name = "Tail"
	tail.Parent = carrier
	local head = Instance.new("Attachment")
	head.Name = "Head"
	head.Parent = carrier
	local beam = Instance.new("Beam")
	beam.Name = "Streak"
	beam.Attachment0 = tail
	beam.Attachment1 = head
	beam.Color = ColorSequence.new(
		FeedbackConfig.PelletVisual.TailColor,
		FeedbackConfig.PelletVisual.MuzzleColor
	)
	beam.Transparency = NumberSequence.new(0.55, 0.12)
	beam.Width0 = FeedbackConfig.PelletVisual.WidthEndStuds
	beam.Width1 = FeedbackConfig.PelletVisual.WidthStartStuds
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = carrier
	return {
		Carrier = carrier,
		Tail = tail,
		Head = head,
		Beam = beam,
		Direction = Vector3.zAxis,
		Distance = 0,
		LifetimeSeconds = 0,
	}
end

local function createGroup(folder, groupIndex)
	local groupFolder = Instance.new("Folder")
	groupFolder.Name = "Shot" .. groupIndex
	groupFolder.Parent = folder
	local flash = makeEffectPart(
		groupFolder,
		"RemoteMuzzleFlash",
		Vector3.one * FeedbackConfig.Muzzle.RemoteFlashSizeStuds
	)
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = FeedbackConfig.PelletVisual.MuzzleColor
	local flashAttachment = Instance.new("Attachment")
	flashAttachment.Name = "FlashAttachment"
	flashAttachment.Parent = flash
	local light = Instance.new("PointLight")
	light.Name = "FlashLight"
	light.Color = FeedbackConfig.PelletVisual.MuzzleColor
	light.Brightness = FeedbackConfig.Muzzle.FlashLightBrightness
	light.Range = FeedbackConfig.Muzzle.FlashLightRangeStuds
	light.Shadows = false
	light.Enabled = false
	light.Parent = flashAttachment
	local pellets = table.create(CombatConfig.PelletsPerShot)
	for pelletIndex = 1, CombatConfig.PelletsPerShot do
		pellets[pelletIndex] = createPellet(groupFolder, groupIndex, pelletIndex)
	end
	return {
		Active = false,
		StartedAt = 0,
		EndsAt = 0,
		Origin = Vector3.zero,
		Shooter = nil,
		ShooterUserId = 0,
		SpawnGeneration = 0,
		Sequence = 0,
		Pellets = pellets,
		Flash = flash,
		Light = light,
		Sparks = makeSparkEmitter(flashAttachment),
		Smoke = makeSmokeEmitter(flashAttachment),
		FlashEndsAt = 0,
		SmokeEmitted = false,
		ShowsRemoteFlash = false,
	}
end

local function deactivateGroup(group)
	group.Active = false
	group.Light.Enabled = false
	group.Flash.Transparency = 1
	group.Sparks:Clear()
	group.Smoke:Clear()
	for _, pellet in group.Pellets do pellet.Beam.Enabled = false end
end

local function validatePayload(payload)
	if type(payload) ~= "table" or not finiteInteger(payload.ShooterUserId)
		or payload.ShooterUserId <= 0 or not finiteInteger(payload.SpawnGeneration)
		or not finiteInteger(payload.Sequence) or payload.Sequence <= 0
		or not VALID_SLOTS[payload.Slot] or not finiteVector(payload.Origin)
		or type(payload.Impacts) ~= "table" then return false end
	local count = 0
	for key, endpoint in payload.Impacts do
		if not finiteInteger(key) or key < 1 or key > CombatConfig.PelletsPerShot
			or not finiteVector(endpoint)
			or (endpoint - payload.Origin).Magnitude
				> CombatConfig.MaximumRangeStuds
					+ FeedbackConfig.Payload.EndpointRangeToleranceStuds then return false end
		count += 1
	end
	return count == CombatConfig.PelletsPerShot
end

function Effects:_pruneLocalOrigins(now)
	while self.LocalOriginOrder[1] do
		local record = self.LocalOriginOrder[1]
		if record.ExpiresAt > now
			and #self.LocalOriginOrder <= FeedbackConfig.Payload.LocalOriginCacheCapacity then break end
		table.remove(self.LocalOriginOrder, 1)
		if self.LocalOrigins[record.Sequence] == record then self.LocalOrigins[record.Sequence] = nil end
	end
end

function Effects:_consumeLocalOrigin(sequence, spawnGeneration, now)
	self:_pruneLocalOrigins(now)
	local record = self.LocalOrigins[sequence]
	if not record or record.SpawnGeneration ~= spawnGeneration or record.ExpiresAt <= now then return nil end
	self.LocalOrigins[sequence] = nil
	for index, candidate in self.LocalOriginOrder do
		if candidate == record then table.remove(self.LocalOriginOrder, index); break end
	end
	return record.Origin
end

function Effects:_startShot(payload)
	if not validatePayload(payload) then return end
	local shooter = Players:GetPlayerByUserId(payload.ShooterUserId)
	local shooterCharacter = shooter and shooter.Character
	if not shooter or not shooterCharacter
		or shooter:GetAttribute("BLIKK_SpawnGeneration") ~= payload.SpawnGeneration
		or shooterCharacter:GetAttribute("BLIKK_SpawnGeneration") ~= payload.SpawnGeneration then return end
	local now = os.clock()
	local origin = payload.Origin
	if shooter == localPlayer then
		origin = self:_consumeLocalOrigin(payload.Sequence, payload.SpawnGeneration, now) or origin
	end

	local group = self.Groups[self.NextGroupIndex]
	self.NextGroupIndex = self.NextGroupIndex % #self.Groups + 1
	deactivateGroup(group)
	group.Active = true
	group.StartedAt = now
	group.Origin = origin
	group.Shooter = shooter
	group.ShooterUserId = payload.ShooterUserId
	group.SpawnGeneration = payload.SpawnGeneration
	group.Sequence = payload.Sequence
	group.ShowsRemoteFlash = shooter ~= localPlayer
	group.SmokeEmitted = false
	local longestLifetime = 0
	for index = 1, CombatConfig.PelletsPerShot do
		local pellet = group.Pellets[index]
		local offset = payload.Impacts[index] - origin
		pellet.Distance = offset.Magnitude
		pellet.Direction = if pellet.Distance > 0.0001 then offset.Unit else Vector3.zAxis
		pellet.LifetimeSeconds = math.clamp(
			pellet.Distance / FeedbackConfig.PelletVisual.SpeedStudsPerSecond,
			FeedbackConfig.PelletVisual.MinimumLifetimeSeconds,
			FeedbackConfig.PelletVisual.MaximumLifetimeSeconds
		)
		longestLifetime = math.max(longestLifetime, pellet.LifetimeSeconds)
		pellet.Carrier.CFrame = CFrame.new(origin)
		pellet.Tail.Position = Vector3.zero
		pellet.Head.Position = Vector3.zero
		pellet.Beam.Enabled = true
	end
	group.FlashEndsAt = now + FeedbackConfig.Muzzle.FlashLifetimeSeconds
	group.EndsAt = now + longestLifetime
	if group.ShowsRemoteFlash then
		group.Flash.CFrame = CFrame.new(origin)
		group.Flash.Transparency = 0.05
		group.Light.Enabled = true
		group.Sparks:Emit(FeedbackConfig.Muzzle.SparkCount)
		group.EndsAt = math.max(
			group.EndsAt,
			group.FlashEndsAt + FeedbackConfig.Muzzle.SmokeLifetimeSeconds
		)
	end
end

function Effects:_update()
	local now = os.clock()
	self:_pruneLocalOrigins(now)
	for _, group in self.Groups do
		if not group.Active then continue end
		local shooterCharacter = group.Shooter and group.Shooter.Character
		if not group.Shooter or group.Shooter.Parent ~= Players or not shooterCharacter
			or group.Shooter:GetAttribute("BLIKK_SpawnGeneration") ~= group.SpawnGeneration
			or shooterCharacter:GetAttribute("BLIKK_SpawnGeneration") ~= group.SpawnGeneration then
			deactivateGroup(group)
			continue
		end
		local elapsed = now - group.StartedAt
		for _, pellet in group.Pellets do
			if elapsed >= pellet.LifetimeSeconds then
				pellet.Beam.Enabled = false
				continue
			end
			local headDistance = math.min(
				pellet.Distance,
				elapsed * FeedbackConfig.PelletVisual.SpeedStudsPerSecond
			)
			local tailDistance = math.max(0, headDistance - FeedbackConfig.PelletVisual.TrailLengthStuds)
			local headPosition = group.Origin + pellet.Direction * headDistance
			local tailPosition = group.Origin + pellet.Direction * tailDistance
			pellet.Carrier.CFrame = CFrame.new(headPosition)
			pellet.Head.Position = Vector3.zero
			pellet.Tail.Position = tailPosition - headPosition
		end
		if group.ShowsRemoteFlash and now >= group.FlashEndsAt then
			group.Light.Enabled = false
			group.Flash.Transparency = 1
			if not group.SmokeEmitted then
				group.SmokeEmitted = true
				group.Smoke:Emit(FeedbackConfig.Muzzle.SmokeCount)
			end
		end
		if now >= group.EndsAt then deactivateGroup(group) end
	end
end

function Effects:RememberLocalOrigin(sequence, spawnGeneration, origin)
	if self.IsDestroyed or not finiteInteger(sequence) or not finiteInteger(spawnGeneration)
		or not finiteVector(origin) then return end
	local now = os.clock()
	self:_pruneLocalOrigins(now)
	local record = {
		Sequence = sequence,
		SpawnGeneration = spawnGeneration,
		Origin = origin,
		ExpiresAt = now + FeedbackConfig.Payload.LocalOriginCacheLifetimeSeconds,
	}
	self.LocalOrigins[sequence] = record
	table.insert(self.LocalOriginOrder, record)
	self:_pruneLocalOrigins(now)
end

function Effects:ClearLocalShooter()
	table.clear(self.LocalOrigins)
	table.clear(self.LocalOriginOrder)
	for _, group in self.Groups do
		if group.ShooterUserId == localPlayer.UserId then deactivateGroup(group) end
	end
end

function Effects:Destroy()
	if self.IsDestroyed then return end
	self.IsDestroyed = true
	self.RemoteConnection:Disconnect()
	self.UpdateConnection:Disconnect()
	self.Folder:Destroy()
	table.clear(self.Groups)
	table.clear(self.LocalOrigins)
	table.clear(self.LocalOriginOrder)
end

function FirearmShotEffects.Create(shotRemote)
	assert(shotRemote and shotRemote:IsA("RemoteEvent"), "FirearmShotEffects requires FirearmShot")
	local folder = Instance.new("Folder")
	folder.Name = "BLIKK_FirearmShotEffects"
	folder:SetAttribute("BLIKK_PresentationOnly", true)
	folder.Parent = Workspace
	local groups = table.create(FeedbackConfig.PelletVisual.PoolShotCapacity)
	for groupIndex = 1, FeedbackConfig.PelletVisual.PoolShotCapacity do
		groups[groupIndex] = createGroup(folder, groupIndex)
	end
	local self = setmetatable({
		Folder = folder,
		Groups = groups,
		NextGroupIndex = 1,
		LocalOrigins = {},
		LocalOriginOrder = {},
		IsDestroyed = false,
		RemoteConnection = nil,
		UpdateConnection = nil,
	}, Effects)
	self.RemoteConnection = shotRemote.OnClientEvent:Connect(function(payload)
		if not self.IsDestroyed then self:_startShot(payload) end
	end)
	self.UpdateConnection = RunService.Heartbeat:Connect(function()
		if not self.IsDestroyed then self:_update() end
	end)
	return self
end

function FirearmShotEffects.CreateWeaponMuzzleEffect(model, flashPart)
	local receiver = model and model.PrimaryPart
	local attachment = receiver and receiver:FindFirstChild("MuzzleAttachment")
	assert(receiver and attachment and attachment:IsA("Attachment")
		and flashPart and flashPart:IsA("BasePart"), "B-8 muzzle effect geometry is unavailable")
	flashPart.Transparency = 1
	local centralFlash = Instance.new("Part")
	centralFlash.Name = "BLIKK_LocalMuzzleFlash"
	centralFlash.Size = flashPart.Size
	centralFlash.CFrame = attachment.WorldCFrame
	centralFlash.Color = FeedbackConfig.PelletVisual.MuzzleColor
	centralFlash.Material = Enum.Material.Neon
	centralFlash.Shape = Enum.PartType.Ball
	centralFlash.Anchored = false
	centralFlash.Massless = true
	centralFlash.CanCollide = false
	centralFlash.CanQuery = false
	centralFlash.CanTouch = false
	centralFlash.CastShadow = false
	centralFlash.Transparency = 1
	centralFlash.Parent = model
	local flashWeld = Instance.new("WeldConstraint")
	flashWeld.Name = "BLIKK_LocalMuzzleFlashWeld"
	flashWeld.Part0 = receiver
	flashWeld.Part1 = centralFlash
	flashWeld.Parent = centralFlash
	local light = Instance.new("PointLight")
	light.Name = "BLIKK_LocalMuzzleLight"
	light.Color = FeedbackConfig.PelletVisual.MuzzleColor
	light.Brightness = FeedbackConfig.Muzzle.FlashLightBrightness
	light.Range = FeedbackConfig.Muzzle.FlashLightRangeStuds
	light.Shadows = false
	light.Enabled = false
	light.Parent = attachment
	return setmetatable({
		FlashPart = centralFlash,
		Light = light,
		Sparks = makeSparkEmitter(attachment),
		Smoke = makeSmokeEmitter(attachment),
		Serial = 0,
		IsDestroyed = false,
	}, WeaponMuzzleEffect)
end

return FirearmShotEffects
