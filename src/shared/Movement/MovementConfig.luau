local MovementConfig = {
	Dash = {
		Distance = 12,
		Duration = 0.14,
		Cooldown = 0.18,
		DoubleTapWindow = 0.25,
		AirDashLimit = 1,
		PreserveVerticalVelocity = true,
	},

	Jump = {
		Height = 7.2,
	},

	Slash = {
		Cooldown = 0.28,
	},

	Block = {
		Instant = true,
	},

	Butterfly = {
		Window = 0.12,
	},

	SlashShot = {
		Window = 0.18,
	},

	ReloadShot = {
		Window = 0.16,
	},

	HalfStep = {
		Window = 0.20,
	},
}

return MovementConfig
