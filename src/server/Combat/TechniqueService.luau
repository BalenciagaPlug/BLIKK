local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Movement.TechniqueConfig)

local TechniqueService = {}
local states = {}
local resultRemote

local VALID_DIRECTIONS = {
	Forward = true,
	Backward = true,
	Left = true,
	Right = true,
}

local function newState()
	return {
		MovementSequence = 0,
		MovementWindowAt = 0,
		MovementWindowCount = 0,
		ResultSequence = 0,
		JumpSerial = 0,
		JumpAt = -math.huge,
		DashSerial = 0,
		DashAt = -math.huge,
		ButterflyPairs = 0,
		LastButterflyAt = -math.huge,
		LastButterflySlashSequence = 0,
		LastSlash = nil,
		LastEquip = nil,
		LastFire = nil,
		LastReload = nil,
		LastAcceptedAt = {},
	}
end

local function stateFor(player)
	local state = states[player]
	if state then return state end
	state = newState()
	states[player] = state
	return state
end

local function finiteInteger(value)
	return type(value) == "number" and value == value and value > -math.huge
		and value < math.huge and value % 1 == 0
end

local function movementRateAllowed(state, now)
	if now - state.MovementWindowAt >= 1 then
		state.MovementWindowAt = now
		state.MovementWindowCount = 0
	end
	state.MovementWindowCount += 1
	return state.MovementWindowCount <= Config.WeaponWeave.MovementIntentMaximumRequestsPerSecond
end

local function aliveHumanoid(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0
		or player:GetAttribute("BLIKK_GameplayReleased") ~= true
		or character:GetAttribute("BLIKK_GameplayReleased") ~= true then return nil end
	return humanoid
end

local function publishAccepted(player, state, name, detail)
	local now = os.clock()
	local lockout = Config.WeaponWeave.AcceptedResultLockoutSeconds
	if now - (state.LastAcceptedAt[name] or -math.huge) < lockout then return false end
	state.LastAcceptedAt[name] = now
	state.ResultSequence += 1
	local payload = {
		Accepted = true,
		Name = name,
		Sequence = state.ResultSequence,
		SpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration"),
	}
	for key, value in detail or {} do payload[key] = value end
	resultRemote:FireClient(player, payload)
	return true
end

local function recordMovement(player, payload)
	local sequence = payload.Sequence
	if not finiteInteger(sequence) then return end
	local state = stateFor(player)
	if sequence <= state.MovementSequence then return end
	local now = os.clock()
	if not movementRateAllowed(state, now) or not aliveHumanoid(player) then return end
	state.MovementSequence = sequence
	if payload.Operation == "Jump" then
		state.JumpSerial += 1
		state.JumpAt = now
		state.ButterflyPairs = 0
		state.LastButterflyAt = -math.huge
		state.LastButterflySlashSequence = 0
		state.LastSlash = nil
	elseif payload.Operation == "Dash" and VALID_DIRECTIONS[payload.Direction] then
		state.DashSerial += 1
		state.DashAt = now
	end
end

function TechniqueService:RegisterSlash(player, slashSequence, acceptedAt)
	local state = stateFor(player)
	local humanoid = aliveHumanoid(player)
	local slashShot = Config.WeaponWeave.SlashShot
	local preSlashDashAt = if state.DashAt >= state.JumpAt
		and acceptedAt - state.DashAt <= slashShot.DashBeforeSlashMaximumSeconds
		then state.DashAt else nil
	state.LastSlash = {
		Sequence = slashSequence,
		At = acceptedAt,
		JumpSerial = state.JumpSerial,
		JumpAt = state.JumpAt,
		PreSlashDashAt = preSlashDashAt,
		Airborne = humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air,
	}
end

function TechniqueService:RegisterButterflyCancel(player, slashSequence, acceptedAt)
	local state = stateFor(player)
	local humanoid = aliveHumanoid(player)
	local slash = state.LastSlash
	local butterfly = Config.Butterfly
	if not humanoid or humanoid.FloorMaterial ~= Enum.Material.Air
		or not slash or slash.Sequence ~= slashSequence
		or slashSequence == state.LastButterflySlashSequence
		or state.ButterflyPairs >= butterfly.MaximumPairsPerJump
		or slash.JumpSerial ~= state.JumpSerial
		or acceptedAt - state.JumpAt > butterfly.JumpChainMaximumSeconds
		or state.ButterflyPairs > 0
			and acceptedAt - state.LastButterflyAt > butterfly.ChainMaximumGapSeconds then
		return nil
	end
	state.ButterflyPairs += 1
	state.LastButterflyAt = acceptedAt
	state.LastButterflySlashSequence = slashSequence
	local count = state.ButterflyPairs
	local name = if count == 1 then "Butterfly"
		elseif count == 2 then "DoubleButterfly" else "TripleButterfly"
	publishAccepted(player, state, name, {
		ChainCount = count,
		MovingVariant = slash.PreSlashDashAt ~= nil,
	})
	return {
		Name = name,
		ChainCount = count,
		MovingVariant = slash.PreSlashDashAt ~= nil,
	}
end

function TechniqueService:RegisterEquip(player, slotId, acceptedAt)
	local state = stateFor(player)
	state.LastEquip = { Slot = slotId, At = acceptedAt }
end

function TechniqueService:RegisterReload(player, slotId, acceptedAt)
	local state = stateFor(player)
	local fire = state.LastFire
	if fire and fire.Slot == slotId
		and acceptedAt - fire.At <= Config.WeaponWeave.ReloadShot.ReloadAfterFireMaximumSeconds then
		state.LastReload = { Slot = slotId, At = acceptedAt, FireAt = fire.At }
	else
		state.LastReload = nil
	end
end

function TechniqueService:RegisterFire(player, slotId, acceptedAt)
	local state = stateFor(player)
	local weave = Config.WeaponWeave
	local equip = state.LastEquip
	local slash = state.LastSlash
	local acceptedName

	local slashSequenceElapsed = if slash then acceptedAt - slash.At else math.huge
	if slash and slash.Airborne and slash.PreSlashDashAt
		and equip and equip.Slot == slotId and equip.At >= slash.At
		and equip.At - slash.At <= weave.SlashShot.EquipAfterSlashMaximumSeconds
		and acceptedAt - equip.At <= weave.SlashShot.FireAfterEquipMaximumSeconds
		and slashSequenceElapsed <= weave.HalfStep.MaximumSequenceSeconds then
		local halfStep = state.DashAt > equip.At
			and state.DashAt - equip.At <= weave.HalfStep.DashAfterEquipMaximumSeconds
			and acceptedAt - state.DashAt <= weave.HalfStep.FireAfterDashMaximumSeconds
		if halfStep or slashSequenceElapsed <= weave.SlashShot.MaximumSequenceSeconds then
			acceptedName = if halfStep then "HalfStep" else "SlashShot"
			publishAccepted(player, state, acceptedName, {
				FromSlot = "Melee",
				ToSlot = slotId,
			})
			state.LastSlash = nil
		end
	end

	local previousFire = state.LastFire
	if not acceptedName and previousFire and previousFire.Slot ~= slotId
		and equip and equip.Slot == slotId and equip.At >= previousFire.At
		and acceptedAt - equip.At <= weave.SwapShot.FireAfterEquipMaximumSeconds
		and acceptedAt - previousFire.At <= weave.SwapShot.MaximumShotGapSeconds then
		local reload = state.LastReload
		local isReloadShot = reload and reload.Slot == previousFire.Slot
			and reload.FireAt == previousFire.At
			and reload.At >= previousFire.At and equip.At >= reload.At
			and equip.At - reload.At <= weave.ReloadShot.EquipAfterReloadMaximumSeconds
			and acceptedAt - previousFire.At <= weave.ReloadShot.MaximumShotGapSeconds
		acceptedName = if isReloadShot then "ReloadShot" else "SwapShot"
		publishAccepted(player, state, acceptedName, {
			FromSlot = previousFire.Slot,
			ToSlot = slotId,
		})
	end

	state.LastFire = { Slot = slotId, At = acceptedAt }
	state.LastReload = nil
	return acceptedName
end

function TechniqueService:Init(remoteRegistry)
	resultRemote = remoteRegistry.TechniqueResult
	remoteRegistry.TechniqueIntent.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or type(payload.Operation) ~= "string" then return end
		if payload.Operation == "Jump" or payload.Operation == "Dash" then
			recordMovement(player, payload)
		end
	end)
	local function setupPlayer(player)
		states[player] = newState()
		player.CharacterAdded:Connect(function() states[player] = newState() end)
	end
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player) states[player] = nil end)
	for _, player in Players:GetPlayers() do setupPlayer(player) end
end

return TechniqueService
