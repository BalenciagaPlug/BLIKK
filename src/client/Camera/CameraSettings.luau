local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before camera settings")
local CameraConfig = require(Shared.Camera.CameraConfig)

local CameraSettings = {}
CameraSettings.Changed = Instance.new("BindableEvent")

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

	if values[key] ~= value then
		values[key] = value
		self.Changed:Fire(key, value)
	end
end

function CameraSettings:ResetToDefaults()
	copyDefaults()
	self.Changed:Fire(nil, nil)
end

return CameraSettings
