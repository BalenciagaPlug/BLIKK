local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CLIENT_REPLICATION_TIMEOUT_SECONDS = 10
local Shared = ReplicatedStorage:FindFirstChild("Shared")
	or ReplicatedStorage:WaitForChild("Shared", CLIENT_REPLICATION_TIMEOUT_SECONDS)
if not Shared then
	warn("[BLIKK CLIENT] Shared client dependencies did not replicate within the bounded bootstrap budget.")
	error("[BLIKK CLIENT] Required Shared dependencies were unavailable", 0)
end

local function requireRequired(moduleScript)
	local succeeded, result = pcall(require, moduleScript)
	if not succeeded then
		error(string.format(
			"[BLIKK CLIENT] Required module failed: %s\nDependency path: Client bootstrap -> %s\nOriginal error:\n%s",
			moduleScript:GetFullName(),
			moduleScript:GetFullName(),
			tostring(result)
		), 0)
	end
	return result
end

local AudioController = requireRequired(script.Audio.AudioController)
local MusicController = requireRequired(script.Audio.MusicController)
local PlayerPreferencesController = requireRequired(script.Settings.PlayerPreferencesController)
local GameplayCamera = requireRequired(script.Camera.GameplayCamera)
local FighterController = requireRequired(script.Character.FighterController)
local PoseCoordinator = requireRequired(script.Character.PoseCoordinator)
local FirearmPresentationController = requireRequired(script.Combat.FirearmPresentationController)
local MeleePresentationController = requireRequired(script.Combat.MeleePresentationController)
local WeaponPresentationCoordinator = requireRequired(script.Combat.WeaponPresentationCoordinator)
local CharacterProfilesController = requireRequired(script.Frontend.CharacterProfilesController)
local FrontendController = requireRequired(script.Frontend.FrontendController)
local InputManager = requireRequired(script.Input.InputManager)
local EnvironmentQualityController = requireRequired(script.Maps.EnvironmentQualityController)
local ActivityController = requireRequired(script.Multiplayer.ActivityController)
local DashPresentationController = requireRequired(script.Movement.DashPresentationController)
local TechniqueRhythmController = requireRequired(script.Movement.TechniqueRhythmController)
local WallInteractionController = requireRequired(script.Movement.WallInteractionController)
local SpectatorReplayController = requireRequired(script.Match.SpectatorReplayController)
local MatchPreparationController = requireRequired(script.Match.MatchPreparationController)
local HUDController = requireRequired(script.UI.HUDController)
local InputOverlayController = requireRequired(script.UI.InputOverlayController)
local PerformanceDisplayController = requireRequired(script.UI.PerformanceDisplayController)
local ScoreboardController = requireRequired(script.UI.ScoreboardController)
local SettingsController = requireRequired(script.UI.SettingsController)
local ChatController = requireRequired(script.UI.ChatController)
local UINavigationController = requireRequired(script.UI.UINavigationController)
local LoadingScreenController = requireRequired(script.UI.LoadingScreenController)
local NavigationController = requireRequired(script.Frontend.NavigationController)

local MovementEngine = requireRequired(Shared.Movement.MovementEngine)

local bootstrapStage = "NotStarted"
local function initialiseRequired(name, controller, ...)
	bootstrapStage = name
	controller:Init(...)
end

local bootstrapSucceeded, bootstrapError = pcall(function()
	initialiseRequired("InputManager", InputManager)
	InputManager:SetGameplayBlocked("LoadingScreen", true)
	initialiseRequired("UINavigationController", UINavigationController, InputManager)
	initialiseRequired(
		"LoadingScreenController",
		LoadingScreenController,
		InputManager,
		GameplayCamera,
		UINavigationController
	)
	initialiseRequired("MatchPreparationController", MatchPreparationController, LoadingScreenController)
	initialiseRequired("ActivityController", ActivityController, InputManager)
	initialiseRequired("PlayerPreferencesController", PlayerPreferencesController, CharacterProfilesController)
	initialiseRequired("EnvironmentQualityController", EnvironmentQualityController)
	initialiseRequired("FighterController", FighterController)
	initialiseRequired("PoseCoordinator", PoseCoordinator)
	initialiseRequired("GameplayCamera", GameplayCamera, InputManager)
	initialiseRequired("MovementEngine", MovementEngine, InputManager, GameplayCamera)
	initialiseRequired("DashPresentationController", DashPresentationController, MovementEngine, GameplayCamera)
	initialiseRequired(
		"WallInteractionController",
		WallInteractionController,
		InputManager,
		MovementEngine,
		GameplayCamera
	)
	initialiseRequired(
		"MeleePresentationController",
		MeleePresentationController,
		InputManager,
		FighterController,
		MovementEngine,
		WallInteractionController
	)
	initialiseRequired(
		"FirearmPresentationController",
		FirearmPresentationController,
		InputManager,
		FighterController,
		MovementEngine,
		GameplayCamera
	)
	initialiseRequired("WeaponPresentationCoordinator", WeaponPresentationCoordinator)
	initialiseRequired(
		"TechniqueRhythmController",
		TechniqueRhythmController,
		InputManager,
		MovementEngine,
		MeleePresentationController,
		WallInteractionController,
		FighterController,
		FirearmPresentationController
	)
	initialiseRequired("AudioController", AudioController)
	initialiseRequired("MusicController", MusicController, NavigationController)
	initialiseRequired("HUDController", HUDController, FighterController, FirearmPresentationController)
	initialiseRequired("InputOverlayController", InputOverlayController, InputManager)
	initialiseRequired("PerformanceDisplayController", PerformanceDisplayController)
	initialiseRequired("ScoreboardController", ScoreboardController, InputManager)
	initialiseRequired("SettingsController", SettingsController, InputManager, GameplayCamera)
	initialiseRequired("ChatController", ChatController, InputManager)
	initialiseRequired("SpectatorReplayController", SpectatorReplayController, InputManager, GameplayCamera)
	initialiseRequired("CharacterProfilesController", CharacterProfilesController)
	initialiseRequired(
		"FrontendController",
		FrontendController,
		InputManager,
		GameplayCamera,
		FighterController,
		SettingsController,
		MusicController,
		ChatController,
		MatchPreparationController,
		SpectatorReplayController
	)
end)

if not bootstrapSucceeded then
	if LoadingScreenController:IsVisible() then
		LoadingScreenController:Fail(
			LoadingScreenController:GetActiveIdentity(),
			"CLIENT INITIALIZATION FAILED // " .. bootstrapStage
		)
	end
	warn(string.format(
		"[BLIKK CLIENT] Failed to initialize %s: %s",
		bootstrapStage,
		tostring(bootstrapError)
	))
	error("[BLIKK CLIENT] Required client initialization failed: " .. bootstrapStage, 0)
end

LoadingScreenController:CompleteInitialBoot()
