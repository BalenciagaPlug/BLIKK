local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(script.Parent.CharacterPersistenceConfig)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileConfig = require(ReplicatedStorage.Shared.Character.ProfileConfig)
local ActionCatalogue = require(ReplicatedStorage.Shared.Input.ActionCatalogue)
local BindingConfig = require(ReplicatedStorage.Shared.Input.BindingConfig)
local PlayerPreferencesConfig = require(ReplicatedStorage.Shared.Settings.PlayerPreferencesConfig)
local Schema = require(script.Parent.CharacterProfileSchema)

local CharacterProfileService = {}
local store = DataStoreService:GetDataStore(Config.DataStoreName)
local sessions = {}
local isInitialised = false
local isShuttingDown = false
local requestRemote = nil
local updateRemote = nil

local function cloneCharacter(character)
	local copy = table.clone(character)
	copy.Appearance = table.clone(character.Appearance)
	return copy
end

local function cloneBindings(bindings)
	local copy = {}
	for actionId, binding in bindings do copy[actionId] = table.clone(binding) end
	return copy
end

local function snapshot(session)
	local account = session.Account
	if not account then return nil end
	local characters = {}
	for _, character in account.Characters do table.insert(characters, cloneCharacter(character)) end
	return {
		SchemaVersion = account.SchemaVersion,
		Characters = characters,
		SelectedCharacterId = account.SelectedCharacterId,
		Settings = {
			Bindings = cloneBindings(account.Settings.Bindings),
			Preferences = table.clone(account.Settings.Preferences),
		},
		Metadata = table.clone(account.Metadata),
	}
end

local function response(session, success, code, message)
	return {
		Success = success,
		Code = code,
		Message = message,
		Status = session and session.Status or "Unavailable",
		Persistent = session and session.Persistent or false,
		Snapshot = session and snapshot(session) or nil,
	}
end

local function retry(operationName, attempts, callback)
	local lastError = nil
	for attempt = 1, attempts do
		local succeeded, result = pcall(callback)
		if succeeded then return true, result end
		lastError = result
		if attempt < attempts then task.wait(Config.RetryBaseDelaySeconds * 2 ^ (attempt - 1)) end
	end
	return false, string.format("%s failed after %d attempts: %s", operationName, attempts, tostring(lastError))
end

local function dataKey(userId)
	return Config.KeyPrefix .. tostring(userId)
end

local function publish(player, session, code, message)
	if player.Parent == Players then
		updateRemote:FireClient(player, response(session, session.Status == "Ready", code, message))
	end
end

local function reportNormalization(userId, diagnostics)
	if diagnostics.RemovedCharacterCount > 0 then
		warn(string.format(
			"[BLIKK DATA] Character records normalized for user %d: removed=%d duplicateIds=%d duplicateNames=%d",
			userId,
			diagnostics.RemovedCharacterCount,
			diagnostics.RemovedDuplicateIdCount,
			diagnostics.RemovedDuplicateNameCount
		))
	end
	if diagnostics.SelectionWasCleared then
		warn(string.format("[BLIKK DATA] Invalid selected character was cleared for user %d", userId))
	end
	local shouldReportDefaultedSettings = not diagnostics.AddedDefaultSettingsDuringMigration
	if diagnostics.RemovedBindingCount > 0
		or (shouldReportDefaultedSettings and diagnostics.DefaultedBindingCount > 0)
	then
		warn(string.format(
			"[BLIKK DATA] Bindings normalized for user %d: removed=%d defaulted=%d",
			userId,
			diagnostics.RemovedBindingCount,
			diagnostics.DefaultedBindingCount
		))
	end
	if diagnostics.ReplacedInvalidPreferenceCount > 0
		or diagnostics.RemovedUnknownPreferenceCount > 0
	then
		warn(string.format(
			"[BLIKK DATA] Preferences normalized for user %d: invalid=%d unknown=%d",
			userId,
			diagnostics.ReplacedInvalidPreferenceCount,
			diagnostics.RemovedUnknownPreferenceCount
		))
	end
end

local saveSession

local function scheduleSave(player, session)
	session.DebounceGeneration += 1
	local debounceGeneration = session.DebounceGeneration
	task.delay(Config.MutationSaveDebounceSeconds, function()
		if sessions[player] ~= session or session.Closing or debounceGeneration ~= session.DebounceGeneration then return end
		saveSession(player, session)
	end)
end

saveSession = function(player, session)
	if not session.Persistent or not session.Account or not session.Dirty then return true end
	if session.SaveInProgress then
		session.SaveQueued = true
		return false
	end

	session.SaveInProgress = true
	session.SaveQueued = false
	local revision = session.Revision
	local accountSnapshot = snapshot(session)
	accountSnapshot.Metadata.UpdatedAtUnix = os.time()
	local updateAccepted = false
	local succeeded, result = retry("save", Config.SaveRetryCount, function()
		return store:UpdateAsync(dataKey(session.UserId), function(previous)
			updateAccepted = false
			if type(previous) == "table"
				and type(previous.SchemaVersion) == "number"
				and previous.SchemaVersion > Config.SchemaVersion
			then
				return nil
			end
			if previous ~= nil and not Schema.NormalizeAccount(previous) then return nil end
			updateAccepted = true
			return accountSnapshot
		end)
	end)
	session.SaveInProgress = false

	if succeeded and updateAccepted and result ~= nil then
		session.Account.Metadata.UpdatedAtUnix = accountSnapshot.Metadata.UpdatedAtUnix
		session.LastSuccessfulSaveUnix = os.time()
		if session.Revision == revision then session.Dirty = false end
	else
		session.Dirty = true
		warn("[BLIKK DATA] Save failed after retries for user " .. session.UserId .. ": " .. tostring(result))
	end

	if session.SaveQueued and session.Dirty and not session.Closing then scheduleSave(player, session) end
	return succeeded and updateAccepted and result ~= nil
end

local function markDirty(player, session)
	session.Revision += 1
	session.Dirty = true
	session.Account.Metadata.UpdatedAtUnix = os.time()
	scheduleSave(player, session)
end

local function loadPlayer(player)
	local session = {
		UserId = player.UserId,
		Account = nil,
		Status = "Loading",
		Persistent = false,
		Dirty = false,
		SaveInProgress = false,
		SaveQueued = false,
		LastSuccessfulSaveUnix = 0,
		Closing = false,
		Revision = 0,
		DebounceGeneration = 0,
		LastMutationAt = -math.huge,
		IsMutating = false,
	}
	sessions[player] = session

	local succeeded, stored = retry("load", Config.LoadRetryCount, function()
		return store:GetAsync(dataKey(player.UserId))
	end)
	if sessions[player] ~= session or session.Closing then return end
	if not succeeded then
		session.Status = "Unavailable"
		warn("[BLIKK DATA] Load failed after retries for user " .. player.UserId .. ". Persistence is unavailable.")
		publish(player, session, "LOAD_FAILED", "PROFILE STORAGE IS UNAVAILABLE")
		return
	end

	if stored == nil then
		session.Account = Schema.NewAccount(os.time())
		session.Status = "Ready"
		session.Persistent = true
		publish(player, session, "FIRST_SESSION", "NO SAVED FIGHTERS")
		return
	end

	local account, diagnostics, validationError = Schema.NormalizeAccount(stored)
	if not account then
		session.Status = "Unavailable"
		warn("[BLIKK DATA] Stored record rejected for user " .. player.UserId .. ": " .. validationError)
		publish(player, session, "INVALID_DATA", "SAVED PROFILE DATA COULD NOT BE VALIDATED")
		return
	end

	session.Account = account
	session.Status = "Ready"
	session.Persistent = true
	if Schema.DiagnosticsRequireSave(diagnostics) then
		reportNormalization(player.UserId, diagnostics)
		markDirty(player, session)
	end
	publish(player, session, "LOADED", "FIGHTERS LOADED")
end

local function setBinding(bindings, actionId, slot, token)
	if type(actionId) ~= "string" or #actionId > 64 or type(slot) ~= "string" or #slot > 16 then
		return false, "INVALID_BINDING", "INVALID BINDING REQUEST"
	end
	local action = ActionCatalogue.ById[actionId]
	if not action or not BindingConfig.Slots[slot] or not BindingConfig.IsValidToken(token) then
		return false, "INVALID_BINDING", "INVALID BINDING REQUEST"
	end
	local ownerActionId, ownerSlot = BindingConfig.FindOwner(bindings, token)
	if ownerActionId and (ownerActionId ~= actionId or ownerSlot ~= slot) then
		if not BindingConfig.CanClear(bindings, ownerActionId, ownerSlot) then
			return false, "PROTECTED_BINDING", "THAT INPUT IS THE LAST BINDING FOR A PROTECTED ACTION"
		end
		bindings[ownerActionId][ownerSlot] = nil
	end
	local otherSlot = if slot == "Primary" then "Secondary" else "Primary"
	if bindings[actionId][otherSlot] == token then bindings[actionId][otherSlot] = nil end
	bindings[actionId][slot] = token
	return true, "BINDING_UPDATED", "BINDING UPDATED"
end

local function resetBinding(bindings, actionId)
	local action = ActionCatalogue.ById[actionId]
	if not action then return false, "INVALID_BINDING", "INVALID BINDING REQUEST" end
	local candidateBindings = cloneBindings(bindings)
	candidateBindings[actionId] = {}
	for _, slot in { "Primary", "Secondary" } do
		local token = action[slot]
		if token then
			local success, code, message = setBinding(candidateBindings, actionId, slot, token)
			if not success then return false, code, message end
		end
	end
	for storedActionId in bindings do bindings[storedActionId] = nil end
	for storedActionId, binding in candidateBindings do bindings[storedActionId] = binding end
	return true, "BINDING_RESET", "BINDING RESET"
end

local function hasOnlyFields(payload, allowedFields, maximumCount)
	if type(payload) ~= "table" then return false end
	local count = 0
	for key in payload do
		count += 1
		if type(key) ~= "string" or not allowedFields[key] or count > maximumCount then return false end
	end
	return true
end

local function mutate(player, operation, payload)
	local session = sessions[player]
	if not session then return response(nil, false, "NO_SESSION", "PROFILE SESSION IS UNAVAILABLE") end
	if session.Status ~= "Ready" or not session.Account then
		return response(session, false, "NOT_READY", "PROFILE STORAGE IS NOT READY")
	end
	local nowClock = os.clock()
	if session.IsMutating or nowClock - session.LastMutationAt < Config.RemoteMutationCooldownSeconds then
		return response(session, false, "RATE_LIMITED", "PLEASE WAIT BEFORE TRYING AGAIN")
	end
	session.IsMutating = true
	session.LastMutationAt = nowClock

	local success = false
	local code = "INVALID_OPERATION"
	local message = "INVALID PROFILE REQUEST"
	local account = session.Account
	local now = os.time()
	if type(operation) ~= "string" or #operation > 32 then
		session.IsMutating = false
		return response(session, false, "INVALID_OPERATION", "INVALID ACCOUNT REQUEST")
	end
	if operation == "Create" then
		if #account.Characters >= ProfileConfig.MaximumProfiles then
			code, message = "MAXIMUM_PROFILES", "MAXIMUM OF FIVE FIGHTERS REACHED"
		else
			local draft, validationError = Schema.ValidateDraft(payload)
			if not draft then
				code, message = "INVALID_PROFILE", validationError
			elseif Schema.HasDuplicateName(account, draft.Name, nil) then
				code, message = "DUPLICATE_NAME", "THAT CHARACTER NAME ALREADY EXISTS"
			else
				local character = Schema.NewCharacter(account, draft, now)
				if character then
					table.insert(account.Characters, character)
					account.SelectedCharacterId = character.Id
					success, code, message = true, "CREATED", "FIGHTER CREATED"
				else
					code, message = "ID_GENERATION_FAILED", "FIGHTER COULD NOT BE CREATED"
				end
			end
		end
	elseif operation == "Update" and type(payload) == "table" then
		local character = Schema.FindCharacter(account, payload.Id)
		local draft, validationError = Schema.ValidateDraft(payload)
		if not character then
			code, message = "NOT_FOUND", "FIGHTER NOT FOUND"
		elseif not draft then
			code, message = "INVALID_PROFILE", validationError
		elseif Schema.HasDuplicateName(account, draft.Name, character.Id) then
			code, message = "DUPLICATE_NAME", "THAT CHARACTER NAME ALREADY EXISTS"
		else
			character.Name = draft.Name
			character.BodyType = draft.BodyType
			character.Appearance = draft.Appearance
			character.UpdatedAtUnix = now
			success, code, message = true, "UPDATED", "FIGHTER UPDATED"
		end
	elseif operation == "Delete" then
		local character, index = Schema.FindCharacter(account, payload)
		if character then
			table.remove(account.Characters, index)
			if account.SelectedCharacterId == character.Id then
				account.SelectedCharacterId = account.Characters[1] and account.Characters[1].Id or nil
			end
			success, code, message = true, "DELETED", "FIGHTER DELETED"
		else
			code, message = "NOT_FOUND", "FIGHTER NOT FOUND"
		end
	elseif operation == "Select" then
		local character = Schema.FindCharacter(account, payload)
		if character then
			account.SelectedCharacterId = character.Id
			character.LastPlayedUnix = now
			character.UpdatedAtUnix = now
			success, code, message = true, "SELECTED", "FIGHTER SELECTED"
		else
			code, message = "NOT_FOUND", "FIGHTER NOT FOUND"
		end
	elseif operation == "SetBinding" and hasOnlyFields(payload, {
		Action = true, Slot = true, Token = true,
	}, 3) then
		success, code, message = setBinding(
			account.Settings.Bindings,
			payload.Action,
			payload.Slot,
			payload.Token
		)
	elseif operation == "ClearBinding" and hasOnlyFields(payload, {
		Action = true, Slot = true,
	}, 2) then
		local binding = account.Settings.Bindings[payload.Action]
		if not binding or not BindingConfig.Slots[payload.Slot] then
			code, message = "INVALID_BINDING", "INVALID BINDING REQUEST"
		elseif not BindingConfig.CanClear(account.Settings.Bindings, payload.Action, payload.Slot) then
			code, message = "PROTECTED_BINDING", "PROTECTED ACTIONS REQUIRE AT LEAST ONE BINDING"
		else
			binding[payload.Slot] = nil
			success, code, message = true, "BINDING_CLEARED", "BINDING CLEARED"
		end
	elseif operation == "ResetBinding" then
		success, code, message = resetBinding(account.Settings.Bindings, payload)
	elseif operation == "ResetAllBindings" then
		account.Settings.Bindings = BindingConfig.DefaultBindings()
		success, code, message = true, "BINDINGS_RESET", "ALL BINDINGS RESET"
	elseif operation == "SetPreference" and hasOnlyFields(payload, {
		Key = true, Value = true,
	}, 2) then
		local value = PlayerPreferencesConfig.ValidatePreference(payload.Key, payload.Value)
		if value == nil then
			code, message = "INVALID_PREFERENCE", "INVALID PREFERENCE REQUEST"
		else
			account.Settings.Preferences[payload.Key] = value
			success, code, message = true, "PREFERENCE_UPDATED", "PREFERENCE UPDATED"
		end
	elseif operation == "ResetPreference" then
		local definition = PlayerPreferencesConfig.Definitions[payload]
		if definition then
			account.Settings.Preferences[payload] = definition.Default
			success, code, message = true, "PREFERENCE_RESET", "PREFERENCE RESET"
		else
			code, message = "INVALID_PREFERENCE", "INVALID PREFERENCE REQUEST"
		end
	elseif operation == "ResetPreferenceGroup" then
		local keys = PlayerPreferencesConfig.Groups[payload]
		if keys then
			for _, key in keys do
				account.Settings.Preferences[key] = PlayerPreferencesConfig.Definitions[key].Default
			end
			success, code, message = true, "PREFERENCES_RESET", "PREFERENCES RESET"
		else
			code, message = "INVALID_PREFERENCE_GROUP", "INVALID PREFERENCE GROUP"
		end
	elseif operation == "ResetAllPreferences" then
		account.Settings.Preferences = PlayerPreferencesConfig.DefaultPreferences()
		success, code, message = true, "PREFERENCES_RESET", "ALL PREFERENCES RESET"
	end

	if success then markDirty(player, session) end
	session.IsMutating = false
	return response(session, success, code, message)
end

local function closePlayer(player)
	local session = sessions[player]
	if not session then return end
	session.Closing = true
	session.DebounceGeneration += 1
	if session.Persistent and session.Dirty then saveSession(player, session) end
	local deadline = os.clock() + Config.ShutdownTimeoutSeconds
	while session.SaveInProgress and os.clock() < deadline do task.wait(0.05) end
	if session.Persistent and session.Dirty and not session.SaveInProgress and os.clock() < deadline then
		saveSession(player, session)
	end
	sessions[player] = nil
end

function CharacterProfileService:Init(remoteRegistry)
	if isInitialised then return end
	isInitialised = true
	requestRemote = remoteRegistry.CharacterProfilesRequest
	updateRemote = remoteRegistry.CharacterProfilesUpdated
	requestRemote.OnServerInvoke = function(player, operation, payload)
		if operation == "Request" then
			local session = sessions[player]
			return response(session, session ~= nil and session.Status == "Ready", "SNAPSHOT", nil)
		end
		return mutate(player, operation, payload)
	end
	Players.PlayerAdded:Connect(function(player) task.spawn(loadPlayer, player) end)
	Players.PlayerRemoving:Connect(closePlayer)
	for _, player in Players:GetPlayers() do task.spawn(loadPlayer, player) end

	task.spawn(function()
		while not isShuttingDown do
			task.wait(Config.AutosaveIntervalSeconds)
			for player, session in sessions do
				if session.Dirty and not session.Closing then task.spawn(saveSession, player, session) end
			end
		end
	end)

	game:BindToClose(function()
		isShuttingDown = true
		local deadline = os.clock() + Config.ShutdownTimeoutSeconds
		for player, session in sessions do
			session.Closing = true
			session.DebounceGeneration += 1
			if session.Persistent and session.Dirty then
				task.spawn(function()
					while session.SaveInProgress and os.clock() < deadline do task.wait(0.05) end
					if session.Dirty and os.clock() < deadline then saveSession(player, session) end
				end)
			end
		end
		while os.clock() < deadline do
			local hasPending = false
			for _, session in sessions do
				if session.SaveInProgress or (session.Persistent and session.Dirty) then hasPending = true; break end
			end
			if not hasPending then break end
			task.wait(0.05)
		end
	end)
end

return CharacterProfileService
