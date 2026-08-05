local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(Shared.Movement.MovementConfig)

local Controller = {}
local config = MovementConfig.Dash.Presentation
local activeAction = nil
local poseJoints = {}
local gameplayCamera = nil
local airReady = false
local humanoidStateConnection = nil

local directionPose = {
	Forward = { Pitch = -1, Roll = 0, Twist = 1 },
	Backward = { Pitch = 1, Roll = 0, Twist = -1 },
	Left = { Pitch = 0, Roll = -1, Twist = 1 },
	Right = { Pitch = 0, Roll = 1, Twist = -1 },
}

local jointAliases = {
	Root = "Root", RootJoint = "Root", Waist = "Waist",
	LeftShoulder = "LeftShoulder", RightShoulder = "RightShoulder",
	LeftHip = "LeftHip", RightHip = "RightHip",
}

local function bindPoseJoints(character)
	table.clear(poseJoints)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local alias = jointAliases[descendant.Name:gsub(" ", "")]
			if alias then poseJoints[alias] = descendant end
		end
	end
end

local function resetJoints()
	for _, joint in poseJoints do
		if joint.Parent then joint.Transform = CFrame.identity end
	end
end

function Controller:Interrupt()
	activeAction = nil
	airReady = false
	resetJoints()
	if gameplayCamera then gameplayCamera:SetDashFovOffset(0) end
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
	beam.Color = ColorSequence.new(Color3.fromRGB(183, 242, 105), Color3.fromRGB(73, 91, 61))
	beam.LightEmission = 0.35
	beam.Transparency = NumberSequence.new(config.StreakTransparency, 1)
	beam.Width0, beam.Width1 = width, width * 0.35
	beam.FaceCamera = true
	beam.Parent = startPart
	Debris:AddItem(startPart, lifetime)
	Debris:AddItem(endPart, lifetime)
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

local function emitStreaks(rootPart, direction, grounded)
	if SessionSettings:Get("ReducedEffects") then return end
	local quality = SessionSettings:Get("EffectsQuality")
	local count = if quality == "LOW" then config.LowStreakCount else config.StreakCount
	local lifetimeMultiplier = if quality == "HIGH" then 1 elseif quality == "MEDIUM" then config.MediumLifetimeMultiplier else config.LowLifetimeMultiplier
	local widthMultiplier = if quality == "MEDIUM" then config.MediumWidthMultiplier else 1
	local firstIndex = if count == 1 then 2 else 1
	for offset = 0, count - 1 do
		local index = firstIndex + offset
		local start = rootPart.Position + Vector3.new(0, config.StreakHeightsStuds[index], 0)
		createBeamStreak(start, start - direction * config.StreakLengthStuds, config.StreakWidthsStuds[index] * widthMultiplier, config.StreakLifetimeSeconds * lifetimeMultiplier)
	end
	if grounded then emitGroundAccent(rootPart, direction) end
end

local function applyPose()
	if (not activeAction and not airReady) or not config.Enabled then return end
	if airReady and not activeAction then
		if poseJoints.Root then poseJoints.Root.Transform = CFrame.Angles(math.rad(-7), 0, 0) end
		if poseJoints.Waist then poseJoints.Waist.Transform = CFrame.Angles(math.rad(4), 0, 0) end
		if poseJoints.LeftShoulder then poseJoints.LeftShoulder.Transform = CFrame.Angles(math.rad(-18), 0, math.rad(-12)) end
		if poseJoints.RightShoulder then poseJoints.RightShoulder.Transform = CFrame.Angles(math.rad(-18), 0, math.rad(12)) end
		if poseJoints.LeftHip then poseJoints.LeftHip.Transform = CFrame.Angles(math.rad(15), 0, math.rad(-7)) end
		if poseJoints.RightHip then poseJoints.RightHip.Transform = CFrame.Angles(math.rad(-9), 0, math.rad(7)) end
		return
	end
	local pose = directionPose[activeAction]
	if not pose then return end
	local lean = math.rad(config.CharacterLeanDegrees)
	local twist = math.rad(config.CounterTwistDegrees * pose.Twist)
	local brace = math.rad(config.ArmBraceDegrees)
	local tuck = math.rad(config.HipTuckDegrees)
	if poseJoints.Root then poseJoints.Root.Transform = CFrame.Angles(pose.Pitch * lean, twist, pose.Roll * lean) end
	if poseJoints.Waist then poseJoints.Waist.Transform = CFrame.Angles(pose.Pitch * lean * 0.45, -twist, pose.Roll * lean * 0.6) end
	if poseJoints.LeftShoulder then poseJoints.LeftShoulder.Transform = CFrame.Angles(-brace, 0, -pose.Roll * brace * 0.8) end
	if poseJoints.RightShoulder then poseJoints.RightShoulder.Transform = CFrame.Angles(-brace, 0, pose.Roll * brace * 0.35) end
	if poseJoints.LeftHip then poseJoints.LeftHip.Transform = CFrame.Angles(tuck + pose.Pitch * tuck, 0, -pose.Roll * tuck * 1.2) end
	if poseJoints.RightHip then poseJoints.RightHip.Transform = CFrame.Angles(-tuck + pose.Pitch * tuck, 0, pose.Roll * tuck * 0.45) end
end

function Controller:Init(movementEngine, cameraController)
	gameplayCamera = cameraController
	local player = Players.LocalPlayer
	local function bindCharacter(character)
		self:Interrupt()
		bindPoseJoints(character)
		if humanoidStateConnection then humanoidStateConnection:Disconnect() end
		local humanoid = character:WaitForChild("Humanoid")
		humanoidStateConnection = humanoid.StateChanged:Connect(function(_, nextState)
			if nextState == Enum.HumanoidStateType.Landed or nextState == Enum.HumanoidStateType.Running then
				airReady = false
				if not activeAction then resetJoints() end
			end
		end)
	end
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then bindCharacter(player.Character) end
	movementEngine.DashStarted.Event:Connect(function(action, direction, grounded)
		if not config.Enabled then return end
		activeAction = action
		airReady = false
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart and config.Enabled then emitStreaks(rootPart, direction, grounded) end
		if not SessionSettings:Get("ReducedEffects") then cameraController:SetDashFovOffset(config.CameraFovImpulseDegrees) end
		if config.SoundId ~= "" and rootPart then
			local sound = Instance.new("Sound")
			sound.SoundId, sound.SoundGroup, sound.Parent = config.SoundId, SoundService:FindFirstChild("BLIKK_Dash"), rootPart
			sound:Play(); Debris:AddItem(sound, 3)
		end
	end)
	movementEngine.DashUpdated.Event:Connect(function(_, _, progress)
		if activeAction and not SessionSettings:Get("ReducedEffects") then
			cameraController:SetDashFovOffset(config.CameraFovImpulseDegrees * (1 - progress) ^ 2)
		end
	end)
	movementEngine.DashEnded.Event:Connect(function(_, _, grounded)
		activeAction = nil
		airReady = not grounded
		cameraController:SetDashFovOffset(0)
		if not airReady then resetJoints() end
	end)
	RunService:BindToRenderStep("BLIKKDashPose", Enum.RenderPriority.Character.Value + 1, applyPose)
end

return Controller
