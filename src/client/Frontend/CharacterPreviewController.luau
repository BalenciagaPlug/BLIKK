local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MenuCamera = require(script.Parent.MenuCamera)
local PreviewPoseAdapter = require(script.Parent.PreviewPoseAdapter)
local MeleePresentationConfig = require(ReplicatedStorage.Shared.Combat.MeleePresentationConfig)
local TrainingKatanaPresentation = require(ReplicatedStorage.Shared.Combat.TrainingKatanaPresentation)
local ProfileConfig = require(ReplicatedStorage.Shared.Character.ProfileConfig)
local StarterLoadout = require(ReplicatedStorage.Shared.Equipment.StarterLoadout)
local WeaponDefinitions = require(ReplicatedStorage.Shared.Equipment.WeaponDefinitions)

local Controller = {}
Controller.IdleRequested = Instance.new("BindableEvent")

local generation = 0
local renderConnection = nil
local inspectionConnections = {}
local timeoutThread = nil
local currentIdleTrack = nil
local currentViewport = nil
local currentPreviewSource = "UNAVAILABLE"
local cachedAvatarDescription = nil
local cachedAvatarRigType = nil
local diagnosedOutliers = {}
local retainedZoomDistance = nil
local retainedYawRadians = nil

local function resetInspectionState()
	retainedZoomDistance = ProfileConfig.PreviewInspection.DefaultCameraDistanceStuds
	retainedYawRadians = math.rad(ProfileConfig.PreviewInspection.DefaultYawDegrees)
end

local function disconnectInspection()
	for _, connection in inspectionConnections do connection:Disconnect() end
	table.clear(inspectionConnections)
end

local function isViewportActive(viewportFrame)
	if currentViewport ~= viewportFrame or not viewportFrame.Parent or not viewportFrame.Visible then
		return false
	end
	local ancestor = viewportFrame.Parent
	while ancestor do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
		if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
		ancestor = ancestor.Parent
	end
	return true
end
local R15_CORE_BODY_PARTS = {
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}
local R6_CORE_BODY_PARTS = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local function cleanClone(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Tool") then descendant:Destroy() end
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function destroyAnimationTrack(track)
	if not track then return end
	pcall(function() track:Stop(0) end)
	pcall(function() track:Destroy() end)
end

local function preparePreviewAnimator(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
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
		animator.Name = "PreviewAnimator"
		animator.Parent = humanoid
	end
	for _, track in animator:GetPlayingAnimationTracks() do destroyAnimationTrack(track) end
	return animator, humanoid
end

local function loadIdleTrack(animator, animationId)
	local animation = Instance.new("Animation")
	animation.Name = "PreviewIdle"
	animation.AnimationId = "rbxassetid://" .. tostring(animationId)
	local track = nil
	local succeeded, loadError = pcall(function()
		track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Core
		track.Looped = true
		track:Play(ProfileConfig.PreviewAnimation.InitialFadeSeconds, 1, 1)
	end)
	animation:Destroy()
	if not succeeded then
		destroyAnimationTrack(track)
		return nil, tostring(loadError)
	end
	return track, nil
end

local function playPreviewIdle(model)
	local animator, humanoid = preparePreviewAnimator(model)
	if not animator or not humanoid then return nil, nil, "Humanoid Animator unavailable" end
	-- HumanoidDescription animation fields can identify catalog animation items rather
	-- than loadable AnimationClips. Only repository-trusted clip IDs may reach Animator.
	local animationId = ProfileConfig.PreviewAnimation.TrustedIdleAnimationIds[humanoid.RigType.Name]
	if type(animationId) ~= "number" or animationId <= 0 then
		return nil, nil, "no trusted idle configured for rig type " .. humanoid.RigType.Name
	end
	local track, loadError = loadIdleTrack(animator, animationId)
	if track then return track, animationId, nil end
	return nil, nil, string.format("trusted idle %d failed (%s)", animationId, loadError)
end

local function isFiniteNumber(value)
	return value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector(value)
	return isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)
end

local R15_REQUIRED_DESCENDANTS = {
	"Humanoid", "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
local R6_REQUIRED_DESCENDANTS = {
	"Humanoid", "HumanoidRootPart", "Head", "Torso",
	"Left Arm", "Right Arm", "Left Leg", "Right Leg",
}

local function bodyMapForHumanoid(humanoid)
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return R6_CORE_BODY_PARTS, R6_REQUIRED_DESCENDANTS, "R6"
	end
	return R15_CORE_BODY_PARTS, R15_REQUIRED_DESCENDANTS, "R15"
end

local function validateAvatarIdentity(model)
	if not model then return false, "model missing" end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false, "missing Humanoid" end
	local coreBodyParts, requiredDescendants, rigName = bodyMapForHumanoid(humanoid)
	for _, descendantName in requiredDescendants do
		if not model:FindFirstChild(descendantName, true) then
			return false, "missing " .. descendantName
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart", true)
	if not root or not root:IsA("BasePart") then return false, "missing HumanoidRootPart" end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and coreBodyParts[descendant.Name]
			and descendant.Transparency < 1 and isFiniteVector(descendant.Position)
			and isFiniteVector(descendant.Size) then
			return true, nil, coreBodyParts, rigName
		end
	end
	return false, "no measurable body parts"
end

local function createNativeUserAvatar(profile)
	local succeeded, modelOrError = pcall(
		Players.CreateHumanoidModelFromUserIdAsync,
		Players,
		Players.LocalPlayer.UserId
	)
	if not succeeded or not modelOrError then return nil, tostring(modelOrError) end
	modelOrError.Name = (profile and profile.Name or "BLIKK Fighter") .. "Preview"
	return modelOrError, nil
end

local function createAvatarFromDescription(description, rigType, profile)
	local succeeded, result = pcall(
		Players.CreateHumanoidModelFromDescriptionAsync,
		Players,
		description,
		rigType
	)
	if not succeeded then return nil, tostring(result) end
	result.Name = (profile and profile.Name or "BLIKK Fighter") .. "Preview"
	return result, nil
end

local function cloneSource(source, profile)
	local wasArchivable = source.Archivable
	source.Archivable = true
	local clone = source:Clone()
	source.Archivable = wasArchivable
	clone.Name = (profile and profile.Name or "BLIKK Fighter") .. "Preview"
	return clone
end

local function collectBlikkSources(profile)
	local candidates = {}
	local seen = {}
	local function add(source, sourceKind)
		if not source or not source:IsA("Model") or seen[source] then return end
		seen[source] = true
		table.insert(candidates, { Model = cloneSource(source, profile), Source = sourceKind })
	end
	for _, tagged in CollectionService:GetTagged("BLIKKFighterPreview") do
		if tagged:IsDescendantOf(ReplicatedStorage) then add(tagged, "CANONICAL_BLIKK") end
	end
	for _, name in { "BLIKKFighter", "BLIKKFighterRig" } do
		add(ReplicatedStorage:FindFirstChild(name, true), "CANONICAL_BLIKK")
	end
	return candidates
end

local function getAvatarDescription()
	local description = cachedAvatarDescription and cachedAvatarDescription:Clone()
	local rigType = cachedAvatarRigType
	if description and rigType then return description, rigType, nil end

	local succeeded, result = pcall(
		Players.GetHumanoidDescriptionFromUserIdAsync,
		Players,
		Players.LocalPlayer.UserId
	)
	if not succeeded then return nil, nil, tostring(result) end
	description = result
	rigType = Enum.HumanoidRigType.R15
	cachedAvatarDescription = description:Clone()
	cachedAvatarRigType = rigType
	return description, rigType, nil
end

local function createUserAvatar(profile)
	local description, rigType, descriptionError = getAvatarDescription()
	if not description then return nil, descriptionError end
	local model, modelError = createAvatarFromDescription(description, rigType, profile)
	description:Destroy()
	return model, modelError
end

local function createPrimitiveR15Fallback(profile)
	local model = Instance.new("Model")
	model.Name = (profile and profile.Name or "BLIKK Fighter") .. "PreviewFallback"
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.Parent = model
	local definitions = {
		HumanoidRootPart = { Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), nil },
		LowerTorso = { Vector3.new(2, 1, 1), Vector3.new(0, 3, 0), "HumanoidRootPart" },
		UpperTorso = { Vector3.new(2, 1.6, 1), Vector3.new(0, 4.3, 0), "LowerTorso" },
		Head = { Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 5.75, 0), "UpperTorso" },
		LeftUpperArm = { Vector3.new(0.65, 1.4, 0.65), Vector3.new(-1.35, 4.45, 0), "UpperTorso" },
		LeftLowerArm = { Vector3.new(0.58, 1.3, 0.58), Vector3.new(-1.35, 3.1, 0), "LeftUpperArm" },
		LeftHand = { Vector3.new(0.58, 0.58, 0.58), Vector3.new(-1.35, 2.2, 0), "LeftLowerArm" },
		RightUpperArm = { Vector3.new(0.65, 1.4, 0.65), Vector3.new(1.35, 4.45, 0), "UpperTorso" },
		RightLowerArm = { Vector3.new(0.58, 1.3, 0.58), Vector3.new(1.35, 3.1, 0), "RightUpperArm" },
		RightHand = { Vector3.new(0.58, 0.58, 0.58), Vector3.new(1.35, 2.2, 0), "RightLowerArm" },
		LeftUpperLeg = { Vector3.new(0.75, 1.55, 0.75), Vector3.new(-0.55, 1.75, 0), "LowerTorso" },
		LeftLowerLeg = { Vector3.new(0.68, 1.5, 0.68), Vector3.new(-0.55, 0.25, 0), "LeftUpperLeg" },
		LeftFoot = { Vector3.new(0.72, 0.55, 1.1), Vector3.new(-0.55, -0.75, -0.18), "LeftLowerLeg" },
		RightUpperLeg = { Vector3.new(0.75, 1.55, 0.75), Vector3.new(0.55, 1.75, 0), "LowerTorso" },
		RightLowerLeg = { Vector3.new(0.68, 1.5, 0.68), Vector3.new(0.55, 0.25, 0), "RightUpperLeg" },
		RightFoot = { Vector3.new(0.72, 0.55, 1.1), Vector3.new(0.55, -0.75, -0.18), "RightLowerLeg" },
	}
	local parts = {}
	for name, definition in definitions do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = definition[1]
		part.Position = definition[2]
		part.Color = Color3.fromRGB(112, 115, 112)
		part.Anchored = false
		part.CanCollide = false
		part.Parent = model
		parts[name] = part
	end
	for name, definition in definitions do
		local parentName = definition[3]
		if parentName then
			local joint = Instance.new("Motor6D")
			joint.Name = parentName .. "To" .. name
			joint.Part0 = parts[parentName]
			joint.Part1 = parts[name]
			joint.C0 = parts[parentName].CFrame:ToObjectSpace(parts[name].CFrame)
			joint.Parent = parts[parentName]
		end
	end
	model.PrimaryPart = parts.HumanoidRootPart
	return model
end

local function removeSlotAppearance(model, slotName)
	for _, descendant in model:GetDescendants() do
		if descendant:GetAttribute("BLIKKPreviewSlot") == slotName then
			descendant:Destroy()
		elseif slotName == "Hair" and descendant:IsA("Accessory") and descendant.AccessoryType == Enum.AccessoryType.Hair then
			descendant:Destroy()
		end
	end
end

local function removeMatchingAccessories(model, accessoryType)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Accessory") and descendant.AccessoryType == accessoryType then
			descendant:Destroy()
		end
	end
end

local function applyAppearanceAsset(model, slotName, selection)
	local assets = ReplicatedStorage:FindFirstChild("BLIKKPreviewAssets")
	local slot = assets and assets:FindFirstChild(slotName)
	local asset = slot and slot:FindFirstChild(selection)
	if not asset then return end

	removeSlotAppearance(model, slotName)
	local clone = asset:Clone()
	clone:SetAttribute("BLIKKPreviewSlot", slotName)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if clone:IsA("Accessory") and humanoid then
		if clone.AccessoryType ~= Enum.AccessoryType.Unknown then
			removeMatchingAccessories(model, clone.AccessoryType)
		end
		humanoid:AddAccessory(clone)
	elseif clone:IsA("Shirt") or clone:IsA("Pants") or clone:IsA("ShirtGraphic") then
		local existing = model:FindFirstChildOfClass(clone.ClassName)
		if existing then existing:Destroy() end
		clone.Parent = model
	elseif clone:IsA("Decal") and slotName == "Face" then
		local head = model:FindFirstChild("Head")
		if not head then clone:Destroy(); return end
		local existing = head and head:FindFirstChild("face")
		if existing then existing:Destroy() end
		clone.Name = "face"
		clone.Parent = head
	else
		clone:Destroy()
	end
end

local function applyProfileAppearance(model, profile)
	if not profile then return end
	model:SetAttribute("BLIKK_BodyType", profile.BodyType)
	if not profile.Appearance then return end
	for _, slotName in { "Face", "Hair", "TopArmour", "Pants", "Boots" } do
		local selection = profile.Appearance[slotName]
		if selection then applyAppearanceAsset(model, slotName, selection) end
	end
end

local function removePresentationWeapons(model)
	local weapons = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("BLIKK_WeaponDefinition") then
			table.insert(weapons, descendant)
		end
	end
	for _, weapon in weapons do weapon:Destroy() end
end

local function buildTrainingKatana()
	local definitionId = StarterLoadout.Weapons.Melee
	local definition = definitionId and WeaponDefinitions[definitionId]
	if not definition or definition.Id ~= "TrainingKatana" then return nil end

	local model = TrainingKatanaPresentation.Build(true)
	model:SetAttribute("BLIKK_MenuPreview", true)
	return model
end

local function attachTrainingKatana(model)
	removePresentationWeapons(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	local attachment = MeleePresentationConfig.TrainingKatana.EquippedAttachment
	local bodyPartName = if humanoid.RigType == Enum.HumanoidRigType.R6
		then "Right Arm" else attachment.PartName
	local bodyPart = model:FindFirstChild(bodyPartName, true)
	if not bodyPart or not bodyPart:IsA("BasePart") then return false end

	local katana = buildTrainingKatana()
	if not katana or not katana.PrimaryPart then return false end
	-- WorldModels do not simulate a full Workspace assembly. Place the handle at the
	-- exact Motor6D solution before creating the joint so no origin-frame sword can render.
	local handleCFrame = bodyPart.CFrame * attachment.Offset * attachment.GripPivot:Inverse()
	katana:PivotTo(handleCFrame)
	katana.Parent = model
	local grip = Instance.new("Motor6D")
	grip.Name = "BLIKK_KatanaGrip"
	grip.Part0 = bodyPart
	grip.Part1 = katana.PrimaryPart
	grip.C0 = attachment.Offset
	grip.C1 = attachment.GripPivot
	grip.Parent = katana.PrimaryPart
	return true
end

local function collectMenuReadyPoseJoints(model)
	return PreviewPoseAdapter.Collect(model, MeleePresentationConfig.Pose.EquippedIdle)
end

local function applyMenuReadyPose(jointsByName)
	PreviewPoseAdapter.Apply(jointsByName, MeleePresentationConfig.Pose.EquippedIdle)
end

local function faceCamera(model, position, cameraDirection)
	model:PivotTo(CFrame.new(position))
	local pivot = model:GetPivot()
	local localForward = model:GetAttribute("BLIKKPreviewForward")
	if typeof(localForward) ~= "Vector3" or localForward.Magnitude < 0.001 then
		localForward = Vector3.new(0, 0, -1)
	end
	local currentForward = pivot:VectorToWorldSpace(localForward).Unit
	cameraDirection = Vector3.new(cameraDirection.X, 0, cameraDirection.Z).Unit
	local angle = math.atan2(currentForward:Cross(cameraDirection).Y, currentForward:Dot(cameraDirection))
	local frontFacingPivot = pivot * CFrame.Angles(0, angle, 0)
	model:PivotTo(frontFacingPivot)
	return frontFacingPivot
end

local function includePartBounds(part, minimum, maximum)
	local halfSize = part.Size * 0.5
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local corner = part.CFrame:PointToWorldSpace(halfSize * Vector3.new(x, y, z))
				minimum = minimum:Min(corner)
				maximum = maximum:Max(corner)
			end
		end
	end
	return minimum, maximum
end

local function collectCoreBounds(model, coreBodyParts)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and coreBodyParts[descendant.Name]
			and isFiniteVector(descendant.Position) and isFiniteVector(descendant.Size) then
			minimum, maximum = includePartBounds(descendant, minimum, maximum)
			count += 1
		end
	end
	if count == 0 or not isFiniteVector(minimum) or not isFiniteVector(maximum) then return nil end
	return minimum, maximum
end

local function waitForStableCoreBounds(model, coreBodyParts, activeGeneration)
	local config = ProfileConfig.PreviewBounds
	local deadline = os.clock() + config.StabilizationTimeoutSeconds
	local previousMinimum, previousMaximum = nil, nil
	local stableSamples = 0
	repeat
		RunService.Heartbeat:Wait()
		if activeGeneration ~= generation then return nil end
		local minimum, maximum = collectCoreBounds(model, coreBodyParts)
		if minimum and previousMinimum
			and (minimum - previousMinimum).Magnitude <= config.PositionToleranceStuds
			and (maximum - previousMaximum).Magnitude <= config.PositionToleranceStuds then
			stableSamples += 1
			if stableSamples >= config.StableSampleCount then return minimum, maximum end
		else
			stableSamples = 0
		end
		previousMinimum, previousMaximum = minimum, maximum
	until os.clock() >= deadline
	return previousMinimum, previousMaximum
end

local function diagnoseOutlier(category, part)
	if not ProfileConfig.PreviewBounds.DiagnosticsEnabled then return end
	local key = category .. ":" .. part.Name
	if diagnosedOutliers[key] then return end
	diagnosedOutliers[key] = true
	warn(string.format("[BLIKK PREVIEW BOUNDS:%s] Excluded %s", category, part:GetFullName()))
end

local function isAttachedCosmetic(part, model, coreBodyParts)
	local accessory = part:FindFirstAncestorOfClass("Accessory")
	if accessory and accessory:IsDescendantOf(model) then return true end
	local ancestor = part.Parent
	while ancestor and ancestor ~= model do
		if ancestor:GetAttribute("BLIKK_WeaponDefinition")
			or ancestor:GetAttribute("BLIKKPreviewSlot") then return true end
		ancestor = ancestor.Parent
	end
	for _, joint in part:GetChildren() do
		if joint:IsA("Weld") or joint:IsA("WeldConstraint") or joint:IsA("Motor6D") then
			local other = if joint.Part0 == part then joint.Part1 else joint.Part0
			if other and other:IsDescendantOf(model) and coreBodyParts[other.Name] then return true end
		end
	end
	return false
end

local function preparePreviewBounds(model, coreBodyParts, cameraDirection, activeGeneration)
	faceCamera(model, Vector3.zero, cameraDirection)
	local coreMinimum, coreMaximum = waitForStableCoreBounds(model, coreBodyParts, activeGeneration)
	if not coreMinimum then return nil end
	local config = ProfileConfig.PreviewBounds
	local coreCenter = (coreMinimum + coreMaximum) * 0.5
	local coreSize = coreMaximum - coreMinimum
	local allowedHalfExtent = coreSize * config.CosmeticMaximumExtentScale * 0.5
		+ Vector3.one * config.CorePaddingStuds
	local minimum, maximum = coreMinimum, coreMaximum

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not coreBodyParts[descendant.Name]
			and descendant.Name ~= "HumanoidRootPart" then
			local isFinite = isFiniteVector(descendant.Position) and isFiniteVector(descendant.Size)
			local isAttached = isAttachedCosmetic(descendant, model, coreBodyParts)
			local offset = descendant.Position - coreCenter
			local isAttachedExtent = isFinite and isAttached
				and math.abs(offset.X) <= allowedHalfExtent.X
				and math.abs(offset.Y) <= allowedHalfExtent.Y
				and math.abs(offset.Z) <= allowedHalfExtent.Z
				and descendant.Size.Magnitude <= coreSize.Magnitude * config.CosmeticMaximumExtentScale
			if isAttachedExtent then
				minimum, maximum = includePartBounds(descendant, minimum, maximum)
			else
				local category = if not isFinite
					then "NON_FINITE_PART"
					elseif not isAttached then "DETACHED_COSMETIC"
					else "EXTREME_COSMETIC"
				diagnoseOutlier(category, descendant)
			end
		end
	end

	local boundsSize = (maximum - minimum) * config.CameraPaddingScale
	if not isFiniteVector(boundsSize) or boundsSize.X <= 0 or boundsSize.Y <= 0 or boundsSize.Z <= 0 then
		return nil
	end
	local boundsCenter = (minimum + maximum) * 0.5
	local targetCenter = Vector3.new(0, boundsSize.Y * 0.5, 0)
	model:PivotTo(CFrame.new(targetCenter - boundsCenter) * model:GetPivot())
	return boundsSize, targetCenter
end

local function waitForValidViewportSize(viewportFrame, activeGeneration)
	local function isValid()
		local size = viewportFrame.AbsoluteSize
		return size.X >= 32 and size.Y >= 32
	end
	if isValid() then return viewportFrame.AbsoluteSize end

	local completed = Instance.new("BindableEvent")
	local isResolved = false
	local connection = nil
	local function resolve()
		if isResolved then return end
		isResolved = true
		completed:Fire()
	end
	connection = viewportFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if isValid() or activeGeneration ~= generation then resolve() end
	end)
	task.delay(ProfileConfig.PreviewTiming.ViewportSizeTimeoutSeconds, resolve)
	completed.Event:Wait()
	connection:Disconnect()
	completed:Destroy()
	if activeGeneration ~= generation or not isValid() then return nil end
	return viewportFrame.AbsoluteSize
end

function Controller:Render(viewportFrame, profile, enableIdleHooks)
	self:Stop()
	generation += 1
	local activeGeneration = generation
	currentViewport = viewportFrame
	viewportFrame.Active = true
	viewportFrame:ClearAllChildren()
	viewportFrame.ImageTransparency = 1
	local loading = Instance.new("TextLabel")
	loading.Name = "LoadingState"
	loading.BackgroundTransparency = 1
	loading.Font = Enum.Font.Code
	loading.Text = "PREPARING FIGHTER //"
	loading.TextColor3 = Color3.fromRGB(154, 213, 83)
	loading.TextSize = 12
	loading.Size = UDim2.fromScale(1, 1)
	loading.ZIndex = 10
	loading.Parent = viewportFrame
	local request = { Terminal = false, TimedOut = false, Reported = {} }
	local function report(source, reason)
		local key = source .. ":" .. reason
		if request.Reported[key] then return end
		request.Reported[key] = true
		warn(string.format("[BLIKK PREVIEW] %s rejected: %s", source, reason))
	end
	local function reportIdle(source, reason)
		local key = "IDLE"
		if request.Reported[key] then return end
		request.Reported[key] = true
		warn(string.format("[BLIKK PREVIEW:IDLE] %s: %s", source, reason))
	end
	local scheduledTimeout = nil
	scheduledTimeout = task.delay(ProfileConfig.PreviewTiming.RequestTimeoutSeconds, function()
		if timeoutThread == scheduledTimeout then timeoutThread = nil end
		if request.Terminal or activeGeneration ~= generation or not loading.Parent then return end
		request.Terminal = true
		request.TimedOut = true
		if request.Camera then request.Camera:Destroy(); request.Camera = nil end
		loading.Text = "PREVIEW UNAVAILABLE - RESELECT TO RETRY"
		warn("[BLIKK PREVIEW:TIMEOUT] Avatar preview generation exceeded its bounded request time.")
	end)
	timeoutThread = scheduledTimeout

	task.spawn(function()
		local viewportSize = waitForValidViewportSize(viewportFrame, activeGeneration)
		if not viewportSize then return end
		local camera = MenuCamera:Attach(viewportFrame)
		request.Camera = camera
		local function resolveFrame(model, coreBodyParts)
			local size, focus = preparePreviewBounds(
				model,
				coreBodyParts,
				Vector3.new(0, 0, 1),
				activeGeneration
			)
			if not size or not focus then return nil end
			local distance = math.clamp(
				MenuCamera:GetDistanceForBounds(camera, size, viewportSize),
				ProfileConfig.PreviewBounds.MinimumCameraDistanceStuds,
				ProfileConfig.PreviewBounds.MaximumCameraDistanceStuds
			)
			local sane = isFiniteVector(size) and isFiniteVector(focus) and isFiniteNumber(distance)
				and size.X > 0 and size.Y > 0 and size.Z > 0
			if not sane then return nil end
			return size, focus, distance
		end
		local candidates = {}
		local clone, world, poseJoints, idleTrack, size, focus, distance =
			nil, nil, nil, nil, nil, nil, nil
		local function tryCandidates(candidateList)
			for _, candidate in candidateList do
				if activeGeneration ~= generation or request.Terminal then
					candidate.Model:Destroy()
					continue
				end
				local candidateModel = candidate.Model
				local identityValid, rejectionReason, coreBodyParts, rigName = validateAvatarIdentity(
					candidateModel
				)
				if identityValid then
					applyProfileAppearance(candidateModel, profile)
					if not attachTrainingKatana(candidateModel) then
						identityValid = false
						rejectionReason = "Training Katana could not attach to the preview rig"
					end
				end
				cleanClone(candidateModel)
				local candidateWorld = Instance.new("WorldModel")
				candidateWorld.Name = "PreviewWorld_" .. candidate.Source
				candidateWorld.Parent = viewportFrame
				candidateModel.Parent = candidateWorld
				RunService.Heartbeat:Wait()
				if activeGeneration ~= generation or request.Terminal or not candidateModel.Parent then
					candidateWorld:Destroy()
					continue
				end
				local candidateIdleTrack, _, idleDiagnostic = playPreviewIdle(candidateModel)
				if idleDiagnostic then reportIdle(candidate.Source, idleDiagnostic) end
				RunService.Heartbeat:Wait()
				local candidatePoseJoints = collectMenuReadyPoseJoints(candidateModel)
				applyMenuReadyPose(candidatePoseJoints)
				RunService.Heartbeat:Wait()
				if activeGeneration == generation and not request.Terminal and identityValid then
					local candidateSize, candidateFocus, candidateDistance = resolveFrame(
						candidateModel,
						coreBodyParts
					)
					if candidateSize then
						clone, world, poseJoints, idleTrack =
							candidateModel, candidateWorld, candidatePoseJoints, candidateIdleTrack
						size, focus, distance = candidateSize, candidateFocus, candidateDistance
						currentPreviewSource = candidate.Source
						candidateModel:SetAttribute("BLIKK_PreviewRig", rigName)
						return true
					end
					rejectionReason = "unsafe or unmeasurable framing bounds"
				end
				if activeGeneration == generation and not request.Terminal then
					report(candidate.Source, rejectionReason or "request became unusable")
				end
				destroyAnimationTrack(candidateIdleTrack)
				candidateWorld:Destroy()
			end
			return false
		end

		local descriptionAvatar, descriptionError = createUserAvatar(profile)
		if descriptionAvatar then
			local descriptionCandidates = {
				{ Model = descriptionAvatar, Source = "ROBLOX_APPLIED_DESCRIPTION" },
			}
			table.insert(candidates, descriptionCandidates[1])
			tryCandidates(descriptionCandidates)
		else
			report("ROBLOX_APPLIED_DESCRIPTION", "generation failed: " .. tostring(descriptionError))
		end
		if not clone and activeGeneration == generation and not request.Terminal then
			local nativeAvatar, nativeError = createNativeUserAvatar(profile)
			if nativeAvatar then
				local nativeCandidates = { { Model = nativeAvatar, Source = "ROBLOX_AVATAR" } }
				table.insert(candidates, nativeCandidates[1])
				tryCandidates(nativeCandidates)
			else
				report("ROBLOX_AVATAR", "generation failed: " .. tostring(nativeError))
			end
		end
		if not clone and activeGeneration == generation and not request.Terminal then
			local fallbackCandidates = collectBlikkSources(profile)
			for _, candidate in fallbackCandidates do table.insert(candidates, candidate) end
			tryCandidates(fallbackCandidates)
		end
		if not clone and ProfileConfig.PreviewBounds.DeveloperPrimitiveFallbackEnabled
			and activeGeneration == generation and not request.Terminal then
			local diagnosticCandidates = {
				{ Model = createPrimitiveR15Fallback(profile), Source = "DEVELOPER_PRIMITIVE" },
			}
			table.insert(candidates, diagnosticCandidates[1])
			tryCandidates(diagnosticCandidates)
		end
		if not size or not clone or not world then
			if activeGeneration ~= generation or request.TimedOut then return end
			request.Terminal = true
			if timeoutThread then task.cancel(timeoutThread); timeoutThread = nil end
			camera:Destroy()
			currentPreviewSource = "UNAVAILABLE"
			loading.Text = "PREVIEW UNAVAILABLE — RESELECT TO RETRY"
			return
		end
		request.Terminal = true
		if timeoutThread then task.cancel(timeoutThread); timeoutThread = nil end
		for _, candidate in candidates do
			if candidate.Model ~= clone and candidate.Model.Parent == nil then candidate.Model:Destroy() end
		end
		MenuCamera:Frame(camera, focus, distance, 0)
		local basePivot = faceCamera(clone, clone:GetPivot().Position, camera.CFrame.Position - focus)
		if activeGeneration ~= generation then
			destroyAnimationTrack(idleTrack)
			world:Destroy()
			camera:Destroy()
			return
		end
		currentIdleTrack = idleTrack
		loading:Destroy()
		viewportFrame.ImageTransparency = 0
		local startedAt = os.clock()
		local inspection = ProfileConfig.PreviewInspection
		local yawRadians = retainedYawRadians or math.rad(inspection.DefaultYawDegrees)
		local isDragging = false
		local lastPointerX = 0
		distance = math.clamp(
			retainedZoomDistance or inspection.DefaultCameraDistanceStuds,
			inspection.MinimumCameraDistanceStuds,
			inspection.MaximumCameraDistanceStuds
		)
		retainedZoomDistance = distance
		retainedYawRadians = yawRadians
		local nextIdleAt = if enableIdleHooks
			then math.random(ProfileConfig.RandomIdleMinimumSeconds, ProfileConfig.RandomIdleMaximumSeconds)
			else nil
		table.insert(inspectionConnections, viewportFrame.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			isDragging = true
			lastPointerX = input.Position.X
		end))
		table.insert(inspectionConnections, viewportFrame.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
			distance = math.clamp(
				distance - input.Position.Z * inspection.ZoomStepStuds,
				inspection.MinimumCameraDistanceStuds,
				inspection.MaximumCameraDistanceStuds
			)
			retainedZoomDistance = distance
		end))
		table.insert(inspectionConnections, UserInputService.InputChanged:Connect(function(input)
			if not isDragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local pointerX = input.Position.X
			local deltaX = pointerX - lastPointerX
			lastPointerX = pointerX
			yawRadians = (yawRadians + math.rad(deltaX * inspection.DragDegreesPerPixel)) % (math.pi * 2)
			retainedYawRadians = yawRadians
		end))
		table.insert(inspectionConnections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and isDragging then
				isDragging = false
			end
		end))
		table.insert(inspectionConnections, UserInputService.WindowFocusReleased:Connect(function()
			isDragging = false
		end))
		renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
			if activeGeneration ~= generation or clone.Parent ~= world then return end
			applyMenuReadyPose(poseJoints)
			if not isViewportActive(viewportFrame) then return end
			local elapsed = os.clock() - startedAt
			if not isDragging then
				yawRadians = (yawRadians + math.rad(
					inspection.AutomaticRotationSpeedDegreesPerSecond
				) * deltaTime) % (math.pi * 2)
				retainedYawRadians = yawRadians
			end
			clone:PivotTo(basePivot * CFrame.Angles(0, yawRadians, 0))
			MenuCamera:Frame(camera, focus, distance, elapsed)
			if nextIdleAt and elapsed >= nextIdleAt then
				self.IdleRequested:Fire(profile)
				nextIdleAt = elapsed
					+ math.random(ProfileConfig.RandomIdleMinimumSeconds, ProfileConfig.RandomIdleMaximumSeconds)
			end
		end)
	end)
end

function Controller:GetPreviewSource()
	return currentPreviewSource
end

function Controller:BeginScreenSession()
	resetInspectionState()
end

function Controller:EndFrontendSession()
	self:Stop()
	resetInspectionState()
end

function Controller:Stop()
	generation += 1
	currentPreviewSource = "UNAVAILABLE"
	if timeoutThread then task.cancel(timeoutThread); timeoutThread = nil end
	disconnectInspection()
	if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
	destroyAnimationTrack(currentIdleTrack)
	currentIdleTrack = nil
	if currentViewport then
		currentViewport:ClearAllChildren()
		currentViewport.CurrentCamera = nil
		currentViewport = nil
	end
end

return Controller
