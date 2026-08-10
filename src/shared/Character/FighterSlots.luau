local FighterSlots = {
	Weapon = {
		Ordered = { "Melee", "Primary1", "Primary2" },
		ById = {
			Melee = { Id = "Melee", DisplayName = "MELEE", AcceptsWeaponSlot = "Melee" },
			Primary1 = { Id = "Primary1", DisplayName = "PRIMARY 1", AcceptsWeaponSlot = "Primary" },
			Primary2 = { Id = "Primary2", DisplayName = "PRIMARY 2", AcceptsWeaponSlot = "Primary" },
		},
	},
	Equipment = {
		Ordered = { "Equipment1", "Equipment2", "Equipment3", "Equipment4" },
	},
	Armour = {
		Ordered = { "Head", "Body", "Legs", "Feet" },
	},
	Ring = {
		Ordered = { "Ring1", "Ring2" },
	},
}

return FighterSlots
