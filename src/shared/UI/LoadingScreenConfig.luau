local LoadingScreenConfig = {
	Default = {
		AssetName = "BLIKK_Loading_Default_01.png",
		ImageAssetId = "rbxassetid://129609609853716",
	},

	Contexts = {
		InitialBoot = {
			StatusText = "INITIALIZING BLIKK",
			DetailText = "PREPARING CLIENT SYSTEMS //",
		},
		MovementLab = {
			StatusText = "PREPARING MOVEMENT LAB",
			DetailText = "SECURING FIGHTER / CAMERA / HUD //",
		},
		Match = {
			StatusText = "PREPARING MATCH",
			DetailText = "SYNCHRONIZING PARTICIPANTS //",
		},
		Round = {
			StatusText = "PREPARING NEXT ROUND",
			DetailText = "RESETTING FIGHTER STATE //",
		},
		Join = {
			StatusText = "JOINING MATCH IN PROGRESS",
			DetailText = "SYNCHRONIZING WORLD STATE //",
		},
		Respawn = {
			StatusText = "REDEPLOYING FIGHTER",
			DetailText = "RESTORING COMBAT SYSTEMS //",
		},
	},

	-- Presentation assets degrade independently from required character/world readiness.
	AssetManifest = {
		Required = {},
		Preferred = {
			{
				Kind = "Image",
				AssetId = "rbxassetid://129609609853716",
				Name = "DefaultLoadingArtwork",
			},
		},
		Cosmetic = {},
	},

	Timing = {
		BootstrapReplicationTimeoutSeconds = 10,
		BootstrapHandoffTimeoutSeconds = 45,
		BootstrapFailureDisplaySeconds = 4,
		PlayerGuiLookupTimeoutSeconds = 10,
		PreloadTimeoutSeconds = 8,
		LoadingPulseSeconds = 0.9,
		DismissFadeSeconds = 0.24,
		FailureDisplaySeconds = 2.5,
		FightRenderLeadSeconds = 0.05,
		FightMaximumLeadSeconds = 120,
		FightBackdropFadeSeconds = 0.16,
		FightEntrySeconds = 0.12,
		FightHoldSeconds = 0.62,
		FightExitSeconds = 0.18,
	},

	Presentation = {
		DisplayOrder = 1000,
		BackgroundColor = Color3.fromRGB(0, 0, 0),
		ShadeColor = Color3.fromRGB(3, 4, 4),
		AccentColor = Color3.fromRGB(151, 217, 74),
		TextColor = Color3.fromRGB(235, 232, 218),
		MutedTextColor = Color3.fromRGB(137, 141, 132),
		FailureColor = Color3.fromRGB(183, 45, 48),
	},

	Fight = {
		Text = "FIGHT",
		SoundAssetId = "",
		SoundVolume = 0.85,
	},
}

return LoadingScreenConfig
