local Attributes = table.freeze({
	CountPrefix = "BLIKK_RecoveryCount_",
	MaximumPrefix = "BLIKK_RecoveryMaximum_",
	InventoryGeneration = "BLIKK_RecoverySpawnGeneration",
})

local Definitions = {
	VitalPatch = table.freeze({
		Id = "VitalPatch",
		DisplayName = "VITAL PATCH",
		ShortName = "V-PATCH",
		Resource = "Health",
		Delivery = "Drop",
		Recovery = 10,
		StockPerLife = 2,
		Color = Color3.fromRGB(211, 52, 64),
	}),
	AegisPatch = table.freeze({
		Id = "AegisPatch",
		DisplayName = "AEGIS PATCH",
		ShortName = "A-PATCH",
		Resource = "Armour",
		Delivery = "Drop",
		Recovery = 10,
		StockPerLife = 2,
		Color = Color3.fromRGB(44, 145, 226),
	}),
	VitalAmp = table.freeze({
		Id = "VitalAmp",
		DisplayName = "VITAL AMP",
		ShortName = "V-AMP",
		Resource = "Health",
		Delivery = "Self",
		Recovery = 20,
		StockPerLife = 2,
		Color = Color3.fromRGB(255, 91, 99),
	}),
	AegisAmp = table.freeze({
		Id = "AegisAmp",
		DisplayName = "AEGIS AMP",
		ShortName = "A-AMP",
		Resource = "Armour",
		Delivery = "Self",
		Recovery = 20,
		StockPerLife = 2,
		Color = Color3.fromRGB(92, 189, 255),
	}),
}

local RecoveryConfig = {
	Attributes = Attributes,
	Definitions = table.freeze(Definitions),
	InventoryOrder = table.freeze({ "VitalPatch", "AegisPatch", "VitalAmp", "AegisAmp" }),
	ActionToItem = table.freeze({
		EquipTactical1 = "VitalPatch",
		EquipTactical2 = "AegisPatch",
		UseRecovery3 = "VitalAmp",
		UseRecovery4 = "AegisAmp",
	}),
	UseDelaySeconds = 1,
	MaximumRequestsPerSecond = 8,
	DroppedPickupLifetimeSeconds = 12,
	DroppedPickupClaimDelaySeconds = 0.15,
	WorldPickupRecovery = 100,
	WorldPickupRespawnSeconds = 45,
	WorldPickupTouchRadiusStuds = 3.2,
	ObserverEffectSeconds = 0.45,
	InspectionHoldSeconds = 3,
	InspectionMaximumDistanceStuds = 100,
}

return table.freeze(RecoveryConfig)
