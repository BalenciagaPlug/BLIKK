local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PoseCoordinator = require(script.Parent.Parent.Character.PoseCoordinator)
local CharacterDependency = require(ReplicatedStorage.Shared.Character.CharacterDependency)
local Config = require(ReplicatedStorage.Shared.Combat.FirearmPresentationConfig)
local CombatConfig = require(ReplicatedStorage.Shared.Combat.FirearmCombatConfig)
local FighterSlots = require(ReplicatedStorage.Shared.Character.FighterSlots)
local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local Controller = {}
Controller.StateChanged = Instance.new("BindableEvent")
Controller.SemanticEvent = Instance.new("BindableEvent")

local player = Players.LocalPlayer
local fighterController
local inputManager
local gameplayCamera
local movementEngineController
local firearmIntent
local character
local humanoid
local slots = {}
local activeSlot = "Melee"
local generation = 0
local switchGeneration = 0
local pendingSwitch = nil
local deathConnection = nil
local characterBindingTarget = nil
local cancelDependencyWatch = nil
local gameplayEnabled = true
local inputSuppressed = false
local isCommittingSwitch = false
local shotSequence = 0
local warnedFallback = false
local warnedReloadReconciliation = false
local tumble = nil
local isInitialised = false

local function makePart(parent, name, size, color, material, cframe)
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
	part.Parent = parent
	return part
end

local function weld(part0, part1)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = part0
	joint.Part1 = part1
	joint.Parent = part1
end

local function buildBreakshot(slotId)
	local dimensions = Config.Geometry
	local colors = Config.Colors
	local offsets = Config.Offsets
	local model = Instance.new("Model")
	model.Name = "BLIKK_B8_" .. slotId
	model:SetAttribute("BLIKK_PresentationOnly", true)
	model:SetAttribute("BLIKK_WeaponSlot", slotId)
	local receiver = makePart(model, "Receiver", dimensions.Receiver, colors.Gunmetal, Enum.Material.Metal)
	local stock = makePart(model, "CompactStock", dimensions.Stock, colors.Black, Enum.Material.SmoothPlastic, offsets.Stock)
	local grip = makePart(model, "PistolGrip", dimensions.Grip, colors.Black, Enum.Material.SmoothPlastic, offsets.Grip)
	local guard = makePart(model, "TriggerGuard", dimensions.Guard, colors.Black, Enum.Material.Metal, offsets.Guard)
	local port = makePart(model, "EjectionPort", dimensions.Port, colors.Accent, Enum.Material.Neon, offsets.Port)
	local shroud = makePart(model, "BarrelShroud", dimensions.Shroud, colors.Black, Enum.Material.Metal, offsets.Shroud)
	local barrel = makePart(model, "Barrel", dimensions.Barrel, colors.Gunmetal, Enum.Material.Metal, offsets.Barrel)
	barrel.Shape = Enum.PartType.Cylinder
	local sight = makePart(model, "FrontSight", dimensions.Sight, colors.Accent, Enum.Material.Neon, offsets.Sight)
	for _, part in { stock, grip, guard, port, shroud, barrel, sight } do weld(receiver, part) end

	local pump = makePart(model, "PumpForeEnd", dimensions.Pump, colors.Black, Enum.Material.SmoothPlastic, offsets.Pump)
	local hinge = Instance.new("Motor6D")
	hinge.Name = "BLIKK_PumpAction"
	hinge.Part0 = receiver
	hinge.Part1 = pump
	hinge.C0 = offsets.Pump
	hinge.Parent = receiver
	local muzzles = {}
	local muzzle = makePart(model, "MuzzleFlash", Vector3.new(0.30, 0.30, 0.18), Color3.fromRGB(255, 188, 82), Enum.Material.Neon, offsets.Muzzle)
	muzzle.Transparency = 1
	weld(receiver, muzzle)
	for index = 1, Config.ChamberCapacity do muzzles[index] = muzzle end
	for name, position in {
		MuzzleAttachment = Config.Attachments.Muzzle,
		ForegripAttachment = Config.Attachments.Foregrip,
		RightHandGripAttachment = Config.Attachments.RightHandGrip,
	} do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = position
		attachment.Parent = receiver
	end
	local shells = {}
	local shellJoints = {}
	for shellIndex = 1, Config.ChamberCapacity do
		local shell = makePart(model, "MagazineRound" .. shellIndex, dimensions.Shell, colors.Accent, Enum.Material.Metal, CFrame.new(0, -0.15, -0.20 + shellIndex * 0.05))
		local shellJoint = Instance.new("Motor6D")
		shellJoint.Name = "ShellJoint" .. shellIndex
		shellJoint.Part0 = receiver
		shellJoint.Part1 = shell
		shellJoint.C0 = CFrame.new(0, -0.15, -0.20 + shellIndex * 0.05)
		shellJoint.Parent = receiver
		shells[shellIndex] = shell
		shellJoints[shellIndex] = shellJoint
	end
	model.PrimaryPart = receiver
	return model, hinge, muzzles, shells, shellJoints
end

local function buildWeapon(slotId)
	if Config.ApprovedCustomModelName ~= "" then
		local folder = ReplicatedStorage:FindFirstChild("BLIKKWeaponModels")
		local source = folder and folder:FindFirstChild(Config.ApprovedCustomModelName)
		local pump = source and source:FindFirstChild("BLIKK_PumpAction", true)
		local muzzle = source and source:FindFirstChild("MuzzleFlash", true)
		if source and source:IsA("Model") and source.PrimaryPart
			and source.PrimaryPart:FindFirstChild("MuzzleAttachment")
			and pump and pump:IsA("Motor6D") and muzzle and muzzle:IsA("BasePart") then
			local clone = source:Clone()
			clone.Name = "BLIKK_B8_" .. slotId
			local clonePump = clone:FindFirstChild("BLIKK_PumpAction", true)
			local cloneMuzzle = clone:FindFirstChild("MuzzleFlash", true)
			local muzzles, shells, shellJoints = {}, {}, {}
			for index = 1, Config.ChamberCapacity do
				muzzles[index] = cloneMuzzle
				shells[index] = clone:FindFirstChild("MagazineRound" .. index, true)
				shellJoints[index] = clone:FindFirstChild("ShellJoint" .. index, true)
				if not shells[index] or not shellJoints[index] then clone:Destroy(); clone = nil; break end
			end
			if clone then return clone, clonePump, muzzles, shells, shellJoints end
		end
		if not warnedFallback then
			warnedFallback = true
			warn("[BLIKK FIREARM:FALLBACK] Approved model unavailable; using coded B-8.")
		end
	end
	return buildBreakshot(slotId)
end

local function attachSlot(slot, equipped)
	if not character or not slot.Model or not slot.Model.PrimaryPart then return false end
	local bodyPart = character:FindFirstChild(if equipped then "RightHand" else "UpperTorso")
	if not bodyPart or not bodyPart:IsA("BasePart") then return false end
	if slot.Grip then slot.Grip:Destroy() end
	local grip = Instance.new("Motor6D")
	grip.Name = "BLIKK_BreakshotGrip_" .. slot.Id
	grip.Part0 = bodyPart
	grip.Part1 = slot.Model.PrimaryPart
	grip.C0 = if equipped then Config.EquippedOffset else Config.HolsteredOffsets[slot.Id]
	grip.Parent = slot.Model.PrimaryPart
	slot.Grip = grip
	return true
end

local function updateShells(slot)
	for index, shell in slot.Shells do shell.Transparency = if slot.Barrels[index] then 0 else 1 end
end

local function chamberCount(slot)
	local count = 0
	for index = 1, Config.ChamberCapacity do
		if slot.Barrels[index] then count += 1 end
	end
	return count
end

local function publish(slot)
	Controller.StateChanged:Fire(slot.Id, slot.State, chamberCount(slot), slot.Reserve)
end

local function setState(slot, nextState)
	slot.State = nextState
	slot.StateStartedAt = os.clock()
	publish(slot)
end

local function cancelSlotAction(slot, reason)
	local wasReloading = string.sub(slot.State, 1, 6) == "Reload"
	slot.Token += 1
	slot.Hinge.Transform = CFrame.identity
	for _, joint in slot.ShellJoints do joint.Transform = CFrame.identity end
	for _, muzzle in slot.Muzzles do
		muzzle.Color = Color3.fromRGB(255, 188, 82)
		muzzle.Transparency = 1
	end
	updateShells(slot)
	setState(slot, "Interrupted")
	if wasReloading then Controller.SemanticEvent:Fire("ReloadCancelled", os.clock(), { Slot = slot.Id, Reason = reason }) end
end

local function callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token)
	return generation == characterGeneration
		and switchGeneration == actionSwitchGeneration
		and slots[slot.Id] == slot
		and slot.Token == token
		and slot.Model and slot.Model.Parent == character
		and player.Character == character
end

local function commitSwitch(slotId, requestGeneration, characterGeneration)
	if requestGeneration ~= switchGeneration or characterGeneration ~= generation
		or not character or player.Character ~= character then return end
	pendingSwitch = nil
	for slotId, inactiveSlot in slots do
		if slotId ~= activeSlot and (inactiveSlot.State == "Unequipping"
			or inactiveSlot.State == "Interrupted") then
			attachSlot(inactiveSlot, false)
			setState(inactiveSlot, "Idle")
		end
	end
	local previous = slots[activeSlot]
	if previous and previous ~= slots[slotId] then
		cancelSlotAction(previous, "WeaponSwitch")
		setState(previous, "Unequipping")
		attachSlot(previous, false)
		Controller.SemanticEvent:Fire("WeaponUnequipped", os.clock(), { Slot = previous.Id })
		local previousToken = previous.Token
		task.delay(Config.UnequipDurationSeconds, function()
			if callbackIsCurrent(previous, characterGeneration, requestGeneration, previousToken)
				and previous.State == "Unequipping" then setState(previous, "Idle") end
		end)
	end
	activeSlot = slotId
	isCommittingSwitch = true
	fighterController:SetActiveWeaponSlot(slotId)
	isCommittingSwitch = false
	if firearmIntent then firearmIntent:FireServer({ Operation = "Equip", Slot = slotId }) end
	local slot = slots[slotId]
	if not slot then PoseCoordinator:Release("Firearm"); return end
	cancelSlotAction(slot, "Equip")
	attachSlot(slot, true)
	setState(slot, "Equipping")
	Controller.SemanticEvent:Fire("WeaponEquipped", os.clock(), { Slot = slot.Id })
	local token = slot.Token
	task.delay(Config.EquipDurationSeconds, function()
		if callbackIsCurrent(slot, characterGeneration, requestGeneration, token)
			and activeSlot == slot.Id and slot.State == "Equipping" then setState(slot, "Ready") end
	end)
end

local function requestSwitch(slotId)
	if not character or not FighterSlots.Weapon.ById[slotId]
		or not fighterController:GetFighter().Weapons[slotId] then return false end
	if pendingSwitch and activeSlot == slotId then
		switchGeneration += 1
		pendingSwitch = nil
		local active = slots[activeSlot]
		if active then setState(active, "Ready") end
		return true
	end
	if not pendingSwitch and fighterController:GetFighter().ActiveWeaponSlot == slotId
		and activeSlot == slotId then return true end
	switchGeneration += 1
	local requestGeneration = switchGeneration
	local characterGeneration = generation
	pendingSwitch = { Slot = slotId, Generation = requestGeneration }
	local previous = slots[activeSlot]
	if previous then cancelSlotAction(previous, "WeaponSwitchPending") end
	local previousToken = previous and previous.Token
	local delaySeconds = 0
	if previous and previous.LastFireAt then
		delaySeconds = math.max(previous.LastFireAt + Config.SwitchCancelOpenSeconds - os.clock(), 0)
	end
	task.delay(delaySeconds, function()
		if previous and (slots[previous.Id] ~= previous or previous.Token ~= previousToken
			or not previous.Model or previous.Model.Parent ~= character) then return end
		commitSwitch(slotId, requestGeneration, characterGeneration)
	end)
	return true
end

local function fireActive()
	local slot = slots[activeSlot]
	if pendingSwitch or not gameplayEnabled or inputSuppressed or not slot or slot.State ~= "Ready"
		or chamberCount(slot) <= 0 or os.clock() < slot.NextFireAt then return false end
	local muzzleAttachment = slot.Model.PrimaryPart:FindFirstChild("MuzzleAttachment")
	local aim = gameplayCamera and gameplayCamera:GetCrosshairAim(
		CombatConfig.MaximumRangeStuds,
		{ slot.Model }
	)
	if not aim or not muzzleAttachment or not muzzleAttachment:IsA("Attachment") then return false end
	local muzzleDirection = aim.AimPoint - muzzleAttachment.WorldPosition
	if muzzleDirection.Magnitude < 0.001 then return false end
	local acceptedAt = os.clock()
	shotSequence += 1
	firearmIntent:FireServer({
		Operation = "Fire",
		Slot = slot.Id,
		Sequence = shotSequence,
		AimDirection = muzzleDirection.Unit,
		ClientTimestamp = acceptedAt,
	})
	slot.LastFireAt = acceptedAt
	slot.Token += 1
	local token = slot.Token
	local preferredBarrel = slot.LastBarrel % Config.ChamberCapacity + 1
	local barrel = if slot.Barrels[preferredBarrel]
		then preferredBarrel
		else preferredBarrel % Config.ChamberCapacity + 1
	if not slot.Barrels[barrel] then return false end
	slot.Barrels[barrel] = false
	slot.LastBarrel = barrel
	slot.NextFireAt = acceptedAt + Config.SameWeaponFireIntervalSeconds
	updateShells(slot)
	setState(slot, "Firing")
	Controller.SemanticEvent:Fire("FireAccepted", acceptedAt, { Slot = slot.Id, Barrel = barrel })
	local characterGeneration = generation
	local actionSwitchGeneration = switchGeneration
	task.delay(Config.FireAnticipationSeconds, function()
		if not callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token) then return end
		local muzzle = slot.Muzzles[barrel]
		muzzle.Transparency = 0.05
		task.delay(Config.MuzzleFlashSeconds, function()
			if not callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token)
				or not muzzle.Parent then return end
			muzzle.Color = Color3.fromRGB(142, 146, 150)
			muzzle.Transparency = 0.62
			task.delay(Config.SmokeSeconds, function()
				if callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token)
					and muzzle.Parent then
					muzzle.Color = Color3.fromRGB(255, 188, 82)
					muzzle.Transparency = 1
				end
			end)
		end)
		setState(slot, "Recovering")
	end)
	task.delay(Config.FireAnticipationSeconds + Config.FireRecoilSeconds + Config.FireRecoverySeconds, function()
		if callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token)
			and activeSlot == slot.Id then setState(slot, "Ready") end
	end)
	return true
end

local function reloadActive()
	local slot = slots[activeSlot]
	if pendingSwitch or not gameplayEnabled or inputSuppressed or not slot or slot.State ~= "Ready"
		or chamberCount(slot) >= Config.ChamberCapacity or slot.Reserve <= 0 then return false end
	slot.Token += 1
	local token = slot.Token
	local missingBarrels = {}
	for index = 1, Config.ChamberCapacity do
		if not slot.Barrels[index] and #missingBarrels < slot.Reserve then table.insert(missingBarrels, index) end
	end
	local characterGeneration = generation
	local actionSwitchGeneration = switchGeneration
	setState(slot, "ReloadOpening")
	shotSequence += 1
	firearmIntent:FireServer({ Operation = "Reload", Slot = slot.Id, Sequence = shotSequence })
	Controller.SemanticEvent:Fire("ReloadStarted", os.clock(), { Slot = slot.Id })
	task.delay(Config.ReloadOpenSeconds, function()
		if not callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token) then return end
		slot.Hinge.Transform = CFrame.new(0, 0, 0.32)
		setState(slot, "ReloadEjecting")
		task.delay(Config.ReloadEjectSeconds, function()
			if not callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token) then return end
			for _, index in missingBarrels do
				local shell = slot.Shells[index]
				local joint = slot.ShellJoints[index]
				shell.Transparency = 0.1
				joint.Transform = CFrame.new(0, 0.45, 0.25) * CFrame.Angles(math.rad(55), 0, 0)
			end
			setState(slot, "ReloadInserting")
			task.delay(Config.ReloadInsertSeconds, function()
				if not callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token) then return end
				for _, joint in slot.ShellJoints do joint.Transform = CFrame.identity end
				updateShells(slot)
				setState(slot, "ReloadClosing")
				task.delay(Config.ReloadCloseSeconds, function()
					if not callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token) then return end
					slot.Hinge.Transform = CFrame.identity
					setState(slot, "Ready")
				end)
			end)
		end)
	end)
	return true
end

local function beginTumble(action, _, grounded)
	if pendingSwitch or not slots[activeSlot] then return end
	local duration = MovementConfig.Dash.EntryDurationSeconds
		+ MovementConfig.Dash.TravelDurationSeconds
		+ MovementConfig.Dash.ExitDurationSeconds
	tumble = {
		Action = action,
		Grounded = grounded,
		StartedAt = os.clock(),
		Duration = duration,
		Slot = activeSlot,
		CharacterGeneration = generation,
	}
	Controller.SemanticEvent:Fire("TumbleStarted", tumble.StartedAt, {
		Slot = tumble.Slot,
		Direction = action,
	})
end

local function endTumble()
	if not tumble then return end
	local endingTumble = tumble
	tumble = nil
	PoseCoordinator:Release("Tumble")
	if endingTumble.CharacterGeneration == generation then
		Controller.SemanticEvent:Fire("TumbleEnded", os.clock(), {
			Slot = endingTumble.Slot,
			Direction = endingTumble.Action,
		})
	end
end

local function updatePose()
	local slot = slots[activeSlot]
	if not slot or not character or not humanoid or humanoid.Health <= 0 then
		PoseCoordinator:Release("Firearm")
		endTumble()
		return
	end
	local poses = {
		Waist = CFrame.Angles(math.rad(-3), math.rad(4), 0),
		RightShoulder = CFrame.Angles(math.rad(-72), math.rad(-8), math.rad(18)),
		LeftShoulder = CFrame.Angles(math.rad(-62), math.rad(12), math.rad(-26)),
		RightElbow = CFrame.Angles(math.rad(-18), 0, 0),
		LeftElbow = CFrame.Angles(math.rad(-32), 0, 0),
	}
	local priority = Config.IdlePriority
	local moveVector = movementEngineController and movementEngineController:GetMoveVector() or Vector3.zero
	if moveVector.Magnitude > 0.05 and character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local localMove = root.CFrame:VectorToObjectSpace(moveVector.Unit)
			poses.Waist *= CFrame.Angles(math.rad(-4 * -localMove.Z), 0, math.rad(-5 * localMove.X))
		end
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		poses.Waist *= CFrame.Angles(math.rad(-5), 0, 0)
		poses.RightShoulder *= CFrame.Angles(math.rad(-4), 0, 0)
		poses.LeftShoulder *= CFrame.Angles(math.rad(-4), 0, 0)
	end
	local aim = gameplayCamera and gameplayCamera:GetCrosshairAim(CombatConfig.MaximumRangeStuds, { slot.Model })
	if aim then
		local pitch = math.clamp(
			math.deg(math.asin(math.clamp(aim.Direction.Y, -1, 1))),
			Config.AimPitchMinimumDegrees,
			Config.AimPitchMaximumDegrees
		)
		poses.Waist *= CFrame.Angles(math.rad(-pitch * 0.45), 0, 0)
		poses.RightShoulder *= CFrame.Angles(math.rad(-pitch * 0.55), 0, 0)
		poses.LeftShoulder *= CFrame.Angles(math.rad(-pitch * 0.55), 0, 0)
	end
	if slot.State == "Firing" or slot.State == "Recovering" then
		local recoilAlpha = math.clamp(1 - (os.clock() - slot.StateStartedAt) / Config.FireRecoilSeconds, 0, 1)
		poses.Waist *= CFrame.Angles(math.rad(5 * recoilAlpha), 0, 0)
		poses.RightShoulder *= CFrame.Angles(math.rad(12 * recoilAlpha), 0, 0)
		priority = Config.ActionPriority
		local pumpAlpha = math.clamp((os.clock() - slot.StateStartedAt) / Config.FireRecoverySeconds, 0, 1)
		slot.Hinge.Transform = CFrame.new(0, 0, 0.30 * math.sin(pumpAlpha * math.pi))
	elseif string.sub(slot.State, 1, 6) == "Reload" then
		poses.RightShoulder = CFrame.Angles(math.rad(-48), math.rad(-18), math.rad(25))
		poses.LeftShoulder = CFrame.Angles(math.rad(-78), math.rad(20), math.rad(-32))
		priority = Config.ActionPriority
	else
		slot.Hinge.Transform = CFrame.identity
	end
	PoseCoordinator:Submit("Firearm", priority, poses, 0.35)

	if tumble then
		local alpha = math.clamp((os.clock() - tumble.StartedAt) / tumble.Duration, 0, 1)
		local wave = math.sin(alpha * math.pi)
		local full = not tumble.Grounded
		local angle = (full and 360 * alpha or 42 * wave)
		local tumblePose = {}
		if tumble.Action == "Forward" then tumblePose.Root = CFrame.Angles(math.rad(-angle), 0, 0)
		elseif tumble.Action == "Backward" then tumblePose.Root = CFrame.Angles(math.rad(angle), 0, 0)
		elseif tumble.Action == "Left" then tumblePose.Root = CFrame.Angles(0, 0, math.rad(angle))
		else tumblePose.Root = CFrame.Angles(0, 0, math.rad(-angle)) end
		tumblePose.Waist = CFrame.Angles(math.rad(-18 * wave), 0, 0)
		tumblePose.LeftHip = CFrame.Angles(math.rad(38 * wave), 0, math.rad(-12 * wave))
		tumblePose.RightHip = CFrame.Angles(math.rad(-24 * wave), 0, math.rad(12 * wave))
		PoseCoordinator:Submit("Tumble", Config.TumblePriority, tumblePose)
		if alpha >= 1 then endTumble() end
	end
end

local function destroyCharacterPresentation()
	generation += 1
	switchGeneration += 1
	pendingSwitch = nil
	endTumble()
	PoseCoordinator:Release("Firearm")
	if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
	for _, slot in slots do if slot.Model then slot.Model:Destroy() end end
	table.clear(slots)
	character, humanoid = nil, nil
end

local function bindCharacter(nextCharacter)
	destroyCharacterPresentation()
	local bindGeneration = generation
	characterBindingTarget = nextCharacter
	if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
	cancelDependencyWatch = CharacterDependency.ObserveHumanoidAndRoot(
		nextCharacter,
		MultiplayerConfig.CharacterDependencyTimeoutSeconds,
		function(nextHumanoid)
			if bindGeneration ~= generation or characterBindingTarget ~= nextCharacter
				or player.Character ~= nextCharacter then return end
			character, humanoid = nextCharacter, nextHumanoid
			for _, slotId in { "Primary1", "Primary2" } do
				local model, hinge, muzzles, shells, shellJoints = buildWeapon(slotId)
				model.Parent = nextCharacter
				local slot = {
					Id = slotId, Model = model, Hinge = hinge, Muzzles = muzzles, Shells = shells,
					ShellJoints = shellJoints,
					Grip = nil,
					State = "Idle",
					StateStartedAt = os.clock(),
					Barrels = table.create(Config.ChamberCapacity, true),
					Reserve = Config.StartingReserve, NextFireAt = 0, LastFireAt = nil, LastBarrel = 0, Token = 0,
				}
				slots[slotId] = slot
				if not attachSlot(slot, fighterController:GetFighter().ActiveWeaponSlot == slotId) then
					warn("[BLIKK FIREARM] Character weapon attachment parts were unavailable.")
					return
				end
				updateShells(slot)
				nextCharacter:SetAttribute("BLIKK_Client" .. slotId .. "Ready", true)
			end
			local desiredSlot = fighterController:GetFighter().ActiveWeaponSlot
			activeSlot = "Melee"
			if slots[desiredSlot] then
				switchGeneration += 1
				commitSwitch(desiredSlot, switchGeneration, generation)
			else
				activeSlot = desiredSlot
			end
			deathConnection = nextHumanoid.Died:Connect(function()
				if character == nextCharacter then destroyCharacterPresentation() end
			end)
		end,
		function()
			if bindGeneration == generation and player.Character == nextCharacter then
				warn("[BLIKK FIREARM] Character dependencies remain incomplete; continuing to observe the current character.")
			end
		end,
		{ "RightHand", "UpperTorso" }
	)
end

function Controller:GetActiveStatus()
	local slot = slots[activeSlot]
	if not slot then return nil end
	return { Slot = slot.Id, State = slot.State, Chambered = chamberCount(slot), Reserve = slot.Reserve }
end

function Controller:Init(inputManagerValue, fighterControllerValue, movementEngine, gameplayCameraValue)
	if isInitialised then return end
	isInitialised = true
	inputManager = inputManagerValue
	fighterController = fighterControllerValue
	gameplayCamera = gameplayCameraValue
	movementEngineController = movementEngine
	local remotes = ReplicatedStorage:WaitForChild("BLIKKRemotes", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	firearmIntent = remotes and remotes:WaitForChild("FirearmIntent", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	local firearmResult = remotes and remotes:WaitForChild("FirearmResult", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	if not firearmIntent or not firearmResult then error("[BLIKK FIREARM] Combat remotes unavailable", 0) end
	firearmResult.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then return end
		local slot = slots[payload.Slot]
		if not slot or type(payload.Magazine) ~= "number" or type(payload.Reserve) ~= "number" then
			if payload.Operation == "Reload" and not warnedReloadReconciliation then
				warnedReloadReconciliation = true
				warn("[BLIKK FIREARM:RELOAD_RECONCILIATION_FAILURE] Ignored malformed or stale server state.")
			end
			return
		end
		for index = 1, Config.ChamberCapacity do slot.Barrels[index] = index <= payload.Magazine end
		slot.Reserve = payload.Reserve
		updateShells(slot)
		if payload.Operation == "Reload" then
			Controller.SemanticEvent:Fire("ReloadCommitted", os.clock(), { Slot = slot.Id, Count = 1 })
		end
		publish(slot)
	end)
	inputManager.ActionBegan.Event:Connect(function(action)
		if action == "EquipWeapon1" then
			requestSwitch("Primary1")
		elseif action == "EquipWeapon2" then
			requestSwitch("Primary2")
		elseif action == "EquipMelee" then
			requestSwitch("Melee")
		elseif action == "NextWeapon" or action == "PreviousWeapon" then
			local ordered = FighterSlots.Weapon.Ordered
			local currentSlot = pendingSwitch and pendingSwitch.Slot
				or fighterController:GetFighter().ActiveWeaponSlot
			local index = table.find(ordered, currentSlot) or 1
			local offset = if action == "NextWeapon" then 1 else -1
			requestSwitch(ordered[(index - 1 + offset) % #ordered + 1])
		elseif slots[activeSlot] and action == "Primary" then fireActive()
		elseif slots[activeSlot] and action == "Reload" then reloadActive() end
	end)
	fighterController.LoadoutChanged.Event:Connect(function(changeType, slotId)
		if changeType == "ActiveWeaponSlot" and not isCommittingSwitch and slotId ~= activeSlot then
			requestSwitch(slotId)
		end
	end)
	movementEngine.DashStarted.Event:Connect(beginTumble)
	movementEngine.DashEnded.Event:Connect(function() endTumble() end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		gameplayEnabled = enabled
		if not enabled then
			switchGeneration += 1
			pendingSwitch = nil
			for _, slot in slots do cancelSlotAction(slot, "GameplayDisabled") end
			endTumble()
		elseif not inputSuppressed then
			for slotId, slot in slots do
				attachSlot(slot, slotId == activeSlot)
				setState(slot, if slotId == activeSlot then "Ready" else "Idle")
			end
		end
	end)
	inputManager.SuppressionChanged.Event:Connect(function(suppressed)
		inputSuppressed = suppressed
		if suppressed then
			switchGeneration += 1
			pendingSwitch = nil
			for _, slot in slots do cancelSlotAction(slot, "InputSuppressed") end
			endTumble()
		elseif gameplayEnabled then
			for slotId, slot in slots do
				attachSlot(slot, slotId == activeSlot)
				setState(slot, if slotId == activeSlot then "Ready" else "Idle")
			end
		end
	end)
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(removingCharacter)
		if removingCharacter ~= characterBindingTarget then return end
		characterBindingTarget = nil
		if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
		destroyCharacterPresentation()
	end)
	if player.Character then bindCharacter(player.Character) end
	RunService:BindToRenderStep(
		"BLIKKFirearmPresentation",
		Enum.RenderPriority.Character.Value + 5,
		updatePose
	)
end

return Controller
