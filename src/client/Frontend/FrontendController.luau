local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterCreationController = require(script.Parent.CharacterCreationController)
local CharacterProfilesController = require(script.Parent.CharacterProfilesController)
local MultiplayerBrowserController = require(script.Parent.MultiplayerBrowserController)
local NavigationController = require(script.Parent.NavigationController)
local OperationsHubController = require(script.Parent.OperationsHubController)
local SplashScreenController = require(script.Parent.SplashScreenController)

local FrontendController = {}

local REMOTE_LOOKUP_TIMEOUT_SECONDS = 5
local isInitialised = false
local isInGameplay = false
local hasWarnedMissingSpawnRemote = false
local frontendGui = nil
local inputManagerReference = nil
local gameplayCameraReference = nil
local settingsControllerReference = nil
local chatControllerReference = nil

local function setFrontendActive(isActive)
	frontendGui.Enabled = isActive
	inputManagerReference:SetGameplayEnabled(not isActive)
	gameplayCameraReference:SetGameplayActive(not isActive)
	gameplayCameraReference:SetInterfaceOpen(isActive)
	settingsControllerReference:SetFrontendActive(isActive)
end

function FrontendController:ReturnToOperationsHub()
	if not isInitialised or not isInGameplay then return false end
	isInGameplay = false
	setFrontendActive(true)
	chatControllerReference:SetContext("Hidden")
	NavigationController:GoTo("OperationsHub", CharacterProfilesController:GetSelectedProfile())
	return true
end

function FrontendController:Init(inputManager, gameplayCamera, fighterController, settingsController, musicController, chatController)
	if isInitialised then return end
	isInitialised = true
	inputManagerReference = inputManager
	gameplayCameraReference = gameplayCamera
	settingsControllerReference = settingsController
	chatControllerReference = chatController
	inputManager:SetGameplayEnabled(false)
	gameplayCamera:SetInterfaceOpen(true)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BLIKKFrontend")
	if existing then existing:Destroy() end
	frontendGui = Instance.new("ScreenGui")
	frontendGui.Name = "BLIKKFrontend"; frontendGui.DisplayOrder = 100; frontendGui.IgnoreGuiInset = true
	frontendGui.ResetOnSpawn = false; frontendGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; frontendGui.Parent = playerGui
	NavigationController:CreateTransition(frontendGui)

	local function enterMovementLab()
		if isInGameplay then return end
		local remotes = ReplicatedStorage:WaitForChild("BLIKKRemotes", REMOTE_LOOKUP_TIMEOUT_SECONDS)
		local requestSpawn = remotes
			and remotes:WaitForChild("RequestMovementLabSpawn", REMOTE_LOOKUP_TIMEOUT_SECONDS)
		if not requestSpawn or not requestSpawn:IsA("RemoteEvent") then
			if not hasWarnedMissingSpawnRemote then
				hasWarnedMissingSpawnRemote = true
				warn("[BLIKK FRONTEND] Movement Lab is unavailable because its spawn remote did not initialise.")
			end
			return
		end
		isInGameplay = true
		NavigationController:Suspend()
		setFrontendActive(false)
		chatController:SetContext("Training")
		requestSpawn:FireServer()
		musicController:SetContext("MovementLab")
	end

	NavigationController:Register("Splash", SplashScreenController:Create(frontendGui, NavigationController))
	NavigationController:Register("Creation", CharacterCreationController:CreatePage(frontendGui, NavigationController))
	NavigationController:Register("Profiles", CharacterProfilesController:CreatePage(frontendGui, NavigationController, fighterController))
	NavigationController:Register("Multiplayer", MultiplayerBrowserController:CreatePage(frontendGui, NavigationController))
	NavigationController:Register("OperationsHub", OperationsHubController:CreatePage(
		frontendGui,
		enterMovementLab,
		function() settingsController:OpenFromFrontend() end,
		function() NavigationController:GoTo("Multiplayer") end,
		inputManager
	))
	settingsController:SetReturnToMenuCallback(function() self:ReturnToOperationsHub() end)
	settingsController:SetFrontendActive(true)
	NavigationController.Changed.Event:Connect(function(route)
		if not isInGameplay then chatController:SetContext(if route == "Multiplayer" then "Lobby" else "Hidden") end
	end)
	NavigationController:GoTo("Splash")
end

return FrontendController
