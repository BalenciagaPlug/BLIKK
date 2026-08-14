local LoadingScreenConfig = {
	Default = {
		AssetName = "BLIKK_Loading_Default_01.png",
		ImageAssetId = "rbxassetid://129609609853716",
	},

	-- The premium loading screen is assembled from independently published images so
	-- motion never requires destructive cropping or a baked UI. The existing default
	-- artwork remains the safe fallback if the premium background cannot be fetched.
	Layers = {
		Background = {
			AssetName = "BLIKK_Loading_AsianWarrior_Background_V1.png",
			ImageAssetId = "rbxassetid://98241025184666",
		},
		Smoke = {
			AssetName = "BLIKK_Loading_Smoke_V1.png",
			ImageAssetId = "rbxassetid://94830671214826",
		},
		Glare = {
			AssetName = "BLIKK_Loading_Glare_V1.png",
			ImageAssetId = "rbxassetid://89832524304874",
		},
		Logo = {
			ImageAssetId = "rbxassetid://77188572994526",
			-- The approved upload has transparent canvas padding. These coordinates
			-- isolate the visible mark without regenerating or distorting the logo.
			ImageRectOffset = Vector2.new(93, 127),
			ImageRectSize = Vector2.new(1350, 661),
		},
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
		SmokeDriftSeconds = 15,
		SecondarySmokeDurationScale = 0.83,
		LogoBreathSeconds = 5.2,
		LogoBreathScale = 1.014,
		GlareCycleSeconds = 8.5,
		GlareSweepSeconds = 0.7,
		LogoShimmerSeconds = 7.5,
		LogoShimmerSweepSeconds = 1.05,
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
		AccentColor = Color3.fromRGB(153, 62, 238),
		AccentSoftColor = Color3.fromRGB(92, 42, 151),
		TextColor = Color3.fromRGB(235, 232, 218),
		MutedTextColor = Color3.fromRGB(137, 141, 132),
		FailureColor = Color3.fromRGB(183, 45, 48),
		LogoPositionScale = Vector2.new(0.51, 0.42),
		LogoSizeScale = Vector2.new(0.54, 0.38),
	},

	Fight = {
		Text = "FIGHT",
	},
}

return LoadingScreenConfig
