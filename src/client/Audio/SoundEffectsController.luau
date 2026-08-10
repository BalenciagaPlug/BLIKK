local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AudioPreloadController = require(script.Parent.AudioPreloadController)
local SoundEffectsConfig = require(ReplicatedStorage.Shared.Audio.SoundEffectsConfig)
local MeleePresentationConfig = require(ReplicatedStorage.Shared.Combat.MeleePresentationConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local SoundEffectsController = {}

local soundsByKey = {}
local disabledKeys = {}
local lastPlayedAtByKey = {}
local connections = {}
local characterAddedConnectionsByPlayer = {}
local deathConnectionsByPlayer = {}
local deathBindGenerationByPlayer = {}
local soundFolder = nil
local isInitialised = false
local isGameplayBound = false
local isDestroyed = false
local slashGeneration = 0

local function validSoundId(soundId)
	return type(soundId) == "string" and soundId:match("^rbxassetid://%d+$") ~= nil
end

local function getDefinition(key)
	return SoundEffectsConfig.Sounds[key]
end

local function configureSound(sound, definition)
	local soundGroupName = if definition.Category == "UI"
		then SoundEffectsConfig.UISoundGroupName
		else SoundEffectsConfig.SoundGroupName
	local soundGroup = SoundService:FindFirstChild(soundGroupName)
	if not soundGroup or not soundGroup:IsA("SoundGroup") then return false end
	sound.Name = definition.Name
	sound.SoundGroup = soundGroup
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.PlaybackSpeed
	sound.Looped = false
	sound.PlayOnRemove = false
	if definition.Spatial then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = definition.RollOffMinDistanceStuds
			or SoundEffectsConfig.RemoteShotRolloffMinDistanceStuds
		sound.RollOffMaxDistance = definition.RollOffMaxDistanceStuds
			or SoundEffectsConfig.RemoteShotRolloffMaxDistanceStuds
	end
	return true
end

local function applyPreloadStatus(key, status)
	local definition = getDefinition(key)
	local sound = soundsByKey[key]
	if not definition or not sound then return end
	if status == "Success" and validSoundId(definition.SoundId) then
		disabledKeys[key] = nil
		sound.SoundId = definition.SoundId
	elseif status == "Failure" or status == "Disabled" then
		disabledKeys[key] = true
		sound:Stop()
		sound.SoundId = ""
	end
end

local function canPlay(key, definition)
	if not definition or definition.Enabled ~= true or disabledKeys[key] then return false end
	if AudioPreloadController:GetStatus(key) ~= "Success" then return false end
	local now = os.clock()
	local minimumInterval = definition.MinimumRetriggerSeconds or 0
	if now - (lastPlayedAtByKey[key] or -math.huge) < minimumInterval then return false end
	lastPlayedAtByKey[key] = now
	return true
end

local function playSound(key, sound, playbackSpeed)
	local definition = getDefinition(key)
	if not sound or not canPlay(key, definition) then return false end
	if sound.SoundId ~= definition.SoundId then sound.SoundId = definition.SoundId end
	sound.PlaybackSpeed = playbackSpeed or definition.PlaybackSpeed
	local succeeded, playError = pcall(function()
		if definition.RestartOnRetrigger then
			sound:Stop()
			sound.TimePosition = 0
		end
		sound:Play()
	end)
	if succeeded then return true end
	disabledKeys[key] = true
	sound.SoundId = ""
	warn(string.format("[BLIKK SFX] Disabled %s after playback failure: %s", key, tostring(playError)))
	return false
end

function SoundEffectsController:Play(key, playbackSpeed)
	return playSound(key, soundsByKey[key], playbackSpeed)
end

local function playTransientAtParent(key, parent, destroyParentOnCleanup)
	local definition = getDefinition(key)
	if not definition or definition.Spatial ~= true or typeof(parent) ~= "Instance" then return false end
	local sound = Instance.new("Sound")
	if not configureSound(sound, definition) then
		sound:Destroy()
		return false
	end
	sound.SoundId = definition.SoundId
	sound.Parent = parent
	if not playSound(key, sound, nil) then
		sound:Destroy()
		return false
	end
	local endedConnection = nil
	local cleaned = false
	local function cleanUp()
		if cleaned then return end
		cleaned = true
		if endedConnection then endedConnection:Disconnect(); endedConnection = nil end
		sound:Destroy()
		if destroyParentOnCleanup then parent:Destroy() end
	end
	endedConnection = sound.Ended:Connect(cleanUp)
	task.delay(SoundEffectsConfig.TransientMaximumLifetimeSeconds, cleanUp)
	return true
end

function SoundEffectsController:PlayAt(key, parent)
	return playTransientAtParent(key, parent, false)
end

function SoundEffectsController:PlayAtPosition(key, worldPosition)
	if typeof(worldPosition) ~= "Vector3" then return false end
	local attachment = Instance.new("Attachment")
	attachment.Name = "BLIKKTransientAudioOrigin"
	attachment.Parent = Workspace.Terrain
	attachment.WorldPosition = worldPosition
	if playTransientAtParent(key, attachment, true) then return true end
	attachment:Destroy()
	return false
end

function SoundEffectsController:PreparePooledSound(key, sound)
	local definition = getDefinition(key)
	if not definition or not sound or not sound:IsA("Sound") then return false end
	return configureSound(sound, definition)
end

function SoundEffectsController:PlayPooled(key, sound)
	return playSound(key, sound, nil)
end

function SoundEffectsController:PlayAuthoritativeMeleeHitConfirm()
	return self:Play("MeleeHitConfirm")
end

function SoundEffectsController:Init(uiNavigationController)
	if isInitialised then return end
	isInitialised = true
	isDestroyed = false
	local existing = SoundService:FindFirstChild(SoundEffectsConfig.FolderName)
	if existing then existing:Destroy() end
	soundFolder = Instance.new("Folder")
	soundFolder.Name = SoundEffectsConfig.FolderName
	soundFolder.Parent = SoundService
	for key, definition in SoundEffectsConfig.Sounds do
		-- Spatial definitions can also need one listener-local playback instance. B8Shot uses
		-- this Sound for immediate local feedback and separate pooled Sounds for remote origins.
		if definition.Enabled and validSoundId(definition.SoundId) then
			local sound = Instance.new("Sound")
			if configureSound(sound, definition) then
				sound.SoundId = ""
				sound.Parent = soundFolder
				soundsByKey[key] = sound
				applyPreloadStatus(key, AudioPreloadController:GetStatus(key))
			else
				sound:Destroy()
				disabledKeys[key] = true
			end
		end
	end
	table.insert(connections, AudioPreloadController.StatusChanged.Event:Connect(applyPreloadStatus))
	table.insert(connections, uiNavigationController.AudioEvent.Event:Connect(function(role)
		local key = SoundEffectsConfig.UIRoleToSoundKey[role]
		if key then self:Play(key) end
	end))
	table.insert(connections, script.Destroying:Connect(function()
		self:Destroy()
	end))
end

function SoundEffectsController:BindGameplay(
	fighterController,
	firearmPresentationController,
	meleePresentationController,
	loadingScreenController,
	movementEngine
)
	if isGameplayBound or isDestroyed then return end
	isGameplayBound = true
	table.insert(connections, firearmPresentationController.SemanticEvent.Event:Connect(function(eventName)
		if eventName == "FireAccepted" then
			self:Play("B8Shot")
		elseif eventName == "DryFire" then
			self:Play("B8DryFire")
		end
	end))
	table.insert(connections, meleePresentationController.SemanticEvent.Event:Connect(function(eventName, _, detail)
		if eventName == "AltFireAccepted" then
			slashGeneration += 1
			local playGeneration = slashGeneration
			task.delay(MeleePresentationConfig.AltFire.SoundCueSeconds, function()
				if isDestroyed or playGeneration ~= slashGeneration
					or meleePresentationController:GetState() ~= "AltFiring" then return end
				self:Play("KatanaSlash", MeleePresentationConfig.AltFire.SoundPlaybackSpeed)
			end)
			return
		end
		if eventName ~= "SlashAccepted" then return end
		slashGeneration += 1
		local playGeneration = slashGeneration
		local variant = type(detail) == "table" and detail.Variant or 1
		task.delay(MeleePresentationConfig.Slash.AnticipationSeconds, function()
			if isDestroyed or playGeneration ~= slashGeneration
				or meleePresentationController:GetState() ~= "Slashing" then return end
			local speeds = SoundEffectsConfig.KatanaSlashVariantPlaybackSpeeds
			self:Play("KatanaSlash", speeds[variant] or 1)
		end)
	end))
	table.insert(connections, meleePresentationController.StateChanged.Event:Connect(function(nextState)
		if nextState == "Blocking" or nextState == "Unequipping" or nextState == "Holstered"
			or nextState == "Interrupted" then slashGeneration += 1 end
	end))
	table.insert(connections, fighterController.LoadoutChanged.Event:Connect(function(changeType)
		if changeType == "ActiveWeaponSlot" then self:Play("WeaponSwitch") end
	end))
	table.insert(connections, movementEngine.DashStarted.Event:Connect(function()
		slashGeneration += 1
	end))

	local function disconnectPlayerDeath(player)
		deathBindGenerationByPlayer[player] = (deathBindGenerationByPlayer[player] or 0) + 1
		local deathConnection = deathConnectionsByPlayer[player]
		if deathConnection then deathConnection:Disconnect(); deathConnectionsByPlayer[player] = nil end
	end
	local function unbindPlayer(player)
		disconnectPlayerDeath(player)
		local characterAddedConnection = characterAddedConnectionsByPlayer[player]
		if characterAddedConnection then
			characterAddedConnection:Disconnect()
			characterAddedConnectionsByPlayer[player] = nil
		end
	end
	local function bindCharacterDeath(player, character)
		disconnectPlayerDeath(player)
		local generation = deathBindGenerationByPlayer[player]
		task.spawn(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
				or character:WaitForChild("Humanoid", MultiplayerConfig.CharacterDependencyTimeoutSeconds)
			local root = character:FindFirstChild("HumanoidRootPart")
				or character:WaitForChild("HumanoidRootPart", MultiplayerConfig.CharacterDependencyTimeoutSeconds)
			if isDestroyed or generation ~= deathBindGenerationByPlayer[player]
				or player.Character ~= character or not humanoid or not humanoid:IsA("Humanoid")
				or not root or not root:IsA("BasePart") then return end
			deathConnectionsByPlayer[player] = humanoid.Died:Connect(function()
				if isDestroyed or player.Character ~= character then return end
				local context = character:GetAttribute("BLIKK_CharacterContext")
					or player:GetAttribute("BLIKK_CharacterContext")
				local matchId = character:GetAttribute("BLIKK_CharacterMatchId")
					or player:GetAttribute("BLIKK_CharacterMatchId")
				if context ~= "MovementLab" and type(matchId) ~= "string" then return end
				self:PlayAt("PlayerDeath", root)
			end)
		end)
	end
	local function bindPlayer(player)
		unbindPlayer(player)
		characterAddedConnectionsByPlayer[player] = player.CharacterAdded:Connect(function(character)
			bindCharacterDeath(player, character)
		end)
		if player.Character then bindCharacterDeath(player, player.Character) end
	end
	for _, player in Players:GetPlayers() do bindPlayer(player) end
	table.insert(connections, Players.PlayerAdded:Connect(bindPlayer))
	table.insert(connections, Players.PlayerRemoving:Connect(unbindPlayer))
	table.insert(connections, loadingScreenController.FightPresented.Event:Connect(function()
		self:Play("FightStart")
	end))
end

function SoundEffectsController:Destroy()
	if isDestroyed then return end
	isDestroyed = true
	slashGeneration += 1
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for player, connection in characterAddedConnectionsByPlayer do
		connection:Disconnect()
		deathBindGenerationByPlayer[player] = (deathBindGenerationByPlayer[player] or 0) + 1
	end
	for _, connection in deathConnectionsByPlayer do connection:Disconnect() end
	table.clear(characterAddedConnectionsByPlayer)
	table.clear(deathConnectionsByPlayer)
	table.clear(deathBindGenerationByPlayer)
	if soundFolder then soundFolder:Destroy(); soundFolder = nil end
	table.clear(soundsByKey)
	table.clear(disabledKeys)
	table.clear(lastPlayedAtByKey)
end

return SoundEffectsController
