local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Movement.TechniqueConfig)

local Controller = {}
Controller.AirSlashAccepted = Instance.new("BindableEvent")
Controller.AirSlashCancelledToBlock = Instance.new("BindableEvent")
Controller.ButterflyCandidate = Instance.new("BindableEvent")
Controller.ButterflyChainCandidate = Instance.new("BindableEvent")
Controller.ButterflyChainBroken = Instance.new("BindableEvent")
Controller.WallButterflyCandidate = Instance.new("BindableEvent")
Controller.WallChainCandidate = Instance.new("BindableEvent")
Controller.WallChainBroken = Instance.new("BindableEvent")

local player = Players.LocalPlayer
local character
local humanoid
local airborneSequence = false
local lastJumpAt = -math.huge
local lastSlashAt = -math.huge
local lastCancelAt = -math.huge
local lastLandingAt = -math.huge
local lastWallJumpAt = -math.huge
local candidateCount = 0
local wallJumpCount = 0
local generation = 0
local lastRejectionReason = ""
local lastCancelDelta = -1
local movementState = "Grounded"
local wallState = "None"
local isInitialised = false
local diedConnection

local cancelConfig = Config.CancelProfiles.TrainingKatana
local rhythmConfig = Config.Butterfly

local function diagnose(message)
	if rhythmConfig.DiagnosticsEnabled then print("[BLIKK RHYTHM] " .. message) end
end

local function publishTelemetry()
	if not rhythmConfig.DiagnosticsEnabled or not character then return end
	character:SetAttribute("BLIKK_AirborneSequence", airborneSequence)
	character:SetAttribute("BLIKK_ButterflyCandidates", candidateCount)
	character:SetAttribute("BLIKK_WallJumpCount", wallJumpCount)
	character:SetAttribute("BLIKK_LastSlashTime", lastSlashAt)
	character:SetAttribute("BLIKK_LastBlockCancelTime", lastCancelAt)
	character:SetAttribute("BLIKK_LastCancelDelta", lastCancelDelta)
	character:SetAttribute("BLIKK_MovementState", movementState)
	character:SetAttribute("BLIKK_TelemetryWallState", wallState)
	character:SetAttribute("BLIKK_TelemetryAirborne", humanoid and humanoid.FloorMaterial == Enum.Material.Air or false)
	character:SetAttribute("BLIKK_LastTechniqueRejection", lastRejectionReason)
end

local function breakChain(reason, wallRelated)
	if candidateCount > 0 then Controller.ButterflyChainBroken:Fire(reason, candidateCount) end
	if wallRelated and wallJumpCount > 0 then Controller.WallChainBroken:Fire(reason, wallJumpCount) end
	airborneSequence = false
	candidateCount = 0
	wallJumpCount = 0
	lastSlashAt = -math.huge
	lastCancelAt = -math.huge
	lastRejectionReason = reason
	publishTelemetry()
end

local function isAirEligible(now)
	return airborneSequence
		and ((humanoid and humanoid.FloorMaterial == Enum.Material.Air)
			or now - lastLandingAt <= cancelConfig.LandingForgivenessSeconds)
end

local function rejectCandidate(reason)
	if candidateCount > 0 then
		breakChain(reason, wallJumpCount > 0)
	else
		lastRejectionReason = reason
		publishTelemetry()
	end
end

local function acceptAirSlash(timestamp)
	if candidateCount > 0 and timestamp - lastCancelAt > rhythmConfig.ChainMaximumGapSeconds then
		breakChain("chain gap", wallJumpCount > 0)
		airborneSequence = humanoid and humanoid.FloorMaterial == Enum.Material.Air or false
	end
	if timestamp - lastCancelAt < cancelConfig.RepeatedSequenceLockoutSeconds then
		lastRejectionReason = "sequence lockout"
		return
	end
	lastSlashAt = timestamp
	Controller.AirSlashAccepted:Fire(timestamp)
	diagnose(string.format("air slash %.3f", timestamp))
	publishTelemetry()
end

local function handleCancel(timestamp)
	local delta = timestamp - lastSlashAt
	if not isAirEligible(timestamp) then rejectCandidate("not airborne"); return end
	if delta < 0 or delta > rhythmConfig.CandidateMaximumSeconds then rejectCandidate("cancel delta"); return end
	if timestamp - lastCancelAt < cancelConfig.RepeatedSequenceLockoutSeconds then rejectCandidate("sequence lockout"); return end
	lastCancelAt = timestamp
	lastCancelDelta = delta
	candidateCount += 1
	lastRejectionReason = ""
	Controller.AirSlashCancelledToBlock:Fire(timestamp, delta)
	Controller.ButterflyCandidate:Fire(candidateCount, delta)
	if candidateCount > 1 then Controller.ButterflyChainCandidate:Fire(candidateCount, timestamp - lastJumpAt) end
	local wallContinuation = timestamp - lastWallJumpAt <= rhythmConfig.WallContinuationSeconds
	if wallContinuation then
		Controller.WallButterflyCandidate:Fire(candidateCount, wallJumpCount)
		if candidateCount > 1 then Controller.WallChainCandidate:Fire(candidateCount, wallJumpCount) end
	end
	diagnose(string.format("candidate=%d cancel=%.3f wall=%s", candidateCount, delta, tostring(wallContinuation)))
	publishTelemetry()
end

local function bindCharacter(nextCharacter)
	generation += 1
	breakChain("character replaced", true)
	if diedConnection then diedConnection:Disconnect(); diedConnection = nil end
	character = nextCharacter
	humanoid = character:WaitForChild("Humanoid")
	diedConnection = humanoid.Died:Connect(function() generation += 1; breakChain("death", true) end)
end

function Controller:GetTelemetry()
	return {
		AirborneSequence = airborneSequence, LastJumpAt = lastJumpAt, LastSlashAt = lastSlashAt,
		LastCancelAt = lastCancelAt, CandidateCount = candidateCount, WallJumpCount = wallJumpCount,
		LastRejectionReason = lastRejectionReason,
	}
end

function Controller:Init(inputManager, movementEngine, meleeController, wallController, fighterController)
	if isInitialised then return end
	isInitialised = true
	movementEngine.JumpAccepted.Event:Connect(function(timestamp, wasAirborne)
		lastJumpAt = timestamp
		movementState = "Airborne"
		if not wasAirborne then airborneSequence = true; candidateCount = 0; wallJumpCount = 0 end
		if timestamp - lastSlashAt <= cancelConfig.AirActionForgivenessSeconds then acceptAirSlash(lastSlashAt) end
		publishTelemetry()
	end)
	movementEngine.Landed.Event:Connect(function(timestamp)
		lastLandingAt = timestamp
		movementState = "Grounded"
		generation += 1
		local landingGeneration = generation
		task.delay(cancelConfig.LandingForgivenessSeconds, function()
			if generation == landingGeneration and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then breakChain("landed", false) end
		end)
	end)
	movementEngine.DashStarted.Event:Connect(function(_, _, grounded) movementState = if grounded then "GroundDash" else "AirDash"; publishTelemetry() end)
	movementEngine.DashEnded.Event:Connect(function(_, _, grounded) movementState = if grounded then "Grounded" else "Airborne"; publishTelemetry() end)
	meleeController.TechniqueHook.Event:Connect(function(hook, timestamp, airborne)
		if hook == "SlashAccepted" then
			lastSlashAt = timestamp
			if airborne or timestamp - lastJumpAt <= cancelConfig.AirActionForgivenessSeconds then acceptAirSlash(timestamp) end
		elseif hook == "SlashCancelledToBlock" then handleCancel(timestamp) end
	end)
	wallController.WallJumped.Event:Connect(function(timestamp)
		airborneSequence = true
		lastWallJumpAt = timestamp
		wallJumpCount += 1
		generation += 1
		publishTelemetry()
	end)
	wallController.StateChanged.Event:Connect(function(nextState)
		wallState = nextState
		if nextState ~= "None" then movementState = nextState end
		publishTelemetry()
	end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled) if not enabled then generation += 1; breakChain("gameplay disabled", true) end end)
	inputManager.SuppressionChanged.Event:Connect(function(suppressed) if suppressed then generation += 1; breakChain("input suppressed", true) end end)
	fighterController.LoadoutChanged.Event:Connect(function(changeType) if changeType == "ActiveWeaponSlot" then generation += 1; breakChain("weapon switched", true) end end)
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(removingCharacter) if removingCharacter == character then generation += 1; breakChain("character removing", true); if diedConnection then diedConnection:Disconnect(); diedConnection = nil end; character = nil; humanoid = nil end end)
	if player.Character then bindCharacter(player.Character) end
end

return Controller
