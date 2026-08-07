local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Combat.FirearmCombatConfig)
local ShotgunSpread = require(ReplicatedStorage.Shared.Combat.ShotgunSpread)

local FirearmService = {}
local states = {}
local warned = {}
local matchService
local resultRemote

local function newSlot()
	return {
		DefinitionId = Config.DefinitionId,
		Magazine = Config.MagazineCapacity,
		Reserve = Config.StartingReserve,
		NextFireAt = 0,
		ReloadToken = 0,
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
	local payload = extra or {}
	payload.Operation = operation
	payload.Accepted = accepted
	payload.Sequence = sequence
	payload.Slot = slotId
	if slot then payload.Magazine = slot.Magazine; payload.Reserve = slot.Reserve end
	resultRemote:FireClient(player, payload)
end

local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and value.Magnitude > 0
end

local function isEligible(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local context = player:GetAttribute("BLIKK_CharacterContext")
	local contextEligible = context == "MovementLab" or context == "Match" and matchService:GetMatch(player) ~= nil
	return character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")
		and player:GetAttribute("BLIKK_GameplayReleased") == true
		and character:GetAttribute("BLIKK_GameplayReleased") == true
		and player:GetAttribute("BLIKK_SpawnGeneration") == character:GetAttribute("BLIKK_SpawnGeneration")
		and player:GetAttribute("BLIKK_CharacterMatchId") == character:GetAttribute("BLIKK_CharacterMatchId")
		and contextEligible,
		character, humanoid, root
end

local function rateAllowed(state, now)
	if now - state.WindowAt >= 1 then state.WindowAt = now; state.WindowCount = 0 end
	state.WindowCount += 1
	return state.WindowCount <= Config.Aim.MaximumRequestsPerSecond
end

local function resolveHumanoid(part)
	local model = part and part:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local victim = model and Players:GetPlayerFromCharacter(model)
	return humanoid, victim
end

local function handleFire(player, state, payload)
	local sequence = payload.Sequence
	local slotId = payload.Slot
	local slot = state[slotId]
	local now = os.clock()
	local eligible, character, _, root = isEligible(player)
	if not eligible then send(player, "Fire", false, sequence, slotId, slot); return end
	if slotId ~= state.ActiveSlot or not slot or slot.DefinitionId ~= Config.DefinitionId then
		warnOnce(player, "INVALID_EQUIPPED_SLOT", tostring(slotId)); send(player, "Fire", false, sequence, slotId, slot); return
	end
	if type(sequence) ~= "number" or sequence % 1 ~= 0 or sequence <= state.Sequence then
		warnOnce(player, "STALE_SEQUENCE", tostring(sequence)); send(player, "Fire", false, sequence, slotId, slot); return
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
	slot.Magazine -= 1
	slot.NextFireAt = now + Config.FireIntervalSeconds
	local seed = math.random(1, 2147483646)
	local origin = root.Position + Vector3.new(0, Config.Aim.MuzzleUpStuds, 0)
		+ root.CFrame.LookVector * Config.Aim.MuzzleForwardStuds
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local damageByHumanoid = {}
	local victimByHumanoid = {}
	local impacts = {}
	for _, direction in ShotgunSpread.GenerateDirections(aim, Config.PelletsPerShot, Config.SpreadHalfAngleDegrees, seed) do
		local hit = Workspace:Raycast(origin, direction * Config.MaximumRangeStuds, params)
		table.insert(impacts, hit and hit.Position or origin + direction * Config.MaximumRangeStuds)
		if hit then
			local targetHumanoid, victim = resolveHumanoid(hit.Instance)
			local attackerTeam = player:GetAttribute("BLIKK_TeamId")
			local victimTeam = victim and victim:GetAttribute("BLIKK_TeamId")
			if targetHumanoid and victim and victim ~= player and targetHumanoid.Health > 0
				and (not attackerTeam or attackerTeam ~= victimTeam)
				and victim:GetAttribute("BLIKK_GameplayReleased") == true then
				damageByHumanoid[targetHumanoid] = math.min(
					(damageByHumanoid[targetHumanoid] or 0) + Config.DamagePerPellet,
					Config.MaximumRawDamagePerTarget
				)
				victimByHumanoid[targetHumanoid] = victim
			end
		end
	end
	for targetHumanoid, damage in damageByHumanoid do
		local victim = victimByHumanoid[targetHumanoid]
		if matchService:RegisterDamageSource(victim, player) then targetHumanoid:TakeDamage(damage) end
	end
	send(player, "Fire", true, sequence, slotId, slot, { Seed = seed, Impacts = impacts })
end

local function handleReload(player, state, payload)
	if not rateAllowed(state, os.clock()) then return end
	local slotId = payload.Slot
	local slot = state[slotId]
	if not slot or slot.DefinitionId ~= Config.DefinitionId
		or slotId ~= state.ActiveSlot or not isEligible(player) then return end
	slot.ReloadToken += 1
	local token = slot.ReloadToken
	task.delay(Config.Reload.StartSeconds, function()
		while states[player] == state and state.ActiveSlot == slotId and slot.ReloadToken == token
			and slot.Magazine < Config.MagazineCapacity and slot.Reserve > 0 do
			task.wait(Config.Reload.InsertSeconds)
			if states[player] ~= state or state.ActiveSlot ~= slotId or slot.ReloadToken ~= token then return end
			slot.Magazine += 1; slot.Reserve -= 1
			send(player, "Reload", true, payload.Sequence, slotId, slot)
		end
	end)
end

function FirearmService:Init(remoteRegistry, matchServiceValue)
	matchService = matchServiceValue
	resultRemote = remoteRegistry.FirearmResult
	remoteRegistry.FirearmIntent.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or type(payload.Operation) ~= "string" then return end
		local state = states[player]
		if not state then resetPlayer(player); state = states[player] end
		if payload.Operation == "Equip" and (payload.Slot == "Melee" or payload.Slot == "Primary1" or payload.Slot == "Primary2") then
			for _, slotId in { "Primary1", "Primary2" } do state[slotId].ReloadToken += 1 end
			state.ActiveSlot = payload.Slot
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
