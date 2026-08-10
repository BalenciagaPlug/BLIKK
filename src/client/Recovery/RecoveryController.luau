local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FighterVitalsConfig = require(ReplicatedStorage.Shared.Combat.FighterVitalsConfig)
local RecoveryConfig = require(ReplicatedStorage.Shared.Recovery.RecoveryConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local RecoveryController = {}
RecoveryController.InventoryChanged = Instance.new("BindableEvent")
RecoveryController.RecoveryPresented = Instance.new("BindableEvent")
RecoveryController.EquippedItemChanged = Instance.new("BindableEvent")

local player = Players.LocalPlayer
local intentRemote = nil
local resultRemote = nil
local sequence = 0
local feedbackGeneration = 0
local feedbackRoot = nil
local feedbackLabel = nil
local inspectionLabel = nil
local inspectedModel = nil
local inspectedSince = 0
local equippedItemId = nil
local equippedModel = nil
local hiddenWeaponParts = {}
local isInitialised = false

local function destroyEquippedModel()
	if equippedModel then equippedModel:Destroy(); equippedModel = nil end
end

local function setWeaponPresentationHidden(hidden)
	if not hidden then
		for part, transparency in hiddenWeaponParts do
			if part.Parent then part.LocalTransparencyModifier = transparency end
		end
		table.clear(hiddenWeaponParts)
		return
	end
	local character = player.Character
	if not character then return end
	for _, child in character:GetChildren() do
		local isWeaponModel = child:IsA("Model") and (
			child.Name == "TrainingKatana"
			or string.sub(child.Name, 1, 9) == "BLIKK_B8_"
		)
		if not isWeaponModel then continue end
		for _, descendant in child:GetDescendants() do
			if descendant:IsA("BasePart") and hiddenWeaponParts[descendant] == nil then
				hiddenWeaponParts[descendant] = descendant.LocalTransparencyModifier
				descendant.LocalTransparencyModifier = 1
			end
		end
	end
end

local function configurePresentationPart(part, color, material)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Color = color
	part.Material = material or Enum.Material.Metal
end

local function addWeldedDetail(handle, name, size, offset, color, material)
	local detail = Instance.new("Part")
	detail.Name = name
	detail.Size = size
	configurePresentationPart(detail, color, material)
	detail.CFrame = handle.CFrame * offset
	detail.Parent = handle.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = detail
	weld.Parent = detail
	return detail
end

local function createEquippedModel(itemId)
	destroyEquippedModel()
	local character = player.Character
	local definition = RecoveryConfig.Definitions[itemId]
	local hand = character and character:FindFirstChild("RightHand", true)
	if not definition or not hand or not hand:IsA("BasePart") then return end
	local model = Instance.new("Model")
	model.Name = "BLIKKEquippedRecovery"
	model:SetAttribute("BLIKK_RecoveryItemId", itemId)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = if definition.Delivery == "Self"
		then Vector3.new(0.62, 0.18, 0.18) else Vector3.new(0.52, 0.68, 0.18)
	handle.Shape = if definition.Delivery == "Self" then Enum.PartType.Cylinder else Enum.PartType.Block
	configurePresentationPart(handle, definition.Color, Enum.Material.Metal)
	handle.Parent = model
	model.PrimaryPart = handle
	if definition.Delivery == "Self" then
		addWeldedDetail(handle, "GlassCore", Vector3.new(0.32, 0.20, 0.20), CFrame.identity,
			definition.Color:Lerp(Color3.new(1, 1, 1), 0.55), Enum.Material.Neon)
		addWeldedDetail(handle, "InjectorTip", Vector3.new(0.12, 0.10, 0.10), CFrame.new(-0.36, 0, 0),
			Color3.fromRGB(215, 219, 224), Enum.Material.Metal)
	else
		addWeldedDetail(handle, "StatusStrip", Vector3.new(0.38, 0.08, 0.20), CFrame.new(0, 0.12, -0.02),
			definition.Color:Lerp(Color3.new(1, 1, 1), 0.45), Enum.Material.Neon)
		addWeldedDetail(handle, "Latch", Vector3.new(0.18, 0.12, 0.22), CFrame.new(0, -0.28, 0),
			Color3.fromRGB(32, 34, 39), Enum.Material.Metal)
	end
	model.Parent = character
	local grip = Instance.new("Motor6D")
	grip.Name = "BLIKKRecoveryGrip"
	grip.Part0 = hand
	grip.Part1 = handle
	grip.C0 = if definition.Delivery == "Self"
		then CFrame.new(0, -0.38, -0.10) * CFrame.Angles(0, 0, math.rad(90))
		else CFrame.new(0, -0.42, -0.16) * CFrame.Angles(math.rad(-8), 0, 0)
	grip.Parent = hand
	equippedModel = model
end

local function createFeedbackGui()
	local playerGui = player:WaitForChild("PlayerGui", MultiplayerConfig.CharacterDependencyTimeoutSeconds)
	if not playerGui then error("PlayerGui was unavailable during recovery initialization") end
	local existing = playerGui:FindFirstChild("BLIKKRecoveryFeedback")
	if existing then existing:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BLIKKRecoveryFeedback"
	gui.DisplayOrder = 27
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	feedbackRoot = Instance.new("Frame")
	feedbackRoot.Name = "RecoveryFlash"
	feedbackRoot.BackgroundTransparency = 1
	feedbackRoot.BorderSizePixel = 0
	feedbackRoot.Size = UDim2.fromScale(1, 1)
	feedbackRoot.Parent = gui
	feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.Font = Enum.Font.Code
	feedbackLabel.Position = UDim2.fromScale(0.5, 0.72)
	feedbackLabel.Size = UDim2.fromOffset(320, 42)
	feedbackLabel.Text = ""
	feedbackLabel.TextSize = 22
	feedbackLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	feedbackLabel.TextStrokeTransparency = 0.2
	feedbackLabel.TextTransparency = 1
	feedbackLabel.Parent = feedbackRoot

	inspectionLabel = Instance.new("TextLabel")
	inspectionLabel.Name = "PickupInspection"
	inspectionLabel.AnchorPoint = Vector2.new(0, 0.5)
	inspectionLabel.BackgroundColor3 = Color3.fromRGB(9, 10, 13)
	inspectionLabel.BackgroundTransparency = 0.18
	inspectionLabel.BorderSizePixel = 0
	inspectionLabel.Font = Enum.Font.Code
	inspectionLabel.Position = UDim2.new(0.5, 42, 0.5, 18)
	inspectionLabel.Size = UDim2.fromOffset(210, 50)
	inspectionLabel.Text = ""
	inspectionLabel.TextColor3 = Color3.new(1, 1, 1)
	inspectionLabel.TextSize = 14
	inspectionLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	inspectionLabel.TextStrokeTransparency = 0.35
	inspectionLabel.Visible = false
	inspectionLabel.ZIndex = 3
	inspectionLabel.Parent = feedbackRoot
end

local function presentRecovery(resource, recovered, text, color)
	feedbackGeneration += 1
	local generation = feedbackGeneration
	feedbackRoot.BackgroundColor3 = color
	feedbackRoot.BackgroundTransparency = 0.88
	feedbackLabel.Text = text or string.format("+%d %s", math.round(recovered),
		if resource == "Health" then "HP" else "AP")
	feedbackLabel.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.7)
	feedbackLabel.TextTransparency = 0
	TweenService:Create(feedbackRoot, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	local labelTween = TweenService:Create(feedbackLabel,
		TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.69),
		})
	labelTween:Play()
	labelTween.Completed:Connect(function()
		if generation ~= feedbackGeneration then return end
		feedbackLabel.Position = UDim2.fromScale(0.5, 0.72)
	end)
end

local function useItem(itemId)
	local definition = RecoveryConfig.Definitions[itemId]
	local character = player.Character
	local spawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
	if not definition or not character or type(spawnGeneration) ~= "number" then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	local resourceFull
	if definition.Resource == "Health" then
		resourceFull = humanoid.Health >= humanoid.MaxHealth
	else
		local maximum = character:GetAttribute(FighterVitalsConfig.Attributes.MaximumArmour)
		local current = character:GetAttribute(FighterVitalsConfig.Attributes.Armour)
		resourceFull = type(maximum) == "number" and type(current) == "number" and current >= maximum
	end
	if resourceFull then return false, "RESOURCE_FULL" end
	sequence += 1
	intentRemote:FireServer({
		Operation = "Use",
		ItemId = itemId,
		Sequence = sequence,
		SpawnGeneration = spawnGeneration,
	})
	return true
end

local function setEquippedItem(itemId)
	if itemId ~= nil and not RecoveryConfig.Definitions[itemId] then return end
	if equippedItemId == itemId then return end
	equippedItemId = itemId
	local character = player.Character
	if character then character:SetAttribute("BLIKK_ActiveRecoveryItem", itemId or "") end
	setWeaponPresentationHidden(itemId ~= nil)
	if itemId then createEquippedModel(itemId) else destroyEquippedModel() end
	RecoveryController.EquippedItemChanged:Fire(itemId)
end

local function updatePickupInspection()
	if not inspectionLabel then return end
	local camera = Workspace.CurrentCamera
	local character = player.Character
	if not camera or not character then inspectionLabel.Visible = false; return end
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local result = Workspace:Raycast(
		ray.Origin,
		ray.Direction * RecoveryConfig.InspectionMaximumDistanceStuds,
		params
	)
	local model = result and result.Instance:FindFirstAncestorOfClass("Model") or nil
	if not model or model:GetAttribute("BLIKK_RecoveryAvailable") == false
		or type(model:GetAttribute("BLIKK_RecoveryResource")) ~= "string" then
		inspectedModel = nil
		inspectionLabel.Visible = false
		return
	end
	if model ~= inspectedModel then
		inspectedModel = model
		inspectedSince = os.clock()
		inspectionLabel.Visible = false
		return
	end
	if os.clock() - inspectedSince < RecoveryConfig.InspectionHoldSeconds then
		inspectionLabel.Visible = false
		return
	end
	local resource = model:GetAttribute("BLIKK_RecoveryResource")
	local amount = model:GetAttribute("BLIKK_RecoveryAmount")
	if type(amount) ~= "number" then inspectionLabel.Visible = false; return end
	inspectionLabel.Text = if model:GetAttribute("BLIKK_RecoveryIsWorldCore") == true
		then string.format(
			"BLIKK CORE // +%d %s\nRESPAWN // %d S",
			amount,
			if resource == "Health" then "HP" else "AP",
			RecoveryConfig.WorldPickupRespawnSeconds
		)
		else string.format(
			"BLIKK DROP // +%d %s\nCONTACT TO COLLECT",
			amount,
			if resource == "Health" then "HP" else "AP"
		)
	inspectionLabel.TextColor3 = if resource == "Health"
		then RecoveryConfig.Definitions.VitalPatch.Color
		else RecoveryConfig.Definitions.AegisPatch.Color
	inspectionLabel.Visible = true
end

function RecoveryController:GetCount(itemId)
	local character = player.Character
	if not character then return 0 end
	local value = character:GetAttribute(RecoveryConfig.Attributes.CountPrefix .. itemId)
	return if type(value) == "number" then value else 0
end

function RecoveryController:GetEquippedItem()
	return equippedItemId
end

function RecoveryController:Init(inputManager, soundEffectsController)
	if isInitialised then return end
	isInitialised = true
	local remotes = ReplicatedStorage:WaitForChild("BLIKKRemotes", MultiplayerConfig.CharacterDependencyTimeoutSeconds)
	if not remotes then error("BLIKKRemotes was unavailable during recovery initialization") end
	intentRemote = remotes:WaitForChild("RecoveryIntent", MultiplayerConfig.CharacterDependencyTimeoutSeconds)
	resultRemote = remotes:WaitForChild("RecoveryResult", MultiplayerConfig.CharacterDependencyTimeoutSeconds)
	if not intentRemote or not resultRemote then error("Recovery remotes were unavailable") end
	createFeedbackGui()

	inputManager.ActionBegan.Event:Connect(function(action)
		local itemId = RecoveryConfig.ActionToItem[action]
		if itemId then
			setEquippedItem(itemId)
			soundEffectsController:Play("UIActivate")
		elseif action == "Primary" and equippedItemId then
			local sent, code = useItem(equippedItemId)
			if not sent and code == "RESOURCE_FULL" then
				soundEffectsController:Play("UIDenied")
			end
		elseif action == "EquipMelee" or action == "EquipWeapon1" or action == "EquipWeapon2"
			or action == "NextWeapon" or action == "PreviousWeapon" then
			setEquippedItem(nil)
		end
	end)
	resultRemote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then return end
		RecoveryController.InventoryChanged:Fire(payload.Counts)
		if payload.Accepted ~= true then
			if payload.Code == "EMPTY" or payload.Code == "RESOURCE_FULL" then
				soundEffectsController:Play("UIDenied")
			end
			return
		end
		local definition = payload.ItemId and RecoveryConfig.Definitions[payload.ItemId] or nil
		local color = definition and definition.Color
			or (if payload.Resource == "Health" then RecoveryConfig.Definitions.VitalPatch.Color
				else RecoveryConfig.Definitions.AegisPatch.Color)
		if type(payload.Recovered) == "number" and payload.Recovered > 0 then
			presentRecovery(payload.Resource, payload.Recovered, nil, color)
		elseif payload.Deployed and definition then
			presentRecovery(definition.Resource, 0, definition.DisplayName .. " // DEPLOYED", color)
		end
		soundEffectsController:Play("UIConfirm")
		RecoveryController.RecoveryPresented:Fire(payload)
	end)
	player.CharacterAdded:Connect(function(character)
		destroyEquippedModel()
		table.clear(hiddenWeaponParts)
		equippedItemId = nil
		character:SetAttribute("BLIKK_ActiveRecoveryItem", "")
		RecoveryController.EquippedItemChanged:Fire(nil)
		RecoveryController.InventoryChanged:Fire(nil)
	end)
	if player.Character then player.Character:SetAttribute("BLIKK_ActiveRecoveryItem", "") end
	RunService:BindToRenderStep("BLIKKPickupInspection", Enum.RenderPriority.Camera.Value + 2, updatePickupInspection)
end

return RecoveryController
