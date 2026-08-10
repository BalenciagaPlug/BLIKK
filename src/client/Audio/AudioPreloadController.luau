local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local PlayerPreferencesController = require(script.Parent.Parent.Settings.PlayerPreferencesController)
local MusicConfig = require(ReplicatedStorage.Shared.Audio.MusicConfig)
local SoundEffectsConfig = require(ReplicatedStorage.Shared.Audio.SoundEffectsConfig)
local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)

local AudioPreloadController = {}
AudioPreloadController.StatusChanged = Instance.new("BindableEvent")

local definitionsByKey = {}
local keysBySoundId = {}
local statusByKey = {}
local requestedSoundIds = {}
local warnedSoundIds = {}
local preferencesConnection = nil
local destroyingConnection = nil
local preloadThread = nil
local activeFolders = {}
local ownedThreads = {}
local navigationController = nil
local isInitialised = false
local isDestroyed = false
local hasStarted = false

local function isValidSoundId(soundId)
	return type(soundId) == "string" and string.match(soundId, "^rbxassetid://%d+$") ~= nil
end

local function register(definition, category)
	if type(definition) ~= "table" or type(definition.Key) ~= "string" then return end
	local enabled = definition.Enabled == true
		and isValidSoundId(definition.SoundId)
	local record = {
		Key = definition.Key,
		SoundId = definition.SoundId,
		Category = category,
		Enabled = enabled,
	}
	definitionsByKey[record.Key] = record
	statusByKey[record.Key] = if enabled then "NotRequested" else "Disabled"
	if not enabled then return end
	local keys = keysBySoundId[record.SoundId]
	if not keys then
		keys = {}
		keysBySoundId[record.SoundId] = keys
	end
	table.insert(keys, record.Key)
end

local function initializeDefinitions()
	register(MusicConfig.Tracks.CharacterSelection, "Frontend")
	register(MusicConfig.Tracks.OperationsHub, "Frontend")
	for _, track in MusicConfig.Tracks.DuelPlaylist do register(track, "Duel") end
	for _, key in SoundEffectsConfig.PreloadOrder do
		register(SoundEffectsConfig.Sounds[key], "SoundEffect")
	end
	local dash = MovementConfig.Dash.Presentation
	register({
		Key = "Dash",
		SoundId = dash.SoundId,
		Enabled = dash.Enabled and dash.SoundId ~= "",
	}, "SoundEffect")
end

local function setStatusForSoundId(soundId, status, durationSeconds)
	for _, key in keysBySoundId[soundId] or {} do
		if statusByKey[key] ~= status then
			statusByKey[key] = status
			AudioPreloadController.StatusChanged:Fire(key, status, durationSeconds)
		end
	end
end

local function diagnose(key, status, durationSeconds)
	if not MusicConfig.DiagnosticsEnabled and not SoundEffectsConfig.DiagnosticsEnabled then return end
	print(string.format(
		"[BLIKK AUDIO PRELOAD] %s %s in %.3f seconds",
		key,
		status,
		durationSeconds
	))
end

local function warnFailure(soundId, detail)
	if warnedSoundIds[soundId] then return end
	warnedSoundIds[soundId] = true
	local keys = keysBySoundId[soundId] or {}
	warn(string.format(
		"[BLIKK AUDIO PRELOAD] Disabled unavailable asset %s (%s): %s",
		table.concat(keys, ","),
		soundId,
		tostring(detail)
	))
end

local function cancelThread(thread)
	if thread and thread ~= coroutine.running() then pcall(task.cancel, thread) end
end

local function completeAsset(batch, soundId, proxy, status, detail, startedAt)
	if isDestroyed or batch.Resolved[soundId] then return end
	batch.Resolved[soundId] = true
	if proxy.Parent then proxy:Destroy() end
	local durationSeconds = os.clock() - startedAt
	setStatusForSoundId(soundId, status, durationSeconds)
	for _, key in keysBySoundId[soundId] or {} do diagnose(key, status, durationSeconds) end
	if status == "Failure" then warnFailure(soundId, detail) end
	batch.Pending -= 1
	if batch.Pending > 0 then return end
	activeFolders[batch.Folder] = nil
	if batch.Folder.Parent then batch.Folder:Destroy() end
	if not batch.Advanced then batch.AdvanceEvent:Fire() end
end

local function beginAssetPreload(batch, soundId, proxy)
	setStatusForSoundId(soundId, "Fetching", 0)
	local startedAt = os.clock()
	local workerThread = nil

	workerThread = task.defer(function()
		local callbackStatus = nil
		local succeeded, preloadError = pcall(function()
			ContentProvider:PreloadAsync({ proxy }, function(callbackSoundId, fetchStatus)
				if callbackSoundId == soundId then callbackStatus = fetchStatus end
			end)
		end)
		ownedThreads[workerThread] = nil
		if isDestroyed then return end
		if succeeded and callbackStatus == Enum.AssetFetchStatus.Success then
			completeAsset(batch, soundId, proxy, "Success", callbackStatus, startedAt)
		else
			completeAsset(
				batch,
				soundId,
				proxy,
				"Failure",
				if succeeded then callbackStatus else preloadError,
				startedAt
			)
		end
	end)
	ownedThreads[workerThread] = true
end

local function runBatch(keys, batchIndex)
	local soundIds = {}
	local seen = {}
	for _, key in keys do
		local definition = definitionsByKey[key]
		local soundId = definition and definition.SoundId
		if definition and definition.Enabled and not requestedSoundIds[soundId]
			and not seen[soundId] then
			seen[soundId] = true
			requestedSoundIds[soundId] = true
			table.insert(soundIds, soundId)
		end
	end
	if #soundIds == 0 or isDestroyed then return end

	local folder = Instance.new("Folder")
	folder.Name = "BLIKK_AudioPreloadBatch" .. tostring(batchIndex)
	folder:SetAttribute("BLIKK_TemporaryAudioPreload", true)
	folder.Parent = SoundService
	activeFolders[folder] = true
	local batch = {
		Folder = folder,
		Pending = #soundIds,
		Resolved = {},
		Advanced = false,
		AdvanceEvent = Instance.new("BindableEvent"),
	}
	for index, soundId in soundIds do
		local proxy = Instance.new("Sound")
		proxy.Name = "PreloadProxy" .. tostring(index)
		proxy.SoundId = soundId
		proxy.Volume = 0
		proxy.Looped = false
		proxy.PlayOnRemove = false
		proxy.Parent = folder
		beginAssetPreload(batch, soundId, proxy)
	end
	local advanceThread = nil
	advanceThread = task.delay(MusicConfig.PreloadBatchAdvanceSeconds, function()
		ownedThreads[advanceThread] = nil
		if not isDestroyed and not batch.Advanced then batch.AdvanceEvent:Fire() end
	end)
	ownedThreads[advanceThread] = true
	batch.AdvanceEvent.Event:Wait()
	batch.Advanced = true
	cancelThread(advanceThread)
	ownedThreads[advanceThread] = nil
	batch.AdvanceEvent:Destroy()
end

local function enabledDuelKeys()
	local keys = {}
	for _, track in MusicConfig.Tracks.DuelPlaylist do
		if statusByKey[track.Key] ~= "Disabled" then table.insert(keys, track.Key) end
	end
	return keys
end

local function beginPreloading()
	if hasStarted or isDestroyed or not PlayerPreferencesController:HasConfirmedPreferences() then
		return
	end
	local musicGroup = SoundService:FindFirstChild(MusicConfig.SoundGroupName)
	local effectsGroup = SoundService:FindFirstChild(SoundEffectsConfig.SoundGroupName)
	local uiGroup = SoundService:FindFirstChild(SoundEffectsConfig.UISoundGroupName)
	if not musicGroup or not musicGroup:IsA("SoundGroup")
		or not effectsGroup or not effectsGroup:IsA("SoundGroup")
		or not uiGroup or not uiGroup:IsA("SoundGroup") then return end
	hasStarted = true
	local route = navigationController and navigationController:GetCurrentRoute() or nil
	local mainMenuFirst = route == "OperationsHub" or route == "Multiplayer" or route == "Clans"
	local firstFrontend = if mainMenuFirst then "OperationsHub" else "CharacterSelection"
	local secondFrontend = if mainMenuFirst then "CharacterSelection" else "OperationsHub"
	local batches = {
		{ firstFrontend },
		{ secondFrontend },
		enabledDuelKeys(),
		SoundEffectsConfig.PreloadOrder,
		{ "Dash" },
	}
	preloadThread = task.spawn(function()
		for batchIndex, keys in batches do
			if isDestroyed then return end
			runBatch(keys, batchIndex)
		end
		preloadThread = nil
	end)
end

function AudioPreloadController:GetStatus(key)
	return statusByKey[key] or "Disabled"
end

function AudioPreloadController:IsEnabled(key)
	local definition = definitionsByKey[key]
	return definition ~= nil and definition.Enabled
end

function AudioPreloadController:Init(navigationControllerValue)
	if isInitialised then return end
	isInitialised = true
	isDestroyed = false
	navigationController = navigationControllerValue
	initializeDefinitions()
	preferencesConnection = PlayerPreferencesController.PreferencesApplied.Event:Connect(beginPreloading)
	destroyingConnection = script.Destroying:Connect(function()
		AudioPreloadController:Destroy()
	end)
	beginPreloading()
end

function AudioPreloadController:Destroy()
	if isDestroyed then return end
	isDestroyed = true
	if preferencesConnection then preferencesConnection:Disconnect(); preferencesConnection = nil end
	if destroyingConnection then destroyingConnection:Disconnect(); destroyingConnection = nil end
	cancelThread(preloadThread)
	preloadThread = nil
	for thread in ownedThreads do cancelThread(thread) end
	table.clear(ownedThreads)
	for folder in activeFolders do
		if folder.Parent then folder:Destroy() end
	end
	table.clear(activeFolders)
end

return AudioPreloadController
