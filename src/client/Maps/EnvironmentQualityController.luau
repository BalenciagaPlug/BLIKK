local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)
local Config = require(ReplicatedStorage.Shared.Maps.DistrictZero.DistrictZeroConfig).Lighting
local RenderQualityConfig = require(ReplicatedStorage.Shared.Settings.RenderQualityConfig)

local EnvironmentQualityController = {}
local isInitialised = false

local function effective(preset, key)
	return if preset then preset[key] else SessionSettings:Get(key)
end

local function applyQuality(quality)
	local preset = RenderQualityConfig.Presets[SessionSettings:Get("RenderPreset")]
	quality = preset and preset.EffectsQuality or quality
	local qualityScale = Config.QualityScaling[quality]
	local reducedEffects = SessionSettings:Get("ReducedEffects")
	Lighting.GlobalShadows = quality ~= "LOW"
	local atmosphere = Lighting:FindFirstChild("BLIKK_DistrictZeroAtmosphere")
	if atmosphere and atmosphere:IsA("Atmosphere") then
		atmosphere.Density = if effective(preset, "AtmosphereEnabled")
			then qualityScale.AtmosphereDensity else 0
	end
	local grade = Lighting:FindFirstChild("BLIKK_DistrictZeroGrade")
	if grade and grade:IsA("PostEffect") then grade.Enabled = quality ~= "LOW" and effective(preset, "ColorCorrectionEnabled") end
	local bloom = Lighting:FindFirstChild("BLIKK_DistrictZeroBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = qualityScale.BloomScale > 0 and not reducedEffects and effective(preset, "BloomEnabled")
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
				and effective(preset, "LocalLightShadows")
				and instance:GetAttribute("BLIKK_CastsShadowsAtHigh") == true
		end
	end
end

function EnvironmentQualityController:Init()
	if isInitialised then return end
	isInitialised = true
	applyQuality(SessionSettings:Get("EffectsQuality"))
	SessionSettings.Changed.Event:Connect(function(key, value)
		if key == "EffectsQuality" or key == "ReducedEffects" or key == "RenderPreset"
			or key == "LocalLightShadows" or key == "BloomEnabled"
			or key == "ColorCorrectionEnabled" or key == "AtmosphereEnabled" then
			applyQuality(SessionSettings:Get("EffectsQuality"))
		end
	end)
	CollectionService:GetInstanceAddedSignal("BLIKK_EnvironmentLight"):Connect(function()
		applyQuality(SessionSettings:Get("EffectsQuality"))
	end)
end

return EnvironmentQualityController
