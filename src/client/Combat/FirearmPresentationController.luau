local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PoseCoordinator = require(script.Parent.Parent.Character.PoseCoordinator)
local FirearmAimRig = require(script.Parent.FirearmAimRig)
local FirearmShotEffects = require(script.Parent.FirearmShotEffects)
local CharacterDependency = require(ReplicatedStorage.Shared.Character.CharacterDependency)
local Config = require(ReplicatedStorage.Shared.Combat.FirearmPresentationConfig)
local CombatConfig = require(ReplicatedStorage.Shared.Combat.FirearmCombatConfig)
local FeedbackConfig = require(ReplicatedStorage.Shared.Combat.FirearmShotFeedbackConfig)
local FighterSlots = require(ReplicatedStorage.Shared.Character.FighterSlots)
local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local TechniqueConfig = require(ReplicatedStorage.Shared.Movement.TechniqueConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local Controller = {}

local WEAPON_ARM_POSE_OPTIONS = {
	SuppressAnimator = {
		RightShoulder = true,
		LeftShoulder = true,
		RightElbow = true,
		LeftElbow = true,
		RightWrist = true,
		LeftWrist = true,
	},
	PriorityOverrides = {
		RightShoulder = Config.ActionPriority,
		LeftShoulder = Config.ActionPriority,
		RightElbow = Config.ActionPriority,
		LeftElbow = Config.ActionPriority,
		RightWrist = Config.ActionPriority,
		LeftWrist = Config.ActionPriority,
	},
}
Controller.StateChanged = Instance.new("BindableEvent")
Controller.SemanticEvent = Instance.new("BindableEvent")

local player = Players.LocalPlayer
local fighterController
local inputManager
local gameplayCamera
local movementEngineController
local firearmIntent
local shotEffects
local character
local humanoid
local rootPart
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
local lastServerSequence = 0
local warnedFallback = false
local warnedReloadReconciliation = false
local warnedAimRigFailure = false
local tumble = nil
local isInitialised = false
local aimRig = nil
local aimRigFailedGeneration = nil
local lastGameplayAim = nil
local aimExclusions = {}
local VALID_RESULT_OPERATIONS = {
	Equip = true,
	Fire = true,
	ReloadAccepted = true,
	ReloadCommitted = true,
	ReloadRejected = true,
}

local function destroyAimRig()
	if aimRig then aimRig:Destroy(); aimRig = nil end
end

local function warnAimRigFailure(reason)
	if warnedAimRigFailure then return end
	warnedAimRigFailure = true
	warn("[BLIKK FIREARM AIM] Arm IK unavailable; firearm gameplay remains active: " .. tostring(reason))
end

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
	local muzzle = makePart(
		model,
		"MuzzleFlash",
		dimensions.MuzzleFlash,
		Color3.fromRGB(255, 188, 82),
		Enum.Material.Neon,
		offsets.Muzzle
	)
	muzzle.Transparency = 1
	weld(receiver, muzzle)
	for index = 1, Config.ChamberCapacity do muzzles[index] = muzzle end
	for name, transform in {
		MuzzleAttachment = Config.Attachments.Muzzle,
		MuzzleReference = Config.Attachments.MuzzleReference,
		ForegripAttachment = Config.Attachments.Foregrip,
		RightHandGripAttachment = Config.Attachments.RightHandGrip,
		StockReference = Config.Attachments.StockReference,
		WeaponTopReference = Config.Attachments.WeaponTopReference,
		WeaponBottomReference = Config.Attachments.WeaponBottomReference,
	} do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.CFrame = transform
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
			and source.PrimaryPart:FindFirstChild("MuzzleReference")
			and source.PrimaryPart:FindFirstChild("ForegripAttachment")
			and source.PrimaryPart:FindFirstChild("RightHandGripAttachment")
			and source.PrimaryPart:FindFirstChild("StockReference")
			and source.PrimaryPart:FindFirstChild("WeaponTopReference")
			and source.PrimaryPart:FindFirstChild("WeaponBottomReference")
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
	if not slot.Model or not slot.Model.PrimaryPart then return false end
	if slot.Grip then slot.Grip:Destroy(); slot.Grip = nil end
	if not equipped then
		slot.MuzzleEffect:Disable()
		slot.RecoilStartedAt = nil
		slot.RecoilSerial += 1
		slot.Hinge.Transform = CFrame.identity
		for _, joint in slot.ShellJoints do joint.Transform = CFrame.identity end
		for _, muzzle in slot.Muzzles do
			muzzle.Color = Color3.fromRGB(255, 188, 82)
			muzzle.Transparency = 1
		end
		slot.Model.Parent = nil
		slot.IsRendered = false
		return true
	end
	if not character then return false end
	local isR6 = humanoid and humanoid.RigType == Enum.HumanoidRigType.R6
	local bodyPart = character:FindFirstChild(if isR6 then "Right Arm" else "RightHand")
	local rightHandGrip = slot.Model.PrimaryPart:FindFirstChild("RightHandGripAttachment")
	if not bodyPart or not bodyPart:IsA("BasePart")
		or not rightHandGrip or not rightHandGrip:IsA("Attachment") then return false end
	local grip = Instance.new("Motor6D")
	grip.Name = "BLIKK_BreakshotGrip_" .. slot.Id
	grip.Part0 = bodyPart
	grip.Part1 = slot.Model.PrimaryPart
	grip.C0 = rightHandGrip.CFrame:Inverse()
	grip.C1 = CFrame.identity
	grip.Transform = CFrame.identity
	grip.Parent = slot.Model.PrimaryPart
	slot.Grip = grip
	slot.Model:PivotTo(bodyPart.CFrame * grip.C0 * grip.C1:Inverse())
	slot.Model.Parent = character
	slot.IsRendered = true
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
	Controller.StateChanged:Fire(
		slot.Id,
		slot.State,
		chamberCount(slot),
		slot.Reserve,
		slot.UnlimitedReserve
	)
end

local function stateRetainsAimOwnership(state)
	return state == "Ready" or state == "Firing" or state == "Recovering"
		or string.sub(state, 1, 6) == "Reload"
end

local function refreshAimRigOwnership()
	local slot = slots[activeSlot]
	local isReleased = character and character:GetAttribute("BLIKK_GameplayReleased") == true
		and player:GetAttribute("BLIKK_GameplayReleased") == true
	local shouldOwn = gameplayEnabled and not inputSuppressed and not pendingSwitch
		and isReleased and character and humanoid and rootPart and slot
		and slot.IsRendered and slot.Model.Parent == character and slot.Grip
		and stateRetainsAimOwnership(slot.State)
	if not shouldOwn then
		destroyAimRig()
		return
	end
	if aimRig or aimRigFailedGeneration == generation then return end
	local nextAimRig, reason = FirearmAimRig.Create(character, humanoid, rootPart)
	if not nextAimRig then
		aimRigFailedGeneration = generation
		warnAimRigFailure(reason)
		return
	end
	aimRig = nextAimRig
end

local function readFreshGameplayAim(slot)
	if not gameplayCamera or not gameplayCamera:IsGameplayActive() then return nil end
	aimExclusions[1] = slot.Model
	local aim = gameplayCamera:GetCrosshairAim(CombatConfig.MaximumRangeStuds, aimExclusions)
	if aim then lastGameplayAim = aim end
	return aim
end

local function setState(slot, nextState)
	slot.State = nextState
	slot.StateStartedAt = os.clock()
	publish(slot)
	refreshAimRigOwnership()
end

local function cancelSlotAction(slot, reason)
	local wasReloading = string.sub(slot.State, 1, 6) == "Reload"
	slot.Token += 1
	slot.MuzzleEffect:Disable()
	slot.RecoilStartedAt = nil
	slot.RecoilSerial += 1
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
		and slot.Model
		and player.Character == character
end

local function recoilEnvelope(elapsedSeconds)
	if elapsedSeconds < 0 then return 0 end
	local recoil = FeedbackConfig.Recoil
	if elapsedSeconds < recoil.KickSeconds then
		return elapsedSeconds / recoil.KickSeconds
	end
	local afterKick = elapsedSeconds - recoil.KickSeconds
	if afterKick < recoil.HoldSeconds then return 1 end
	local returnElapsed = afterKick - recoil.HoldSeconds
	if returnElapsed >= recoil.ReturnSeconds then return 0 end
	return 1 - returnElapsed / recoil.ReturnSeconds
end

local function rotationFromDegrees(degrees)
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
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
	refreshAimRigOwnership()
	isCommittingSwitch = true
	fighterController:SetActiveWeaponSlot(slotId)
	isCommittingSwitch = false
	if firearmIntent then firearmIntent:FireServer({ Operation = "Equip", Slot = slotId }) end
	local slot = slots[slotId]
	if not slot then PoseCoordinator:Release("Firearm"); return end
	cancelSlotAction(slot, "Equip")
	if not attachSlot(slot, true) then
		setState(slot, "Interrupted")
		warnAimRigFailure("the equipped firearm hand attachment is unavailable")
		return
	end
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
	refreshAimRigOwnership()
	local previous = slots[activeSlot]
	if previous then cancelSlotAction(previous, "WeaponSwitchPending") end
	local previousToken = previous and previous.Token
	local delaySeconds = 0
	if previous and previous.LastFireAt then
		delaySeconds = math.max(previous.LastFireAt + Config.SwitchCancelOpenSeconds - os.clock(), 0)
	end
	task.delay(delaySeconds, function()
		if previous and (slots[previous.Id] ~= previous or previous.Token ~= previousToken
			or not previous.Model) then return end
		commitSwitch(slotId, requestGeneration, characterGeneration)
	end)
	return true
end

local function fireActive()
	local slot = slots[activeSlot]
	if pendingSwitch or not gameplayEnabled or inputSuppressed or not slot or slot.State ~= "Ready"
		or not slot.IsRendered or slot.Model.Parent ~= character
		then return false end
	if not gameplayCamera or not gameplayCamera:IsGameplayActive() then return false end
	if chamberCount(slot) <= 0 then
		Controller.SemanticEvent:Fire("DryFire", os.clock(), { Slot = slot.Id })
		return false
	end
	if os.clock() < slot.NextFireAt then return false end
	local muzzleAttachment = slot.Model.PrimaryPart:FindFirstChild("MuzzleAttachment")
	local aim = readFreshGameplayAim(slot)
	if not aim or not rootPart or not rootPart.Parent
		or not muzzleAttachment or not muzzleAttachment:IsA("Attachment") then return false end
	local gameplayOrigin = rootPart.Position
		+ Vector3.yAxis * CombatConfig.Aim.MuzzleUpStuds
		+ rootPart.CFrame.LookVector * CombatConfig.Aim.MuzzleForwardStuds
	local gameplayDirection = aim.AimPoint - gameplayOrigin
	if gameplayDirection.Magnitude < 0.001 then return false end
	local preferredBarrel = slot.LastBarrel % Config.ChamberCapacity + 1
	local barrel = nil
	for offset = 0, Config.ChamberCapacity - 1 do
		local candidate = (preferredBarrel - 1 + offset) % Config.ChamberCapacity + 1
		if slot.Barrels[candidate] then barrel = candidate; break end
	end
	if not barrel then return false end
	local acceptedAt = os.clock()
	shotSequence += 1
	local sequence = shotSequence
	slot.LastFireAt = acceptedAt
	slot.Token += 1
	local token = slot.Token
	slot.RecoilStartedAt = acceptedAt
	slot.RecoilSerial += 1
	local recoilSerial = slot.RecoilSerial
	local spawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
	if type(spawnGeneration) == "number" then
		shotEffects:RememberLocalOrigin(sequence, spawnGeneration, muzzleAttachment.WorldPosition)
	end
	local characterGeneration = generation
	local actionSwitchGeneration = switchGeneration
	slot.MuzzleEffect:Trigger(function()
		return callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token)
			and slot.RecoilSerial == recoilSerial and slot.IsRendered
	end)
	firearmIntent:FireServer({
		Operation = "Fire",
		Slot = slot.Id,
		Sequence = sequence,
		-- The stable root-relative origin converges on the centered crosshair point.
		-- The rendered muzzle may animate, but presentation must never steer a shot.
		AimDirection = gameplayDirection.Unit,
		ClientTimestamp = acceptedAt,
	})
	slot.Barrels[barrel] = false
	slot.LastBarrel = barrel
	slot.NextFireAt = acceptedAt + Config.SameWeaponFireIntervalSeconds
	updateShells(slot)
	setState(slot, "Firing")
	Controller.SemanticEvent:Fire("FireAccepted", acceptedAt, { Slot = slot.Id, Barrel = barrel })
	task.delay(Config.FireAnticipationSeconds, function()
		if not callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token) then return end
		setState(slot, "Recovering")
	end)
	task.delay(Config.FireAnticipationSeconds + Config.FireActionSeconds + Config.FireRecoverySeconds, function()
		if callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token)
			and activeSlot == slot.Id then setState(slot, "Ready") end
	end)
	if FeedbackConfig.DiagnosticsEnabled then
		task.delay(FeedbackConfig.Recoil.TotalDurationSeconds, function()
			if not callbackIsCurrent(slot, characterGeneration, actionSwitchGeneration, token)
				or slot.RecoilSerial ~= recoilSerial then return end
			print(string.format(
				"[BLIKK RECOIL DIAGNOSTIC] Sequence=%d StartedAt=%.6f CompletedAt=%.6f",
				sequence,
				acceptedAt,
				os.clock()
			))
		end)
	end
	return true
end

local function reloadActive()
	local slot = slots[activeSlot]
	local reloadShotWindow = TechniqueConfig.WeaponWeave.ReloadShot.ReloadAfterFireMaximumSeconds
	local isReloadShotCancel = slot and slot.LastFireAt
		and (slot.State == "Firing" or slot.State == "Recovering")
		and os.clock() - slot.LastFireAt <= reloadShotWindow
	if pendingSwitch or not gameplayEnabled or inputSuppressed or not slot
		or (slot.State ~= "Ready" and not isReloadShotCancel)
		or chamberCount(slot) >= Config.ChamberCapacity
		or (not slot.UnlimitedReserve and slot.Reserve <= 0) then return false end
	slot.Token += 1
	local token = slot.Token
	local missingBarrels = {}
	for index = 1, Config.ChamberCapacity do
		if not slot.Barrels[index]
			and (slot.UnlimitedReserve or #missingBarrels < slot.Reserve) then
			table.insert(missingBarrels, index)
		end
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

local function beginTumble(action, _, _, kind)
	if kind ~= "Tumble" or pendingSwitch or not slots[activeSlot] then return end
	local duration = MovementConfig.Tumble.EntryDurationSeconds
		+ MovementConfig.Tumble.TravelDurationSeconds
		+ MovementConfig.Tumble.ExitDurationSeconds
	tumble = {
		Action = action,
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
	if not slot or not character or not humanoid or humanoid.Health <= 0
		or not slot.IsRendered or slot.Model.Parent ~= character or not slot.Grip then
		destroyAimRig()
		PoseCoordinator:Release("Firearm")
		endTumble()
		return
	end
	refreshAimRigOwnership()
	local carryPose = Config.Pose.FallbackCarry
	local poses = {
		Waist = rotationFromDegrees(carryPose.Waist),
		RightShoulder = rotationFromDegrees(carryPose.RightShoulder),
		LeftShoulder = rotationFromDegrees(carryPose.LeftShoulder),
		RightElbow = rotationFromDegrees(carryPose.RightElbow),
		LeftElbow = rotationFromDegrees(carryPose.LeftElbow),
	}
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
	local freshAim = readFreshGameplayAim(slot)
	local aim = freshAim or lastGameplayAim
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
	local recoilElapsed = if slot.RecoilStartedAt then os.clock() - slot.RecoilStartedAt else math.huge
	local recoilAlpha = recoilEnvelope(recoilElapsed)
	if recoilAlpha > 0 then
		poses.Waist *= CFrame.Angles(math.rad(FeedbackConfig.Recoil.PitchDegrees * 0.5 * recoilAlpha), 0, 0)
		poses.RightShoulder *= CFrame.Angles(math.rad(FeedbackConfig.Recoil.PitchDegrees * recoilAlpha), 0, 0)
	end
	if string.sub(slot.State, 1, 6) == "Reload" then
		poses.RightShoulder = rotationFromDegrees(Config.Pose.Reload.RightShoulder)
		poses.LeftShoulder = rotationFromDegrees(Config.Pose.Reload.LeftShoulder)
	else
		local pumpElapsed = recoilElapsed - FeedbackConfig.Recoil.PumpDelaySeconds
		if pumpElapsed >= 0 and pumpElapsed < FeedbackConfig.Recoil.PumpCycleSeconds then
			local pumpAlpha = pumpElapsed / FeedbackConfig.Recoil.PumpCycleSeconds
			slot.Hinge.Transform = CFrame.new(
				0,
				0,
				FeedbackConfig.Recoil.PumpTravelStuds * math.sin(pumpAlpha * math.pi)
			)
		else
			slot.Hinge.Transform = CFrame.identity
		end
	end
	if aimRig then
		local shouldSolve = slot.State == "Ready" or slot.State == "Firing"
			or slot.State == "Recovering"
		if shouldSolve then
			local updated, reason = true, nil
			if freshAim then
				updated, reason = aimRig:Update(slot.Model, slot.Grip, freshAim.Direction, recoilAlpha)
			elseif aimRig:HasPose() then
				aimRig:SetEnabled(true)
			else
				updated, reason = aimRig:Update(slot.Model, slot.Grip, rootPart.CFrame.LookVector, 0)
			end
			if not updated then
				destroyAimRig()
				aimRigFailedGeneration = generation
				warnAimRigFailure(reason)
			end
		else
			aimRig:SetEnabled(false)
		end
	end
	-- Body accents yield to dash/wall counter-rotation, while arm overrides in
	-- WEAPON_ARM_POSE_OPTIONS retain action priority and crosshair ownership.
	PoseCoordinator:Submit("Firearm", Config.IdlePriority, poses, 0.35, WEAPON_ARM_POSE_OPTIONS)

	if tumble then
		local alpha = math.clamp((os.clock() - tumble.StartedAt) / tumble.Duration, 0, 1)
		local tumbleConfig = Config.Tumble
		local easedAlpha
		if alpha < tumbleConfig.FloatStartProgress then
			local phase = alpha / tumbleConfig.FloatStartProgress
			easedAlpha = tumbleConfig.FloatRotationShare * phase * phase * (3 - 2 * phase)
		elseif alpha <= tumbleConfig.FloatEndProgress then
			local phase = (alpha - tumbleConfig.FloatStartProgress)
				/ (tumbleConfig.FloatEndProgress - tumbleConfig.FloatStartProgress)
			easedAlpha = tumbleConfig.FloatRotationShare
				+ phase * tumbleConfig.FloatRotationDriftShare
		elseif alpha < tumbleConfig.RecoveryUprightProgress then
			local phase = (alpha - tumbleConfig.FloatEndProgress)
				/ (tumbleConfig.RecoveryUprightProgress - tumbleConfig.FloatEndProgress)
			-- Accelerate out of the inverted Matrix beat, then settle early enough
			-- that ground contact never catches the avatar upside down.
			phase = 1 - (1 - math.clamp(phase, 0, 1)) ^ tumbleConfig.RecoveryEaseOutPower
			easedAlpha = tumbleConfig.FloatRotationShare + tumbleConfig.FloatRotationDriftShare
				+ (1 - tumbleConfig.FloatRotationShare - tumbleConfig.FloatRotationDriftShare) * phase
		else
			easedAlpha = 1
		end
		local wave = math.sin(alpha * math.pi) ^ 0.58
		local floatPhase = math.clamp(
			(alpha - tumbleConfig.FloatStartProgress)
				/ (tumbleConfig.FloatEndProgress - tumbleConfig.FloatStartProgress),
			0,
			1
		)
		local hangtimeWave = math.sin(floatPhase * math.pi)
		local angle = tumbleConfig.RotationDegrees * easedAlpha
		local tumblePose = {}
		local lift = tumbleConfig.VisualLiftStuds * wave
			+ tumbleConfig.HangtimeLiftBonusStuds * hangtimeWave
		local bodyRotation
		if tumble.Action == "Forward" then
			bodyRotation = CFrame.Angles(math.rad(-angle), 0, 0)
		elseif tumble.Action == "Backward" then
			bodyRotation = CFrame.Angles(math.rad(angle), 0, 0)
		elseif tumble.Action == "Left" then
			bodyRotation = CFrame.Angles(0, 0, math.rad(angle))
		else
			bodyRotation = CFrame.Angles(0, 0, math.rad(-angle))
		end
		tumblePose.Root = CFrame.new(0, lift, 0) * bodyRotation
		-- The tumble is a coherent whole-body flip. Camera aim and the gameplay
		-- ray remain independent of this Motor6D presentation, while the live arm
		-- IK continues solving the weapon toward the crosshair during the roll.
		tumblePose.Waist = CFrame.Angles(
			math.rad(-tumbleConfig.WaistTuckDegrees * wave),
			0,
			math.rad(tumbleConfig.WaistBankDegrees * wave)
		)
		tumblePose.Neck = CFrame.Angles(math.rad(tumbleConfig.NeckCounterDegrees * wave), 0, 0)
		tumblePose.LeftHip = CFrame.Angles(math.rad(tumbleConfig.LeadHipTuckDegrees * wave), 0, math.rad(-12 * wave))
		tumblePose.RightHip = CFrame.Angles(math.rad(-tumbleConfig.TrailHipTuckDegrees * wave), 0, math.rad(12 * wave))
		PoseCoordinator:Submit("Tumble", Config.TumblePriority, tumblePose)
		if alpha >= 1 then endTumble() end
	end
end

local function destroyCharacterPresentation()
	generation += 1
	lastServerSequence = 0
	aimRigFailedGeneration = nil
	lastGameplayAim = nil
	switchGeneration += 1
	pendingSwitch = nil
	destroyAimRig()
	endTumble()
	PoseCoordinator:Release("Firearm")
	if deathConnection then deathConnection:Disconnect(); deathConnection = nil end
	if shotEffects then shotEffects:ClearLocalShooter() end
	for _, slot in slots do
		if slot.MuzzleEffect then slot.MuzzleEffect:Destroy() end
		if slot.Model then slot.Model:Destroy() end
	end
	table.clear(slots)
	character, humanoid, rootPart = nil, nil, nil
end

local function bindCharacter(nextCharacter)
	destroyCharacterPresentation()
	local bindGeneration = generation
	characterBindingTarget = nextCharacter
	if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
	cancelDependencyWatch = CharacterDependency.ObserveHumanoidAndRoot(
		nextCharacter,
		MultiplayerConfig.CharacterDependencyTimeoutSeconds,
		function(nextHumanoid, nextRootPart)
			if bindGeneration ~= generation or characterBindingTarget ~= nextCharacter
				or player.Character ~= nextCharacter then return end
			character, humanoid, rootPart = nextCharacter, nextHumanoid, nextRootPart
			for _, slotId in { "Primary1", "Primary2" } do
				local model, hinge, muzzles, shells, shellJoints = buildWeapon(slotId)
				local slot = {
					Id = slotId, Model = model, Hinge = hinge, Muzzles = muzzles, Shells = shells,
					ShellJoints = shellJoints,
					Grip = nil,
					MuzzleEffect = FirearmShotEffects.CreateWeaponMuzzleEffect(model, muzzles[1]),
					IsRendered = false,
					State = "Idle",
					StateStartedAt = os.clock(),
					Barrels = table.create(Config.ChamberCapacity, true),
					Reserve = Config.StartingReserve, UnlimitedReserve = false,
					NextFireAt = 0, LastFireAt = nil,
					LastBarrel = 0, Token = 0, RecoilStartedAt = nil, RecoilSerial = 0,
				}
				slots[slotId] = slot
				if not attachSlot(slot, false) then
					warn("[BLIKK FIREARM] Character weapon attachment parts were unavailable.")
					for _, builtSlot in slots do builtSlot.Model:Destroy() end
					table.clear(slots)
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
		function(observedHumanoid)
			if observedHumanoid.RigType == Enum.HumanoidRigType.R6 then
				return { "Right Arm", "Torso" }
			end
			return {
				"RightHand",
				"RightUpperArm",
				"RightLowerArm",
				"LeftHand",
				"LeftUpperArm",
				"UpperTorso",
			}
		end
	)
end

function Controller:GetActiveStatus()
	local slot = slots[activeSlot]
	if not slot then return nil end
	return {
		Slot = slot.Id,
		State = slot.State,
		Chambered = chamberCount(slot),
		Reserve = slot.Reserve,
		UnlimitedReserve = slot.UnlimitedReserve,
	}
end

function Controller:Init(
	inputManagerValue,
	fighterControllerValue,
	movementEngine,
	gameplayCameraValue,
	soundEffectsController
)
	if isInitialised then return end
	isInitialised = true
	inputManager = inputManagerValue
	fighterController = fighterControllerValue
	gameplayCamera = gameplayCameraValue
	movementEngineController = movementEngine
	local remotes = ReplicatedStorage:WaitForChild("BLIKKRemotes", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	firearmIntent = remotes and remotes:WaitForChild("FirearmIntent", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	local firearmResult = remotes and remotes:WaitForChild("FirearmResult", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	local firearmShot = remotes and remotes:WaitForChild("FirearmShot", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	if not firearmIntent or not firearmResult or not firearmShot then
		error("[BLIKK FIREARM] Combat remotes unavailable", 0)
	end
	shotEffects = FirearmShotEffects.Create(firearmShot, soundEffectsController)
	script.Destroying:Connect(function()
		if shotEffects then shotEffects:Destroy(); shotEffects = nil end
	end)
	firearmResult.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then return end
		if VALID_RESULT_OPERATIONS[payload.Operation] ~= true
			or type(payload.Sequence) ~= "number" or payload.Sequence ~= payload.Sequence
			or payload.Sequence <= -math.huge or payload.Sequence >= math.huge
			or payload.Sequence % 1 ~= 0 or payload.Sequence < lastServerSequence then return end
		local slot = slots[payload.Slot]
		local spawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
		if payload.SpawnGeneration ~= spawnGeneration then return end
		if not slot or type(payload.Magazine) ~= "number" or payload.Magazine % 1 ~= 0
			or payload.Magazine < 0 or payload.Magazine > Config.ChamberCapacity
			or type(payload.Reserve) ~= "number" or payload.Reserve % 1 ~= 0
			or payload.Reserve < 0 or payload.Reserve > CombatConfig.StartingReserve
			or type(payload.UnlimitedReserve) ~= "boolean" then
			if string.sub(tostring(payload.Operation), 1, 6) == "Reload"
				and not warnedReloadReconciliation then
				warnedReloadReconciliation = true
				warn("[BLIKK FIREARM:RELOAD_RECONCILIATION_FAILURE] Ignored malformed or stale server state.")
			end
			return
		end
		lastServerSequence = math.max(lastServerSequence, payload.Sequence)
		for index = 1, Config.ChamberCapacity do slot.Barrels[index] = index <= payload.Magazine end
		slot.Reserve = payload.Reserve
		slot.UnlimitedReserve = payload.UnlimitedReserve
		updateShells(slot)
		if payload.Operation == "ReloadCommitted" and payload.Accepted == true then
			if type(payload.Transferred) ~= "number" or payload.Transferred % 1 ~= 0
				or payload.Transferred < 1 or payload.Transferred > Config.ChamberCapacity then
				if not warnedReloadReconciliation then
					warnedReloadReconciliation = true
					warn("[BLIKK FIREARM:RELOAD_RECONCILIATION_FAILURE] Ignored invalid transfer count.")
				end
				return
			end
			Controller.SemanticEvent:Fire("ReloadCommitted", os.clock(), {
				Slot = slot.Id,
				Count = payload.Transferred,
			})
		elseif payload.Operation == "ReloadRejected"
			and string.sub(slot.State, 1, 6) == "Reload" then
			cancelSlotAction(slot, "ServerRejected")
			if activeSlot == slot.Id then setState(slot, "Ready") end
		end
		publish(slot)
	end)
	inputManager.ActionBegan.Event:Connect(function(action)
		local recoveryEquipped = character
			and character:GetAttribute("BLIKK_ActiveRecoveryItem") ~= ""
			and character:GetAttribute("BLIKK_ActiveRecoveryItem") ~= nil
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
		elseif not recoveryEquipped and slots[activeSlot] and action == "Primary" then fireActive()
		elseif not recoveryEquipped and slots[activeSlot] and action == "Reload" then reloadActive() end
	end)
	fighterController.LoadoutChanged.Event:Connect(function(changeType, slotId)
		if changeType == "ActiveWeaponSlot" and not isCommittingSwitch and slotId ~= activeSlot then
			requestSwitch(slotId)
		end
	end)
	movementEngine.DashStarted.Event:Connect(beginTumble)
	movementEngine.DashEnded.Event:Connect(function(_, _, _, kind)
		if kind == "Tumble" then endTumble() end
	end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		gameplayEnabled = enabled
		if not enabled then
			switchGeneration += 1
			pendingSwitch = nil
			lastGameplayAim = nil
			for _, slot in slots do
				cancelSlotAction(slot, "GameplayDisabled")
				attachSlot(slot, false)
			end
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
