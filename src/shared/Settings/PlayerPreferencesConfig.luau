local CameraConfig = require(script.Parent.Parent.Camera.CameraConfig)
local SettingsConfig = require(script.Parent.SettingsConfig)

local PlayerPreferencesConfig = {}

PlayerPreferencesConfig.Definitions = {
	FieldOfViewDegrees = { Owner = "Camera", Type = "number", Default = CameraConfig.FieldOfViewDegrees, Range = CameraConfig.SettingsRanges.FieldOfViewDegrees },
	CameraDistanceStuds = { Owner = "Camera", Type = "number", Default = CameraConfig.CameraDistanceStuds, Range = CameraConfig.SettingsRanges.CameraDistanceStuds },
	CameraHeightAboveRootStuds = { Owner = "Camera", Type = "number", Default = CameraConfig.CameraHeightAboveRootStuds, Range = CameraConfig.SettingsRanges.CameraHeightAboveRootStuds },
	CameraRightOffsetStuds = { Owner = "Camera", Type = "number", Default = CameraConfig.CameraRightOffsetStuds, Range = CameraConfig.SettingsRanges.CameraRightOffsetStuds },
	MouseSensitivityDegreesPerPixel = { Owner = "Camera", Type = "number", Default = CameraConfig.MouseSensitivityDegreesPerPixel, Range = CameraConfig.SettingsRanges.MouseSensitivityDegreesPerPixel },
	InvertY = { Owner = "Camera", Type = "boolean", Default = CameraConfig.InvertY },
	MasterVolume = { Owner = "Session", Type = "number", Default = SettingsConfig.AudioDefaults.MasterVolume, Range = SettingsConfig.AudioRanges.MasterVolume },
	MusicVolume = { Owner = "Session", Type = "number", Default = SettingsConfig.AudioDefaults.MusicVolume, Range = SettingsConfig.AudioRanges.MusicVolume },
	SoundEffectsVolume = { Owner = "Session", Type = "number", Default = SettingsConfig.AudioDefaults.SoundEffectsVolume, Range = SettingsConfig.AudioRanges.SoundEffectsVolume },
	MusicMuted = { Owner = "Session", Type = "boolean", Default = SettingsConfig.AudioDefaults.MusicMuted },
	UIScale = { Owner = "Session", Type = "number", Default = SettingsConfig.ExtrasDefaults.UIScale, Range = SettingsConfig.ExtrasRanges.UIScale },
	HudScale = { Owner = "Session", Type = "number", Default = SettingsConfig.ExtrasDefaults.HudScale, Range = SettingsConfig.ExtrasRanges.HudScale },
	InputOverlayScale = { Owner = "Session", Type = "number", Default = SettingsConfig.ExtrasDefaults.InputOverlayScale, Range = SettingsConfig.ExtrasRanges.InputOverlayScale },
	InputOverlayOpacity = { Owner = "Session", Type = "number", Default = SettingsConfig.ExtrasDefaults.InputOverlayOpacity, Range = SettingsConfig.ExtrasRanges.InputOverlayOpacity },
	ChatOpacity = { Owner = "Session", Type = "number", Default = SettingsConfig.ExtrasDefaults.ChatOpacity, Range = SettingsConfig.ExtrasRanges.ChatOpacity },
	ChatScale = { Owner = "Session", Type = "number", Default = SettingsConfig.ExtrasDefaults.ChatScale, Range = SettingsConfig.ExtrasRanges.ChatScale },
	HudVisible = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.HudVisible },
	InputOverlayVisible = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.InputOverlayVisible },
	ReducedEffects = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.ReducedEffects },
	ChatVisible = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.ChatVisible },
	ChatTimestamps = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.ChatTimestamps },
	EffectsQuality = { Owner = "Session", Type = "string", Default = SettingsConfig.ExtrasDefaults.EffectsQuality, Allowed = { "HIGH", "MEDIUM", "LOW" } },
	RenderPreset = { Owner = "Session", Type = "string", Default = SettingsConfig.ExtrasDefaults.RenderPreset, Allowed = { "COMPETITIVE", "BALANCED", "CINEMATIC", "CUSTOM" } },
	LocalLightShadows = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.LocalLightShadows },
	BloomEnabled = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.BloomEnabled },
	ColorCorrectionEnabled = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.ColorCorrectionEnabled },
	AtmosphereEnabled = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.AtmosphereEnabled },
	ParticleDensity = { Owner = "Session", Type = "number", Default = SettingsConfig.ExtrasDefaults.ParticleDensity, Range = SettingsConfig.ExtrasRanges.ParticleDensity },
	WeaponTrailsEnabled = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.WeaponTrailsEnabled },
	ScreenShakeScale = { Owner = "Session", Type = "number", Default = SettingsConfig.ExtrasDefaults.ScreenShakeScale, Range = SettingsConfig.ExtrasRanges.ScreenShakeScale },
	ShowFPS = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.ShowFPS },
	ShowPing = { Owner = "Session", Type = "boolean", Default = SettingsConfig.ExtrasDefaults.ShowPing },
}

PlayerPreferencesConfig.Groups = {
	Camera = {
		"FieldOfViewDegrees", "CameraDistanceStuds", "CameraHeightAboveRootStuds",
		"CameraRightOffsetStuds", "MouseSensitivityDegreesPerPixel", "InvertY",
	},
}

function PlayerPreferencesConfig.DefaultPreferences()
	local defaults = {}
	for key, definition in PlayerPreferencesConfig.Definitions do defaults[key] = definition.Default end
	return defaults
end

function PlayerPreferencesConfig.ValidatePreference(key, value)
	local definition = PlayerPreferencesConfig.Definitions[key]
	if not definition or type(value) ~= definition.Type then return nil end
	if definition.Type == "number" then
		if value ~= value or value <= -math.huge or value >= math.huge then return nil end
		local range = definition.Range
		if value < range.Minimum or value > range.Maximum then return nil end
		if value == definition.Default then return value end
		local steps = math.floor((value - range.Minimum) / range.Step + 0.5)
		return math.clamp(range.Minimum + steps * range.Step, range.Minimum, range.Maximum)
	elseif definition.Allowed and not table.find(definition.Allowed, value) then
		return nil
	end
	return value
end

function PlayerPreferencesConfig.NormalizePreferences(source)
	local normalized = PlayerPreferencesConfig.DefaultPreferences()
	local diagnostics = {
		AddedMissingPreferenceDefaultCount = 0,
		ReplacedInvalidPreferenceCount = 0,
		RemovedUnknownPreferenceCount = 0,
	}
	if type(source) ~= "table" then
		for _ in PlayerPreferencesConfig.Definitions do
			diagnostics.AddedMissingPreferenceDefaultCount += 1
		end
		return normalized, diagnostics
	end
	local count = 0
	for key, value in source do
		count += 1
		local validated = PlayerPreferencesConfig.ValidatePreference(key, value)
		if not PlayerPreferencesConfig.Definitions[key] then
			diagnostics.RemovedUnknownPreferenceCount += 1
		elseif validated ~= nil then
			normalized[key] = validated
			if validated ~= value then diagnostics.ReplacedInvalidPreferenceCount += 1 end
		else
			diagnostics.ReplacedInvalidPreferenceCount += 1
		end
		if count > 32 then diagnostics.RemovedUnknownPreferenceCount += 1; break end
	end
	for key in PlayerPreferencesConfig.Definitions do
		if source[key] == nil then diagnostics.AddedMissingPreferenceDefaultCount += 1 end
	end
	return normalized, diagnostics
end

return PlayerPreferencesConfig
