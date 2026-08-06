local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local Config = require(ReplicatedStorage.Shared.Maps.DistrictZero.DistrictZeroConfig).Lighting

local EnvironmentQualityController = {}
local isInitialised = false

local function applyQuality(quality)
	local qualityScale = Config.QualityScaling[quality]
	local reducedEffects = SessionSettings:Get("ReducedEffects")
	Lighting.GlobalShadows = quality ~= "LOW"
	local atmosphere = Lighting:FindFirstChild("BLIKK_DistrictZeroAtmosphere")
	if atmosphere and atmosphere:IsA("Atmosphere") then
		atmosphere.Density = qualityScale.AtmosphereDensity
	end
	local grade = Lighting:FindFirstChild("BLIKK_DistrictZeroGrade")
	if grade and grade:IsA("PostEffect") then grade.Enabled = quality ~= "LOW" end
	local bloom = Lighting:FindFirstChild("BLIKK_DistrictZeroBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = qualityScale.BloomScale > 0 and not reducedEffects
		bloom.Intensity = Config.PostProcessing.BloomIntensity * qualityScale.BloomScale
	end

	for _, instance in CollectionService:GetTagged("BLIKK_EnvironmentLight") do
		local light = instance:FindFirstChildWhichIsA("Light")
		if light then
			local tier = instance:GetAttribute("BLIKK_QualityTier") or light:GetAttribute("BLIKK_QualityTier")
			local enabledByQuality = tier == "ESSENTIAL"
				or (tier == "MEDIUM" and quality ~= "LOW")
				or (tier == "HIGH" and quality == "HIGH" and not reducedEffects)
			light.Enabled = enabledByQuality
			light.Brightness = (light:GetAttribute("BLIKK_BaseBrightness") or light.Brightness)
				* qualityScale.BrightnessScale
			light.Range = (light:GetAttribute("BLIKK_BaseRange") or light.Range)
				* qualityScale.RangeScale
			light.Shadows = enabledByQuality
				and quality == "HIGH"
				and instance:GetAttribute("BLIKK_CastsShadowsAtHigh") == true
		end
	end
end

function EnvironmentQualityController:Init()
	if isInitialised then return end
	isInitialised = true
	applyQuality(SessionSettings:Get("EffectsQuality"))
	SessionSettings.Changed.Event:Connect(function(key, value)
		if key == "EffectsQuality" or key == "ReducedEffects" then
			applyQuality(SessionSettings:Get("EffectsQuality"))
		end
	end)
	CollectionService:GetInstanceAddedSignal("BLIKK_EnvironmentLight"):Connect(function()
		applyQuality(SessionSettings:Get("EffectsQuality"))
	end)
end

return EnvironmentQualityController
