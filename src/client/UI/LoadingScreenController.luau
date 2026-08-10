local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LoadingScreenConfig = require(ReplicatedStorage.Shared.UI.LoadingScreenConfig)
local LoadingScreenView = require(ReplicatedStorage.Shared.UI.LoadingScreenView)

local LoadingScreenController = {}

LoadingScreenController.AssetPreloadCompleted = Instance.new("BindableEvent")
LoadingScreenController.Failed = Instance.new("BindableEvent")
LoadingScreenController.FightPresented = Instance.new("BindableEvent")
LoadingScreenController.VisibilityChanged = Instance.new("BindableEvent")

local GAMEPLAY_BLOCKER_OWNER = "LoadingScreen"
local NAVIGATION_SCOPE_ID = "LoadingScreen"

local isInitialised = false
local inputManager = nil
local gameplayCamera = nil
local uiNavigationController = nil
local loadingScope = nil
local view = nil
local isVisible = false
local ownsGameplayBlock = false
local activeContext = nil
local activeIdentity = nil
local activeGeneration = 0
local activeFightArmToken = 0
local armedReleaseAtServerTime = nil
local isFightPresented = false
local isDismissing = false
local releaseWakeThread = nil
local releaseWatchConnection = nil
local fightRevealConnection = nil
local pulseTween = nil
local activeTweens = {}
local tweenConnections = {}
local hasWarnedLegacyInput = false
local hasWarnedLegacyCamera = false
local hasWarnedPreloadTimeout = false
local warnedAssetFailures = {}

local function forgetTween(tween)
	local connection = tweenConnections[tween]
	if connection then connection:Disconnect() end
	tweenConnections[tween] = nil
	activeTweens[tween] = nil
	tween:Destroy()
end

local function cancelTween(tween)
	if not tween or not activeTweens[tween] then return end
	local connection = tweenConnections[tween]
	if connection then connection:Disconnect() end
	tweenConnections[tween] = nil
	activeTweens[tween] = nil
	tween:Cancel()
	tween:Destroy()
end

local function cancelAllTweens()
	local tweens = {}
	for tween in activeTweens do table.insert(tweens, tween) end
	for _, tween in tweens do cancelTween(tween) end
	pulseTween = nil
end

local function playTween(instance, tweenInfo, goal, completed)
	local tween = TweenService:Create(instance, tweenInfo, goal)
	activeTweens[tween] = true
	tweenConnections[tween] = tween.Completed:Connect(function(playbackState)
		local shouldComplete = playbackState == Enum.PlaybackState.Completed
		forgetTween(tween)
		if shouldComplete and completed then completed() end
	end)
	tween:Play()
	return tween
end

local function stopPulse()
	if pulseTween then cancelTween(pulseTween) end
	pulseTween = nil
end

local function startPulse()
	stopPulse()
	view.Pulse.GroupTransparency = 0.15
	pulseTween = playTween(
		view.Pulse,
		TweenInfo.new(
			LoadingScreenConfig.Timing.LoadingPulseSeconds,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		),
		{ GroupTransparency = 0.72 }
	)
end

local function disconnectReleaseWatch()
	if releaseWatchConnection then releaseWatchConnection:Disconnect() end
	releaseWatchConnection = nil
	if fightRevealConnection then fightRevealConnection:Disconnect() end
	fightRevealConnection = nil
end

local function cancelFightArm()
	activeFightArmToken += 1
	armedReleaseAtServerTime = nil
	if releaseWakeThread then
		task.cancel(releaseWakeThread)
		releaseWakeThread = nil
	end
	disconnectReleaseWatch()
end

local function setNavigationBlocked(blocked)
	if not loadingScope then return end
	local succeeded, scopeError = pcall(loadingScope.SetActive, loadingScope, blocked)
	if not succeeded then
		warn("[BLIKK LOADING] Loading navigation ownership failed: " .. tostring(scopeError))
	end
end

local function setInputBlocked(blocked)
	if not inputManager then return end
	if type(inputManager.SetGameplayBlocked) == "function" then
		inputManager:SetGameplayBlocked(GAMEPLAY_BLOCKER_OWNER, blocked)
		return
	end
	if not hasWarnedLegacyInput then
		hasWarnedLegacyInput = true
		warn("[BLIKK LOADING] InputManager is using legacy loading-screen suppression.")
	end
	if type(inputManager.SetGameplayEnabled) == "function" then
		inputManager:SetGameplayEnabled(not blocked)
	end
end

local function setCameraBlocked(blocked)
	if not gameplayCamera then return end
	if type(gameplayCamera.SetGameplayBlocked) == "function" then
		gameplayCamera:SetGameplayBlocked(GAMEPLAY_BLOCKER_OWNER, blocked)
		return
	end
	if not hasWarnedLegacyCamera then
		hasWarnedLegacyCamera = true
		warn("[BLIKK LOADING] GameplayCamera is using legacy loading-screen suppression.")
	end
	if type(gameplayCamera.SetGameplayActive) == "function" then
		gameplayCamera:SetGameplayActive(not blocked)
	end
end

local function setGameplayOwnership(blocked)
	if ownsGameplayBlock == blocked then return end
	ownsGameplayBlock = blocked
	if blocked then
		setInputBlocked(true)
		setCameraBlocked(true)
		setNavigationBlocked(true)
	else
		-- Remove interface ownership before the gameplay gates so no input edge leaks between them.
		setNavigationBlocked(false)
		setCameraBlocked(false)
		setInputBlocked(false)
	end
	if view then view.Root.Active = blocked end
end

local function setVisible(nextVisible)
	if isVisible == nextVisible then return end
	isVisible = nextVisible
	LoadingScreenController.VisibilityChanged:Fire(
		nextVisible,
		activeContext,
		activeIdentity
	)
end

local function identityMatches(identity)
	return identity == nil or identity == activeIdentity
end

local function createManifestInstance(definition)
	if type(definition) ~= "table"
		or type(definition.AssetId) ~= "string"
		or definition.AssetId == "" then return nil end

	local instance
	if definition.Kind == "Image" then
		instance = Instance.new("ImageLabel")
		instance.Image = definition.AssetId
	elseif definition.Kind == "Sound" then
		instance = Instance.new("Sound")
		instance.SoundId = definition.AssetId
	elseif definition.Kind == "Animation" then
		instance = Instance.new("Animation")
		instance.AnimationId = definition.AssetId
	else
		return nil
	end
	instance.Name = definition.Name or "LoadingManifestAsset"
	return instance
end

local function canonicalAssetId(assetId)
	local value = tostring(assetId)
	local numericId = value:match("rbxassetid://(%d+)")
		or value:match("[?&]id=(%d+)")
	if numericId then return "rbxassetid://" .. numericId end
	return value
end

local function startFinitePreload(generation, identity)
	local instances = {}
	local definitions = {}
	for _, classification in { "Required", "Preferred", "Cosmetic" } do
		for _, definition in LoadingScreenConfig.AssetManifest[classification] or {} do
			local instance = createManifestInstance(definition)
			if instance then
				table.insert(instances, instance)
				table.insert(definitions, {
					AssetId = definition.AssetId,
					Classification = classification,
				})
			end
		end
	end

	if #instances == 0 then
		LoadingScreenController.AssetPreloadCompleted:Fire(identity, {
			TimedOut = false,
			FailedAssetIds = {},
			RequiredFailureCount = 0,
		})
		return
	end

	local resolved = false
	local failedAssetIds = {}
	local failedLookup = {}
	local function markFailed(assetId)
		assetId = canonicalAssetId(assetId)
		if failedLookup[assetId] then return end
		failedLookup[assetId] = true
		table.insert(failedAssetIds, assetId)
	end
	local function resolve(timedOut, preloadFailed)
		if resolved then return end
		resolved = true
		if preloadFailed then
			for _, definition in definitions do markFailed(definition.AssetId) end
		end
		for _, instance in instances do instance:Destroy() end

		if generation ~= activeGeneration then return end
		if timedOut or failedLookup[canonicalAssetId(LoadingScreenConfig.Default.ImageAssetId)] then
			LoadingScreenView.SetArtworkAvailable(view, false)
		end
		local requiredFailureCount = 0
		for _, definition in definitions do
			if definition.Classification == "Required"
				and failedLookup[canonicalAssetId(definition.AssetId)] then requiredFailureCount += 1 end
		end
		LoadingScreenController.AssetPreloadCompleted:Fire(identity, {
			TimedOut = timedOut,
			FailedAssetIds = failedAssetIds,
			RequiredFailureCount = requiredFailureCount,
		})

		if timedOut and not hasWarnedPreloadTimeout then
			hasWarnedPreloadTimeout = true
			warn("[BLIKK LOADING] Presentation preload exceeded its bounded budget.")
		end
		for _, assetId in failedAssetIds do
			if not warnedAssetFailures[assetId] then
				warnedAssetFailures[assetId] = true
				warn("[BLIKK LOADING] Presentation asset unavailable: " .. assetId)
			end
		end
	end

	local preloadThread = task.spawn(function()
		local succeeded = pcall(function()
			ContentProvider:PreloadAsync(instances, function(assetId, status)
				if status ~= Enum.AssetFetchStatus.Success then markFailed(assetId) end
			end)
		end)
		resolve(false, not succeeded)
	end)
	task.delay(LoadingScreenConfig.Timing.PreloadTimeoutSeconds, function()
		if resolved then return end
		resolve(true, false)
		if coroutine.status(preloadThread) ~= "dead" then task.cancel(preloadThread) end
	end)
end

local function finaliseHidden(generation)
	if generation ~= activeGeneration or not view then return end
	setGameplayOwnership(false)
	view.Gui.Enabled = false
	view.Root.Active = false
	LoadingScreenView.SetFightVisible(view, false)
	setVisible(false)
	activeContext = nil
	activeIdentity = nil
	isDismissing = false
end

local function dismiss(identity, fadeSeconds)
	if not isInitialised or not isVisible or not identityMatches(identity) then return false end
	if isDismissing then return true end
	isDismissing = true
	activeGeneration += 1
	local generation = activeGeneration
	cancelFightArm()
	isFightPresented = false
	cancelAllTweens()
	local duration = fadeSeconds or LoadingScreenConfig.Timing.DismissFadeSeconds
	playTween(
		view.Backdrop,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 1 }
	)
	if view.FightGroup.Visible then
		playTween(
			view.FightGroup,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 1 }
		)
	end
	task.delay(duration, function()
		finaliseHidden(generation)
	end)
	return true
end

local function presentFight(generation, armToken, identity, releaseAtServerTime)
	if generation ~= activeGeneration
		or armToken ~= activeFightArmToken
		or identity ~= activeIdentity
		or not isVisible
		or isFightPresented then return end
	isFightPresented = true
	isDismissing = false
	armedReleaseAtServerTime = nil
	disconnectReleaseWatch()
	stopPulse()
	view.Backdrop.GroupTransparency = 1
	view.Backdrop.Visible = false
	view.Root.BackgroundTransparency = 1
	view.Root.Active = false
	setGameplayOwnership(false)

	-- Give the released world one complete render before painting the transparent FIGHT layer.
	fightRevealConnection = RunService.RenderStepped:Connect(function()
		if fightRevealConnection then fightRevealConnection:Disconnect() end
		fightRevealConnection = nil
		if generation ~= activeGeneration
			or armToken ~= activeFightArmToken
			or identity ~= activeIdentity
			or not isVisible then return end
		LoadingScreenView.SetFightVisible(view, true)
		view.FightGroup.GroupTransparency = 1
		view.FightScale.Scale = 0.82

		playTween(
			view.FightGroup,
			TweenInfo.new(
				LoadingScreenConfig.Timing.FightEntrySeconds,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out
			),
			{ GroupTransparency = 0 }
		)
		playTween(
			view.FightScale,
			TweenInfo.new(
				LoadingScreenConfig.Timing.FightEntrySeconds,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{ Scale = 1 }
		)
		LoadingScreenController.FightPresented:Fire(
			identity,
			releaseAtServerTime,
			Workspace:GetServerTimeNow()
		)
	end)

	task.delay(LoadingScreenConfig.Timing.FightHoldSeconds, function()
		if generation ~= activeGeneration or identity ~= activeIdentity then return end
		playTween(
			view.FightGroup,
			TweenInfo.new(
				LoadingScreenConfig.Timing.FightExitSeconds,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{ GroupTransparency = 1 }
		)
		task.delay(LoadingScreenConfig.Timing.FightExitSeconds, function()
			if generation ~= activeGeneration or identity ~= activeIdentity then return end
			finaliseHidden(generation)
		end)
	end)
end

function LoadingScreenController:Init(
	gameplayInputManager,
	gameplayCameraController,
	navigationController
)
	if isInitialised then return true end
	inputManager = gameplayInputManager
	gameplayCamera = gameplayCameraController
	uiNavigationController = navigationController

	local playerGui = Players.LocalPlayer:WaitForChild(
		"PlayerGui",
		LoadingScreenConfig.Timing.PlayerGuiLookupTimeoutSeconds
	)
	if not playerGui then
		warn("[BLIKK LOADING] Loading controller could not acquire PlayerGui.")
		return false
	end

	view = LoadingScreenView.AdoptOrCreate(playerGui, LoadingScreenConfig)
	view.Gui:SetAttribute("BLIKK_LoadingClaimedByClient", true)
	if uiNavigationController
		and type(uiNavigationController.CreateScope) == "function" then
		local scopeSucceeded, scopeResult = pcall(
			uiNavigationController.CreateScope,
			uiNavigationController,
			NAVIGATION_SCOPE_ID,
			{ Root = view.Root }
		)
		if scopeSucceeded then
			loadingScope = scopeResult
		else
			warn("[BLIKK LOADING] Loading navigation scope was unavailable: " .. tostring(scopeResult))
		end
	end

	isInitialised = true
	self:Begin("InitialBoot", "InitialBoot")
	script.Destroying:Connect(function()
		activeGeneration += 1
		cancelFightArm()
		cancelAllTweens()
		setGameplayOwnership(false)
		if loadingScope then loadingScope:Destroy(); loadingScope = nil end
		if view and view.Gui then view.Gui:Destroy() end
	end)
	return true
end

function LoadingScreenController:CompleteInitialBoot()
	if activeContext ~= "InitialBoot" then return false end
	return dismiss(activeIdentity, LoadingScreenConfig.Timing.DismissFadeSeconds)
end

function LoadingScreenController:Begin(contextName, identity)
	if not isInitialised or not LoadingScreenConfig.Contexts[contextName] then return nil end
	if isVisible and contextName == activeContext
		and (identity == nil or identity == activeIdentity) then return activeIdentity end

	activeGeneration += 1
	local generation = activeGeneration
	activeContext = contextName
	activeIdentity = identity or string.format("%s:%d", contextName, generation)
	cancelFightArm()
	isFightPresented = false
	isDismissing = false
	cancelAllTweens()
	LoadingScreenView.Reset(view, LoadingScreenConfig, contextName)
	view.Gui:SetAttribute("BLIKK_LoadingContext", contextName)
	view.Gui:SetAttribute("BLIKK_LoadingIdentity", tostring(activeIdentity))
	setVisible(true)
	setGameplayOwnership(true)
	startPulse()
	startFinitePreload(generation, activeIdentity)
	return activeIdentity
end

function LoadingScreenController:SetStatus(identity, statusText, detailText)
	if not isInitialised or not isVisible or not identityMatches(identity) then return false end
	LoadingScreenView.SetStatus(
		view,
		LoadingScreenConfig,
		statusText,
		detailText,
		false
	)
	return true
end

function LoadingScreenController:ArmFight(identity, releaseAtServerTime)
	if not isInitialised or not isVisible or identity ~= activeIdentity then return false end
	if isFightPresented or isDismissing then return false end
	if type(releaseAtServerTime) ~= "number"
		or releaseAtServerTime ~= releaseAtServerTime
		or releaseAtServerTime == math.huge
		or releaseAtServerTime == -math.huge then return false end
	local now = Workspace:GetServerTimeNow()
	if releaseAtServerTime - now > LoadingScreenConfig.Timing.FightMaximumLeadSeconds then
		return false
	end

	if armedReleaseAtServerTime == releaseAtServerTime then return true end
	cancelFightArm()
	armedReleaseAtServerTime = releaseAtServerTime
	local armToken = activeFightArmToken
	self:SetStatus(identity, "SYNCHRONIZED", "FIGHT RELEASE ARMED //")
	local generation = activeGeneration
	local wakeDelay = math.max(
		0,
		releaseAtServerTime
			- now
			- LoadingScreenConfig.Timing.FightRenderLeadSeconds
	)
	releaseWakeThread = task.delay(wakeDelay, function()
		releaseWakeThread = nil
		if generation ~= activeGeneration
			or armToken ~= activeFightArmToken
			or identity ~= activeIdentity then return end
		releaseWatchConnection = RunService.RenderStepped:Connect(function()
			if generation ~= activeGeneration
				or armToken ~= activeFightArmToken
				or identity ~= activeIdentity then
				disconnectReleaseWatch()
				return
			end
			if Workspace:GetServerTimeNow() >= releaseAtServerTime then
				presentFight(generation, armToken, identity, releaseAtServerTime)
			end
		end)
	end)
	return true
end

function LoadingScreenController:Fail(identity, message, retainOwnership)
	if not isInitialised or not isVisible or not identityMatches(identity) then return false end
	activeGeneration += 1
	local generation = activeGeneration
	cancelFightArm()
	isFightPresented = false
	isDismissing = false
	cancelAllTweens()
	LoadingScreenView.SetArtworkAvailable(view, false)
	LoadingScreenView.SetFightVisible(view, false)
	view.Backdrop.GroupTransparency = 0
	LoadingScreenView.SetStatus(
		view,
		LoadingScreenConfig,
		message or "LOADING FAILED",
		"RETURNING TO A SAFE STATE //",
		true
	)
	LoadingScreenController.Failed:Fire(activeIdentity, message)
	if retainOwnership then return true end
	task.delay(LoadingScreenConfig.Timing.FailureDisplaySeconds, function()
		if generation == activeGeneration and identityMatches(identity) then
			dismiss(activeIdentity, LoadingScreenConfig.Timing.DismissFadeSeconds)
		end
	end)
	return true
end

function LoadingScreenController:Cancel(identity)
	return dismiss(identity, LoadingScreenConfig.Timing.DismissFadeSeconds)
end

function LoadingScreenController:IsVisible()
	return isVisible
end

function LoadingScreenController:GetActiveIdentity()
	return activeIdentity
end

return LoadingScreenController
