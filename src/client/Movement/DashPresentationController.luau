local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local PoseCoordinator = require(script.Parent.Parent.Character.PoseCoordinator)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before dash presentation")
local CharacterDependency = require(Shared.Character.CharacterDependency)
local MovementConfig = require(Shared.Movement.MovementConfig)
local MultiplayerConfig = require(Shared.Multiplayer.MultiplayerConfig)
local RenderQualityConfig = require(Shared.Settings.RenderQualityConfig)

local Controller = {}
local config = MovementConfig.Dash.Presentation
local activeAction = nil
local airReady = false
local humanoidStateConnection = nil
local activeRootPart = nil
local activeDirection = nil
local activeGrounded = false
local activeProgress = 0
local previousRootPosition = nil
local activeStreaks = {}
local ownedStreakParts = {}
local isInitialised = false
local characterGeneration = 0
local boundCharacter = nil
local characterBindingTarget = nil
local cancelDependencyWatch = nil
local dashSound = nil

local function renderValue(key)
	local preset = RenderQualityConfig.Presets[SessionSettings:Get("RenderPreset")]
	return if preset then preset[key] else SessionSettings:Get(key)
end

local directionPose = {
	Forward = { Pitch = -1, Roll = 0, Twist = 1 },
	Backward = { Pitch = 1, Roll = 0, Twist = -1 },
	Left = { Pitch = 0, Roll = -1, Twist = 1 },
	Right = { Pitch = 0, Roll = 1, Twist = -1 },
}

local function resetJoints()
	PoseCoordinator:Release("Dash")
end

function Controller:Interrupt()
	activeAction = nil
	airReady = false
	activeRootPart = nil
	activeDirection = nil
	activeProgress = 0
	previousRootPosition = nil
	table.clear(activeStreaks)
	for part in ownedStreakParts do
		if part.Parent then part:Destroy() end
	end
	table.clear(ownedStreakParts)
	resetJoints()
	if dashSound then dashSound:Stop() end
end

local function destroyDashSound()
	if not dashSound then return end
	dashSound:Destroy()
	dashSound = nil
end

local function bindDashSound(rootPart)
	destroyDashSound()
	if config.SoundId == "" or not rootPart then return end
	local sound = Instance.new("Sound")
	sound.Name = "BLIKKDashWhoosh"
	sound.SoundId = config.SoundId
	sound.Volume = config.SoundVolume
	sound.SoundGroup = SoundService:FindFirstChild("BLIKK_Dash")
	sound.Parent = rootPart
	dashSound = sound
end

local function createBeamStreak(startPosition, endPosition, width, lifetime)
	local startPart = Instance.new("Part")
	startPart.Anchored, startPart.CanCollide, startPart.CanQuery, startPart.CanTouch = true, false, false, false
	startPart.Transparency, startPart.Size, startPart.Position = 1, Vector3.one * 0.05, startPosition
	startPart.Parent = Workspace
	local endPart = startPart:Clone()
	endPart.Position, endPart.Parent = endPosition, Workspace
	local startAttachment = Instance.new("Attachment")
	startAttachment.Parent = startPart
	local endAttachment = Instance.new("Attachment")
	endAttachment.Parent = endPart
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = startAttachment, endAttachment
	beam.Color = ColorSequence.new(config.StreakColor)
	beam.LightEmission = 0.35
	beam.Transparency = NumberSequence.new(config.StreakTransparency, 1)
	beam.Width0, beam.Width1 = width, width * 0.35
	beam.FaceCamera = true
	beam.Parent = startPart
	Debris:AddItem(startPart, lifetime)
	Debris:AddItem(endPart, lifetime)
	ownedStreakParts[startPart] = true
	ownedStreakParts[endPart] = true
	task.delay(lifetime, function()
		ownedStreakParts[startPart] = nil
		ownedStreakParts[endPart] = nil
	end)
	return { StartPart = startPart, EndPart = endPart }
end

local function emitGroundAccent(rootPart, direction)
	local accent = Instance.new("Part")
	accent.Name = "BLIKKDashDeparture"
	accent.Anchored, accent.CanCollide, accent.CanQuery, accent.CanTouch = true, false, false, false
	accent.Material = Enum.Material.Neon
	accent.Color = Color3.fromRGB(133, 190, 76)
	accent.Transparency = 0.45
	accent.Size = Vector3.new(config.GroundAccentSizeStuds, 0.04, 0.16)
	accent.CFrame = CFrame.lookAt(rootPart.Position - Vector3.new(0, 2.8, 0), rootPart.Position - direction - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, math.pi / 2, 0)
	accent.Parent = Workspace
	Debris:AddItem(accent, config.GroundAccentLifetimeSeconds)
end

local function streakDirection(rootPart, fallbackDirection, grounded, displacement)
	local tangent = displacement
	if grounded then tangent = Vector3.new(tangent.X, 0, tangent.Z) end
	if tangent.Magnitude < config.StreakMinimumDisplacementStuds then
		tangent = rootPart.AssemblyLinearVelocity
		if grounded then tangent = Vector3.new(tangent.X, 0, tangent.Z) end
	end
	if tangent.Magnitude < config.StreakMinimumDisplacementStuds then tangent = fallbackDirection end
	return tangent.Unit
end

local function positionStreaks(rootPart, direction)
	for _, streak in activeStreaks do
		if streak.StartPart.Parent and streak.EndPart.Parent then
			local start = rootPart.Position + Vector3.new(0, streak.Height, 0)
			streak.StartPart.Position = start
			streak.EndPart.Position = start - direction * config.StreakLengthStuds
		end
	end
end

local function emitStreaks(rootPart, direction, grounded)
	if SessionSettings:Get("ReducedEffects") then return end
	local quality = SessionSettings:Get("EffectsQuality")
	local count = if quality == "LOW" then config.LowStreakCount else config.StreakCount
	count = math.max(1, math.floor(count * renderValue("ParticleDensity") + 0.5))
	local lifetimeMultiplier = if quality == "HIGH" then 1 elseif quality == "MEDIUM" then config.MediumLifetimeMultiplier else config.LowLifetimeMultiplier
	local widthMultiplier = if quality == "MEDIUM" then config.MediumWidthMultiplier else 1
	local firstIndex = if count == 1 then 2 else 1
	for offset = 0, count - 1 do
		local index = firstIndex + offset
		local start = rootPart.Position + Vector3.new(0, config.StreakHeightsStuds[index], 0)
		local streak = createBeamStreak(start, start - direction * config.StreakLengthStuds, config.StreakWidthsStuds[index] * widthMultiplier, config.StreakLifetimeSeconds * lifetimeMultiplier)
		streak.Height = config.StreakHeightsStuds[index]
		table.insert(activeStreaks, streak)
	end
	if grounded then emitGroundAccent(rootPart, direction) end
end

local function applyPose()
	if (not activeAction and not airReady) or not config.Enabled then
		PoseCoordinator:Release("Dash")
		return
	end
	local poses = {}
	if airReady and not activeAction then
		local rootPose = CFrame.Angles(math.rad(-4), 0, 0)
		poses.Root = rootPose
		poses.Waist = rootPose.Rotation:Inverse() * CFrame.Angles(math.rad(2), 0, 0)
		local readyTuck = math.rad(config.AirReadyHipTuckDegrees)
		local readySpread = math.rad(config.AirHipSpreadDegrees * 0.5)
		poses.LeftHip = CFrame.Angles(readyTuck, 0, -readySpread)
		poses.RightHip = CFrame.Angles(readyTuck, 0, readySpread)
		PoseCoordinator:Submit("Dash", 30, poses)
		return
	end
	local pose = directionPose[activeAction]
	if not pose then return end
	local function smoothstep(alpha)
		alpha = math.clamp(alpha, 0, 1)
		return alpha * alpha * (3 - 2 * alpha)
	end
	local entry = smoothstep(activeProgress / config.StepPeakProgress)
	local recovery = 1 - smoothstep(
		(activeProgress - config.StepRecoveryStartProgress)
			/ (1 - config.StepRecoveryStartProgress)
	)
	local actionStrength = entry * recovery
	if not activeGrounded then
		-- Airborne traversal deliberately has no leading foot. The compact,
		-- symmetrical pose reads as controlled flight and leaves weapon arms to
		-- their higher-priority aim/melee owner throughout the dash.
		local airLean = math.rad(config.AirCharacterLeanDegrees)
		local airYaw = math.rad(config.AirDirectionYawDegrees * pose.Twist)
		local airWave = math.sin(math.clamp(activeProgress, 0, 1) * math.pi)
		local airStrength = actionStrength * (0.72 + airWave * 0.28)
		local rootPose = CFrame.Angles(
			pose.Pitch * airLean * airStrength,
			airYaw * airStrength,
			pose.Roll * airLean * airStrength
		)
		poses.Root = rootPose
		poses.Waist = rootPose.Rotation:Inverse() * CFrame.Angles(
			-pose.Pitch * airLean * 0.18 * airStrength,
			-airYaw * 0.25 * airStrength,
			-pose.Roll * airLean * 0.16 * airStrength
		)
		poses.Neck = CFrame.Angles(
			-pose.Pitch * airLean * 0.20 * airStrength,
			-airYaw * 0.18 * airStrength,
			-pose.Roll * airLean * 0.22 * airStrength
		)
		local tuck = math.rad(config.AirHipTuckDegrees) * airWave * actionStrength
		local spread = math.rad(config.AirHipSpreadDegrees) * airWave * actionStrength
		poses.LeftHip = CFrame.Angles(tuck, 0, -spread)
		poses.RightHip = CFrame.Angles(tuck, 0, spread)
		PoseCoordinator:Submit("Dash", 30, poses)
		return
	end
	local stepWave = math.sin(math.clamp(activeProgress, 0, 1) * math.pi) * actionStrength
	local hipStrength = smoothstep(
		(activeProgress - config.HipMotionDelayProgress)
			/ math.max(0.001, config.StepPeakProgress - config.HipMotionDelayProgress)
	) * recovery
	local lean = math.rad(config.CharacterLeanDegrees)
	local twist = math.rad(config.CounterTwistDegrees * pose.Twist) * actionStrength
	local brace = math.rad(config.ArmBraceDegrees)
	local shoulderLead = math.rad(config.LeadShoulderDegrees) * actionStrength
	local leadStep = math.rad(config.LeadStepDegrees) * stepWave * hipStrength
	local trailStep = math.rad(config.TrailStepDegrees) * stepWave * hipStrength
	local rootPose = CFrame.Angles(
		pose.Pitch * lean * actionStrength,
		twist,
		pose.Roll * lean * actionStrength
	)
	local waistAccent = CFrame.Angles(
		pose.Pitch * lean * 0.62 * actionStrength,
		-twist * 0.55,
		pose.Roll * lean * 0.42 * actionStrength
	)
	poses.Root = rootPose
	-- Keep the leg/lower-torso lean, but cancel its inherited rotation before
	-- applying the smaller upper-body accent. Weapon poses can remain on aim.
	poses.Waist = rootPose.Rotation:Inverse() * waistAccent
	poses.Neck = CFrame.Angles(
		-pose.Pitch * lean * 0.22 * actionStrength,
		-twist * 0.25,
		-pose.Roll * lean * 0.18 * actionStrength
	)
	if activeAction == "Forward" then
		poses.RightShoulder = CFrame.Angles(-brace - shoulderLead, 0, math.rad(8) * actionStrength)
		poses.LeftShoulder = CFrame.Angles(-brace * 0.55, 0, -math.rad(7) * actionStrength)
		poses.RightHip = CFrame.Angles(-leadStep, 0, math.rad(3) * hipStrength)
		poses.LeftHip = CFrame.Angles(trailStep, 0, -math.rad(3) * hipStrength)
	elseif activeAction == "Backward" then
		poses.LeftShoulder = CFrame.Angles(-brace - shoulderLead, 0, -math.rad(8) * actionStrength)
		poses.RightShoulder = CFrame.Angles(-brace * 0.55, 0, math.rad(7) * actionStrength)
		poses.LeftHip = CFrame.Angles(-leadStep, 0, -math.rad(3) * hipStrength)
		poses.RightHip = CFrame.Angles(trailStep, 0, math.rad(3) * hipStrength)
	elseif activeAction == "Left" then
		poses.LeftShoulder = CFrame.Angles(-brace - shoulderLead * 0.75, 0, -shoulderLead * 0.55)
		poses.RightShoulder = CFrame.Angles(-brace * 0.55, 0, -shoulderLead * 0.18)
		poses.LeftHip = CFrame.Angles(-leadStep * 0.55, 0, -leadStep)
		poses.RightHip = CFrame.Angles(trailStep * 0.4, 0, trailStep * 0.65)
	else
		poses.RightShoulder = CFrame.Angles(-brace - shoulderLead * 0.75, 0, shoulderLead * 0.55)
		poses.LeftShoulder = CFrame.Angles(-brace * 0.55, 0, shoulderLead * 0.18)
		poses.RightHip = CFrame.Angles(-leadStep * 0.55, 0, leadStep)
		poses.LeftHip = CFrame.Angles(trailStep * 0.4, 0, -trailStep * 0.65)
	end
	PoseCoordinator:Submit("Dash", 30, poses)
end

function Controller:Init(movementEngine, _cameraController)
	if isInitialised then return end
	isInitialised = true
	local player = Players.LocalPlayer
	local function bindCharacter(character)
		characterGeneration += 1
		local bindGeneration = characterGeneration
		characterBindingTarget = character
		if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
		self:Interrupt()
		if humanoidStateConnection then humanoidStateConnection:Disconnect() end
		humanoidStateConnection = nil
		boundCharacter = nil
		cancelDependencyWatch = CharacterDependency.ObserveHumanoidAndRoot(
			character,
			MultiplayerConfig.CharacterDependencyTimeoutSeconds,
			function(humanoid, rootPart)
				if bindGeneration ~= characterGeneration or characterBindingTarget ~= character
					or player.Character ~= character then return end
				boundCharacter = character
				bindDashSound(rootPart)
				humanoidStateConnection = humanoid.StateChanged:Connect(function(_, nextState)
					if bindGeneration ~= characterGeneration or boundCharacter ~= character then return end
					if nextState == Enum.HumanoidStateType.Landed
						or nextState == Enum.HumanoidStateType.Running then
						airReady = false
						if not activeAction then resetJoints() end
					end
				end)
			end,
			function()
				if bindGeneration == characterGeneration and player.Character == character then
					warn("[BLIKK DASH] Character dependencies remain incomplete; continuing to observe the current character.")
				end
			end
		)
	end
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(character)
		if character ~= characterBindingTarget then return end
		characterGeneration += 1
		characterBindingTarget = nil
		if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
		boundCharacter = nil
		self:Interrupt()
		destroyDashSound()
		if humanoidStateConnection then humanoidStateConnection:Disconnect(); humanoidStateConnection = nil end
		resetJoints()
	end)
	if player.Character then bindCharacter(player.Character) end
	movementEngine.DashStarted.Event:Connect(function(action, direction, grounded, kind)
		if not config.Enabled or kind == "Tumble" then return end
		activeAction = action
		airReady = false
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		activeRootPart = rootPart
		activeDirection = direction
		activeGrounded = grounded
		activeProgress = 0
		previousRootPosition = rootPart and rootPart.Position or nil
		table.clear(activeStreaks)
		if rootPart and config.Enabled then
			local tangent = streakDirection(rootPart, direction, grounded, Vector3.zero)
			emitStreaks(rootPart, tangent, grounded)
		end
		if dashSound and dashSound.Parent == rootPart then
			local dashGroup = SoundService:FindFirstChild("BLIKK_Dash")
			if dashGroup and dashGroup:IsA("SoundGroup") then dashSound.SoundGroup = dashGroup end
			dashSound:Stop()
			dashSound.TimePosition = 0
			dashSound:Play()
		end
	end)
	movementEngine.DashUpdated.Event:Connect(function(_, _, progress)
		activeProgress = progress
		if activeAction and activeRootPart and activeRootPart.Parent and previousRootPosition then
			local currentPosition = activeRootPart.Position
			local tangent = streakDirection(
				activeRootPart,
				activeDirection,
				activeGrounded,
				currentPosition - previousRootPosition
			)
			previousRootPosition = currentPosition
			positionStreaks(activeRootPart, tangent)
		end
	end)
	movementEngine.DashEnded.Event:Connect(function(action, _, grounded, kind)
		if kind == "Tumble" then return end
		if not activeAction or action ~= activeAction then return end
		activeAction = nil
		activeRootPart = nil
		activeDirection = nil
		activeProgress = 0
		previousRootPosition = nil
		table.clear(activeStreaks)
		airReady = not grounded
		if not airReady then resetJoints() end
	end)
	RunService:BindToRenderStep("BLIKKDashPose", Enum.RenderPriority.Character.Value + 1, applyPose)
end

return Controller
