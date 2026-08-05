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
