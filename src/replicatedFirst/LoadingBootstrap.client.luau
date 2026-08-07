local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SCREEN_GUI_NAME = "BLIKKLoadingScreen"
local FALLBACK_REPLICATION_TIMEOUT_SECONDS = 10
local FALLBACK_HANDOFF_TIMEOUT_SECONDS = 45
local FALLBACK_FAILURE_DISPLAY_SECONDS = 4

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA(className) then
		existing:Destroy()
		existing = nil
	end
	if existing then return existing end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function createBlackCover(playerGui)
	local gui = playerGui:FindFirstChild(SCREEN_GUI_NAME)
	if gui and not gui:IsA("ScreenGui") then
		gui:Destroy()
		gui = nil
	end
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = SCREEN_GUI_NAME
	end
	gui.DisplayOrder = 1000
	gui.Enabled = true
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

	local root = getOrCreate(gui, "Frame", "Root")
	root.Active = true
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 0
	root.BorderSizePixel = 0
	root.Position = UDim2.fromScale(0, 0)
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = true
	root.ZIndex = 1000

	local backdrop = getOrCreate(root, "Frame", "BootstrapBackdrop")
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BorderSizePixel = 0
	backdrop.Position = UDim2.fromScale(0, 0)
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = 1001

	local status = getOrCreate(root, "TextLabel", "BootstrapStatus")
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Code
	status.Position = UDim2.new(0.5, 0, 1, -54)
	status.Size = UDim2.new(1, -48, 0, 28)
	status.Text = "INITIALIZING BLIKK //"
	status.TextColor3 = Color3.fromRGB(235, 232, 218)
	status.TextSize = 13
	status.ZIndex = 1002

	gui:SetAttribute("BLIKK_LoadingBootstrap", true)
	gui:SetAttribute("BLIKK_LoadingClaimedByClient", false)
	gui.Parent = playerGui
	return gui, root, status
end

local function waitForChildBefore(parent, name, deadline)
	local remaining = deadline - os.clock()
	if remaining <= 0 then return nil end
	return parent:WaitForChild(name, remaining)
end

local playerGui = Players.LocalPlayer:WaitForChild(
	"PlayerGui",
	FALLBACK_REPLICATION_TIMEOUT_SECONDS
)
if not playerGui then
	warn("[BLIKK LOADING] PlayerGui did not become available; Roblox loading UI was preserved.")
	return
end

local gui, root, bootstrapStatus = createBlackCover(playerGui)
if gui.Parent == playerGui and gui.Enabled and root.Visible then
	local removedDefault, removeError = pcall(function()
		ReplicatedFirst:RemoveDefaultLoadingScreen()
	end)
	if not removedDefault then
		warn("[BLIKK LOADING] Default loading screen removal failed: " .. tostring(removeError))
	end
end

local replicationDeadline = os.clock() + FALLBACK_REPLICATION_TIMEOUT_SECONDS
local shared = waitForChildBefore(ReplicatedStorage, "Shared", replicationDeadline)
local uiFolder = shared and waitForChildBefore(shared, "UI", replicationDeadline)
local configModule = uiFolder and waitForChildBefore(
	uiFolder,
	"LoadingScreenConfig",
	replicationDeadline
)
local viewModule = uiFolder and waitForChildBefore(
	uiFolder,
	"LoadingScreenView",
	replicationDeadline
)

local configSucceeded, config = false, nil
local viewSucceeded, LoadingScreenView = false, nil
if configModule then configSucceeded, config = pcall(require, configModule) end
if viewModule then viewSucceeded, LoadingScreenView = pcall(require, viewModule) end

local failureDisplaySeconds = FALLBACK_FAILURE_DISPLAY_SECONDS
local handoffTimeoutSeconds = FALLBACK_HANDOFF_TIMEOUT_SECONDS
if configSucceeded and type(config) == "table" and type(config.Timing) == "table" then
	failureDisplaySeconds = config.Timing.BootstrapFailureDisplaySeconds
		or failureDisplaySeconds
	handoffTimeoutSeconds = config.Timing.BootstrapHandoffTimeoutSeconds
		or handoffTimeoutSeconds
end

local function revealBootstrapFailure(message)
	if not gui.Parent or gui:GetAttribute("BLIKK_LoadingClaimedByClient") then return end
	bootstrapStatus.Text = message
	bootstrapStatus.TextColor3 = Color3.fromRGB(183, 45, 48)
	root.Active = false
	task.delay(failureDisplaySeconds, function()
		if gui.Parent and not gui:GetAttribute("BLIKK_LoadingClaimedByClient") then
			gui:Destroy()
		end
	end)
end

if not configSucceeded or not viewSucceeded
	or type(config) ~= "table" or type(LoadingScreenView) ~= "table" then
	warn("[BLIKK LOADING] Shared loading presentation did not replicate within the bootstrap budget.")
	revealBootstrapFailure("CLIENT CONTENT UNAVAILABLE // REJOIN")
	return
end

local view = LoadingScreenView.AdoptOrCreate(playerGui, config)
LoadingScreenView.Reset(view, config, "InitialBoot")

local preloadResolved = false
local preloadHadFailure = false
local function resolvePreload(timedOut)
	if preloadResolved then return end
	preloadResolved = true
	if timedOut or preloadHadFailure then
		-- The normal client controller owns presentation after claiming this view.
		if gui.Parent and not gui:GetAttribute("BLIKK_LoadingClaimedByClient") then
			LoadingScreenView.SetArtworkAvailable(view, false)
			warn("[BLIKK LOADING] Initial artwork unavailable; using the black fallback.")
		end
	end
end

local preloadThread = task.spawn(function()
	local succeeded = pcall(function()
		ContentProvider:PreloadAsync({ view.Artwork }, function(_, status)
			if status ~= Enum.AssetFetchStatus.Success then preloadHadFailure = true end
		end)
	end)
	if not succeeded then preloadHadFailure = true end
	resolvePreload(false)
end)
task.delay(config.Timing.PreloadTimeoutSeconds, function()
	if preloadResolved then return end
	resolvePreload(true)
	if coroutine.status(preloadThread) ~= "dead" then task.cancel(preloadThread) end
end)

task.delay(handoffTimeoutSeconds, function()
	if gui.Parent and not gui:GetAttribute("BLIKK_LoadingClaimedByClient") then
		warn("[BLIKK LOADING] Client loading controller did not claim the bootstrap view in time.")
		LoadingScreenView.SetStatus(
			view,
			config,
			"CLIENT INITIALIZATION FAILED",
			"REJOIN OR USE THE ROBLOX MENU TO EXIT //",
			true
		)
		root.Active = false
		task.delay(failureDisplaySeconds, function()
			if gui.Parent and not gui:GetAttribute("BLIKK_LoadingClaimedByClient") then
				gui:Destroy()
			end
		end)
	end
end)
