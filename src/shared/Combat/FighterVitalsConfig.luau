local Attributes = table.freeze({
	Armour = "BLIKK_Armour",
	MaximumArmour = "BLIKK_MaximumArmour",
	FreshLifeInitialized = "BLIKK_FreshVitalsInitialized",
})

local FighterVitalsConfig = {
	MaximumHealth = 100,
	MaximumArmour = 100,
	Attributes = Attributes,
}

return table.freeze(FighterVitalsConfig)
