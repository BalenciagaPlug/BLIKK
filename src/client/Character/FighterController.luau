local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before FighterController")
local CharacterDependency = require(Shared.Character.CharacterDependency)
local FighterConfig = require(Shared.Character.FighterConfig)
local FighterSlots = require(Shared.Character.FighterSlots)
local StarterLoadout = require(Shared.Equipment.StarterLoadout)
local WeaponDefinitions = require(Shared.Equipment.WeaponDefinitions)
local MultiplayerConfig = require(Shared.Multiplayer.MultiplayerConfig)

local FighterController = {}
FighterController.CharacterBound = Instance.new("BindableEvent")
FighterController.LoadoutChanged = Instance.new("BindableEvent")

local player = Players.LocalPlayer
local isInitialised = false
local characterGeneration = 0
local characterBindingTarget = nil
local cancelDependencyWatch = nil
local fighter = {
	BodyType = StarterLoadout.BodyType,
	ActiveWeaponSlot = StarterLoadout.ActiveWeaponSlot,
	Weapons = table.clone(StarterLoadout.Weapons),
	Equipment = table.clone(StarterLoadout.Equipment),
	Armour = table.clone(StarterLoadout.Armour),
	Rings = table.clone(StarterLoadout.Rings),
	Character = nil,
	Humanoid = nil,
	RootPart = nil,
}

local function contains(orderedSlots, slotId)
	for _, candidate in orderedSlots do
		if candidate == slotId then
			return true
		end
	end
	return false
end

local function publishCharacterState()
	local character = fighter.Character
	if not character then
		return
	end

	character:SetAttribute("BLIKK_Fighter", true)
	character:SetAttribute("BLIKK_BodyType", fighter.BodyType)
	character:SetAttribute("BLIKK_ActiveWeaponSlot", fighter.ActiveWeaponSlot)
	for slotId, definitionId in fighter.Weapons do
		character:SetAttribute("BLIKK_Weapon_" .. slotId, definitionId or "")
	end
	for slotId, definitionId in fighter.Equipment do
		character:SetAttribute("BLIKK_Equipment_" .. slotId, definitionId or "")
	end
	for slotId, definitionId in fighter.Armour do
		character:SetAttribute("BLIKK_Armour_" .. slotId, definitionId or "")
	end
	for slotId, definitionId in fighter.Rings do
		character:SetAttribute("BLIKK_Ring_" .. slotId, definitionId or "")
	end
end

local function bindCharacter(character)
	characterGeneration += 1
	local generation = characterGeneration
	characterBindingTarget = character
	if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
	cancelDependencyWatch = CharacterDependency.ObserveHumanoidAndRoot(
		character,
		MultiplayerConfig.CharacterDependencyTimeoutSeconds,
		function(humanoid, rootPart)
			if generation ~= characterGeneration or characterBindingTarget ~= character
				or character ~= player.Character then return end
			fighter.Character = character
			fighter.Humanoid = humanoid
			fighter.RootPart = rootPart
			publishCharacterState()
			character:SetAttribute("BLIKK_ClientFighterReady", true)
			FighterController.CharacterBound:Fire(character, fighter)
		end,
		function()
			if generation == characterGeneration and character == player.Character then
				warn("[BLIKK CHARACTER] Fighter dependencies remain incomplete; continuing to observe the current character.")
			end
		end
	)
end

function FighterController:GetFighter()
	return fighter
end

function FighterController:GetWeaponDefinition(slotId)
	local definitionId = fighter.Weapons[slotId]
	return definitionId and WeaponDefinitions[definitionId] or nil
end

function FighterController:GetAnimationHook(slotId, hookName)
	local definition = self:GetWeaponDefinition(slotId)
	return definition and definition.AnimationSet[hookName] or nil
end

function FighterController:GetPresentationHook(slotId, hookName)
	local definition = self:GetWeaponDefinition(slotId)
	return definition and definition.PresentationSet[hookName] or nil
end

function FighterController:SetBodyType(bodyType)
	if not FighterConfig.SupportedBodyTypes[bodyType] then
		return false
	end
	fighter.BodyType = bodyType
	publishCharacterState()
	self.LoadoutChanged:Fire("BodyType", bodyType)
	return true
end

function FighterController:EquipWeapon(slotId, definitionId)
	local slot = FighterSlots.Weapon.ById[slotId]
	local definition = WeaponDefinitions[definitionId]
	if not slot or not definition or slot.AcceptsWeaponSlot ~= definition.WeaponSlot then
		return false
	end
	fighter.Weapons[slotId] = definitionId
	publishCharacterState()
	self.LoadoutChanged:Fire("Weapon", slotId, definitionId)
	return true
end

function FighterController:SetActiveWeaponSlot(slotId)
	if not FighterSlots.Weapon.ById[slotId] or not fighter.Weapons[slotId] then
		return false
	end
	fighter.ActiveWeaponSlot = slotId
	publishCharacterState()
	self.LoadoutChanged:Fire("ActiveWeaponSlot", slotId)
	return true
end

function FighterController:SetEquipmentSlot(slotId, definitionId)
	if not contains(FighterSlots.Equipment.Ordered, slotId) then return false end
	fighter.Equipment[slotId] = definitionId or ""
	publishCharacterState()
	self.LoadoutChanged:Fire("Equipment", slotId, definitionId)
	return true
end

function FighterController:SetArmourSlot(slotId, definitionId)
	if not contains(FighterSlots.Armour.Ordered, slotId) then return false end
	fighter.Armour[slotId] = definitionId or ""
	publishCharacterState()
	self.LoadoutChanged:Fire("Armour", slotId, definitionId)
	return true
end

function FighterController:SetRingSlot(slotId, definitionId)
	if not contains(FighterSlots.Ring.Ordered, slotId) then return false end
	fighter.Rings[slotId] = definitionId or ""
	publishCharacterState()
	self.LoadoutChanged:Fire("Ring", slotId, definitionId)
	return true
end

function FighterController:Init()
	if isInitialised then return end
	isInitialised = true
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(character)
		if characterBindingTarget == character then
			characterGeneration += 1
			characterBindingTarget = nil
			if cancelDependencyWatch then cancelDependencyWatch(); cancelDependencyWatch = nil end
		end
		if fighter.Character == character then
			fighter.Character, fighter.Humanoid, fighter.RootPart = nil, nil, nil
		end
	end)
	if player.Character then bindCharacter(player.Character) end
end

return FighterController
