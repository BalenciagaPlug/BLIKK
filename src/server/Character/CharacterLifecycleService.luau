local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterDependency = require(ReplicatedStorage.Shared.Character.CharacterDependency)
local FighterVitalsConfig = require(ReplicatedStorage.Shared.Combat.FighterVitalsConfig)
local DistrictZeroConfig = require(ReplicatedStorage.Shared.Maps.DistrictZero.DistrictZeroConfig)
local GameModeRegistry = require(ReplicatedStorage.Shared.Multiplayer.GameModeRegistry)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)
local RateLimiter = require(script.Parent.Parent.Networking.RateLimiter)

local CharacterLifecycleService = {}

CharacterLifecycleService.CharacterPrepared = Instance.new("BindableEvent")
CharacterLifecycleService.CharacterFailed = Instance.new("BindableEvent")
CharacterLifecycleService.CharacterDied = Instance.new("BindableEvent")

local states = {}
local spawnService = nil
local lifecycleUpdatedRemote = nil
local movementLabEligibilityCallback = nil
local readinessLimiter = RateLimiter.New()
local isInitialised = false
local movementLabCombatRules = GameModeRegistry.Get("Deathmatch")

local function isInteger(value)
	return type(value) == "number" and value % 1 == 0
end

local function validOptionalIdentifier(value)
	return value == nil or (type(value) == "string" and #value > 0 and #value <= 128)
end

local function identitiesMatch(left, right)
	return type(left) == "table"
		and type(right) == "table"
		and left.Context == right.Context
		and left.RoomId == right.RoomId
		and left.MatchId == right.MatchId
		and left.MatchGeneration == right.MatchGeneration
		and left.Round == right.Round
		and left.SpawnGeneration == right.SpawnGeneration
end

local function identitiesShareCycle(left, right)
	return type(left) == "table"
		and type(right) == "table"
		and left.Context == right.Context
		and left.RoomId == right.RoomId
		and left.MatchId == right.MatchId
		and left.MatchGeneration == right.MatchGeneration
		and left.Round == right.Round
end

local function setLifecycleAttributes(player, character, identity, isReleased)
	local spawnGeneration = identity and identity.SpawnGeneration or nil
	local context = identity and identity.Context or nil
	local roomId = identity and identity.RoomId or nil
	local matchId = identity and identity.MatchId or nil
	local experienceRewardsEnabled = identity ~= nil
		and identity.Context ~= "MovementLab"
		and type(identity.MatchId) == "string"
	player:SetAttribute("BLIKK_SpawnGeneration", spawnGeneration)
	player:SetAttribute("BLIKK_CharacterContext", context)
	player:SetAttribute("BLIKK_CharacterRoomId", roomId)
	player:SetAttribute("BLIKK_CharacterMatchId", matchId)
	player:SetAttribute("BLIKK_GameplayReleased", isReleased)
	player:SetAttribute(
		"BLIKK_ExperienceRewardsEnabled",
		experienceRewardsEnabled
	)
	if character then
		character:SetAttribute("BLIKK_SpawnGeneration", spawnGeneration)
		character:SetAttribute("BLIKK_CharacterContext", context)
		character:SetAttribute("BLIKK_CharacterRoomId", roomId)
		character:SetAttribute("BLIKK_CharacterMatchId", matchId)
		character:SetAttribute("BLIKK_GameplayReleased", isReleased)
		character:SetAttribute(
			"BLIKK_ExperienceRewardsEnabled",
			experienceRewardsEnabled
		)
	end
end

local function fireClientUpdate(player, status, identity, code, character, explicitAttemptGeneration)
	if not lifecycleUpdatedRemote or player.Parent ~= Players then return end
	local state = states[player]
	local attemptGeneration = explicitAttemptGeneration
	if not attemptGeneration and identity and identity.Context == "MovementLab" and state then
		attemptGeneration = state.MovementLabAttemptsBySpawnGeneration[identity.SpawnGeneration]
	end
	lifecycleUpdatedRemote:FireClient(player, {
		Status = status,
		Identity = identity,
		MovementLabAttemptGeneration = attemptGeneration,
		Code = code,
		Character = character,
		ServerTime = Workspace:GetServerTimeNow(),
	})
end

local function disconnectDeath(state)
	if state.DeathConnection then
		state.DeathConnection:Disconnect()
		state.DeathConnection = nil
	end
end

local function waitForCharacterParts(player, character, deadline)
	if not character or character ~= player.Character then return nil, nil, "STALE_CHARACTER" end
	local expiresAt = deadline or (os.clock() + MultiplayerConfig.CharacterDependencyTimeoutSeconds)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or CharacterDependency.WaitForChildBefore(character, "Humanoid", expiresAt)
	if character ~= player.Character then return nil, nil, "STALE_CHARACTER" end
	local root = CharacterDependency.WaitForChildBefore(character, "HumanoidRootPart", expiresAt)
	if character ~= player.Character then return nil, nil, "STALE_CHARACTER" end
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return nil, nil, "CHARACTER_INCOMPLETE"
	end
	return humanoid, root, nil
end

local function holdCharacterInstance(player, character, identity, deadline)
	setLifecycleAttributes(player, character, identity, false)
	local humanoid, root, code = waitForCharacterParts(player, character, deadline)
	if not root then return false, code end
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true, nil, humanoid, root
end

local function isLatestRequest(state, request)
	return not state.Disposed
		and state.LatestIdentity ~= nil
		and identitiesMatch(state.LatestIdentity, request.Identity)
end

local function destroyCurrentCharacter(player, character)
	if character and character.Parent and player.Character == character then
		character:Destroy()
	end
end

local function failRequest(player, state, request, code, character)
	if state.Active == request then state.Active = nil end
	local failedCharacter = character or request.ObservedCharacter
	if failedCharacter then destroyCurrentCharacter(player, failedCharacter) end
	spawnService:ClearSpawnProtection(player)
	spawnService:ClearReservation(player, request.Identity.SpawnGeneration)
	setLifecycleAttributes(player, nil, nil, false)
	CharacterLifecycleService.CharacterFailed:Fire(player, request.Identity, code)
	fireClientUpdate(player, "Failed", request.Identity, code, failedCharacter)
end

local function scheduleMovementLabRespawn(player, state, current)
	task.delay(movementLabCombatRules.RespawnDelaySeconds, function()
		if state.Disposed or player.Parent ~= Players then return end
		if state.LatestIdentity and identitiesMatch(state.LatestIdentity, current.Identity)
			and not state.Active and not state.Pending then
			CharacterLifecycleService:RequestCharacter(player, {
				Context = "MovementLab",
				MatchGeneration = 0,
				Round = 0,
				ClientAttemptGeneration = state.CurrentMovementLabAttemptGeneration,
			})
		end
	end)
end

local function bindAcceptedDeath(player, state, current)
	disconnectDeath(state)
	state.DeathConnection = current.Humanoid.Died:Connect(function()
		if state.Current ~= current or player.Character ~= current.Character then return end
		current.Status = "Died"
		current.Released = false
		setLifecycleAttributes(player, current.Character, current.Identity, false)
		CharacterLifecycleService.CharacterDied:Fire(
			player,
			current.Identity,
			current.Character,
			current.Humanoid
		)
		fireClientUpdate(player, "Died", current.Identity, nil, current.Character)
		if current.Identity.Context == "MovementLab" then
			scheduleMovementLabRespawn(player, state, current)
		end
	end)
end

local function scheduleMovementLabReadinessTimeout(player, state, current)
	task.delay(MultiplayerConfig.IndividualPreparationTimeoutSeconds, function()
		if state.Disposed or state.Current ~= current or current.Released
			or current.Status ~= "Prepared" then return end
		CharacterLifecycleService:CancelPlayer(player, "READINESS_TIMEOUT")
	end)
end

local startWorker

local function prepareRequest(player, state, request)
	local loadedCharacter = nil
	local lastCode = "CHARACTER_LOAD_FAILED"
	for attempt = 1, MultiplayerConfig.CharacterLoadRetryCount do
		if not isLatestRequest(state, request) or player.Parent ~= Players then return false, "STALE_REQUEST" end
		request.ObservedCharacter = nil
		local completed = false
		local succeeded = false
		local loadError = nil
		local timedOut = false
		task.spawn(function()
			local loadStartedAt = os.clock()
			succeeded, loadError = pcall(player.LoadCharacterAsync, player)
			request.LastLoadDurationSeconds = os.clock() - loadStartedAt
			completed = true
			if timedOut then
				local lateCharacter = request.ObservedCharacter or player.Character
				if lateCharacter then destroyCurrentCharacter(player, lateCharacter) end
				if state.TerminalRequest == request then
					state.TerminalCode = nil
					state.TerminalRequest = nil
					fireClientUpdate(player, "Recovered", request.Identity, "LATE_LOAD_DISCARDED", lateCharacter)
					if state.Pending and not state.Disposed then startWorker(player, state) end
				end
			end
		end)
		local loadDeadline = os.clock() + MultiplayerConfig.CharacterLoadTimeoutSeconds
		while not completed and os.clock() < loadDeadline do
			task.wait(0.05)
		end
		if not completed then
			timedOut = true
			state.TerminalCode = "CHARACTER_LOAD_TIMEOUT"
			state.TerminalRequest = request
			warn(string.format(
				"[BLIKK CHARACTER] Load timed out for user %d; later completion will be discarded.",
				player.UserId
			))
			return false, "CHARACTER_LOAD_TIMEOUT"
		end
		loadedCharacter = request.ObservedCharacter or player.Character
		if succeeded and loadedCharacter and loadedCharacter == player.Character then
			lastCode = nil
			break
		end
		if not succeeded then
			warn(string.format(
				"[BLIKK CHARACTER] Load attempt %d failed for user %d, spawn generation %d: %s",
				attempt,
				player.UserId,
				request.Identity.SpawnGeneration,
				tostring(loadError)
			))
		end
		lastCode = if succeeded then "CHARACTER_MISSING" else "CHARACTER_LOAD_FAILED"
		if attempt < MultiplayerConfig.CharacterLoadRetryCount then
			task.wait(MultiplayerConfig.CharacterLoadRetryBaseDelaySeconds * 2 ^ (attempt - 1))
		end
	end
	if lastCode then return false, lastCode, loadedCharacter end
	if not isLatestRequest(state, request) then return false, "STALE_REQUEST", loadedCharacter end

	local placementDeadline = os.clock() + MultiplayerConfig.IndividualPreparationTimeoutSeconds
	local held, holdCode, humanoid, root = holdCharacterInstance(
		player,
		loadedCharacter,
		request.Identity,
		placementDeadline
	)
	if not held then return false, holdCode, loadedCharacter end

	local placementResult = nil
	local placementCode = "SPAWN_UNAVAILABLE"
	local placementAttempts = 0
	repeat
		placementAttempts += 1
		if not isLatestRequest(state, request) or loadedCharacter ~= player.Character then
			return false, "STALE_REQUEST", loadedCharacter
		end
		local placementStartedAt = os.clock()
		local callSucceeded, placed, code, result = pcall(
			spawnService.PlaceCharacter,
			spawnService,
			player,
			loadedCharacter,
			placementDeadline,
			request.Identity.Context,
			request.ModeId,
			request.Identity.SpawnGeneration
		)
		request.LastPlacementDurationSeconds = os.clock() - placementStartedAt
		if not callSucceeded then
			warn(string.format(
				"[BLIKK CHARACTER] Spawn placement failed for user %d, spawn generation %d: %s",
				player.UserId,
				request.Identity.SpawnGeneration,
				tostring(placed)
			))
			placementCode = "SPAWN_PLACEMENT_FAILED"
			break
		end
		if placed then
			placementResult = result
			placementCode = nil
			break
		end
		placementCode = code or "SPAWN_UNAVAILABLE"
		if placementCode ~= "SPAWN_UNAVAILABLE" or os.clock() >= placementDeadline
			or placementAttempts >= DistrictZeroConfig.SpawnSafety.MaximumPlacementRetries then break end
		task.wait(math.min(
			MultiplayerConfig.CharacterLoadRetryBaseDelaySeconds,
			math.max(0, placementDeadline - os.clock())
		))
	until os.clock() >= placementDeadline
	if placementCode then return false, placementCode, loadedCharacter end
	if not isLatestRequest(state, request) or loadedCharacter ~= player.Character then
		return false, "STALE_REQUEST", loadedCharacter
	end

	root = placementResult.RootPart or root
	humanoid = placementResult.Humanoid or humanoid
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true, nil, loadedCharacter, humanoid, root, placementResult
end

local function completeRequest(player, state, request, character, humanoid, root, placementResult)
	if not isLatestRequest(state, request) or player.Character ~= character then return false end
	if character:GetAttribute(FighterVitalsConfig.Attributes.FreshLifeInitialized) ~= true then
		humanoid.MaxHealth = FighterVitalsConfig.MaximumHealth
		humanoid.Health = FighterVitalsConfig.MaximumHealth
		character:SetAttribute(
			FighterVitalsConfig.Attributes.MaximumArmour,
			FighterVitalsConfig.MaximumArmour
		)
		character:SetAttribute(FighterVitalsConfig.Attributes.Armour, FighterVitalsConfig.MaximumArmour)
		character:SetAttribute(FighterVitalsConfig.Attributes.FreshLifeInitialized, true)
	end
	local current = {
		Identity = request.Identity,
		Character = character,
		Humanoid = humanoid,
		RootPart = root,
		Spawn = placementResult.Spawn,
		Released = false,
		Status = "Prepared",
	}
	state.Current = current
	state.Active = nil
	bindAcceptedDeath(player, state, current)
	CharacterLifecycleService.CharacterPrepared:Fire(
		player,
		request.Identity,
		character,
		placementResult
	)
	fireClientUpdate(player, "Prepared", request.Identity, nil, character)
	if request.Identity.Context == "MovementLab" then
		if identitiesMatch(state.MovementLabReadyIdentity, request.Identity) then
			state.MovementLabReadyIdentity = nil
			CharacterLifecycleService:ReleaseCharacter(player, request.Identity, "CLIENT_READY")
		else
			scheduleMovementLabReadinessTimeout(player, state, current)
		end
	end
	return true
end

startWorker = function(player, state)
	if state.WorkerRunning or state.Disposed then return end
	state.WorkerRunning = true
	task.spawn(function()
		while not state.Disposed and not state.TerminalCode and player.Parent == Players and state.Pending do
			local request = state.Pending
			state.Pending = nil
			state.Active = request
			if isLatestRequest(state, request) then
				local preparationStartedAt = os.clock()
				local callSucceeded, succeeded, code, character, humanoid, root, placementResult = pcall(
					prepareRequest,
					player,
					state,
					request
				)
				request.PreparationDurationSeconds = os.clock() - preparationStartedAt
				if not callSucceeded then
					local preparationError = succeeded
					warn(string.format(
						"[BLIKK CHARACTER] Preparation failed for user %d, spawn generation %d: %s",
						player.UserId,
						request.Identity.SpawnGeneration,
						tostring(preparationError)
					))
					succeeded = false
					code = "CHARACTER_PREPARATION_FAILED"
				end
				if succeeded then
					if not completeRequest(player, state, request, character, humanoid, root, placementResult) then
						destroyCurrentCharacter(player, character)
					end
				elseif code ~= "STALE_REQUEST" and isLatestRequest(state, request) then
					failRequest(player, state, request, code or "CHARACTER_PREPARATION_FAILED", character)
				elseif character and player.Character == character and not state.Pending then
					destroyCurrentCharacter(player, character)
				end
			end
			if state.Active == request then state.Active = nil end
		end
		state.WorkerRunning = false
		if state.Pending and not state.Disposed and not state.TerminalCode then startWorker(player, state) end
	end)
end

local function bindPlayer(player)
	if states[player] then return states[player] end
	local state = {
		LatestSpawnGeneration = 0,
		LatestIdentity = nil,
		Pending = nil,
		Active = nil,
		Current = nil,
		WorkerRunning = false,
		Disposed = false,
		DeathConnection = nil,
		CharacterAddedConnection = nil,
		CharacterRemovingConnection = nil,
		LastMovementLabRequestAt = -math.huge,
		MovementLabReadyIdentity = nil,
		CurrentMovementLabAttemptGeneration = nil,
		LastMovementLabAttemptGeneration = 0,
		MovementLabAttemptsBySpawnGeneration = {},
		MovementLabAttemptOrder = {},
		TerminalCode = nil,
		TerminalRequest = nil,
	}
	states[player] = state
	state.CharacterAddedConnection = player.CharacterAdded:Connect(function(character)
		local active = state.Active
		if active and isLatestRequest(state, active) then
			active.ObservedCharacter = character
			setLifecycleAttributes(player, character, active.Identity, false)
			task.spawn(function()
				if state.Active ~= active or not isLatestRequest(state, active) then return end
				local _, root = waitForCharacterParts(player, character)
				if state.Active ~= active or not isLatestRequest(state, active)
					or player.Character ~= character or not root then return end
				root.Anchored = true
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end)
		else
			setLifecycleAttributes(player, character, nil, false)
			task.spawn(function()
				if player.Character ~= character then return end
				local _, root = waitForCharacterParts(player, character)
				if root and player.Character == character then
					root.Anchored = true
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end
			end)
		end
	end)
	state.CharacterRemovingConnection = player.CharacterRemoving:Connect(function(character)
		local current = state.Current
		if not current or current.Character ~= character then return end
		disconnectDeath(state)
		state.Current = nil
		if not state.Active and not state.Pending and current.Status ~= "Died"
			and current.Status ~= "Superseded" and not state.IsCancelling then
			CharacterLifecycleService.CharacterFailed:Fire(
				player,
				current.Identity,
				"CHARACTER_REMOVED"
			)
			fireClientUpdate(player, "Failed", current.Identity, "CHARACTER_REMOVED", character)
		end
	end)
	if player.Character then
		local existingCharacter = player.Character
		setLifecycleAttributes(player, existingCharacter, nil, false)
		task.spawn(function()
			if player.Character == existingCharacter and not state.Active then
				holdCharacterInstance(player, existingCharacter, nil)
			end
		end)
	end
	return state
end

local function buildIdentity(state, request)
	if type(request) ~= "table" or type(request.Context) ~= "string"
		or #request.Context < 1 or #request.Context > 32 then
		return nil, "INVALID_CONTEXT"
	end
	if not validOptionalIdentifier(request.RoomId) or not validOptionalIdentifier(request.MatchId) then
		return nil, "INVALID_IDENTITY"
	end
	local matchGeneration = request.MatchGeneration
	if matchGeneration == nil then matchGeneration = request.Generation or 0 end
	local round = request.Round or 0
	if not isInteger(matchGeneration) or matchGeneration < 0 or not isInteger(round) or round < 0 then
		return nil, "INVALID_IDENTITY"
	end
	local spawnGeneration = request.SpawnGeneration
	if spawnGeneration == nil then spawnGeneration = state.LatestSpawnGeneration + 1 end
	if not isInteger(spawnGeneration) or spawnGeneration < 1 then return nil, "INVALID_SPAWN_GENERATION" end
	local identity = table.freeze({
		Context = request.Context,
		RoomId = request.RoomId,
		MatchId = request.MatchId,
		MatchGeneration = matchGeneration,
		Round = round,
		SpawnGeneration = spawnGeneration,
	})
	return identity, nil
end

function CharacterLifecycleService:Init(remoteRegistry, placementService)
	if isInitialised then return self end
	isInitialised = true
	spawnService = placementService
	lifecycleUpdatedRemote = remoteRegistry.CharacterLifecycleUpdated
	assert(spawnService and type(spawnService.PlaceCharacter) == "function", "Character lifecycle requires placement")

	remoteRegistry.RequestMovementLabSpawn.OnServerEvent:Connect(function(player, payload)
		local state = bindPlayer(player)
		if type(payload) ~= "table" or type(payload.Operation) ~= "string" then return end
		local attemptGeneration = payload.AttemptGeneration
		if not isInteger(attemptGeneration) or attemptGeneration < 1
			or attemptGeneration > 2147483647 then return end
		if payload.Operation == "Exit" then
			local identity = state.LatestIdentity or (state.Current and state.Current.Identity)
			local expectedSpawnGeneration = payload.SpawnGeneration
			if expectedSpawnGeneration ~= nil and (not isInteger(expectedSpawnGeneration)
				or expectedSpawnGeneration < 1) then return end
			if identity and identity.Context == "MovementLab"
				and state.CurrentMovementLabAttemptGeneration == attemptGeneration
				and (expectedSpawnGeneration == nil
					or identity.SpawnGeneration == expectedSpawnGeneration) then
				self:CancelPlayer(player, "MOVEMENT_LAB_EXIT")
			end
			return
		end
		if payload.Operation ~= "Begin" or attemptGeneration <= state.LastMovementLabAttemptGeneration then
			return
		end
		state.LastMovementLabAttemptGeneration = attemptGeneration
		local now = os.clock()
		if now - state.LastMovementLabRequestAt < MultiplayerConfig.MovementLabRequestCooldownSeconds then
			fireClientUpdate(
				player,
				"Rejected",
				nil,
				"MOVEMENT_LAB_REQUEST_COOLDOWN",
				player.Character,
				attemptGeneration
			)
			return
		end
		state.LastMovementLabRequestAt = now
		local allowed = false
		local code = "MOVEMENT_LAB_UNAVAILABLE"
		if movementLabEligibilityCallback then
			local succeeded, result, reason = pcall(movementLabEligibilityCallback, player)
			allowed = succeeded and result == true
			if succeeded and type(reason) == "string" then code = reason end
		end
		if not allowed then
			fireClientUpdate(player, "Rejected", nil, code, player.Character, attemptGeneration)
			return
		end
		local existingIdentity = state.LatestIdentity or (state.Current and state.Current.Identity)
		if existingIdentity and existingIdentity.Context == "MovementLab" then
			self:CancelPlayer(player, "MOVEMENT_LAB_SUPERSEDED")
		end
		state.CurrentMovementLabAttemptGeneration = attemptGeneration
		local identity, requestCode = self:RequestCharacter(player, {
			Context = "MovementLab",
			MatchGeneration = 0,
			Round = 0,
			ClientAttemptGeneration = attemptGeneration,
		})
		if not identity then
			state.CurrentMovementLabAttemptGeneration = nil
			fireClientUpdate(
				player,
				"Rejected",
				nil,
				requestCode,
				player.Character,
				attemptGeneration
			)
		end
	end)

	remoteRegistry.MatchReady.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or payload.Context ~= "MovementLab"
			or type(payload.Identity) ~= "table" then return end
		if not RateLimiter.Allow(
			readinessLimiter,
			player,
			"MovementLabReady",
			MultiplayerConfig.MatchReadyWindowSeconds,
			MultiplayerConfig.MatchReadyMaximumBurst
		) then return end
		local state = states[player]
		if not state or not state.LatestIdentity
			or not identitiesMatch(state.LatestIdentity, payload.Identity) then return end
		if state.Current and identitiesMatch(state.Current.Identity, payload.Identity) then
			self:ReleaseCharacter(player, payload.Identity, "CLIENT_READY")
		else
			state.MovementLabReadyIdentity = state.LatestIdentity
		end
	end)

	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if not state then return end
		state.Disposed = true
		state.Pending = nil
		state.Active = nil
		disconnectDeath(state)
		if state.CharacterAddedConnection then state.CharacterAddedConnection:Disconnect() end
		if state.CharacterRemovingConnection then state.CharacterRemovingConnection:Disconnect() end
		RateLimiter.Clear(readinessLimiter, player)
		spawnService:ClearReservation(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do bindPlayer(player) end
	return self
end

function CharacterLifecycleService:SetMovementLabEligibilityCallback(callback)
	assert(callback == nil or type(callback) == "function", "Movement Lab eligibility must be a function")
	movementLabEligibilityCallback = callback
end

function CharacterLifecycleService:RequestCharacter(player, request)
	if not isInitialised or player.Parent ~= Players then return nil, "PLAYER_UNAVAILABLE" end
	local state = bindPlayer(player)
	if state.TerminalCode then return nil, state.TerminalCode end
	local identity, code = buildIdentity(state, request)
	if not identity then return nil, code end
	local hasExplicitSpawnGeneration = request.SpawnGeneration ~= nil
	local candidates = { state.Current, state.Active, state.Pending }
	for candidateIndex = 1, 3 do
		local candidate = candidates[candidateIndex]
		local candidateIdentity = candidate and candidate.Identity
		local isReusableCurrent = candidate ~= nil
			and (candidate ~= state.Current or candidate.Status ~= "Died")
		local isLatestCandidate = candidateIdentity and state.LatestIdentity
			and identitiesMatch(candidateIdentity, state.LatestIdentity)
		local isSameRequest = if hasExplicitSpawnGeneration
			then identitiesMatch(candidateIdentity, identity)
			else identitiesShareCycle(candidateIdentity, identity)
		if isReusableCurrent and isLatestCandidate and isSameRequest then
			return candidateIdentity, if candidate == state.Current then "PREPARED" else "COALESCED",
				candidate.Character
		end
	end
	if identity.SpawnGeneration <= state.LatestSpawnGeneration then return nil, "STALE_GENERATION" end

	state.LatestSpawnGeneration = identity.SpawnGeneration
	state.LatestIdentity = identity
	state.MovementLabReadyIdentity = nil
	state.Pending = {
		Identity = identity,
		ObservedCharacter = nil,
		ClientAttemptGeneration = request.ClientAttemptGeneration,
	}
	if identity.Context == "MovementLab" and isInteger(request.ClientAttemptGeneration) then
		state.MovementLabAttemptsBySpawnGeneration[identity.SpawnGeneration] =
			request.ClientAttemptGeneration
		table.insert(state.MovementLabAttemptOrder, identity.SpawnGeneration)
		while #state.MovementLabAttemptOrder > MultiplayerConfig.MaximumPreparationDiagnostics do
			local expiredSpawnGeneration = table.remove(state.MovementLabAttemptOrder, 1)
			state.MovementLabAttemptsBySpawnGeneration[expiredSpawnGeneration] = nil
		end
	end
	if state.Current and state.Current.Character == player.Character then
		local previousCurrent = state.Current
		self:HoldCharacter(player, previousCurrent.Identity, "SUPERSEDED")
		previousCurrent.Status = "Superseded"
		disconnectDeath(state)
	end
	spawnService:ClearSpawnProtection(player)
	spawnService:ClearReservation(player)
	fireClientUpdate(player, "Preparing", identity, nil, player.Character)
	startWorker(player, state)
	return identity, "QUEUED"
end

function CharacterLifecycleService:HoldCharacter(player, identity, reason)
	local state = states[player]
	local current = state and state.Current
	if not current or not identitiesMatch(current.Identity, identity)
		or current.Character ~= player.Character then return false, "STALE_GENERATION" end
	local humanoid = current.Humanoid
	local root = current.RootPart
	if current.Status == "Died" or not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
		return false, "CHARACTER_NOT_LIVE"
	end
	if not root or not root.Parent or not root:IsDescendantOf(current.Character) then
		return false, "CHARACTER_INCOMPLETE"
	end
	setLifecycleAttributes(player, current.Character, current.Identity, false)
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	current.Released = false
	current.Status = "Prepared"
	fireClientUpdate(player, "Held", current.Identity, reason, current.Character)
	return true, "HELD"
end

function CharacterLifecycleService:ReleaseCharacter(player, identity, reason)
	local state = states[player]
	local current = state and state.Current
	if not current or not identitiesMatch(current.Identity, identity)
		or current.Character ~= player.Character then return false, "STALE_GENERATION" end
	if current.Released then return true, "ALREADY_RELEASED" end
	local root = current.RootPart
	local humanoid = current.Humanoid
	if current.Status ~= "Prepared" or not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
		return false, "CHARACTER_NOT_PREPARED"
	end
	if not root or not root.Parent or not root:IsDescendantOf(current.Character) then
		return false, "CHARACTER_INCOMPLETE"
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = false
	current.Released = true
	current.Status = "Released"
	setLifecycleAttributes(player, current.Character, current.Identity, true)
	if current.Identity.Context == "MovementLab" then
		spawnService:SetSpawnProtection(player, movementLabCombatRules.SpawnProtectionSeconds)
	end
	fireClientUpdate(player, "Released", current.Identity, reason, current.Character)
	return true, "RELEASED"
end

function CharacterLifecycleService:CancelPlayer(player, reason)
	local state = states[player]
	if not state then return false end
	local identity = state.LatestIdentity or (state.Current and state.Current.Identity)
	state.LatestSpawnGeneration += 1
	state.LatestIdentity = nil
	state.Pending = nil
	state.Active = nil
	state.MovementLabReadyIdentity = nil
	state.IsCancelling = true
	disconnectDeath(state)
	spawnService:ClearSpawnProtection(player)
	spawnService:ClearReservation(player)
	local character = state.Current and state.Current.Character or player.Character
	state.Current = nil
	if character then destroyCurrentCharacter(player, character) end
	state.IsCancelling = false
	setLifecycleAttributes(player, nil, nil, false)
	if identity then fireClientUpdate(player, "Cancelled", identity, reason or "CANCELLED", character) end
	if identity and identity.Context == "MovementLab" then
		state.CurrentMovementLabAttemptGeneration = nil
	end
	return true
end

function CharacterLifecycleService:GetState(player)
	local state = states[player]
	if not state then return nil end
	local current = state.Current
	return {
		Identity = state.LatestIdentity,
		CurrentIdentity = current and current.Identity or nil,
		Character = current and current.Character or nil,
		Status = (state.Active and "Preparing")
			or (state.Pending and "Queued")
			or (current and current.Status)
			or "Idle",
		Released = current and current.Released or false,
		ActiveIdentity = state.Active and state.Active.Identity or nil,
		PendingIdentity = state.Pending and state.Pending.Identity or nil,
		TerminalCode = state.TerminalCode,
	}
end

return CharacterLifecycleService
