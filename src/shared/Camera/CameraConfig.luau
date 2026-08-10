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
		GapPixels = 4,
		LineLengthPixels = 7,
		ThicknessPixels = 2,
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0,
		DisplayOrder = 10,
	},
}

return CameraConfig
