local WeaponDefinitions = {
	TrainingKatana = {
		Id = "TrainingKatana",
		DisplayName = "TRAINING KATANA",
		Category = "Weapon",
		WeaponType = "Katana",
		WeaponSlot = "Melee",
		Rarity = "Training",
		Stats = {},
		AnimationSet = {
			Idle = "",
			Equip = "",
			Unequip = "",
		},
		PresentationSet = {
			SlashTrail = "",
			HitSparks = "",
		},
		EffectSet = {},
		Behaviour = {
			ModuleId = "",
			CombatEnabled = false,
		},
	},
	TrainingShotgun = {
		Id = "TrainingShotgun",
		DisplayName = "TRAINING SHOTGUN",
		Category = "Weapon",
		WeaponType = "Shotgun",
		WeaponSlot = "Primary",
		Rarity = "Training",
		Stats = {},
		AnimationSet = {
			Idle = "",
			Equip = "",
			Unequip = "",
		},
		PresentationSet = {
			MuzzleFlash = "",
			ShellEjection = "",
			Smoke = "",
		},
		EffectSet = {},
		Behaviour = {
			ModuleId = "",
			CombatEnabled = false,
		},
	},
}

return WeaponDefinitions
