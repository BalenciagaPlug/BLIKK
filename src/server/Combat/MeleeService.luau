local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Combat.MeleeCombatConfig)
local CombatDamageResolver = require(script.Parent.CombatDamageResolver)

local MeleeService = {}
local states = {}
local matchService
local roomService
local practiceDummyService
local firearmService
local techniqueService
local resultRemote
local swingRemote
local activeTossFloats = {}

local function finiteInteger(value)
	return type(value) == "number" and value == value and value > -math.huge
		and value < math.huge and value % 1 == 0
end

local function finiteVector3(value)
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < math.huge and math.abs(value.Y) < math.huge
		and math.abs(value.Z) < math.huge
end

local function validatedAim(root, originValue, directionValue)
	if not finiteVector3(originValue) or not finiteVector3(directionValue) then return nil end
	local magnitude = directionValue.Magnitude
	local validation = Config.AimValidation
	if magnitude < validation.MinimumDirectionMagnitude
		or magnitude > validation.MaximumDirectionMagnitude then return nil end
	if (originValue - root.Position).Magnitude > validation.MaximumOriginDistanceFromRootStuds then
		return nil
	end
	local direction = directionValue.Unit
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	local flatFacing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flatDirection.Magnitude < 0.001 or flatFacing.Magnitude < 0.001
		or flatFacing.Unit:Dot(flatDirection.Unit) < validation.MinimumFacingDot then return nil end
	local pitch = math.deg(math.asin(math.clamp(direction.Y, -1, 1)))
	if pitch < validation.MinimumPitchDegrees or pitch > validation.MaximumPitchDegrees then return nil end
	return originValue, direction
end

local function resetPlayer(player)
	states[player] = {
		Sequence = 0,
		BlockSequence = 0,
		AltSequence = 0,
		NextSlashAt = 0,
		NextAltAt = 0,
		WindowAt = 0,
		WindowCount = 0,
		SlashToken = 0,
		AltToken = 0,
		CancelledSequence = 0,
		SlashAcceptedAt = -math.huge,
		GuardCharacter = nil,
		AirTossSequence = 0,
		AirTossStartedAt = -math.huge,
		AirTossExpiresAt = -math.huge,
		AirTossCharacter = nil,
		AirTossRecovered = false,
	}
end

local function isEligible(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local context = player:GetAttribute("BLIKK_CharacterContext")
	local spawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
	local contextEligible = context == "MovementLab" or matchService:GetMatch(player) ~= nil
	return character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")
		and player:GetAttribute("BLIKK_GameplayReleased") == true
		and character:GetAttribute("BLIKK_GameplayReleased") == true
		and finiteInteger(spawnGeneration)
		and spawnGeneration == character:GetAttribute("BLIKK_SpawnGeneration")
		and player:GetAttribute("BLIKK_CharacterMatchId")
			== character:GetAttribute("BLIKK_CharacterMatchId")
		and contextEligible,
		character, humanoid, root
end

local function rateAllowed(state, now)
	if now - state.WindowAt >= 1 then state.WindowAt = now; state.WindowCount = 0 end
	state.WindowCount += 1
	return state.WindowCount <= Config.MaximumRequestsPerSecond
end

local function resolvePlayerTarget(part, attacker)
	local model = part and part:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local victim = model and Players:GetPlayerFromCharacter(model)
	local attackerTeam = attacker:GetAttribute("BLIKK_TeamId")
	local victimTeam = victim and victim:GetAttribute("BLIKK_TeamId")
	if not humanoid or not victim or victim == attacker or humanoid.Health <= 0
		or attackerTeam and attackerTeam == victimTeam
		or victim:GetAttribute("BLIKK_GameplayReleased") ~= true then return nil end
	return {
		Kind = "Player",
		TargetId = "P:" .. tostring(victim.UserId),
		Humanoid = humanoid,
		Player = victim,
		Model = model,
	}
end

local function resolveTarget(part, attacker)
	local target = resolvePlayerTarget(part, attacker)
		or practiceDummyService:ResolveTarget(part, attacker)
	if target and not target.Model then target.Model = target.Humanoid.Parent end
	return target
end

local function targetPosition(target)
	local model = target.Model
	local upperTorso = model and model:FindFirstChild("UpperTorso", true)
	local root = model and model:FindFirstChild("HumanoidRootPart", true)
	local part = if upperTorso and upperTorso:IsA("BasePart") then upperTorso else root
	return if part and part:IsA("BasePart") then part.Position else nil
end

local function isInAimArc(origin, aimDirection, position, hitVolume)
	local delta = position - origin
	if math.abs(delta.Y) > hitVolume.MaximumVerticalDifferenceStuds then return false end
	if delta.Magnitude <= 0 or delta.Magnitude > hitVolume.MaximumRangeStuds then
		return false
	end
	return aimDirection:Dot(delta.Unit) >= math.cos(math.rad(hitVolume.HalfAngleDegrees))
end

local function hasLineOfSight(attackerCharacter, origin, target, position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attackerCharacter }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(origin, position - origin, params)
	return not hit or hit.Instance:IsDescendantOf(target.Model)
end

local function collectArcTargets(player, character, root, hitVolume, maximumTargets, aimDirection)
	local sightOrigin = root.Position + Vector3.new(0, hitVolume.UpOffsetStuds, 0)
	local queryCFrame = CFrame.lookAt(sightOrigin, sightOrigin + aimDirection)
		* CFrame.new(0, 0, -hitVolume.ForwardOffsetStuds)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local parts = Workspace:GetPartBoundsInBox(queryCFrame, hitVolume.SizeStuds, params)
	local seenHumanoids = {}
	local targets = {}
	for _, part in parts do
		if #targets >= maximumTargets then break end
		local target = resolveTarget(part, player)
		if not target or seenHumanoids[target.Humanoid] then continue end
		seenHumanoids[target.Humanoid] = true
		local position = targetPosition(target)
		if position and isInAimArc(sightOrigin, aimDirection, position, hitVolume)
			and hasLineOfSight(character, sightOrigin, target, position) then
			target.WorldPosition = position
			table.insert(targets, target)
		end
	end
	table.sort(targets, function(left, right) return left.TargetId < right.TargetId end)
	return targets
end

local function rigAttachment(part, name)
	local attachment = part and part:FindFirstChild(name)
	return if attachment and attachment:IsA("Attachment") then attachment else nil
end

local function measureStrikeGeometry(character, root)
	local hitVolume = Config.HitVolume
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local rightShoulder = rigAttachment(torso, "RightShoulderRigAttachment")
	local leftShoulder = rigAttachment(torso, "LeftShoulderRigAttachment")
	local shoulderSpan
	local strikeOrigin
	if rightShoulder and leftShoulder then
		strikeOrigin = rightShoulder.WorldPosition
		shoulderSpan = (rightShoulder.WorldPosition - leftShoulder.WorldPosition).Magnitude
	elseif torso and torso:IsA("BasePart") then
		shoulderSpan = torso.Size.X
		strikeOrigin = torso.Position
			+ torso.CFrame.RightVector * (shoulderSpan * 0.5)
			+ torso.CFrame.UpVector * (torso.Size.Y * 0.35)
	else
		shoulderSpan = hitVolume.MinimumShoulderSpanStuds
		strikeOrigin = root.Position
			+ root.CFrame.RightVector * (shoulderSpan * 0.5)
			+ root.CFrame.UpVector * 1.35
	end

	local upperArm = character:FindFirstChild("RightUpperArm")
	local lowerArm = character:FindFirstChild("RightLowerArm")
	local hand = character:FindFirstChild("RightHand")
	local r6Arm = character:FindFirstChild("Right Arm")
	local armReach
	if upperArm and upperArm:IsA("BasePart")
		and lowerArm and lowerArm:IsA("BasePart")
		and hand and hand:IsA("BasePart") then
		armReach = upperArm.Size.Y + lowerArm.Size.Y + hand.Size.Y * 0.5
	elseif r6Arm and r6Arm:IsA("BasePart") then
		armReach = r6Arm.Size.Y
	else
		armReach = hitVolume.MinimumWeaponArmReachStuds
	end

	shoulderSpan = math.clamp(
		shoulderSpan * hitVolume.ShoulderWidthScale,
		hitVolume.MinimumShoulderSpanStuds,
		hitVolume.MaximumShoulderSpanStuds
	)
	armReach = math.clamp(
		armReach,
		hitVolume.MinimumWeaponArmReachStuds,
		hitVolume.MaximumWeaponArmReachStuds
	)
	return {
		Origin = strikeOrigin,
		WidthStuds = shoulderSpan,
		HalfWidthStuds = shoulderSpan * 0.5,
		ReachStuds = armReach + hitVolume.KatanaTipReachFromGripStuds,
	}
end

local function crosshairResult(character, aimOrigin, aimDirection)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.IgnoreWater = true
	return Workspace:Raycast(
		aimOrigin,
		aimDirection * Config.WallContact.MaximumRayDistanceStuds,
		rayParams
	)
end

local function strikeDirectionTowardCrosshair(geometry, aimOrigin, aimDirection, crosshairHit)
	local aimPoint = if crosshairHit
		then crosshairHit.Position
		else aimOrigin + aimDirection * Config.WallContact.MaximumRayDistanceStuds
	local delta = aimPoint - geometry.Origin
	return if delta.Magnitude > 0.001 then delta.Unit else aimDirection
end

local function strikeMetrics(origin, direction, position)
	local delta = position - origin
	local depth = delta:Dot(direction)
	local closestPoint = origin + direction * depth
	return depth, (position - closestPoint).Magnitude
end

local function collectStrikeTargets(
	player,
	character,
	aimOrigin,
	strikeGeometry,
	strikeDirection,
	crosshairHit
)
	local hitVolume = Config.HitVolume
	local pointBlankTolerance = hitVolume.PointBlankRearToleranceStuds
	local corridorLength = strikeGeometry.ReachStuds + pointBlankTolerance
	local corridorCenterDepth = (strikeGeometry.ReachStuds - pointBlankTolerance) * 0.5
	local corridorCFrame = CFrame.lookAt(
		strikeGeometry.Origin,
		strikeGeometry.Origin + strikeDirection
	) * CFrame.new(0, 0, -corridorCenterDepth)
	local padding = hitVolume.BroadPhasePaddingStuds
	local corridorSize = Vector3.new(
		strikeGeometry.WidthStuds + padding * 2,
		strikeGeometry.WidthStuds + padding * 2,
		corridorLength + padding * 2
	)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local parts = Workspace:GetPartBoundsInBox(corridorCFrame, corridorSize, params)
	if crosshairHit then table.insert(parts, 1, crosshairHit.Instance) end

	local directTarget = crosshairHit and resolveTarget(crosshairHit.Instance, player) or nil
	local directHumanoid = directTarget and directTarget.Humanoid or nil
	local seenHumanoids = {}
	local targets = {}
	for _, part in parts do
		local target = resolveTarget(part, player)
		if not target or seenHumanoids[target.Humanoid] then continue end
		seenHumanoids[target.Humanoid] = true
		local position = if target.Humanoid == directHumanoid
			then crosshairHit.Position
			else targetPosition(target)
		if not position then continue end
		local depth, crosshairMiss = strikeMetrics(
			strikeGeometry.Origin,
			strikeDirection,
			position
		)
		if depth < -pointBlankTolerance or depth > strikeGeometry.ReachStuds
			or crosshairMiss > strikeGeometry.HalfWidthStuds then continue end
		if not hasLineOfSight(character, aimOrigin, target, position)
			or not hasLineOfSight(character, strikeGeometry.Origin, target, position) then continue end
		target.WorldPosition = position
		target.CrosshairMissStuds = crosshairMiss
		target.AimDepthStuds = depth
		table.insert(targets, target)
	end
	table.sort(targets, function(left, right)
		if left.CrosshairMissStuds ~= right.CrosshairMissStuds then
			return left.CrosshairMissStuds < right.CrosshairMissStuds
		end
		if left.AimDepthStuds ~= right.AimDepthStuds then
			return left.AimDepthStuds < right.AimDepthStuds
		end
		return left.TargetId < right.TargetId
	end)
	while #targets > Config.MaximumTargetsPerSwing do table.remove(targets) end
	return targets
end

local function resolveWallContact(character, strikeOrigin, strikeDirection, maximumReach)
	local contact = Config.WallContact
	local exclusions = { character }
	local origin = strikeOrigin
	local remainingDistance = maximumReach
	for _ = 1, contact.MaximumSkippedParts do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclusions
		params.IgnoreWater = true
		local result = Workspace:Raycast(origin, strikeDirection * remainingDistance, params)
		if not result then return nil end
		local travelled = (result.Position - strikeOrigin).Magnitude
		local instance = result.Instance
		local humanoidModel = instance:FindFirstAncestorOfClass("Model")
		if humanoidModel and humanoidModel:FindFirstChildOfClass("Humanoid") then return nil end
		if instance:IsA("BasePart") and instance.CanCollide
			and instance.Transparency < contact.MaximumSurfaceTransparency
			and math.abs(result.Normal.Y) <= contact.MaximumSurfaceNormalY then
			return result
		end
		table.insert(exclusions, instance)
		remainingDistance = maximumReach - travelled
		if remainingDistance <= 0 then return nil end
		origin = result.Position + strikeDirection * 0.02
	end
	return nil
end

local function publishAcceptedPresentation(player, payload)
	local match = matchService:GetMatch(player)
	local room = roomService:GetRoom(player)
	if player:GetAttribute("BLIKK_CharacterContext") == "MovementLab" and not match and not room then
		for _, recipient in Players:GetPlayers() do
			if recipient:GetAttribute("BLIKK_CharacterContext") == "MovementLab"
				and recipient:GetAttribute("BLIKK_GameplayReleased") == true
				and not matchService:GetMatch(recipient) and not roomService:GetRoom(recipient) then
				swingRemote:FireClient(recipient, payload)
			end
		end
		return
	end
	if not match or not room or match.RoomId ~= room.RoomId or not match.Players[player] then
		swingRemote:FireClient(player, payload)
		return
	end
	for recipient in room.Members do
		if recipient.Parent == Players then swingRemote:FireClient(recipient, payload) end
	end
end

local function sendResult(player, sequence, hitResults)
	resultRemote:FireClient(player, {
		Operation = "Melee",
		Accepted = true,
		Sequence = sequence,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
		HitResults = hitResults,
	})
end

local function sendActionResult(player, operation, sequence, extra)
	local payload = {
		Operation = operation,
		Accepted = true,
		Sequence = sequence,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
	}
	for key, value in extra or {} do payload[key] = value end
	resultRemote:FireClient(player, payload)
end

local function sendActionRejection(player, operation, sequence)
	resultRemote:FireClient(player, {
		Operation = operation,
		Accepted = false,
		Sequence = sequence,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
	})
end

local function clearGuard(state)
	local guardCharacter = state and state.GuardCharacter
	if guardCharacter and guardCharacter.Parent then
		guardCharacter:SetAttribute(Config.Guard.AttributeName, false)
	end
	if state then state.GuardCharacter = nil end
end

local function clearAirToss(state)
	local tossCharacter = state and state.AirTossCharacter
	if tossCharacter and tossCharacter.Parent then
		tossCharacter:SetAttribute("BLIKK_AirTossActive", false)
	end
	if state then
		state.AirTossStartedAt = -math.huge
		state.AirTossExpiresAt = -math.huge
		state.AirTossCharacter = nil
	end
end

local function beginAirToss(targetPlayer, targetCharacter, now)
	local state = states[targetPlayer]
	if not state then resetPlayer(targetPlayer); state = states[targetPlayer] end
	clearAirToss(state)
	state.AirTossSequence += 1
	state.AirTossStartedAt = now + Config.AltFire.SafeFallWindowOpenSeconds
	state.AirTossExpiresAt = now + Config.AltFire.SafeFallWindowCloseSeconds
	state.AirTossCharacter = targetCharacter
	state.AirTossRecovered = false
	targetCharacter:SetAttribute("BLIKK_AirTossActive", true)
	targetCharacter:SetAttribute("BLIKK_AirTossSequence", state.AirTossSequence)
	targetCharacter:SetAttribute("BLIKK_AirTossStartedAt", now)
	targetCharacter:SetAttribute("BLIKK_AirTossExpiresAt", state.AirTossExpiresAt)
	local sequence = state.AirTossSequence
	task.delay(Config.AltFire.SafeFallWindowCloseSeconds + 0.06, function()
		if states[targetPlayer] == state and state.AirTossSequence == sequence
			and state.AirTossCharacter == targetCharacter then clearAirToss(state) end
	end)
end

local function clearTossFloat(model)
	local record = activeTossFloats[model]
	if not record then return end
	activeTossFloats[model] = nil
	if model.Parent then model:SetAttribute("BLIKK_AirTossFloatActive", false) end
	if record.Force and record.Force.Parent then record.Force:Destroy() end
	if record.Attachment and record.Attachment.Parent then record.Attachment:Destroy() end
end

local function beginTossFloat(model, humanoid, root, now)
	clearTossFloat(model)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BLIKK_AirTossFloatAttachment"
	attachment.Parent = root
	local force = Instance.new("VectorForce")
	force.Name = "BLIKK_AirTossFloatForce"
	force.Attachment0 = attachment
	force.ApplyAtCenterOfMass = true
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Force = Vector3.zero
	force.Parent = root
	model:SetAttribute("BLIKK_AirTossFloatActive", true)
	activeTossFloats[model] = {
		Humanoid = humanoid,
		Root = root,
		Attachment = attachment,
		Force = force,
		StartedAt = now,
		ExpiresAt = now + Config.AltFire.Float.MaximumDurationSeconds,
	}
end

local function stepTossFloats()
	local now = os.clock()
	local float = Config.AltFire.Float
	for model, record in activeTossFloats do
		local humanoid, root, force = record.Humanoid, record.Root, record.Force
		if now >= record.ExpiresAt or not model.Parent or not humanoid.Parent
			or humanoid.Health <= 0 or not root.Parent or root.Anchored or not force.Parent
			or (now - record.StartedAt >= float.MinimumAirborneCheckDelaySeconds
				and humanoid.FloorMaterial ~= Enum.Material.Air) then
			clearTossFloat(model)
			continue
		end
		local vertical = root.AssemblyLinearVelocity.Y
		local gravityScale = 1
		if vertical <= float.AscentWindowStudsPerSecond
			and vertical >= float.DescentWindowStudsPerSecond then
			if vertical >= 0 then
				gravityScale = float.GravityScaleAtApex + (1 - float.GravityScaleAtApex)
					* math.clamp(vertical / math.max(float.AscentWindowStudsPerSecond, 0.001), 0, 1)
			else
				gravityScale = float.GravityScaleAtApex
					+ (float.GravityScaleAtDescentExit - float.GravityScaleAtApex)
						* math.clamp(vertical / math.min(float.DescentWindowStudsPerSecond, -0.001), 0, 1)
			end
		end
		force.Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity * (1 - gravityScale), 0)
	end
end

local function beginGuard(state, character, sequence, now)
	clearGuard(state)
	state.GuardCharacter = character
	character:SetAttribute(Config.Guard.AttributeName, true)
	character:SetAttribute(Config.Guard.SequenceAttributeName, sequence)
	character:SetAttribute(Config.Guard.StartedAtAttributeName, now)
end

local function publishSlashImpact(player, spawnGeneration, sequence, variant, outcome, position, normal)
	publishAcceptedPresentation(player, {
		Operation = "Impact",
		ShooterUserId = player.UserId,
		SpawnGeneration = spawnGeneration,
		Sequence = sequence,
		Variant = variant,
		Outcome = outcome,
		WorldPosition = position,
		SurfaceNormal = normal,
	})
end

local function targetContactNormal(root, position, aimDirection)
	local delta = root.Position - position
	return if delta.Magnitude > 0.001 then delta.Unit else -aimDirection
end

local function resolveImpact(
	player,
	state,
	character,
	spawnGeneration,
	sequence,
	variant,
	token,
	aimOriginOffset,
	aimDirection
)
	if states[player] ~= state or state.SlashToken ~= token or player.Character ~= character
		or player:GetAttribute("BLIKK_SpawnGeneration") ~= spawnGeneration
		or not firearmService:IsMeleeEquipped(player) then return end
	local eligible, currentCharacter, _, root = isEligible(player)
	if not eligible or currentCharacter ~= character then return end
	local aimOrigin = root.Position + aimOriginOffset
	local strikeGeometry = measureStrikeGeometry(character, root)
	local crosshairHit = crosshairResult(character, aimOrigin, aimDirection)
	local strikeDirection = strikeDirectionTowardCrosshair(
		strikeGeometry,
		aimOrigin,
		aimDirection,
		crosshairHit
	)
	local hitResults = {}
	local hadContact = false
	for _, target in collectStrikeTargets(
		player,
		character,
		aimOrigin,
		strikeGeometry,
		strikeDirection,
		crosshairHit
	) do
		if target.Kind == "Player"
			and CombatDamageResolver.ResolveGuard(target.Humanoid, root.Position, "Melee") then
			hadContact = true
			publishSlashImpact(
				player,
				spawnGeneration,
				sequence,
				variant,
				"Guarded",
				target.WorldPosition,
				targetContactNormal(root, target.WorldPosition, strikeDirection)
			)
			local victimState = states[target.Player]
			if victimState then
				clearGuard(victimState)
				publishAcceptedPresentation(target.Player, {
					Operation = "BlockEnd",
					ShooterUserId = target.Player.UserId,
					SpawnGeneration = target.Player:GetAttribute("BLIKK_SpawnGeneration"),
					Sequence = victimState.BlockSequence,
				})
			end
			continue
		end
		local mayApply = if target.Kind == "Player"
			then matchService:RegisterDamageSource(target.Player, player)
			else practiceDummyService:IsTargetCurrent(target)
		if not mayApply then continue end
		local result = CombatDamageResolver.Apply(target.Humanoid, Config.DamagePerTarget)
		if not result then continue end
		if target.Kind == "PracticeDummy" then practiceDummyService:OnDamageApplied(target, result) end
		local appliedDamage = result.ArmourDamage + result.HealthDamage
		if appliedDamage > 0 then
			hadContact = true
			publishSlashImpact(
				player,
				spawnGeneration,
				sequence,
				variant,
				"Damage",
				target.WorldPosition,
				targetContactNormal(root, target.WorldPosition, strikeDirection)
			)
			table.insert(hitResults, {
				TargetKind = target.Kind,
				TargetId = target.TargetId,
				ContactCount = 1,
				RawDamage = result.RawDamage,
				ArmourDamage = result.ArmourDamage,
				HealthDamage = result.HealthDamage,
				AppliedDamage = appliedDamage,
				WorldPosition = target.WorldPosition,
				Eliminated = result.HealthAfter <= 0,
			})
		end
	end
	if not hadContact then
		local wallContact = resolveWallContact(
			character,
			strikeGeometry.Origin,
			strikeDirection,
			strikeGeometry.ReachStuds
		)
		if wallContact then
			publishSlashImpact(
				player,
				spawnGeneration,
				sequence,
				variant,
				"Wall",
				wallContact.Position,
				wallContact.Normal
			)
		end
	end
	sendResult(player, sequence, hitResults)
end

local function handleSlash(player, payload)
	local state = states[player]
	if not state then resetPlayer(player); state = states[player] end
	local sequence = payload.Sequence
	local variant = payload.Variant
	if not finiteInteger(sequence) or sequence <= state.Sequence
		or not finiteInteger(variant) or variant < 1 or variant > 2 then return end
	local now = os.clock()
	local eligible, character, _, root = isEligible(player)
	if not eligible or not firearmService:IsMeleeEquipped(player)
		or now < state.NextSlashAt or now < state.NextAltAt
		or character:GetAttribute(Config.Guard.AttributeName) == true
		or not rateAllowed(state, now) then return end
	local aimOrigin, aimDirection = validatedAim(root, payload.AimOrigin, payload.AimDirection)
	if not aimOrigin or not aimDirection then return end
	local aimOriginOffset = aimOrigin - root.Position
	state.Sequence = sequence
	state.CancelledSequence = 0
	state.SlashAcceptedAt = now
	state.NextSlashAt = now + Config.MinimumSlashIntervalSeconds
	state.SlashToken += 1
	techniqueService:RegisterSlash(player, sequence, now)
	local token = state.SlashToken
	local spawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
	publishAcceptedPresentation(player, {
		Operation = "Slash",
		ShooterUserId = player.UserId,
		SpawnGeneration = spawnGeneration,
		Sequence = sequence,
		Variant = variant,
	})
	task.delay(Config.ImpactDelaySeconds, function()
		resolveImpact(
			player,
			state,
			character,
			spawnGeneration,
			sequence,
			variant,
			token,
			aimOriginOffset,
			aimDirection
		)
	end)
end

local function cancelSlash(player, state, sequence, now, requireCancelWindow)
	local elapsed = now - state.SlashAcceptedAt
	local openAt = Config.Slash.CancelWindowOpenSeconds - Config.AuthoritativeCancelGraceSeconds
	local closeAt = Config.Slash.CancelWindowCloseSeconds + Config.AuthoritativeCancelGraceSeconds
	if not finiteInteger(sequence) or sequence ~= state.Sequence
		or state.CancelledSequence == sequence
		or requireCancelWindow and (elapsed < openAt or elapsed > closeAt) then
		return false, elapsed
	end
	state.CancelledSequence = sequence
	-- The accepted active-frame contact remains live. Cancelling presentation must
	-- not erase the slash that makes a manually executed Butterfly offensive.
	publishAcceptedPresentation(player, {
		Operation = "SlashCancel",
		ShooterUserId = player.UserId,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
		Sequence = sequence,
	})
	return true, elapsed
end

local function handleCancel(player, payload)
	local state = states[player]
	local sequence = payload.Sequence
	if not state then return end
	cancelSlash(player, state, sequence, os.clock(), false)
end

local function handleBlockBegin(player, payload)
	local state = states[player]
	if not state then resetPlayer(player); state = states[player] end
	local sequence = payload.Sequence
	if not finiteInteger(sequence) or sequence <= state.BlockSequence then return end
	local now = os.clock()
	local eligible, character, humanoid = isEligible(player)
	if not eligible or not firearmService:IsMeleeEquipped(player)
		or now < state.NextAltAt or not rateAllowed(state, now) then
		sendActionRejection(player, "GuardRejected", sequence)
		return
	end

	local cancelledSlash = false
	local cancelDelta = nil
	if payload.CancelledSlashSequence ~= nil then
		cancelledSlash, cancelDelta = cancelSlash(
			player,
			state,
			payload.CancelledSlashSequence,
			now,
			true
		)
		if not cancelledSlash then
			sendActionRejection(player, "GuardRejected", sequence)
			return
		end
	elseif now < state.NextSlashAt then
		sendActionRejection(player, "GuardRejected", sequence)
		return
	end

	state.BlockSequence = sequence
	beginGuard(state, character, sequence, now)
	local butterflyResult = if cancelledSlash
		then techniqueService:RegisterButterflyCancel(player, state.Sequence, now)
		else nil
	local butterflyAccepted = butterflyResult ~= nil
	if butterflyAccepted then
		state.NextSlashAt = math.min(
			state.NextSlashAt,
			now + Config.Slash.RepeatedSequenceLockoutSeconds
		)
	end
	publishAcceptedPresentation(player, {
		Operation = "BlockBegin",
		ShooterUserId = player.UserId,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
		Sequence = sequence,
		CancelledSlashSequence = if cancelledSlash then state.Sequence else nil,
		ButterflyAccepted = butterflyAccepted,
		TechniqueName = butterflyResult and butterflyResult.Name or nil,
		ChainCount = butterflyResult and butterflyResult.ChainCount or nil,
		MovingVariant = butterflyResult and butterflyResult.MovingVariant or nil,
	})
	sendActionResult(player, "GuardAccepted", sequence, {
		ButterflyAccepted = butterflyAccepted,
		CancelDeltaSeconds = cancelDelta,
		TechniqueName = butterflyResult and butterflyResult.Name or nil,
		ChainCount = butterflyResult and butterflyResult.ChainCount or nil,
		MovingVariant = butterflyResult and butterflyResult.MovingVariant or nil,
	})
end

local function handleBlockEnd(player, payload)
	local state = states[player]
	local sequence = payload.Sequence
	if not state or not finiteInteger(sequence) or sequence ~= state.BlockSequence then return end
	clearGuard(state)
	publishAcceptedPresentation(player, {
		Operation = "BlockEnd",
		ShooterUserId = player.UserId,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
		Sequence = sequence,
	})
end

local function resolveAltFire(
	player,
	state,
	character,
	spawnGeneration,
	sequence,
	token
)
	if states[player] ~= state or state.AltToken ~= token or player.Character ~= character
		or player:GetAttribute("BLIKK_SpawnGeneration") ~= spawnGeneration
		or not firearmService:IsMeleeEquipped(player) then return end
	local eligible, currentCharacter, _, root = isEligible(player)
	if not eligible or currentCharacter ~= character then return end
	local launchedCount = 0
	local alt = Config.AltFire
	local altDirection = root.CFrame.LookVector
	for _, target in collectArcTargets(
		player,
		character,
		root,
		alt.HitVolume,
		alt.MaximumTargets,
		altDirection
	) do
		local mayLaunch = if target.Kind == "Player"
			then matchService:RegisterDamageSource(target.Player, player)
			else target.Kind == "PracticeDummy" and practiceDummyService:IsTargetCurrent(target)
		if not mayLaunch then continue end
		local targetRoot = target.Model and target.Model:FindFirstChild("HumanoidRootPart")
		if not targetRoot or not targetRoot:IsA("BasePart") then continue end
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if forward.Magnitude <= 0 then continue end
		local desiredVelocity = forward.Unit * alt.LaunchForwardSpeedStudsPerSecond
			+ Vector3.new(0, alt.LaunchUpSpeedStudsPerSecond, 0)
		if target.Kind == "PracticeDummy" then
			if not practiceDummyService:LaunchTarget(target, desiredVelocity) then continue end
		else
			if targetRoot.Anchored then continue end
			target.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			targetRoot:ApplyImpulse(
				(desiredVelocity - targetRoot.AssemblyLinearVelocity) * targetRoot.AssemblyMass
			)
			beginAirToss(target.Player, target.Model, os.clock())
		end
		beginTossFloat(target.Model, target.Humanoid, targetRoot, os.clock())
		launchedCount += 1
	end
	sendActionResult(player, "AltFireResolved", sequence, { TargetCount = launchedCount })
end

local function handleAirTossRecover(player, payload)
	local state = states[player]
	local sequence = payload.Sequence
	if not state or not finiteInteger(sequence) or sequence ~= state.AirTossSequence
		or state.AirTossRecovered then return end
	local now = os.clock()
	local eligible, character, humanoid = isEligible(player)
	if not eligible or character ~= state.AirTossCharacter
		or humanoid.FloorMaterial ~= Enum.Material.Air
		or now < state.AirTossStartedAt or now > state.AirTossExpiresAt then return end
	state.AirTossRecovered = true
	clearAirToss(state)
	character:SetAttribute("BLIKK_AirTossRecoverySequence", sequence)
	character:SetAttribute("BLIKK_AirTossRecoveryStartedAt", now)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	sendActionResult(player, "AirTossRecovered", sequence, { RecoveryStartedAt = now })
	publishAcceptedPresentation(player, {
		Operation = "AirTossRecover",
		ShooterUserId = player.UserId,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
		Sequence = sequence,
	})
end

local function handleAltFire(player, payload)
	local state = states[player]
	if not state then resetPlayer(player); state = states[player] end
	local sequence = payload.Sequence
	if not finiteInteger(sequence) or sequence <= state.AltSequence then return end
	local now = os.clock()
	local eligible, character, humanoid = isEligible(player)
	if not eligible or not firearmService:IsMeleeEquipped(player)
		or humanoid.FloorMaterial == Enum.Material.Air
		or character:GetAttribute(Config.Guard.AttributeName) == true
		or now < state.NextSlashAt or now < state.NextAltAt
		or not rateAllowed(state, now) then
		sendActionRejection(player, "AltFireRejected", sequence)
		return
	end
	state.AltSequence = sequence
	state.NextAltAt = now + Config.AltFire.MinimumIntervalSeconds
	state.AltToken += 1
	local token = state.AltToken
	local spawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
	publishAcceptedPresentation(player, {
		Operation = "AltFire",
		ShooterUserId = player.UserId,
		SpawnGeneration = spawnGeneration,
		Sequence = sequence,
	})
	sendActionResult(player, "AltFireAccepted", sequence)
	task.delay(Config.AltFire.ImpactDelaySeconds, function()
		resolveAltFire(player, state, character, spawnGeneration, sequence, token)
	end)
end

function MeleeService:Init(
	remoteRegistry,
	matchServiceValue,
	roomServiceValue,
	practiceDummyServiceValue,
	firearmServiceValue,
	techniqueServiceValue
)
	matchService = matchServiceValue
	roomService = roomServiceValue
	practiceDummyService = practiceDummyServiceValue
	firearmService = firearmServiceValue
	techniqueService = techniqueServiceValue
	resultRemote = remoteRegistry.MeleeResult
	swingRemote = remoteRegistry.MeleeSwing
	RunService.Heartbeat:Connect(stepTossFloats)
	remoteRegistry.MeleeIntent.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then return end
		if payload.Operation == "Slash" then handleSlash(player, payload)
		elseif payload.Operation == "CancelSlash" then handleCancel(player, payload)
		elseif payload.Operation == "BlockBegin" then handleBlockBegin(player, payload)
		elseif payload.Operation == "BlockEnd" then handleBlockEnd(player, payload)
		elseif payload.Operation == "AltFire" then handleAltFire(player, payload)
		elseif payload.Operation == "AirTossRecover" then handleAirTossRecover(player, payload) end
	end)
	local function setupPlayer(player)
		resetPlayer(player)
		player.CharacterRemoving:Connect(function(character)
			clearTossFloat(character)
		end)
		player.CharacterAdded:Connect(function()
			clearGuard(states[player])
			clearAirToss(states[player])
			resetPlayer(player)
		end)
	end
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then clearTossFloat(player.Character) end
		clearGuard(states[player])
		clearAirToss(states[player])
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do setupPlayer(player) end
end

return MeleeService
