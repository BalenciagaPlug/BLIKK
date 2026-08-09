local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Combat.FirearmCombatConfig)
local FeedbackConfig = require(ReplicatedStorage.Shared.Combat.FirearmShotFeedbackConfig)
local ShotgunSpread = require(ReplicatedStorage.Shared.Combat.ShotgunSpread)
local FirearmDamageResolver = require(script.Parent.FirearmDamageResolver)

local FirearmService = {}
local states = {}
local warned = {}
local matchService
local roomService
local practiceDummyService
local resultRemote
local shotRemote
local seedRandom = Random.new()

local function newSlot()
	return {
		DefinitionId = Config.DefinitionId,
		Magazine = Config.MagazineCapacity,
		Reserve = Config.StartingReserve,
		UnlimitedReserve = false,
		NextFireAt = 0,
		ReloadToken = 0,
		ReloadActive = false,
	}
end

local function resetPlayer(player)
	states[player] = { ActiveSlot = "Melee", Sequence = 0, WindowAt = 0, WindowCount = 0,
		Primary1 = newSlot(), Primary2 = newSlot() }
end

local function warnOnce(player, category, detail)
	local key = tostring(player.UserId) .. ":" .. category
	if warned[key] then return end
	warned[key] = true
	warn(string.format("[BLIKK FIREARM:%s] %s (%s)", category, player.Name, detail))
end

local function send(player, operation, accepted, sequence, slotId, slot, extra)
	local response = {
		Operation = operation,
		Accepted = accepted,
		Sequence = sequence,
		Slot = slotId,
		Magazine = slot and slot.Magazine or nil,
		Reserve = slot and slot.Reserve or nil,
		UnlimitedReserve = slot and slot.UnlimitedReserve or false,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
	}
	for key, value in extra or {} do response[key] = value end
	resultRemote:FireClient(player, response)
end

local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and value.Magnitude > 0
end

local function finiteInteger(value)
	return type(value) == "number" and value == value and value > -math.huge
		and value < math.huge and value % 1 == 0
end

local function isEligible(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local context = player:GetAttribute("BLIKK_CharacterContext")
	local spawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
	local contextEligible = context == "MovementLab" or context == "Match" and matchService:GetMatch(player) ~= nil
	return character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")
		and player:GetAttribute("BLIKK_GameplayReleased") == true
		and character:GetAttribute("BLIKK_GameplayReleased") == true
		and finiteInteger(spawnGeneration)
		and spawnGeneration == character:GetAttribute("BLIKK_SpawnGeneration")
		and player:GetAttribute("BLIKK_CharacterMatchId") == character:GetAttribute("BLIKK_CharacterMatchId")
		and contextEligible,
		character, humanoid, root
end

local function rateAllowed(state, now)
	if now - state.WindowAt >= 1 then state.WindowAt = now; state.WindowCount = 0 end
	state.WindowCount += 1
	return state.WindowCount <= Config.Aim.MaximumRequestsPerSecond
end

local function synchronizeReserveContext(player, state)
	local isUnlimited = Config.MovementLabUnlimitedReserve
		and player:GetAttribute("BLIKK_CharacterContext") == "MovementLab"
		and roomService:GetRoom(player) == nil
		and matchService:GetMatch(player) == nil
	for _, slotId in { "Primary1", "Primary2" } do
		state[slotId].UnlimitedReserve = isUnlimited
	end
	return isUnlimited
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
	}
end

local function resolveDamageTarget(part, attacker)
	return resolvePlayerTarget(part, attacker)
		or practiceDummyService:ResolveTarget(part, attacker)
end

local function fallbackWorldPosition(target)
	local model = target.Humanoid and target.Humanoid.Parent
	local upperTorso = model and model:FindFirstChild("UpperTorso", true)
	local root = model and model:FindFirstChild("HumanoidRootPart", true)
	local part = if upperTorso and upperTorso:IsA("BasePart") then upperTorso else root
	return if part and part:IsA("BasePart") then part.Position else Vector3.zero
end

local function publishAcceptedShot(player, payload)
	local match = matchService:GetMatch(player)
	local room = roomService:GetRoom(player)
	if not match or not room or match.RoomId ~= room.RoomId or not match.Players[player] then
		shotRemote:FireClient(player, payload)
		return
	end
	for recipient in room.Members do
		if recipient.Parent == Players then shotRemote:FireClient(recipient, payload) end
	end
end

local function reportShotDiagnostic(sequence, seed, directions, origin, impacts, damageReports)
	if not FeedbackConfig.DiagnosticsEnabled then return end
	local directionValues = table.create(#directions)
	local distanceValues = table.create(#impacts)
	for index, direction in directions do directionValues[index] = tostring(direction) end
	for index, impact in impacts do
		distanceValues[index] = string.format("%.3f", (impact - origin).Magnitude)
	end
	local damageValues = table.create(#damageReports)
	for index, report in damageReports do
		damageValues[index] = string.format(
			"target=%s hits=%d raw=%.1f ap=%.1f hp=%.1f",
			report.TargetId,
			report.PelletHits,
			report.Result.RawDamage,
			report.Result.ArmourDamage,
			report.Result.HealthDamage
		)
	end
	print(string.format(
		"[BLIKK SHOT DIAGNOSTIC] Sequence=%d Seed=%d Directions={%s} Distances={%s} Damage={%s}",
		sequence,
		seed,
		table.concat(directionValues, ";"),
		table.concat(distanceValues, ","),
		table.concat(damageValues, ";")
	))
end

local function handleFire(player, state, payload)
	local sequence = payload.Sequence
	local slotId = payload.Slot
	local slot = state[slotId]
	if not finiteInteger(sequence) or sequence <= state.Sequence then
		warnOnce(player, "STALE_SEQUENCE", tostring(sequence))
		return
	end
	local now = os.clock()
	local eligible, character, _, root = isEligible(player)
	if not eligible then send(player, "Fire", false, sequence, slotId, slot); return end
	synchronizeReserveContext(player, state)
	if slotId ~= state.ActiveSlot or not slot or slot.DefinitionId ~= Config.DefinitionId then
		warnOnce(player, "INVALID_EQUIPPED_SLOT", tostring(slotId)); send(player, "Fire", false, sequence, slotId, slot); return
	end
	state.Sequence = sequence
	if not rateAllowed(state, now) then
		warnOnce(player, "FIRE_RATE_REJECTION", "request-rate limit")
		send(player, "Fire", false, sequence, slotId, slot)
		return
	end
	local aim = payload.AimDirection
	if not finiteVector(aim) or aim.Magnitude < Config.Aim.MinimumDirectionMagnitude
		or aim.Magnitude > Config.Aim.MaximumDirectionMagnitude then
		warnOnce(player, "INVALID_SHOT_REQUEST", "non-unit aim"); send(player, "Fire", false, sequence, slotId, slot); return
	end
	aim = aim.Unit
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	local flatFacing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flatAim.Magnitude < 0.001 or flatFacing.Magnitude < 0.001
		or flatAim.Unit:Dot(flatFacing.Unit) < Config.Aim.MinimumFacingDot then
		warnOnce(player, "IMPOSSIBLE_AIM", "outside facing tolerance"); send(player, "Fire", false, sequence, slotId, slot); return
	end
	if slot.Magazine <= 0 or now < slot.NextFireAt then
		send(player, "Fire", false, sequence, slotId, slot); return
	end
	slot.ReloadToken += 1
	slot.ReloadActive = false
	slot.Magazine -= 1
	slot.NextFireAt = now + Config.FireIntervalSeconds
	local seed = seedRandom:NextInteger(1, 2147483646)
	local origin = root.Position + Vector3.new(0, Config.Aim.MuzzleUpStuds, 0)
		+ root.CFrame.LookVector * Config.Aim.MuzzleForwardStuds
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local groupsByHumanoid = {}
	local targetGroups = {}
	local impacts = table.create(Config.PelletsPerShot)
	local directions = ShotgunSpread.GenerateDirections(
		aim,
		Config.PelletsPerShot,
		Config.SpreadHalfAngleDegrees,
		seed
	)
	for index = 1, Config.PelletsPerShot do
		local direction = directions[index]
		local hit = Workspace:Raycast(origin, direction * Config.MaximumRangeStuds, params)
		impacts[index] = hit and hit.Position or origin + direction * Config.MaximumRangeStuds
		if hit then
			local target = resolveDamageTarget(hit.Instance, player)
			if target then
				local group = groupsByHumanoid[target.Humanoid]
				if not group then
					group = {
						Target = target,
						PelletHits = 0,
						ImpactPositionSum = Vector3.zero,
					}
					groupsByHumanoid[target.Humanoid] = group
					table.insert(targetGroups, group)
				end
				group.PelletHits = math.min(group.PelletHits + 1, Config.PelletsPerShot)
				group.ImpactPositionSum += hit.Position
			end
		end
	end
	table.sort(targetGroups, function(left, right)
		if left.Target.Kind ~= right.Target.Kind then
			return left.Target.Kind < right.Target.Kind
		end
		return left.Target.TargetId < right.Target.TargetId
	end)
	local hitResults = table.create(math.min(#targetGroups, Config.PelletsPerShot))
	for _, group in targetGroups do
		if #hitResults >= Config.PelletsPerShot then break end
		local target = group.Target
		local pelletHits = group.PelletHits
		local rawDamage = math.min(
			pelletHits * Config.DamagePerPellet,
			Config.MaximumRawDamagePerTarget
		)
		local mayApply = if target.Kind == "Player"
			then matchService:RegisterDamageSource(target.Player, player)
			else practiceDummyService:IsTargetCurrent(target)
		if not mayApply then continue end
		local result = FirearmDamageResolver.Apply(target.Humanoid, rawDamage)
		if not result then continue end
		if target.Kind == "PracticeDummy" then
			practiceDummyService:OnDamageApplied(target, result)
		end
		local appliedDamage = result.ArmourDamage + result.HealthDamage
		if appliedDamage > 0 then
			local worldPosition = if pelletHits > 0
				then group.ImpactPositionSum / pelletHits
				else fallbackWorldPosition(target)
			table.insert(hitResults, {
				TargetKind = target.Kind,
				TargetId = target.TargetId,
				PelletHits = pelletHits,
				RawDamage = result.RawDamage,
				ArmourDamage = result.ArmourDamage,
				HealthDamage = result.HealthDamage,
				AppliedDamage = appliedDamage,
				WorldPosition = worldPosition,
				Eliminated = result.HealthAfter <= 0,
			})
		end
	end
	send(player, "Fire", true, sequence, slotId, slot, { HitResults = hitResults })
	publishAcceptedShot(player, {
		ShooterUserId = player.UserId,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
		Sequence = sequence,
		Slot = slotId,
		Origin = origin,
		Impacts = impacts,
	})
	if FeedbackConfig.DiagnosticsEnabled then
		local damageReports = table.create(#hitResults)
		for index, hitResult in hitResults do
			damageReports[index] = {
				TargetId = hitResult.TargetId,
				PelletHits = hitResult.PelletHits,
				Result = hitResult,
			}
		end
		reportShotDiagnostic(sequence, seed, directions, origin, impacts, damageReports)
	end
end

local function handleReload(player, state, payload)
	local now = os.clock()
	if not rateAllowed(state, now) then return end
	local slotId = payload.Slot
	local slot = state[slotId]
	local sequence = payload.Sequence
	if not finiteInteger(sequence) or sequence <= state.Sequence then return end
	if not slot or slot.DefinitionId ~= Config.DefinitionId
		or slotId ~= state.ActiveSlot or not isEligible(player) then
		send(player, "ReloadRejected", false, sequence, slotId, slot)
		return
	end
	state.Sequence = sequence
	synchronizeReserveContext(player, state)
	if slot.ReloadActive or slot.Magazine >= Config.MagazineCapacity
		or (not slot.UnlimitedReserve and slot.Reserve <= 0) then
		send(player, "ReloadRejected", false, sequence, slotId, slot)
		return
	end
	slot.ReloadToken += 1
	local token = slot.ReloadToken
	slot.ReloadActive = true
	local spawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
	local character = player.Character
	send(player, "ReloadAccepted", true, sequence, slotId, slot)
	task.delay(Config.Reload.CommitSeconds, function()
		if states[player] ~= state or state.ActiveSlot ~= slotId or slot.ReloadToken ~= token
			or not slot.ReloadActive or player.Character ~= character
			or player:GetAttribute("BLIKK_SpawnGeneration") ~= spawnGeneration
			or not isEligible(player) then return end
		synchronizeReserveContext(player, state)
		local missing = Config.MagazineCapacity - slot.Magazine
		local transfer = if slot.UnlimitedReserve then missing else math.min(missing, slot.Reserve)
		if transfer <= 0 then
			slot.ReloadActive = false
			send(player, "ReloadRejected", false, sequence, slotId, slot)
			return
		end
		slot.Magazine += transfer
		if not slot.UnlimitedReserve then slot.Reserve -= transfer end
		slot.ReloadActive = false
		send(player, "ReloadCommitted", true, sequence, slotId, slot, {
			Transferred = transfer,
		})
	end)
end

function FirearmService:Init(
	remoteRegistry,
	matchServiceValue,
	roomServiceValue,
	practiceDummyServiceValue
)
	matchService = matchServiceValue
	roomService = roomServiceValue
	practiceDummyService = practiceDummyServiceValue
	assert(practiceDummyService and type(practiceDummyService.ResolveTarget) == "function",
		"Firearm service requires practice-dummy target authority")
	resultRemote = remoteRegistry.FirearmResult
	shotRemote = remoteRegistry.FirearmShot
	remoteRegistry.FirearmIntent.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or type(payload.Operation) ~= "string" then return end
		local state = states[player]
		if not state then resetPlayer(player); state = states[player] end
		if payload.Operation == "Equip" and (payload.Slot == "Melee" or payload.Slot == "Primary1" or payload.Slot == "Primary2") then
			for _, slotId in { "Primary1", "Primary2" } do
				state[slotId].ReloadToken += 1
				state[slotId].ReloadActive = false
			end
			state.ActiveSlot = payload.Slot
			synchronizeReserveContext(player, state)
			local equippedSlot = state[payload.Slot]
			if equippedSlot then
				send(player, "Equip", true, state.Sequence, payload.Slot, equippedSlot)
			end
		elseif payload.Operation == "Fire" then handleFire(player, state, payload)
		elseif payload.Operation == "Reload" then handleReload(player, state, payload) end
	end)
	local function setupPlayer(player)
		resetPlayer(player)
		player.CharacterAdded:Connect(function() resetPlayer(player) end)
	end
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player) states[player] = nil end)
	for _, player in Players:GetPlayers() do setupPlayer(player) end
end

return FirearmService
