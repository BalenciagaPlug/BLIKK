local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local PoseCoordinator = require(script.Parent.Parent.Character.PoseCoordinator)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before melee presentation")
local Config = require(Shared.Combat.MeleePresentationConfig)

local Controller = {}
Controller.StateChanged = Instance.new("BindableEvent")
Controller.TechniqueHook = Instance.new("BindableEvent")
Controller.SemanticEvent = Instance.new("BindableEvent")

local CHARACTER_PART_WAIT_SECONDS = 3

local player = Players.LocalPlayer
local fighterController
local inputManager
local movementEngine
local character
local humanoid
local weaponModel
local gripJoint
local trail
local connections = {}
local state = "Holstered"
local stateStarted = 0
local generation = 0
local characterGeneration = 0
local pendingCharacter = nil
local blockHeld = false
local heldBlockActions = {}
local bufferedBlockAt
local cancelWindowReported = false
local dashActive = false
local wallPresentationActive = false
local isInitialised = false
local authoredTrack
local playHook
local playAuthoredHook
local slashVariant = 1
local lastSlashAcceptedAt = -math.huge
local visualState = "Holstered"

local function diagnose(message)
	if Config.Diagnostics.Enabled then print("[BLIKK MELEE] " .. message) end
end

local function disconnectCharacterConnections()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

local function resetPose()
	PoseCoordinator:Release("Melee")
end

local function setState(nextState)
	if state == nextState then return end
	state = nextState
	stateStarted = os.clock()
	if playHook then playHook(nextState) end
	Controller.StateChanged:Fire(nextState)
end

local function setVisualState(nextState)
	if visualState == nextState then return end
	visualState = nextState
	Controller.StateChanged:Fire(nextState)
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
	part.CastShadow = SessionSettings:Get("EffectsQuality") ~= "LOW"
	part.Parent = parent
	return part
end

local function weld(handle, part)
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = handle
	weldConstraint.Part1 = part
	weldConstraint.Parent = part
end

local function buildTrainingKatana()
	local dimensions = Config.TrainingKatana.Dimensions
	local geometry = Config.TrainingKatana.Geometry
	local handleHalfLength = dimensions.Handle.Y * 0.5
	local guardCenterY = handleHalfLength + dimensions.Guard.Y * 0.5
	local bladeStartY = handleHalfLength + dimensions.Guard.Y + geometry.BladeGuardGapStuds
	local bladeCenterY = bladeStartY + dimensions.Blade.Y * 0.5
	local bladeEndY = bladeStartY + dimensions.Blade.Y
	local pommelCenterY = -handleHalfLength - dimensions.Pommel.Y * 0.5
	local trailRootY = bladeStartY + dimensions.Blade.Y * geometry.TrailRootBladeFraction
	local trailTipY = bladeEndY - dimensions.Blade.Y * geometry.TrailTipInsetBladeFraction
	local model = Instance.new("Model")
	model.Name = "TrainingKatana"
	model:SetAttribute("BLIKK_WeaponDefinition", "TrainingKatana")
	model:SetAttribute("BLIKK_PresentationOnly", true)
	local handle = makePart(model, "Handle", dimensions.Handle, Color3.fromRGB(25, 25, 29), Enum.Material.Metal)
	local grip = makePart(model, "Grip", dimensions.Grip, Color3.fromRGB(53, 42, 61), Enum.Material.Fabric, CFrame.new(0, geometry.GripCenterYStuds, 0))
	local guard = makePart(model, "Guard", dimensions.Guard, Color3.fromRGB(92, 66, 115), Enum.Material.Metal, CFrame.new(0, guardCenterY, 0))
	local blade = makePart(model, "Blade", dimensions.Blade, Color3.fromRGB(92, 98, 108), Enum.Material.Metal, CFrame.new(0, bladeCenterY, 0))
	local edge = makePart(model, "BladeEdge", dimensions.BladeEdge, Color3.fromRGB(229, 226, 213), Enum.Material.SmoothPlastic, CFrame.new(geometry.EdgeOffsetXStuds, bladeCenterY, 0))
	local pommel = makePart(model, "Pommel", dimensions.Pommel, Color3.fromRGB(106, 71, 135), Enum.Material.Metal, CFrame.new(0, pommelCenterY, 0))
	for _, part in { grip, guard, blade, edge, pommel } do weld(handle, part) end
	local trailStart = Instance.new("Attachment")
	trailStart.Name = "TrailAttachmentStart"
	trailStart.Position = Vector3.new(0, trailRootY, 0)
	trailStart.Parent = handle
	local trailEnd = Instance.new("Attachment")
	trailEnd.Name = "TrailAttachmentEnd"
	trailEnd.Position = Vector3.new(0, trailTipY, 0)
	trailEnd.Parent = handle
	local bladeTrail = Instance.new("Trail")
	bladeTrail.Name = "BladeTrail"
	bladeTrail.Attachment0 = trailStart
	bladeTrail.Attachment1 = trailEnd
	bladeTrail.Color = ColorSequence.new(Color3.fromRGB(224, 218, 230), Color3.fromRGB(118, 63, 166))
	bladeTrail.LightEmission = 0.25
	bladeTrail.Enabled = false
	bladeTrail.Parent = handle
	model.PrimaryPart = handle
	return model, bladeTrail
end

local function attachWeaponTo(model, targetCharacter, targetHumanoid, existingGrip, mode, dependencyDeadline)
	if not model or not targetCharacter then return false, existingGrip end
	local attachment = if mode == "Equipped" then Config.TrainingKatana.EquippedAttachment else Config.TrainingKatana.HolsteredAttachment
	local fallbackPartName = if mode == "Equipped" then "Right Arm" else "Torso"
	local targetPartName = if targetHumanoid and targetHumanoid.RigType == Enum.HumanoidRigType.R6
		then fallbackPartName
		else attachment.PartName
	local bodyPart = targetCharacter:FindFirstChild(targetPartName)
		or targetCharacter:WaitForChild(
			targetPartName,
			math.max(0, (dependencyDeadline or (os.clock() + CHARACTER_PART_WAIT_SECONDS)) - os.clock())
		)
	if not bodyPart or not bodyPart:IsA("BasePart") then return false, existingGrip end
	local handle = model.PrimaryPart
	if not handle then return false, existingGrip end
	local nextGrip = existingGrip
	if nextGrip and (nextGrip.Parent ~= handle or nextGrip.Part1 ~= handle) then
		nextGrip = nil
	end
	if not nextGrip then
		nextGrip = Instance.new("Motor6D")
		nextGrip.Name = "BLIKK_KatanaGrip"
		nextGrip.Part1 = handle
		nextGrip.Parent = handle
	end
	nextGrip.Part0 = bodyPart
	nextGrip.C0 = attachment.Offset
	nextGrip.C1 = attachment.GripPivot
	return true, nextGrip
end

local function attachWeapon(mode)
	local bindGeneration = characterGeneration
	local targetCharacter, targetHumanoid, model = character, humanoid, weaponModel
	local attached, nextGrip = attachWeaponTo(
		model,
		targetCharacter,
		targetHumanoid,
		gripJoint,
		mode,
		os.clock() + CHARACTER_PART_WAIT_SECONDS
	)
	if not attached or bindGeneration ~= characterGeneration or targetCharacter ~= character
		or model ~= weaponModel or targetCharacter ~= player.Character then return false end
	gripJoint = nextGrip
	return true
end

local function isAirborne()
	return humanoid and humanoid.FloorMaterial == Enum.Material.Air
end

local function isMeleeActive()
	local fighter = fighterController:GetFighter()
	return fighter.ActiveWeaponSlot == "Melee" and fighter.Weapons.Melee == "TrainingKatana"
end

playAuthoredHook = function(hookName, looped, priority)
	if authoredTrack then authoredTrack:Stop(0.04); authoredTrack:Destroy(); authoredTrack = nil end
	if not humanoid or not isMeleeActive() then return end
	local animationId = fighterController:GetAnimationHook("Melee", hookName)
	if type(animationId) ~= "string" or animationId == "" or not animationId:match("^rbxassetid://%d+$") then return end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	authoredTrack = animator:LoadAnimation(animation)
	animation:Destroy()
	authoredTrack.Priority = priority
	authoredTrack.Looped = looped
	authoredTrack:Play(0.04)
end

playHook = function(nextState)
	local hookByState = {
		Equipping = "KatanaEquip", Unequipping = "KatanaUnequip", MeleeIdle = if isAirborne() then "KatanaAirIdle" else "KatanaIdle",
		Slashing = if isAirborne() then "KatanaAirSlash" else "KatanaSlash1",
		Blocking = if isAirborne() then "KatanaAirBlock" else "KatanaBlockEnter",
	}
	local hook = hookByState[nextState]
	if hook then playAuthoredHook(hook, nextState == "MeleeIdle", if nextState == "MeleeIdle" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action) end
end

local function updateTrail(enabled)
	if not trail then return end
	local quality = SessionSettings:Get("EffectsQuality")
	local visible = SessionSettings:Get("BladeTrailVisible") and SessionSettings:Get("WeaponTrailsEnabled")
		and not SessionSettings:Get("ReducedEffects") and quality ~= "LOW"
	trail.Enabled = enabled and visible
	trail.Lifetime = if quality == "HIGH" then Config.Trail.HighLifetimeSeconds else Config.Trail.MediumLifetimeSeconds
	local opacity = math.clamp(SessionSettings:Get("BladeTrailOpacity") or Config.Trail.DefaultOpacity, 0, 1)
	trail.Transparency = NumberSequence.new(opacity, 1)
end

local function updateWeaponQuality()
	if not weaponModel then return end
	local castsShadow = SessionSettings:Get("EffectsQuality") ~= "LOW"
	for _, descendant in weaponModel:GetDescendants() do
		if descendant:IsA("BasePart") then descendant.CastShadow = castsShadow end
	end
	updateTrail(state == "Slashing")
end

local function interrupt(nextState)
	generation += 1
	blockHeld = false
	table.clear(heldBlockActions)
	bufferedBlockAt = nil
	updateTrail(false)
	if authoredTrack then authoredTrack:Stop(0.03); authoredTrack:Destroy(); authoredTrack = nil end
	resetPose()
	setState(nextState or "Interrupted")
end

local function enterBlock(cancelledSlash)
	bufferedBlockAt = nil
	updateTrail(false)
	setState("Blocking")
	setVisualState(if cancelledSlash
		then (if isAirborne() then "AirSlashToBlockCancel" else "SlashToBlockCancel")
		else "BlockEnter")
	Controller.SemanticEvent:Fire("BlockAccepted", os.clock(), { Airborne = isAirborne(), Cancel = cancelledSlash })
	if isAirborne() then
		Controller.TechniqueHook:Fire(if cancelledSlash then "AirSlashCancelledToBlock" else "AirBlockAccepted", os.clock())
	end
	if cancelledSlash then Controller.TechniqueHook:Fire("SlashCancelledToBlock", os.clock(), isAirborne()) end
	if cancelledSlash then diagnose("SlashCancelledToBlock") end
	local blockGeneration = generation
	task.delay(Config.Slash.PostCancelBlockEnterBlendSeconds, function()
		if generation == blockGeneration and state == "Blocking" then
			setVisualState("BlockHold")
			playAuthoredHook(if isAirborne() then "KatanaAirBlock" else "KatanaBlockHold", true, Enum.AnimationPriority.Action)
		end
	end)
end

local function acceptSlash()
	if not isMeleeActive() or state == "Slashing" or state == "Equipping" or state == "Unequipping" then return end
	local acceptedAt = os.clock()
	if acceptedAt - lastSlashAcceptedAt > Config.Slash.SequenceResetSeconds then slashVariant = 1 else slashVariant = 3 - slashVariant end
	lastSlashAcceptedAt = acceptedAt
	bufferedBlockAt = nil
	cancelWindowReported = false
	setState("Slashing")
	setVisualState(if wallPresentationActive
		then "WallSlash"
		elseif isAirborne() then "AirSlash"
		else "GroundSlash" .. tostring(slashVariant))
	Controller.SemanticEvent:Fire("SlashAccepted", acceptedAt, { Airborne = isAirborne(), Variant = slashVariant })
	movementEngine:ConfirmSlashAccepted(acceptedAt)
	Controller.TechniqueHook:Fire("SlashAccepted", acceptedAt, isAirborne())
	if isAirborne() then Controller.TechniqueHook:Fire("AirSlashAccepted", acceptedAt) end
	diagnose("SlashAccepted")
end

local function beginBlock(action)
	if not isMeleeActive() then return end
	heldBlockActions[action] = true
	blockHeld = true
	if state ~= "Slashing" then enterBlock(false); return end
	local elapsed = os.clock() - stateStarted
	if elapsed >= Config.Slash.CancelWindowOpenSeconds and elapsed <= Config.Slash.CancelWindowCloseSeconds then
		enterBlock(true)
	elseif elapsed < Config.Slash.CancelWindowOpenSeconds and Config.Slash.CancelWindowOpenSeconds - elapsed <= Config.Slash.EarlyInputBufferSeconds then
		bufferedBlockAt = os.clock()
		diagnose("CancelBuffered")
	else
		bufferedBlockAt = os.clock()
		diagnose("CancelRejectedLate")
	end
end

local function poseForState(now)
	local airborne = isAirborne()
	if state == "Equipping" and now - stateStarted >= Config.Equip.DurationSeconds then setState("MeleeIdle") end
	if state == "Equipping" and now - stateStarted >= Config.Equip.DurationSeconds then setVisualState(if airborne then "AirIdle" else "GroundIdle") end
	if state == "Unequipping" and now - stateStarted >= Config.Equip.UnequipDurationSeconds then setState("Holstered"); setVisualState("Holstered") end
	if state == "Slashing" then
		local elapsed = now - stateStarted
		local activeStart = Config.Slash.AnticipationSeconds
		local activeEnd = activeStart + Config.Slash.ActiveSeconds
		local total = activeEnd + Config.Slash.RecoverySeconds
		if not cancelWindowReported and elapsed >= Config.Slash.CancelWindowOpenSeconds then
			cancelWindowReported = true
			diagnose("CancelWindowOpened")
		end
		if bufferedBlockAt and blockHeld and elapsed >= Config.Slash.CancelWindowOpenSeconds and elapsed <= Config.Slash.CancelWindowCloseSeconds then enterBlock(true) end
		updateTrail(elapsed >= activeStart and elapsed < activeEnd)
		if elapsed >= total then
			updateTrail(false)
			if blockHeld and bufferedBlockAt then enterBlock(false) else setState("MeleeIdle"); setVisualState(if airborne then "AirIdle" else "GroundIdle") end
		end
	end
	if state == "Holstered" or state == "Interrupted" or state == "Equipping" or state == "Unequipping" then return nil end
	if dashActive and not airborne and state ~= "Slashing" and state ~= "Blocking" then return nil end
	local poses = {}
	if state == "Slashing" then
		local elapsed = now - stateStarted
		local activeStart = Config.Slash.AnticipationSeconds
		local swingAlpha = math.clamp((elapsed - activeStart) / Config.Slash.ActiveSeconds, 0, 1)
		poses.Root = CFrame.Angles(0, math.rad(-20 + 58 * swingAlpha), math.rad(-5))
		poses.Waist = CFrame.Angles(math.rad(-5), math.rad(28 - 70 * swingAlpha), math.rad(8))
		poses.RightShoulder = CFrame.Angles(math.rad(-72 + 45 * swingAlpha), math.rad(-18), math.rad(48 - 90 * swingAlpha))
		poses.LeftShoulder = CFrame.Angles(math.rad(-42), math.rad(10), math.rad(-30 + 35 * swingAlpha))
	elseif state == "Blocking" then
		poses.Waist = CFrame.Angles(math.rad(-4), math.rad(-12), math.rad(3))
		poses.RightShoulder = CFrame.Angles(math.rad(-78), math.rad(-20), math.rad(62))
		poses.LeftShoulder = CFrame.Angles(math.rad(-58), math.rad(15), math.rad(-38))
		poses.RightElbow = CFrame.Angles(math.rad(-35), 0, 0)
	else
		for alias, degrees in Config.Pose.EquippedIdle do
			if wallPresentationActive
				and alias ~= "RightShoulder"
				and alias ~= "RightElbow"
				and alias ~= "RightWrist" then
				continue
			end
			if dashActive and alias == "Waist" then continue end
			if airborne then
				degrees += Config.Pose.EquippedAirborneOffsets[alias] or Vector3.zero
			end
			poses[alias] = CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
		end
	end
	if airborne and not dashActive and not wallPresentationActive then
		poses.Root = poses.Root or CFrame.Angles(math.rad(Config.Pose.AirReadyTorsoDegrees), 0, 0)
		poses.LeftHip = CFrame.Angles(math.rad(Config.Pose.AirReadyHipDegrees), 0, math.rad(-5))
		poses.RightHip = CFrame.Angles(math.rad(-Config.Pose.AirReadyHipDegrees * 0.65), 0, math.rad(5))
	end
	return poses
end

local function applyPose(deltaTime)
	if not character or not humanoid or humanoid.Health <= 0 then resetPose(); return end
	local now = os.clock()
	local poses = poseForState(now)
	if not poses then resetPose(); return end
	local blockBlend = if state == "Blocking" then math.clamp((now - stateStarted) / Config.Slash.PostCancelBlockEnterBlendSeconds, 0, 1) else 1
	local idleBlendSpeed = if isAirborne()
		then Config.Pose.AirborneBlendSpeed
		else Config.Pose.IdleBlendSpeed
	local idleBlend = 1 - math.exp(-idleBlendSpeed * deltaTime)
	local blend = if state == "MeleeIdle" then idleBlend else blockBlend
	PoseCoordinator:Submit("Melee", if state == "Slashing" or state == "Blocking" then 40 else 20, poses, blend)
end

local function bindCharacter(nextCharacter)
	characterGeneration += 1
	local bindCharacterGeneration = characterGeneration
	pendingCharacter = nextCharacter
	interrupt("Interrupted")
	disconnectCharacterConnections()
	if weaponModel then weaponModel:Destroy() end
	gripJoint = nil
	character, humanoid, weaponModel, trail = nil, nil, nil, nil
	local dependencyDeadline = os.clock() + CHARACTER_PART_WAIT_SECONDS
	local nextHumanoid = nextCharacter:FindFirstChild("Humanoid")
		or nextCharacter:WaitForChild("Humanoid", math.max(0, dependencyDeadline - os.clock()))
	if bindCharacterGeneration ~= characterGeneration or nextCharacter ~= player.Character
		or not nextHumanoid or not nextHumanoid:IsA("Humanoid") then
		if bindCharacterGeneration == characterGeneration then pendingCharacter = nil end
		if bindCharacterGeneration == characterGeneration and nextCharacter == player.Character then
			warn("[BLIKK MELEE] Character bind timed out waiting for Humanoid.")
		end
		return
	end
	local nextWeaponModel, nextTrail = buildTrainingKatana()
	nextWeaponModel.Parent = nextCharacter
	local attached, nextGrip = attachWeaponTo(
		nextWeaponModel,
		nextCharacter,
		nextHumanoid,
		nil,
		if isMeleeActive() then "Equipped" else "Holstered",
		dependencyDeadline
	)
	if not attached or bindCharacterGeneration ~= characterGeneration
		or nextCharacter ~= player.Character or nextWeaponModel.Parent ~= nextCharacter then
		if nextWeaponModel.Parent then nextWeaponModel:Destroy() end
		if bindCharacterGeneration == characterGeneration then pendingCharacter = nil end
		return
	end
	pendingCharacter = nil
	character, humanoid = nextCharacter, nextHumanoid
	weaponModel, trail, gripJoint = nextWeaponModel, nextTrail, nextGrip
	setState(if isMeleeActive() then "MeleeIdle" else "Holstered")
	setVisualState(if isMeleeActive() then "GroundIdle" else "Holstered")
	character:SetAttribute("BLIKK_ClientMeleeReady", true)
	table.insert(connections, humanoid.Died:Connect(function()
		if bindCharacterGeneration == characterGeneration then interrupt("Interrupted") end
	end))
	table.insert(connections, humanoid.StateChanged:Connect(function(_, nextHumanoidState)
		if bindCharacterGeneration ~= characterGeneration or character ~= nextCharacter then return end
		if nextHumanoidState == Enum.HumanoidStateType.Landed or nextHumanoidState == Enum.HumanoidStateType.Running then
			if isMeleeActive() and state ~= "Slashing" and state ~= "Blocking" then setState("MeleeIdle") end
		end
	end))
end

function Controller:GetState() return state end

function Controller:Init(inputManagerValue, fighterControllerValue, movementEngineValue, wallInteractionController)
	if isInitialised then return end
	isInitialised = true
	inputManager, fighterController, movementEngine = inputManagerValue, fighterControllerValue, movementEngineValue
	inputManager.ActionBegan.Event:Connect(function(action)
		if isMeleeActive() and (action == "Primary" or action == "Slash") then acceptSlash()
		elseif isMeleeActive() and (action == "Secondary" or action == "Block") then beginBlock(action) end
	end)
	inputManager.ActionEnded.Event:Connect(function(action)
		if action == "Secondary" or action == "Block" then
			heldBlockActions[action] = nil
			blockHeld = next(heldBlockActions) ~= nil
			bufferedBlockAt = nil
			if state == "Blocking" and not blockHeld then
				setState("MeleeIdle")
				setVisualState("BlockExit")
				local releasedAt = stateStarted
				playAuthoredHook("KatanaBlockExit", false, Enum.AnimationPriority.Action)
				task.delay(Config.Block.ExitPresentationSeconds, function()
					if state == "MeleeIdle" and stateStarted == releasedAt then
						setVisualState(if isAirborne() then "AirIdle" else "GroundIdle")
						playHook("MeleeIdle")
					end
				end)
			end
		end
	end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		if not enabled then interrupt(if isMeleeActive() then "MeleeIdle" else "Holstered") end
	end)
	inputManager.SuppressionChanged.Event:Connect(function(suppressed)
		if suppressed then interrupt(if isMeleeActive() then "MeleeIdle" else "Holstered") end
	end)
	fighterController.LoadoutChanged.Event:Connect(function(changeType)
		if changeType == "ActiveWeaponSlot" and character then
			if isMeleeActive() then
				local wasHolstered = state == "Holstered"
				attachWeapon("Equipped")
				setState("Equipping")
				setVisualState("Equip")
				if wasHolstered then
					Controller.SemanticEvent:Fire("WeaponEquipped", os.clock(), { Slot = "Melee" })
				end
			elseif state ~= "Holstered" and state ~= "Unequipping" then
				interrupt("Unequipping")
				setVisualState("Unequip")
				Controller.SemanticEvent:Fire("WeaponUnequipped", os.clock(), { Slot = "Melee" })
				attachWeapon("Holstered")
			end
		end
	end)
	movementEngine.DashStarted.Event:Connect(function()
		dashActive = true
		resetPose()
	end)
	movementEngine.DashEnded.Event:Connect(function() dashActive = false end)
	wallInteractionController.StateChanged.Event:Connect(function(nextState)
		wallPresentationActive = nextState == "VerticalWallRun"
			or nextState == "HorizontalWallRun"
			or nextState == "WallJumpRecovery"
		if wallPresentationActive then
			resetPose()
			if isMeleeActive() and state == "MeleeIdle" then setVisualState("WallReady") end
		elseif isMeleeActive() and state == "MeleeIdle" then
			setVisualState(if isAirborne() then "AirIdle" else "GroundIdle")
		end
	end)
	SessionSettings.Changed.Event:Connect(function(key)
		if key == "EffectsQuality" or key == "ReducedEffects" or key == "BladeTrailVisible"
			or key == "BladeTrailOpacity" or key == "WeaponTrailsEnabled" then updateWeaponQuality() end
	end)
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(removingCharacter)
		if pendingCharacter == removingCharacter then
			characterGeneration += 1
			pendingCharacter = nil
		end
		if character == removingCharacter then
			characterGeneration += 1
			interrupt("Interrupted")
			disconnectCharacterConnections()
			if weaponModel then weaponModel:Destroy() end
			character, humanoid, weaponModel, gripJoint, trail = nil, nil, nil, nil, nil
		end
	end)
	if player.Character then bindCharacter(player.Character) end
	RunService:BindToRenderStep("BLIKKMeleePresentation", Enum.RenderPriority.Character.Value + 3, applyPose)
end

return Controller
