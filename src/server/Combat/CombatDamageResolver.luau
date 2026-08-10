local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FighterVitalsConfig = require(ReplicatedStorage.Shared.Combat.FighterVitalsConfig)
local MeleeCombatConfig = require(ReplicatedStorage.Shared.Combat.MeleeCombatConfig)

local CombatDamageResolver = {}

local function finiteNonNegative(value)
	return type(value) == "number" and value == value and value < math.huge and value >= 0
end

function CombatDamageResolver.ResolveGuard(targetHumanoid, attackPosition, attackKind)
	local character = targetHumanoid and targetHumanoid.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local guard = MeleeCombatConfig.Guard
	if not targetHumanoid or not targetHumanoid:IsA("Humanoid")
		or targetHumanoid.Health <= 0 or not character or not character:IsA("Model")
		or not root or not root:IsA("BasePart") or typeof(attackPosition) ~= "Vector3"
		or character:GetAttribute(guard.AttributeName) ~= true then return false end

	local startedAt = character:GetAttribute(guard.StartedAtAttributeName)
	if not finiteNonNegative(startedAt) or os.clock() - startedAt > guard.MaximumDurationSeconds then
		character:SetAttribute(guard.AttributeName, false)
		return false
	end
	local toAttacker = Vector3.new(
		attackPosition.X - root.Position.X,
		0,
		attackPosition.Z - root.Position.Z
	)
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if toAttacker.Magnitude <= 0 or facing.Magnitude <= 0
		or facing.Unit:Dot(toAttacker.Unit) <= guard.MinimumFacingDot then return false end

	-- GunZ melee guard success ends the guard while ranged impacts may be held.
	if attackKind == "Melee" then character:SetAttribute(guard.AttributeName, false) end
	return true
end

function CombatDamageResolver.Apply(targetHumanoid, rawDamage)
	local character = targetHumanoid and targetHumanoid.Parent
	if not targetHumanoid or not targetHumanoid:IsA("Humanoid")
		or not character or not character:IsA("Model")
		or not finiteNonNegative(rawDamage) then return nil end

	local attributes = FighterVitalsConfig.Attributes
	local maximumArmour = character:GetAttribute(attributes.MaximumArmour)
	if not finiteNonNegative(maximumArmour) then maximumArmour = FighterVitalsConfig.MaximumArmour end
	local currentArmour = character:GetAttribute(attributes.Armour)
	if not finiteNonNegative(currentArmour) then currentArmour = 0 end
	currentArmour = math.clamp(currentArmour, 0, maximumArmour)

	local armourDamage = math.min(currentArmour, rawDamage)
	local requestedHealthDamage = math.max(0, rawDamage - armourDamage)
	local nextArmour = math.clamp(currentArmour - armourDamage, 0, maximumArmour)
	local healthBefore = math.max(0, targetHumanoid.Health)
	character:SetAttribute(attributes.Armour, nextArmour)
	if requestedHealthDamage > 0 then targetHumanoid:TakeDamage(requestedHealthDamage) end
	local healthAfter = math.max(0, targetHumanoid.Health)
	local healthDamage = math.max(0, healthBefore - healthAfter)

	return {
		RawDamage = rawDamage,
		ArmourDamage = armourDamage,
		HealthDamage = healthDamage,
		ArmourBefore = currentArmour,
		ArmourAfter = nextArmour,
		HealthBefore = healthBefore,
		HealthAfter = healthAfter,
	}
end

return CombatDamageResolver
