local ProfileConfig = {
	MaximumProfiles = 5,
	DefaultLevel = 1,
	MaximumNameLength = 20,
	NamePattern = "^[%w _%-]+$",
	BodyTypes = { "Male", "Female" },
	Faces = { "VANGUARD", "RENEGADE", "WRAITH" },
	StarterHair = { "CROPPED", "SHAG", "SLICK" },
	StarterTopArmour = { "BLACK SHELL", "ASH SHELL", "OLIVE SHELL" },
	StarterPants = { "BLACK CARGO", "ASH CARGO", "INDIGO CARGO" },
	StarterBoots = { "COMBAT BLACK", "COMBAT GREY", "COMBAT OXIDE" },
	RandomIdleMinimumSeconds = 8,
	RandomIdleMaximumSeconds = 20,
}

return ProfileConfig
