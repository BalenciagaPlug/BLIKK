local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MenuCamera = require(script.Parent.MenuCamera)
local ProfileConfig = require(ReplicatedStorage.Shared.Character.ProfileConfig)

local Controller = {}
Controller.IdleRequested = Instance.new("BindableEvent")

local generation = 0
local renderConnection = nil
local currentRequest = nil
local watchersStarted = false
local GENERATED_AVATAR_ATTEMPTS = 2

local function findBlikkModel()
	for _, tagged in CollectionService:GetTagged("BLIKKFighterPreview") do
		if tagged:IsA("Model") then return tagged end
	end
	for _, container in { ReplicatedStorage, Workspace } do
		for _, name in { "BLIKKFighter", "BLIKKFighterRig" } do
			local candidate = container:FindFirstChild(name, true)
			if candidate and candidate:IsA("Model") then return candidate end
		end
	end
	return nil
end

local function cleanClone(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Tool") then descendant:Destroy() end
		if descendant:IsA("BasePart") then descendant.Anchored = true; descendant.CanCollide = false end
	end
end

local function createGeneratedAvatar(profile)
	local player = Players.LocalPlayer
	if player.UserId <= 0 then return nil end
	local success, avatar = pcall(function()
		return Players:CreateHumanoidModelFromUserId(player.UserId)
	end)
	if not success then return nil end
	avatar.Name = (profile and profile.Name or "BLIKK Fighter") .. "Preview"
	return avatar
end

local function cloneSource(profile, forceGenerated)
	local source = findBlikkModel()
	if forceGenerated then source = nil end
	if not source then
		local player = Players.LocalPlayer
		local hasCompleteAppearance = false
		if player.Character then
			local success, result = pcall(function() return player:HasAppearanceLoaded() end)
			hasCompleteAppearance = success and result
		end
		if hasCompleteAppearance and not forceGenerated then source = player.Character end
	end
	if not source then
		return createGeneratedAvatar(profile), "GeneratedAvatar"
	end
	local sourceKind = if source == Players.LocalPlayer.Character then "LiveAvatar" else "BlikkRig"
	local wasArchivable = source.Archivable
	source.Archivable = true
	local clone = source:Clone()
	source.Archivable = wasArchivable
	clone.Name = (profile and profile.Name or "BLIKK Fighter") .. "Preview"
	return clone, sourceKind
end

local R15_REQUIRED_DESCENDANTS = {
	"Humanoid", "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local function isValidR15Avatar(model)
	if not model then return false end
	for _, descendantName in R15_REQUIRED_DESCENDANTS do
		if not model:FindFirstChild(descendantName, true) then return false end
	end
	return model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function getValidatedPreviewClone(profile, activeGeneration)
	local clone, sourceKind = cloneSource(profile, false)
	local generatedAttempts = if sourceKind == "GeneratedAvatar" then 1 else 0
	if activeGeneration ~= generation then
		if clone then clone:Destroy() end
		return nil, nil
	end
	if sourceKind == "BlikkRig" or isValidR15Avatar(clone) then return clone, sourceKind end
	if clone then clone:Destroy() end

	while generatedAttempts < GENERATED_AVATAR_ATTEMPTS do
		generatedAttempts += 1
		clone = createGeneratedAvatar(profile)
		sourceKind = "GeneratedAvatar"
		if activeGeneration ~= generation then
			if clone then clone:Destroy() end
			return nil, nil
		end
		if isValidR15Avatar(clone) then return clone, sourceKind end
		if clone then clone:Destroy() end
	end
	return nil, nil
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
		removeMatchingAccessories(model, clone.AccessoryType)
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
	task.delay(1, resolve)
	completed.Event:Wait()
	connection:Disconnect()
	completed:Destroy()
	if activeGeneration ~= generation or not isValid() then return nil end
	return viewportFrame.AbsoluteSize
end

local function prepareStableBounds(model, cameraDirection, activeGeneration)
	faceCamera(model, Vector3.zero, cameraDirection)
	local firstCFrame, firstSize = model:GetBoundingBox()
	RunService.Heartbeat:Wait()
	if activeGeneration ~= generation then return nil end
	local secondCFrame, secondSize = model:GetBoundingBox()
	local sizeChanged = (secondSize - firstSize).Magnitude > 0.05
	local centerChanged = (secondCFrame.Position - firstCFrame.Position).Magnitude > 0.05
	local boundsCFrame = if sizeChanged or centerChanged then secondCFrame else firstCFrame
	local boundsSize = if sizeChanged or centerChanged then secondSize else firstSize
	local targetCenter = Vector3.new(0, boundsSize.Y * 0.5, 0)
	local offset = targetCenter - boundsCFrame.Position
	model:PivotTo(CFrame.new(offset) * model:GetPivot())
	return boundsSize, targetCenter
end

local function startWatchers()
	if watchersStarted then return end
	watchersStarted = true
	local function refreshIfActive(instance)
		if currentRequest and (instance.Name == "BLIKKFighter" or instance.Name == "BLIKKFighterRig" or CollectionService:HasTag(instance, "BLIKKFighterPreview")) then
			Controller:Render(currentRequest.Viewport, currentRequest.Profile, currentRequest.IdleHooks)
		end
	end
	ReplicatedStorage.DescendantAdded:Connect(refreshIfActive)
	Workspace.DescendantAdded:Connect(refreshIfActive)
	CollectionService:GetInstanceAddedSignal("BLIKKFighterPreview"):Connect(refreshIfActive)
end

function Controller:Render(viewportFrame, profile, enableIdleHooks)
	self:Stop()
	startWatchers()
	generation += 1
	local activeGeneration = generation
	currentRequest = { Viewport = viewportFrame, Profile = profile, IdleHooks = enableIdleHooks }
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

	task.spawn(function()
		local viewportSize = waitForValidViewportSize(viewportFrame, activeGeneration)
		if not viewportSize then return end
		local clone = getValidatedPreviewClone(profile, activeGeneration)
		if activeGeneration ~= generation then if clone then clone:Destroy() end; return end
		if not clone then
			if clone then clone:Destroy() end
			loading.Text = "PREVIEW UNAVAILABLE"
			return
		end

		applyProfileAppearance(clone, profile)
		cleanClone(clone)
		if activeGeneration ~= generation then clone:Destroy(); return end

		local hasMeasurablePart = clone:FindFirstChildWhichIsA("BasePart", true) ~= nil
		if not hasMeasurablePart then
			clone:Destroy()
			loading.Text = "PREVIEW MODEL HAS NO VISIBLE PARTS"
			return
		end

		local camera = MenuCamera:Attach(viewportFrame)
		local size, focus = prepareStableBounds(clone, Vector3.new(0, 0, 1), activeGeneration)
		if not size or not focus then clone:Destroy(); camera:Destroy(); return end
		local distance = MenuCamera:GetDistanceForBounds(camera, size, viewportSize)
		MenuCamera:Frame(camera, focus, distance, 0)
		local basePivot = faceCamera(clone, clone:GetPivot().Position, camera.CFrame.Position - focus)
		local world = Instance.new("WorldModel")
		clone.Parent = world
		world.Parent = viewportFrame

		if activeGeneration ~= generation then
			world:Destroy()
			camera:Destroy()
			return
		end
		loading:Destroy()
		viewportFrame.ImageTransparency = 0
		local startedAt = os.clock()
		renderConnection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - startedAt
			local showcaseElapsed = math.max(elapsed - 0.6, 0)
			clone:PivotTo(basePivot * CFrame.Angles(0, showcaseElapsed * 0.12, 0))
			MenuCamera:Frame(camera, focus, distance, elapsed)
		end)
		if enableIdleHooks then
			task.spawn(function()
				while activeGeneration == generation do
					task.wait(math.random(ProfileConfig.RandomIdleMinimumSeconds, ProfileConfig.RandomIdleMaximumSeconds))
					if activeGeneration == generation then self.IdleRequested:Fire(profile) end
				end
			end)
		end
	end)
end

function Controller:Stop()
	generation += 1
	currentRequest = nil
	if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
end

return Controller
