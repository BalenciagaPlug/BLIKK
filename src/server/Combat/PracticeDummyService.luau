local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatFeedbackConfig = require(ReplicatedStorage.Shared.Combat.CombatFeedbackConfig)
local FighterVitalsConfig = require(ReplicatedStorage.Shared.Combat.FighterVitalsConfig)
local MeleePresentationConfig = require(ReplicatedStorage.Shared.Combat.MeleePresentationConfig)
local PracticeDummyConfig = require(ReplicatedStorage.Shared.Combat.PracticeDummyConfig)
local TrainingKatanaPresentation = require(
	ReplicatedStorage.Shared.Combat.TrainingKatanaPresentation
)
local DistrictZeroConfig = require(
	ReplicatedStorage.Shared.Maps.DistrictZero.DistrictZeroConfig
)

local PracticeDummyService = {}

local warnedDiagnostics = {}
local dummyFolder = nil
local roomService = nil
local matchService = nil
local activeRecord = nil
local mapGeneration = 0
local buildThread = nil
local buildTimeoutThread = nil
local isInitialised = false

local function warnDiagnostic(category, message)
	if warnedDiagnostics[category] then return end
	warnedDiagnostics[category] = true
	warn("[BLIKK PRACTICE DUMMY:" .. category .. "] " .. message)
end

local function ensureFolder()
	if dummyFolder and dummyFolder.Parent == Workspace then return dummyFolder end
	local existing = Workspace:FindFirstChild(PracticeDummyConfig.FolderName)
	if existing then existing:Destroy() end
	dummyFolder = Instance.new("Folder")
	dummyFolder.Name = PracticeDummyConfig.FolderName
	dummyFolder:SetAttribute("BLIKK_ServerOwned", true)
	dummyFolder.Parent = Workspace
	return dummyFolder
end

local function disconnectConnections(connections)
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

local function cancelThread(thread)
	if thread and thread ~= coroutine.running() then pcall(task.cancel, thread) end
end

local function cancelReset(record)
	record.ResetToken += 1
	cancelThread(record.ResetThread)
	record.ResetThread = nil
end

local function stopIdle(record)
	if not record.IdleTrack then return end
	pcall(function()
		record.IdleTrack:Stop(0)
		record.IdleTrack:Destroy()
	end)
	record.IdleTrack = nil
end

local function destroyRecord()
	local record = activeRecord
	if not record then return end
	activeRecord = nil
	cancelReset(record)
	disconnectConnections(record.Connections)
	stopIdle(record)
	if record.Model.Parent then record.Model:Destroy() end
end

local function invalidateMapOwnership()
	mapGeneration += 1
	cancelThread(buildThread)
	cancelThread(buildTimeoutThread)
	buildThread = nil
	buildTimeoutThread = nil
	destroyRecord()
end

local function getDistrict()
	local root = Workspace:FindFirstChild(DistrictZeroConfig.Identity.WorkspaceRootName)
	return root and root:FindFirstChild(DistrictZeroConfig.Identity.ModelName)
end

local function isBuildCurrent(generation, district)
	return isInitialised and mapGeneration == generation and district.Parent ~= nil
		and getDistrict() == district
end

local function stripUnsafeDescendants(model)
	local unsafeAccessories = {}
	local presentationWeapons = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("BLIKK_WeaponDefinition") then
			table.insert(presentationWeapons, descendant)
		end
		if descendant:IsA("Accessory") then
			for _, accessoryDescendant in descendant:GetDescendants() do
				if accessoryDescendant:IsA("LuaSourceContainer")
					or accessoryDescendant:IsA("Tool") then
					unsafeAccessories[descendant] = true
					break
				end
			end
		end
	end
	for _, weapon in presentationWeapons do weapon:Destroy() end
	for accessory in unsafeAccessories do accessory:Destroy() end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Tool")
			or descendant:IsA("Backpack")
			or descendant:IsA("RemoteEvent")
			or descendant:IsA("RemoteFunction")
			or descendant:IsA("BindableEvent")
			or descendant:IsA("BindableFunction")
			or descendant:IsA("ProximityPrompt")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("Sound")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("Fire")
			or descendant:IsA("Smoke")
			or descendant:IsA("Sparkles")
			or descendant:IsA("Light")
			or descendant:IsA("LayerCollector") then
			descendant:Destroy()
		end
	end
end

local function prepareAnimator(model, humanoid)
	local animator = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Animator") then
			if descendant.Parent == humanoid and not animator then
				animator = descendant
			else
				descendant:Destroy()
			end
		elseif descendant:IsA("AnimationController") then
			descendant:Destroy()
		end
	end
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "PracticeDummyAnimator"
		animator.Parent = humanoid
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		pcall(function()
			track:Stop(0)
			track:Destroy()
		end)
	end
	return animator
end

local function playTrustedIdle(record)
	local animationId = PracticeDummyConfig.Animation.TrustedR15IdleAnimationId
	if type(animationId) ~= "number" or animationId <= 0 then
		warnDiagnostic("IDLE_UNAVAILABLE", "No trusted R15 idle animation is configured.")
		return
	end
	local animator = prepareAnimator(record.Model, record.Humanoid)
	local animation = Instance.new("Animation")
	animation.Name = "PracticeDummyIdle"
	animation.AnimationId = "rbxassetid://" .. tostring(animationId)
	local track = nil
	local succeeded, loadError = pcall(function()
		track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Core
		track.Looped = true
		track:Play(PracticeDummyConfig.Animation.InitialFadeSeconds, 1, 1)
	end)
	animation:Destroy()
	if not succeeded or not track then
		if track then pcall(function() track:Destroy() end) end
		warnDiagnostic("IDLE_LOAD_FAILED", "Trusted dummy idle failed: " .. tostring(loadError))
		return
	end
	record.IdleTrack = track
end

local function configurePhysicalModel(model, humanoid, root)
	humanoid.DisplayName = "DAMAGE DUMMY"
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.BreakJointsOnDeath = false
	pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
	pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.Massless = descendant ~= root
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = true
		end
	end
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function attachCanonicalKatana(model)
	local attachment = MeleePresentationConfig.TrainingKatana.EquippedAttachment
	local hand = model:FindFirstChild(attachment.PartName, true)
	if not hand or not hand:IsA("BasePart") then return false, "RightHand unavailable" end
	local katana = TrainingKatanaPresentation.Build(true)
	if not katana or not katana.PrimaryPart then return false, "Katana geometry unavailable" end
	local handleCFrame = hand.CFrame * attachment.Offset * attachment.GripPivot:Inverse()
	katana:PivotTo(handleCFrame)
	katana:SetAttribute("BLIKK_PracticeDummyWeapon", true)
	katana.Parent = model

	local grip = Instance.new("Motor6D")
	grip.Name = "BLIKK_PracticeDummyKatanaGrip"
	grip.Part0 = hand
	grip.Part1 = katana.PrimaryPart
	grip.C0 = attachment.Offset
	grip.C1 = attachment.GripPivot
	grip.Parent = katana.PrimaryPart
	return true, nil
end

local function partTopY(part)
	local halfSize = part.Size * 0.5
	local cframe = part.CFrame
	return cframe.Position.Y
		+ math.abs(cframe.RightVector.Y) * halfSize.X
		+ math.abs(cframe.UpVector.Y) * halfSize.Y
		+ math.abs(cframe.LookVector.Y) * halfSize.Z
end

local function findPlacement(district)
	local architecture = district:FindFirstChild("Architecture")
	local clockTower = architecture and architecture:FindFirstChild("ClockTower")
	if not clockTower then return nil, nil, { ClockTowerMissing = 1 } end
	local clock = DistrictZeroConfig.Buildings.ClockTower
	local placement = PracticeDummyConfig.Placement
	local wallZ = clock.Center.Z + clock.Size.Y * 0.5
	local rejections = {
		Candidates = 0,
		NoGround = 0,
		Steep = 0,
		NonCollidable = 0,
		ClearanceBlocked = 0,
		WallMissing = 0,
		WallStandOff = 0,
	}
	local exclusions = { ensureFolder() }
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = exclusions
	raycastParams.IgnoreWater = true
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = exclusions
	overlapParams.MaxParts = placement.ClearanceMaximumParts
	overlapParams.RespectCanCollide = true

	for _, xOffset in placement.HorizontalFallbackOffsetsStuds do
		rejections.Candidates += 1
		local horizontalPosition = Vector3.new(
			clock.Center.X + xOffset,
			0,
			wallZ + placement.WallStandOffStuds
		)
		local groundHit = Workspace:Raycast(
			horizontalPosition + Vector3.new(0, placement.GroundProbeHeightStuds, 0),
			Vector3.new(0, -placement.GroundProbeDepthStuds, 0),
			raycastParams
		)
		if not groundHit then
			rejections.NoGround += 1
			continue
		elseif not groundHit.Instance.CanCollide then
			rejections.NonCollidable += 1
			continue
		elseif groundHit.Normal.Y < placement.MinimumGroundNormalY then
			rejections.Steep += 1
			continue
		end

		local groundPosition = groundHit.Position
		local clearanceSize = placement.ClearanceSizeStuds
		local clearanceCenter = Vector3.new(
			horizontalPosition.X,
			groundPosition.Y + placement.ClearanceBottomAboveGroundStuds
				+ clearanceSize.Y * 0.5,
			horizontalPosition.Z
		)
		local isClear = true
		for _, part in Workspace:GetPartBoundsInBox(
			CFrame.new(clearanceCenter),
			clearanceSize,
			overlapParams
		) do
			local isFloor = part == groundHit.Instance
				or partTopY(part) <= groundPosition.Y + placement.FloorSurfaceToleranceStuds
			if part.CanCollide and not isFloor then
				isClear = false
				break
			end
		end
		if not isClear then
			rejections.ClearanceBlocked += 1
			continue
		end

		local wallOrigin = groundPosition + Vector3.new(0, placement.WallProbeTorsoHeightStuds, 0)
		local wallHit = Workspace:Raycast(
			wallOrigin,
			Vector3.new(0, 0, -(placement.WallStandOffStuds + placement.WallProbeExtraStuds)),
			raycastParams
		)
		if not wallHit or not wallHit.Instance:IsDescendantOf(clockTower) then
			rejections.WallMissing += 1
			continue
		end
		if math.abs(wallHit.Distance - placement.WallStandOffStuds) > 0.5 then
			rejections.WallStandOff += 1
			continue
		end
		return groundPosition + Vector3.new(0, placement.GroundOffsetStuds, 0),
			Vector3.new(0, 0, 1),
			rejections
	end
	return nil, nil, rejections
end

local function createReadout(record)
	if not PracticeDummyConfig.Readout.Enabled then return end
	local head = record.Model:FindFirstChild("Head", true)
	if not head or not head:IsA("BasePart") then return end
	local config = PracticeDummyConfig.Readout
	local colors = CombatFeedbackConfig.Colors
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BLIKK_PracticeDummyReadout"
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = config.MaximumDistanceStuds
	billboard.Size = UDim2.fromOffset(config.SizePixels.X, config.SizePixels.Y)
	billboard.StudsOffsetWorldSpace = config.StudsOffset
	billboard.Adornee = head
	billboard.Parent = record.Model

	local function makeLabel(name, y, height, color, textSize)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 0, 0, y)
		label.Size = UDim2.new(1, 0, 0, height)
		label.Font = Enum.Font.Code
		label.TextColor3 = color
		label.TextSize = textSize
		label.TextStrokeColor3 = colors.Shadow
		label.TextStrokeTransparency = 0.2
		label.Parent = billboard
		return label
	end
	local title = makeLabel("Title", 0, 18, colors.Mixed, config.TitleTextSizePixels)
	title.Text = "DAMAGE DUMMY"
	local armour = makeLabel("Armour", 18, 18, colors.Armour, config.VitalTextSizePixels)
	local health = makeLabel("Health", 36, 18, colors.Health, config.VitalTextSizePixels)

	local function update()
		if activeRecord ~= record then return end
		local attributes = FighterVitalsConfig.Attributes
		armour.Text = string.format(
			"AP %d / %d",
			math.round(record.Model:GetAttribute(attributes.Armour) or 0),
			math.round(record.Model:GetAttribute(attributes.MaximumArmour) or 0)
		)
		health.Text = string.format(
			"HP %d / %d",
			math.round(math.max(0, record.Humanoid.Health)),
			math.round(record.Humanoid.MaxHealth)
		)
	end
	table.insert(
		record.Connections,
		record.Model:GetAttributeChangedSignal(FighterVitalsConfig.Attributes.Armour):Connect(update)
	)
	table.insert(record.Connections, record.Humanoid.HealthChanged:Connect(update))
	update()
end

local function restoreRecord(record)
	if activeRecord ~= record or not record.Model.Parent or not record.Humanoid.Parent
		or not record.Root.Parent then return end
	local attributes = FighterVitalsConfig.Attributes
	record.Humanoid.MaxHealth = FighterVitalsConfig.MaximumHealth
	record.Humanoid.Health = FighterVitalsConfig.MaximumHealth
	record.Model:SetAttribute(attributes.MaximumArmour, FighterVitalsConfig.MaximumArmour)
	record.Model:SetAttribute(attributes.Armour, FighterVitalsConfig.MaximumArmour)
	record.IsActive = true
	record.Model:SetAttribute(PracticeDummyConfig.Attributes.IsActive, true)
	record.Root.Anchored = true
	record.Root.AssemblyLinearVelocity = Vector3.zero
	record.Root.AssemblyAngularVelocity = Vector3.zero
	pcall(function() record.Humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics) end)
	if record.IdleTrack and not record.IdleTrack.IsPlaying then
		pcall(function()
			record.IdleTrack:Play(PracticeDummyConfig.Animation.InitialFadeSeconds, 1, 1)
		end)
	end
end

local function createR15Model(description)
	return pcall(
		Players.CreateHumanoidModelFromDescriptionAsync,
		Players,
		description,
		Enum.HumanoidRigType.R15
	)
end

local function beginDummyBuild(district)
	local generation = mapGeneration
	buildThread = task.defer(function()
		local succeeded, buildError = xpcall(function()
		local description = nil
		local fetched, fetchedDescription = pcall(
			Players.GetHumanoidDescriptionFromUserIdAsync,
			Players,
			PracticeDummyConfig.AvatarUserId
		)
		if fetched and fetchedDescription then
			description = fetchedDescription
		else
			description = Instance.new("HumanoidDescription")
			warnDiagnostic(
				"DESCRIPTION_FALLBACK",
				"Configured avatar description was unavailable; using the safe default R15 description."
			)
		end
		if not isBuildCurrent(generation, district) then
			description:Destroy()
			return
		end

		local created, modelOrError = createR15Model(description)
		description:Destroy()
		if not created or not modelOrError then
			local fallbackDescription = Instance.new("HumanoidDescription")
			created, modelOrError = createR15Model(fallbackDescription)
			fallbackDescription:Destroy()
			warnDiagnostic(
				"AVATAR_BUILD_FALLBACK",
				"Configured avatar construction failed; attempted one safe default R15 fallback."
			)
		end
		if not created or not modelOrError then
			warnDiagnostic("AVATAR_BUILD_FAILED", "Safe default R15 avatar construction also failed.")
			return
		end
		local model = modelOrError
		if not isBuildCurrent(generation, district) then
			model:Destroy()
			return
		end

		stripUnsafeDescendants(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart", true)
		if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15
			or not root or not root:IsA("BasePart") then
			model:Destroy()
			warnDiagnostic("AVATAR_INCOMPLETE", "Constructed shared dummy avatar was incomplete.")
			return
		end
		model.Name = PracticeDummyConfig.ModelName
		model.PrimaryPart = root
		configurePhysicalModel(model, humanoid, root)
		local attached, attachmentError = attachCanonicalKatana(model)
		if not attached then
			model:Destroy()
			warnDiagnostic("KATANA_ATTACHMENT_FAILED", tostring(attachmentError))
			return
		end

		local groundPosition, facing, rejections = findPlacement(district)
		if not groundPosition or not facing then
			model:Destroy()
			warnDiagnostic("PLACEMENT_FAILED", string.format(
				"Clock bay rejected. Candidates=%d NoGround=%d Steep=%d NonCollidable=%d ClearanceBlocked=%d WallMissing=%d WallStandOff=%d",
				rejections.Candidates or 0,
				rejections.NoGround or 0,
				rejections.Steep or 0,
				rejections.NonCollidable or 0,
				rejections.ClearanceBlocked or 0,
				rejections.WallMissing or 0,
				rejections.WallStandOff or 0
			))
			return
		end
		local rootHeight = humanoid.HipHeight + root.Size.Y * 0.5
		local rootPosition = groundPosition + Vector3.new(0, rootHeight, 0)
		model:PivotTo(CFrame.lookAt(rootPosition, rootPosition + facing))
		if not isBuildCurrent(generation, district) then
			model:Destroy()
			return
		end

		local attributes = PracticeDummyConfig.Attributes
		model:SetAttribute(attributes.IsPracticeDummy, true)
		model:SetAttribute(attributes.AvatarUserId, PracticeDummyConfig.AvatarUserId)
		model:SetAttribute(attributes.Generation, generation)
		model:SetAttribute(attributes.IsActive, true)
		model:SetAttribute(FighterVitalsConfig.Attributes.MaximumArmour, FighterVitalsConfig.MaximumArmour)
		model:SetAttribute(FighterVitalsConfig.Attributes.Armour, FighterVitalsConfig.MaximumArmour)
		humanoid.MaxHealth = FighterVitalsConfig.MaximumHealth
		humanoid.Health = FighterVitalsConfig.MaximumHealth
		local record = {
			Model = model,
			Humanoid = humanoid,
			Root = root,
			Generation = generation,
			TargetId = "D:CLOCK:" .. tostring(generation),
			IsActive = true,
			ResetToken = 0,
			ResetThread = nil,
			IdleTrack = nil,
			Connections = {},
		}
		activeRecord = record
		CollectionService:AddTag(model, PracticeDummyConfig.CollectionTag)
		model.Parent = ensureFolder()
		createReadout(record)
		playTrustedIdle(record)
		if PracticeDummyConfig.DiagnosticsEnabled then
			print("[BLIKK PRACTICE DUMMY] Created shared Clock Tower target " .. record.TargetId)
		end
		end, debug.traceback)
		if mapGeneration == generation then
			buildThread = nil
			cancelThread(buildTimeoutThread)
			buildTimeoutThread = nil
		end
		if not succeeded and mapGeneration == generation then
			warnDiagnostic("BUILD_EXCEPTION", tostring(buildError))
		end
	end)
	buildTimeoutThread = task.delay(PracticeDummyConfig.AvatarConstructionTimeoutSeconds, function()
		if mapGeneration ~= generation or activeRecord then return end
		warnDiagnostic("AVATAR_BUILD_TIMEOUT", string.format(
			"Shared dummy construction exceeded %.1f seconds.",
			PracticeDummyConfig.AvatarConstructionTimeoutSeconds
		))
		mapGeneration += 1
		cancelThread(buildThread)
		buildThread = nil
		buildTimeoutThread = nil
	end)
end

local function findRegisteredRecord(instance)
	local record = activeRecord
	return if record and instance and instance:IsDescendantOf(record.Model) then record else nil
end

function PracticeDummyService:ResolveTarget(hitInstance, attacker)
	local record = findRegisteredRecord(hitInstance)
	if not record or not attacker or attacker.Parent ~= Players
		or attacker:GetAttribute("BLIKK_CharacterContext") ~= "MovementLab"
		or attacker:GetAttribute("BLIKK_GameplayReleased") ~= true
		or roomService:GetRoom(attacker) or matchService:GetMatch(attacker) then return nil end
	local model = record.Model
	local attributes = PracticeDummyConfig.Attributes
	if activeRecord ~= record or not model:IsDescendantOf(ensureFolder())
		or not CollectionService:HasTag(model, PracticeDummyConfig.CollectionTag)
		or model:GetAttribute(attributes.IsPracticeDummy) ~= true
		or model:GetAttribute(attributes.AvatarUserId) ~= PracticeDummyConfig.AvatarUserId
		or model:GetAttribute(attributes.Generation) ~= record.Generation
		or model:GetAttribute(attributes.IsActive) ~= true
		or not record.IsActive or not record.Humanoid.Parent
		or record.Humanoid.Health <= 0 then return nil end
	return {
		Kind = "PracticeDummy",
		TargetId = record.TargetId,
		Humanoid = record.Humanoid,
		Record = record,
	}
end

function PracticeDummyService:IsTargetCurrent(target)
	local record = target and target.Record
	return record ~= nil and activeRecord == record and record.IsActive
		and record.Model:GetAttribute(PracticeDummyConfig.Attributes.IsActive) == true
		and record.Humanoid.Parent ~= nil and record.Humanoid.Health > 0
end

function PracticeDummyService:OnDamageApplied(target, damageResult)
	local record = target and target.Record
	if not record or activeRecord ~= record or type(damageResult) ~= "table" then return end
	cancelReset(record)
	local eliminated = damageResult.HealthAfter <= 0
	if eliminated then
		record.IsActive = false
		record.Model:SetAttribute(PracticeDummyConfig.Attributes.IsActive, false)
	end
	local token = record.ResetToken
	local delaySeconds = if eliminated
		then PracticeDummyConfig.Vitals.LethalRecoverySeconds
		else PracticeDummyConfig.Vitals.ResetAfterInactivitySeconds
	record.ResetThread = task.delay(delaySeconds, function()
		if activeRecord ~= record or record.ResetToken ~= token then return end
		record.ResetThread = nil
		restoreRecord(record)
	end)
end

function PracticeDummyService:OnMapRebuilt()
	invalidateMapOwnership()
	ensureFolder()
	local district = getDistrict()
	if district then beginDummyBuild(district) end
end

function PracticeDummyService:Init(roomServiceValue, matchServiceValue)
	if isInitialised then return self end
	isInitialised = true
	roomService = roomServiceValue
	matchService = matchServiceValue
	ensureFolder()
	return self
end

function PracticeDummyService:Destroy()
	if not isInitialised then return end
	isInitialised = false
	invalidateMapOwnership()
	if dummyFolder then dummyFolder:Destroy(); dummyFolder = nil end
end

return PracticeDummyService
