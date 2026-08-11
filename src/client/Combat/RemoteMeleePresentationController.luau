local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MeleePresentationConfig = require(ReplicatedStorage.Shared.Combat.MeleePresentationConfig)
local MeleeCombatConfig = require(ReplicatedStorage.Shared.Combat.MeleeCombatConfig)
local MeleePoseSampler = require(ReplicatedStorage.Shared.Combat.MeleePoseSampler)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)
local SlashPoseSampler = require(ReplicatedStorage.Shared.Combat.SlashPoseSampler)
local TrainingKatanaPresentation = require(ReplicatedStorage.Shared.Combat.TrainingKatanaPresentation)

local Controller = {}
local localPlayer = Players.LocalPlayer
local active = {}
local remoteConnection
local updateConnection
local playerRemovingConnection
local soundEffectsController
local isInitialised = false
local cancelledSequences = {}
local impactAttachments = {}

local VALID_IMPACT_OUTCOMES = {
	Damage = true,
	Guarded = true,
	Wall = true,
}

local aliases = {
	Root = "Root",
	RootJoint = "Root",
	Waist = "Waist",
	Neck = "Neck",
	RightShoulder = "RightShoulder",
	LeftShoulder = "LeftShoulder",
	RightElbow = "RightElbow",
	LeftElbow = "LeftElbow",
	RightWrist = "RightWrist",
	LeftWrist = "LeftWrist",
	LeftHip = "LeftHip",
	RightHip = "RightHip",
}

local function clearRecord(userId)
	local record = active[userId]
	if not record then return end
	for alias in record.Applied do
		local joint = record.Joints[alias]
		if joint and joint.Parent and joint:IsA("Motor6D") then joint.Transform = CFrame.identity end
	end
	if record.Model then record.Model:Destroy() end
	active[userId] = nil
end

local function collectJoints(character)
	local joints = {}
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("AnimationConstraint") and not descendant:IsA("Motor6D") then continue end
		local alias = aliases[descendant.Name:gsub(" ", "")]
		if alias then
			local current = joints[alias]
			if descendant:IsA("AnimationConstraint") or not current or not current.Parent then
				joints[alias] = descendant
			end
		end
	end
	return joints
end

local function attachKatana(character, humanoid)
	local model, trail = TrainingKatanaPresentation.Build(true)
	local attachment = MeleePresentationConfig.TrainingKatana.EquippedAttachment
	local partName = if humanoid.RigType == Enum.HumanoidRigType.R6 then "Right Arm" else attachment.PartName
	local hand = character:FindFirstChild(partName, true)
	if not hand or not hand:IsA("BasePart") or not model.PrimaryPart then model:Destroy(); return nil end
	model:PivotTo(hand.CFrame * attachment.Offset * attachment.GripPivot:Inverse())
	model.Name = "BLIKK_RemoteTrainingKatana"
	model.Parent = character
	local grip = Instance.new("Motor6D")
	grip.Name = "BLIKK_RemoteKatanaGrip"
	grip.Part0 = hand
	grip.Part1 = model.PrimaryPart
	grip.C0 = attachment.Offset
	grip.C1 = attachment.GripPivot
	grip.Parent = model.PrimaryPart
	return model, trail, grip
end

local function finiteVector3(value)
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < math.huge and math.abs(value.Y) < math.huge
		and math.abs(value.Z) < math.huge
end

local function validPayload(payload)
	if type(payload) ~= "table"
		or type(payload.ShooterUserId) ~= "number" or payload.ShooterUserId % 1 ~= 0
		or type(payload.SpawnGeneration) ~= "number" or payload.SpawnGeneration % 1 ~= 0
		or type(payload.Sequence) ~= "number" or payload.Sequence <= 0
		or payload.Sequence % 1 ~= 0 then return false end
	if payload.Operation == "Slash" then return payload.Variant == 1 or payload.Variant == 2 end
	if payload.Operation == "Impact" then
		return (payload.Variant == 1 or payload.Variant == 2)
			and VALID_IMPACT_OUTCOMES[payload.Outcome] == true
			and finiteVector3(payload.WorldPosition)
			and finiteVector3(payload.SurfaceNormal)
			and payload.SurfaceNormal.Magnitude >= 0.9
			and payload.SurfaceNormal.Magnitude <= 1.1
	end
	return payload.Operation == "SlashCancel" or payload.Operation == "BlockBegin"
		or payload.Operation == "BlockEnd" or payload.Operation == "AltFire"
		or payload.Operation == "AirTossRecover"
end

local function showSlashImpact(payload)
	local config = MeleePresentationConfig.ContactVFX
	local normal = payload.SurfaceNormal.Unit
	local tangent = normal:Cross(Vector3.yAxis)
	if tangent.Magnitude < 0.01 then tangent = normal:Cross(Vector3.xAxis) end
	tangent = tangent.Unit
	local vertical = tangent:Cross(normal).Unit
	local variantSign = if payload.Variant == 1 then 1 else -1
	local slashDirection = (tangent * variantSign + vertical * 0.42).Unit
	local center = payload.WorldPosition + normal * config.SurfaceOffsetStuds
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "BLIKKSlashContactStart"
	attachment0.Parent = Workspace.Terrain
	attachment0.WorldPosition = center - slashDirection * config.LengthStuds * 0.5
	impactAttachments[attachment0] = true
	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "BLIKKSlashContactEnd"
	attachment1.Parent = Workspace.Terrain
	attachment1.WorldPosition = center + slashDirection * config.LengthStuds * 0.5
	impactAttachments[attachment1] = true

	local color = config.Colors[payload.Outcome]
	local glow = Instance.new("Beam")
	glow.Name = "BLIKKSlashContactGlow"
	glow.Attachment0 = attachment0
	glow.Attachment1 = attachment1
	glow.Color = ColorSequence.new(color)
	glow.Width0 = config.GlowWidthStuds
	glow.Width1 = config.GlowWidthStuds * 0.45
	glow.Transparency = NumberSequence.new(0.38, 0.78)
	glow.LightEmission = config.LightEmission
	glow.FaceCamera = true
	glow.Parent = attachment0

	local core = Instance.new("Beam")
	core.Name = "BLIKKSlashContactCore"
	core.Attachment0 = attachment0
	core.Attachment1 = attachment1
	core.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	core.Width0 = config.CoreWidthStuds
	core.Width1 = config.CoreWidthStuds * 0.30
	core.Transparency = NumberSequence.new(0.02, 0.35)
	core.LightEmission = 1
	core.FaceCamera = true
	core.Parent = attachment0

	task.delay(config.LifetimeSeconds * config.FadeAtLifetimeFraction, function()
		if glow.Parent then glow.Transparency = NumberSequence.new(0.78, 1) end
		if core.Parent then core.Transparency = NumberSequence.new(0.65, 1) end
	end)
	task.delay(config.LifetimeSeconds, function()
		impactAttachments[attachment0] = nil
		impactAttachments[attachment1] = nil
		attachment0:Destroy()
		attachment1:Destroy()
	end)
end

local function beginRemotePresentation(payload)
	if not validPayload(payload) then return end
	if payload.Operation == "Impact" then
		local shooter = Players:GetPlayerByUserId(payload.ShooterUserId)
		local shooterCharacter = shooter and shooter.Character
		if not shooter or not shooterCharacter
			or shooter:GetAttribute("BLIKK_SpawnGeneration") ~= payload.SpawnGeneration
			or shooterCharacter:GetAttribute("BLIKK_SpawnGeneration")
				~= payload.SpawnGeneration then return end
		showSlashImpact(payload)
		if soundEffectsController
			and (payload.Outcome ~= "Damage" or payload.ShooterUserId ~= localPlayer.UserId) then
			soundEffectsController:PlayAtPosition("KatanaImpact", payload.WorldPosition)
		end
		return
	end
	if payload.ShooterUserId == localPlayer.UserId then return end
	if payload.Operation == "SlashCancel" then
		cancelledSequences[payload.ShooterUserId] = math.max(
			cancelledSequences[payload.ShooterUserId] or 0,
			payload.Sequence
		)
		local existing = active[payload.ShooterUserId]
		if existing and existing.Mode == "Slash"
			and payload.Sequence == existing.Sequence then clearRecord(payload.ShooterUserId) end
		return
	end
	if payload.Operation == "BlockEnd" then
		local existing = active[payload.ShooterUserId]
		if existing and existing.Mode == "Block"
			and payload.Sequence == existing.Sequence then clearRecord(payload.ShooterUserId) end
		return
	end
	if payload.Operation == "Slash"
		and payload.Sequence <= (cancelledSequences[payload.ShooterUserId] or 0) then return end
	local shooter = Players:GetPlayerByUserId(payload.ShooterUserId)
	local character = shooter and shooter.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not shooter or not character or not humanoid or humanoid.Health <= 0
		or shooter:GetAttribute("BLIKK_SpawnGeneration") ~= payload.SpawnGeneration
		or character:GetAttribute("BLIKK_SpawnGeneration") ~= payload.SpawnGeneration then return end
	local mode = if payload.Operation == "BlockBegin" then "Block"
		elseif payload.Operation == "AirTossRecover" then "SafeFall"
		else payload.Operation
	local existing = active[payload.ShooterUserId]
	if existing and existing.Mode == mode
		and payload.Sequence <= existing.Sequence then return end
	clearRecord(payload.ShooterUserId)
	local model, trail, grip
	if mode ~= "SafeFall" then
		model, trail, grip = attachKatana(character, humanoid)
		if not model then return end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart")
		and (payload.Operation == "Slash" or payload.Operation == "AltFire") then
		soundEffectsController:PlayAtPosition("KatanaSlash", root.Position)
	end
	active[payload.ShooterUserId] = {
		Mode = mode,
		Character = character,
		Humanoid = humanoid,
		Joints = collectJoints(character),
		Applied = {},
		Resolved = {},
		Model = model,
		Grip = grip,
		Trail = trail,
		Variant = payload.Variant,
		Sequence = payload.Sequence,
		StartedAt = os.clock(),
	}
end

local function updateRemoteSlashes(deltaTime)
	local now = os.clock()
	local actionBlend = 1 - math.exp(-MeleePresentationConfig.Pose.ActionBlendSpeed * deltaTime)
	local slash = MeleePresentationConfig.Slash
	local activeStart = slash.AnticipationSeconds
	local activeEnd = activeStart + slash.ActiveSeconds
	local total = activeEnd + slash.RecoverySeconds
	for userId, record in active do
		local elapsed = now - record.StartedAt
		local duration = if record.Mode == "Block"
			then MeleePresentationConfig.Block.MaximumDurationSeconds
			elseif record.Mode == "AltFire"
			then MeleePresentationConfig.AltFire.TotalDurationSeconds
			elseif record.Mode == "SafeFall"
			then MeleeCombatConfig.AltFire.SafeFallAnimationDurationSeconds
			else total
		if not record.Character.Parent or record.Humanoid.Health <= 0 or elapsed >= duration then
			clearRecord(userId)
			continue
		end
		if record.Trail then
			record.Trail.Enabled = record.Mode == "Slash"
				and elapsed >= activeStart and elapsed < activeEnd
		end
		local root = record.Character:FindFirstChild("HumanoidRootPart")
		if record.Mode == "Slash" then
			SlashPoseSampler.ApplyWeaponArc(record.Grip, root, record.Variant, elapsed)
		elseif record.Mode == "Block" then
			local weaponPose = MeleePresentationConfig.Pose.ProceduralBlockWeapon
			local blockWeaponBlend = math.clamp(
				elapsed / math.max(MeleePresentationConfig.Block.EnterPresentationSeconds, 0.001),
				0,
				1
			)
			SlashPoseSampler.ApplyWeaponDirection(
				record.Grip,
				root,
				weaponPose.Direction,
				weaponPose.EdgeRollDegrees,
				blockWeaponBlend
			)
		elseif record.Grip then
			SlashPoseSampler.ResetWeaponArc(record.Grip)
		end
		local poses = if record.Mode == "Block"
			then MeleePoseSampler.SampleBlock(elapsed)
			elseif record.Mode == "AltFire"
			then MeleePoseSampler.SampleAltFire(elapsed)
			elseif record.Mode == "SafeFall"
			then MeleePoseSampler.SampleSafeFall(elapsed)
			else SlashPoseSampler.Sample(record.Variant, elapsed)
		for alias, pose in poses do
			local joint = record.Joints[alias]
			if not joint or not joint.Parent then continue end
			if alias == "RightShoulder" or alias == "LeftShoulder"
				or alias == "RightElbow" or alias == "LeftElbow"
				or alias == "RightWrist" or alias == "LeftWrist" then
				-- Remote weapon limbs use the accepted weapon pose as their absolute
				-- presentation for this frame; the remote walk cycle remains on the
				-- torso and lower body without dragging the attached katana.
				local resolved = (record.Resolved[alias] or joint.Transform):Lerp(pose, actionBlend)
				joint.Transform = resolved
				record.Resolved[alias] = resolved
			elseif joint:IsA("AnimationConstraint") then
				joint.Transform = CFrame.identity:Lerp(pose, actionBlend) * joint.Transform
			else
				joint.Transform = joint.Transform:Lerp(pose, actionBlend)
			end
			if joint:IsA("Motor6D") then record.Applied[alias] = true end
		end
	end
end

function Controller:Init(soundEffectsControllerValue)
	if isInitialised then return end
	isInitialised = true
	soundEffectsController = soundEffectsControllerValue
	local remotes = ReplicatedStorage:WaitForChild("BLIKKRemotes", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	local meleeSwing = remotes and remotes:WaitForChild("MeleeSwing", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	if not meleeSwing then error("[BLIKK REMOTE MELEE] MeleeSwing unavailable", 0) end
	remoteConnection = meleeSwing.OnClientEvent:Connect(beginRemotePresentation)
	updateConnection = RunService.PreSimulation:Connect(updateRemoteSlashes)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		clearRecord(player.UserId)
		cancelledSequences[player.UserId] = nil
	end)
end

function Controller:Destroy()
	if remoteConnection then remoteConnection:Disconnect(); remoteConnection = nil end
	if updateConnection then updateConnection:Disconnect(); updateConnection = nil end
	if playerRemovingConnection then playerRemovingConnection:Disconnect(); playerRemovingConnection = nil end
	for userId in active do clearRecord(userId) end
	for attachment in impactAttachments do attachment:Destroy() end
	table.clear(impactAttachments)
	table.clear(cancelledSequences)
	soundEffectsController = nil
end

return Controller
