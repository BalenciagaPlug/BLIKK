local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FighterVitalsConfig = require(ReplicatedStorage.Shared.Combat.FighterVitalsConfig)

local FirearmDamageResolver = {}

local function finiteNonNegative(value)
	return type(value) == "number" and value == value and value < math.huge and value >= 0
end

function FirearmDamageResolver.Apply(targetHumanoid, rawDamage)
	local character = targetHumanoid and targetHumanoid.Parent
	if not targetHumanoid or not targetHumanoid:IsA("Humanoid")
		or not character or not character:IsA("Model")
		or not finiteNonNegative(rawDamage) then return nil end

	local attributes = FighterVitalsConfig.Attributes
	local maximumArmour = character:GetAttribute(attributes.MaximumArmour)
	if not finiteNonNegative(maximumArmour) then
		maximumArmour = FighterVitalsConfig.MaximumArmour
	end
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

return FirearmDamageResolver
