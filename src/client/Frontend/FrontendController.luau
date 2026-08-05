local Players = game:GetService("Players")

local CharacterCreationController = require(script.Parent.CharacterCreationController)
local CharacterProfilesController = require(script.Parent.CharacterProfilesController)
local NavigationController = require(script.Parent.NavigationController)
local OperationsHubController = require(script.Parent.OperationsHubController)
local SplashScreenController = require(script.Parent.SplashScreenController)
local SessionSettings = require(script.Parent.Parent.Settings.SessionSettings)

local FrontendController = {}
local isInitialised = false
local isInGameplay = false
local frontendGui = nil
local inputManagerReference = nil
local gameplayCameraReference = nil
local settingsControllerReference = nil

local function setFrontendActive(isActive)
	frontendGui.Enabled = isActive
	inputManagerReference:SetGameplayEnabled(not isActive)
	gameplayCameraReference:SetGameplayActive(not isActive)
	gameplayCameraReference:SetInterfaceOpen(isActive)
	settingsControllerReference:SetFrontendActive(isActive)
	SessionSettings:Set("HudVisible", not isActive)
	SessionSettings:Set("InputOverlayVisible", not isActive)
end

function FrontendController:ReturnToOperationsHub()
	if not isInitialised or not isInGameplay then return false end
	isInGameplay = false
	setFrontendActive(true)
	NavigationController:GoTo("OperationsHub", CharacterProfilesController:GetSelectedProfile())
	return true
end

function FrontendController:Init(inputManager, gameplayCamera, fighterController, settingsController, musicController)
	if isInitialised then return end
	isInitialised = true
	inputManagerReference = inputManager
	gameplayCameraReference = gameplayCamera
	settingsControllerReference = settingsController
	inputManager:SetGameplayEnabled(false)
	gameplayCamera:SetInterfaceOpen(true)
	SessionSettings:Set("HudVisible", false)
	SessionSettings:Set("InputOverlayVisible", false)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BLIKKFrontend")
	if existing then existing:Destroy() end
	frontendGui = Instance.new("ScreenGui")
	frontendGui.Name = "BLIKKFrontend"; frontendGui.DisplayOrder = 100; frontendGui.IgnoreGuiInset = true
	frontendGui.ResetOnSpawn = false; frontendGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; frontendGui.Parent = playerGui
	NavigationController:CreateTransition(frontendGui)

	local function enterMovementLab()
		if isInGameplay then return end
		isInGameplay = true
		NavigationController:Suspend()
		setFrontendActive(false)
		musicController:SetContext("MovementLab")
	end

	NavigationController:Register("Splash", SplashScreenController:Create(frontendGui, NavigationController))
	NavigationController:Register("Creation", CharacterCreationController:CreatePage(frontendGui, NavigationController))
	NavigationController:Register("Profiles", CharacterProfilesController:CreatePage(frontendGui, NavigationController, fighterController))
	NavigationController:Register("OperationsHub", OperationsHubController:CreatePage(
		frontendGui,
		enterMovementLab,
		function() settingsController:OpenFromFrontend() end,
		inputManager
	))
	settingsController:SetReturnToMenuCallback(function() self:ReturnToOperationsHub() end)
	settingsController:SetFrontendActive(true)
	NavigationController:GoTo("Splash")
end

return FrontendController
