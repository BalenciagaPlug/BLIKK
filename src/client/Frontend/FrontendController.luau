local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadingScreenConfig = require(ReplicatedStorage.Shared.UI.LoadingScreenConfig)

local CharacterCreationController = require(script.Parent.CharacterCreationController)
local CharacterProfilesController = require(script.Parent.CharacterProfilesController)
local ClanController = require(script.Parent.ClanController)
local MultiplayerBrowserController = require(script.Parent.MultiplayerBrowserController)
local NavigationController = require(script.Parent.NavigationController)
local OperationsHubController = require(script.Parent.OperationsHubController)
local SplashScreenController = require(script.Parent.SplashScreenController)

local FrontendController = {}

local isInitialised = false
local isInGameplay = false
local hasWarnedMissingSpawnRemote = false
local frontendGui = nil
local gameplayCameraReference = nil
local settingsControllerReference = nil
local chatControllerReference = nil
local multiplayerPageReference = nil
local matchPreparationControllerReference = nil
local musicControllerReference = nil

local function setFrontendActive(isActive)
	frontendGui.Enabled = isActive
	gameplayCameraReference:SetGameplayActive(not isActive)
	settingsControllerReference:SetFrontendActive(isActive)
	musicControllerReference:SetFrontendActive(isActive)
end

function FrontendController:ReturnToOperationsHub()
	if not isInitialised then return false end
	if multiplayerPageReference and multiplayerPageReference:HasCurrentRoom() then
		return multiplayerPageReference:LeaveCurrentRoom()
	end
	if not isInGameplay then return false end
	if matchPreparationControllerReference then
		matchPreparationControllerReference:ExitMovementLab()
	end
	isInGameplay = false
	setFrontendActive(true)
	chatControllerReference:SetContext("Hidden")
	NavigationController:GoTo("OperationsHub", CharacterProfilesController:GetSelectedProfile())
	return true
end

function FrontendController:Init(
	inputManager,
	gameplayCamera,
	fighterController,
	settingsController,
	musicController,
	chatController,
	matchPreparationController,
	spectatorReplayController
)
	if isInitialised then return end
	isInitialised = true
	gameplayCameraReference = gameplayCamera
	settingsControllerReference = settingsController
	chatControllerReference = chatController
	matchPreparationControllerReference = matchPreparationController
	musicControllerReference = musicController
	inputManager:SetGameplayEnabled(false)
	gameplayCamera:SetInterfaceOpen(true)

	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then error("[BLIKK FRONTEND] PlayerGui was unavailable after bootstrap", 0) end
	local existing = playerGui:FindFirstChild("BLIKKFrontend")
	if existing then existing:Destroy() end
	frontendGui = Instance.new("ScreenGui")
	frontendGui.Name = "BLIKKFrontend"; frontendGui.DisplayOrder = 100; frontendGui.IgnoreGuiInset = true
	frontendGui.ResetOnSpawn = false; frontendGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; frontendGui.Parent = playerGui
	NavigationController:CreateTransition(frontendGui)

	local function enterMovementLab()
		if isInGameplay then return end
		if not matchPreparationController:BeginMovementLab() then
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
	end

	local function enterMultiplayerGameplay(matchSnapshot)
		if isInGameplay then return true end
		isInGameplay = true
		NavigationController:Suspend()
		setFrontendActive(false)
		chatController:SetContext(if matchSnapshot.ModeId == "Training" then "Training" else "Match")
		return true
	end

	local function showMultiplayerRoomLobby()
		isInGameplay = false
		setFrontendActive(true)
		chatController:SetContext("Lobby")
		NavigationController:GoTo("Multiplayer")
	end

	local function returnToHubAfterRoomLeave()
		isInGameplay = false
		setFrontendActive(true)
		chatController:SetContext("Hidden")
		NavigationController:GoTo("OperationsHub", CharacterProfilesController:GetSelectedProfile())
	end

	NavigationController:Register("Splash", SplashScreenController:Create(frontendGui, NavigationController))
	NavigationController:Register("Creation", CharacterCreationController:CreatePage(frontendGui, NavigationController))
	NavigationController:Register("Profiles", CharacterProfilesController:CreatePage(frontendGui, NavigationController, fighterController))
	multiplayerPageReference = MultiplayerBrowserController:CreatePage(frontendGui, NavigationController, {
		EnterGameplay = enterMultiplayerGameplay,
		MatchUpdated = function(snapshot)
			spectatorReplayController:AdoptMatchSnapshot(snapshot)
			matchPreparationController:AdoptMatchSnapshot(snapshot)
		end,
		ShowRoomLobby = showMultiplayerRoomLobby,
		ReturnToHub = returnToHubAfterRoomLeave,
	})
	matchPreparationController.TransitionFailed.Event:Connect(function(context)
		if context ~= "MovementLab" then return end
		task.delay(
			LoadingScreenConfig.Timing.FailureDisplaySeconds
				+ LoadingScreenConfig.Timing.DismissFadeSeconds,
			function()
				if isInGameplay and not multiplayerPageReference:HasCurrentRoom() then
					FrontendController:ReturnToOperationsHub()
				end
			end
		)
	end)
	NavigationController:Register("Multiplayer", multiplayerPageReference)
	NavigationController:Register("Clans", ClanController:CreatePage(frontendGui, NavigationController))
	NavigationController:Register("OperationsHub", OperationsHubController:CreatePage(
		frontendGui,
		enterMovementLab,
		function() settingsController:OpenFromFrontend() end,
		function() NavigationController:GoTo("Multiplayer") end,
		function() NavigationController:GoTo("Clans") end,
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
