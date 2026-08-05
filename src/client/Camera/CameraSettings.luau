local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraConfig = require(Shared.Camera.CameraConfig)

local CameraSettings = {}

local values = {}

local settingKeys = {
	"FieldOfViewDegrees",
	"CameraDistanceStuds",
	"CameraHeightAboveRootStuds",
	"CameraRightOffsetStuds",
	"MouseSensitivityDegreesPerPixel",
	"InvertY",
}

local function copyDefaults()
	for _, key in settingKeys do
		values[key] = CameraConfig[key]
	end
end

copyDefaults()

function CameraSettings:Get(key)
	return values[key]
end

function CameraSettings:Set(key, value)
	if CameraConfig[key] == nil then
		return
	end

	values[key] = value
end

function CameraSettings:ResetToDefaults()
	copyDefaults()
end

return CameraSettings
