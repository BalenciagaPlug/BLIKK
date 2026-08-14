local CameraConfig = {
	FieldOfViewDegrees = 80,
	MouseSensitivityDegreesPerPixel = 0.03,
	InvertY = false,
	NeutralPitchDegrees = 0,
	PitchMinDegrees = -70,
	PitchMaxDegrees = 70,
	CameraDistanceStuds = 13,
	CameraHeightAboveRootStuds = 3.25,
	CameraRightOffsetStuds = 2.5,

	MouseInput = {
		-- BLIKK owns sensitivity in degrees per input pixel. Keep Roblox's additional
		-- delta scale neutral so one physical delta is integrated exactly once.
		DeltaSensitivityScale = 1,
	},

	DeveloperFreeLook = {
		Enabled = true,
		PitchMinDegrees = -75,
		PitchMaxDegrees = 65,
		MinimumDistanceStuds = 5,
		MaximumDistanceStuds = 20,
		FallbackDistanceStuds = 13,
		TargetVerticalOffsetStuds = 2.5,
		OrbitSmoothingSpeed = 0,
		ReturnDurationSeconds = 0,
	},

	DeathCamera = {
		PitchMinDegrees = -70,
		PitchMaxDegrees = 55,
		MinimumDistanceStuds = 5,
		MaximumDistanceStuds = 18,
		FallbackDistanceStuds = 11,
		TargetVerticalOffsetStuds = 2.25,
		ZoomStepStuds = 1.5,
	},

	Obstruction = {
		FadeLocalTransparency = 0.72,
		FadeInSpeed = 18,
		FadeOutSpeed = 10,
		CollisionRadiusStuds = 0.45,
		CollisionPaddingStuds = 0.25,
		MinimumCameraDistanceStuds = 2,
		DistanceRestoreSpeed = 12,
		TargetOffsetsStuds = {
			Vector3.new(0, 3.0, 0),
			Vector3.new(0, 1.8, 0),
			Vector3.new(0, 0.5, 0),
			Vector3.new(-0.8, 1.8, 0),
			Vector3.new(0.8, 1.8, 0),
		},
		MaximumFadedParts = 12,
	},

	SettingsRanges = {
		FieldOfViewDegrees = {
			Minimum = 65,
			Maximum = 100,
			Step = 1,
		},
		CameraDistanceStuds = {
			Minimum = 8,
			Maximum = 20,
			Step = 0.5,
		},
		CameraHeightAboveRootStuds = {
			Minimum = 0.5,
			Maximum = 5,
			Step = 0.25,
		},
		CameraRightOffsetStuds = {
			Minimum = 0,
			Maximum = 5,
			Step = 0.25,
		},
		MouseSensitivityDegreesPerPixel = {
			Minimum = 0.003,
			Maximum = 0.5,
			Step = 0.001,
			Scale = "Logarithmic",
		},
	},

	Crosshair = {
		GapPixels = 5,
		LineLengthPixels = 14,
		ThicknessPixels = 2,
		DotSizePixels = 2,
		Opacity = 1,
		CenterDotEnabled = true,
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0,
		DisplayOrder = 10,
		SettingsRanges = {
			LineLengthPixels = { Minimum = 4, Maximum = 30, Step = 1 },
			ThicknessPixels = { Minimum = 1, Maximum = 6, Step = 1 },
			DotSizePixels = { Minimum = 1, Maximum = 10, Step = 1 },
			GapPixels = { Minimum = 0, Maximum = 18, Step = 1 },
			Opacity = { Minimum = 0.25, Maximum = 1, Step = 0.05 },
		},
	},
}

return CameraConfig
