local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)

local EnvironmentQualityController = {}
local isInitialised = false

local function applyQuality(quality)
	Lighting.GlobalShadows = quality ~= "LOW"
	local atmosphere = Lighting:FindFirstChild("BLIKK_DistrictZeroAtmosphere")
	if atmosphere and atmosphere:IsA("Atmosphere") then
		atmosphere.Density = if quality == "HIGH" then 0.17 elseif quality == "MEDIUM" then 0.1 else 0.03
	end
	local grade = Lighting:FindFirstChild("BLIKK_DistrictZeroGrade")
	if grade and grade:IsA("PostEffect") then grade.Enabled = quality ~= "LOW" end

	for _, instance in CollectionService:GetTagged("BLIKK_EnvironmentLight") do
		local light = instance:FindFirstChildWhichIsA("Light")
		if light then
			local tier = instance:GetAttribute("BLIKK_QualityTier") or light:GetAttribute("BLIKK_QualityTier")
			light.Enabled = tier == "ESSENTIAL" or quality == "HIGH" or (quality == "MEDIUM" and tier == "MEDIUM")
			light.Shadows = quality == "HIGH"
		end
	end
end

function EnvironmentQualityController:Init()
	if isInitialised then return end
	isInitialised = true
	applyQuality(SessionSettings:Get("EffectsQuality"))
	SessionSettings.Changed.Event:Connect(function(key, value)
		if key == "EffectsQuality" then applyQuality(value) end
	end)
	CollectionService:GetInstanceAddedSignal("BLIKK_EnvironmentLight"):Connect(function()
		applyQuality(SessionSettings:Get("EffectsQuality"))
	end)
end

return EnvironmentQualityController
