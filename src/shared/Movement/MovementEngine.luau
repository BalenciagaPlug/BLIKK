local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActionBuffer = require(ReplicatedStorage.Shared.Input.ActionBuffer)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)
local MovementConfig = require(script.Parent.MovementConfig)
local WallConfig = require(script.Parent.TechniqueConfig).Wall

local MovementEngine = {}
MovementEngine.DashStarted = Instance.new("BindableEvent")
MovementEngine.DashUpdated = Instance.new("BindableEvent")
MovementEngine.DashEnded = Instance.new("BindableEvent")
MovementEngine.JumpAccepted = Instance.new("BindableEvent")
MovementEngine.Landed = Instance.new("BindableEvent")
MovementEngine.WallStateChanged = Instance.new("BindableEvent")
MovementEngine.WallJumped = Instance.new("BindableEvent")

local dashConfig = MovementConfig.Dash
local jumpConfig = MovementConfig.Jump
local directions = {
	Forward = Vector2.new(0, 1),
	Backward = Vector2.new(0, -1),
	Left = Vector2.new(-1, 0),
	Right = Vector2.new(1, 0),
}

local isInitialised = false
local gameplayEnabled = true
local inputSuppressed = false
local airDashCount = 0
local lastDashTime = -math.huge
local lastGroundedAt = -math.huge
local lastDirectionPress = {}
local generation = 0
local humanoid
local rootPart
local character
local stateConnection
local cameraController
local heldDirections = {}
local dashState
local movementState = "AirborneFree"
local movementStateStartedAt = 0
local characterHeightStuds = 5.5
local characterHorizontalHalfExtentStuds = 1
local wallContact
local lastWallContactAt = -math.huge
local wallRun
local lastWall
local lastWallNormal = Vector3.zero
local lastWallPoint = Vector3.zero
local lastWallActionAt = -math.huge
local hasSeparatedFromLastWall = false
local returnDashExpiresAt = -math.huge
local returnDashAvailable = false

local function diagnose(message)
	if dashConfig.Diagnostics.Enabled or WallConfig.DiagnosticsEnabled then
		print("[BLIKK MOVEMENT] " .. message)
	end
end

local function isWallState(state)
	return state == "WallApproach"
		or state == "VerticalWallRun"
		or state == "HorizontalWallRun"
		or state == "WallJumpRecovery"
		or state == "WallCancelFreedom"
		or state == "RecontactLocked"
end

local function setMovementState(nextState)
	if movementState == nextState then return end
	local previousState = movementState
	movementState = nextState
	movementStateStartedAt = os.clock()
	if character and WallConfig.DiagnosticsEnabled then
		character:SetAttribute("BLIKK_MovementState", nextState)
	end
	if isWallState(nextState) or isWallState(previousState) then
		local contact = wallContact
		MovementEngine.WallStateChanged:Fire(
			nextState,
			contact and contact.Side or "Forward",
			contact and contact.Normal or lastWallNormal,
			contact and contact.Part or lastWall
		)
	end
end

local function measureCharacter()
	local highest = -math.huge
	local lowest = math.huge
	local maximumHorizontalSize = rootPart and math.max(rootPart.Size.X, rootPart.Size.Z) or 2
	for _, descendant in character:GetChildren() do
		if descendant:IsA("BasePart") and humanoid:GetBodyPartR15(descendant) ~= Enum.BodyPartR15.Unknown then
			highest = math.max(highest, descendant.Position.Y + descendant.Size.Y * 0.5)
			lowest = math.min(lowest, descendant.Position.Y - descendant.Size.Y * 0.5)
			if descendant.Name == "UpperTorso" or descendant.Name == "Torso" then
				maximumHorizontalSize = math.max(maximumHorizontalSize, descendant.Size.X, descendant.Size.Z)
			end
		end
	end
	if highest > lowest then characterHeightStuds = highest - lowest end
	characterHorizontalHalfExtentStuds = maximumHorizontalSize * 0.5
	if WallConfig.DiagnosticsEnabled then
		character:SetAttribute("BLIKK_CharacterHeightStuds", characterHeightStuds)
		character:SetAttribute("BLIKK_RootHeightStuds", rootPart.Size.Y)
		character:SetAttribute("BLIKK_FootToRootStuds", rootPart.Position.Y - lowest)
		character:SetAttribute("BLIKK_WallMinimumClearanceStuds", characterHorizontalHalfExtentStuds + WallConfig.ClearancePaddingStuds)
	end
end

local function flatDirection(action)
	local coefficient = directions[action]
	if not coefficient or not cameraController then return nil end
	local forward, right = cameraController:GetFlatBasis()
	local direction = right * coefficient.X + forward * coefficient.Y
	return if direction.Magnitude > 0 then direction.Unit else nil
end

function MovementEngine:GetMoveVector()
	if not cameraController then return Vector3.zero end
	local forward, right = cameraController:GetFlatBasis()
	local movement = Vector3.zero
	for action in heldDirections do
		local coefficient = directions[action]
		movement += right * coefficient.X + forward * coefficient.Y
	end
	return if movement.Magnitude > 1 then movement.Unit else movement
end

local function ownsHorizontalVelocity()
	return dashState ~= nil
		or movementState == "VerticalWallRun"
		or movementState == "HorizontalWallRun"
		or movementState == "WallJumpRecovery"
end

local function updateWalking()
	if not humanoid or humanoid.Health <= 0 then return end
	if ownsHorizontalVelocity() then
		humanoid:Move(Vector3.zero, false)
	else
		humanoid:Move(MovementEngine:GetMoveVector(), false)
	end
end

local function phaseAt(elapsed)
	local entryEnd = dashConfig.EntryDurationSeconds
	local travelEnd = entryEnd + dashConfig.TravelDurationSeconds
	if elapsed < entryEnd then
		return "Entry", elapsed / entryEnd, dashConfig.EntrySpeedMultiplier, dashConfig.PeakSpeedMultiplier
	elseif elapsed < travelEnd then
		return "Travel", (elapsed - entryEnd) / dashConfig.TravelDurationSeconds,
			dashConfig.PeakSpeedMultiplier, dashConfig.TravelEndSpeedMultiplier
	end
	return "Exit", (elapsed - travelEnd) / dashConfig.ExitDurationSeconds,
		dashConfig.TravelEndSpeedMultiplier, dashConfig.ExitMomentumRetention
end

local function curveArea()
	return dashConfig.EntryDurationSeconds * (dashConfig.EntrySpeedMultiplier + dashConfig.PeakSpeedMultiplier) / 2
		+ dashConfig.TravelDurationSeconds * (dashConfig.PeakSpeedMultiplier + dashConfig.TravelEndSpeedMultiplier) / 2
		+ dashConfig.ExitDurationSeconds * (dashConfig.TravelEndSpeedMultiplier + dashConfig.ExitMomentumRetention) / 2
end

local function finishDash(interrupted)
	local state = dashState
	if not state then return end
	dashState = nil
	if rootPart and state.StartPosition then
		diagnose(string.format(
			"%s end interrupted=%s displacement=%.2f duration=%.3f peak=%.2f",
			state.Action,
			tostring(interrupted),
			(rootPart.Position - state.StartPosition).Magnitude,
			state.Elapsed,
			state.PeakSpeed
		))
	end
	MovementEngine.DashEnded:Fire(state.Action, interrupted, state.Grounded)
	if state.Grounded then
		setMovementState("Grounded")
	elseif not isWallState(movementState) then
		setMovementState("AirborneFree")
	end
end

local function cancelOwnedMovement()
	finishDash(true)

	if wallContact then
		lastWall = wallContact.Part
		lastWallNormal = wallContact.Normal
		lastWallPoint = wallContact.Position
		lastWallActionAt = os.clock()
		hasSeparatedFromLastWall = false
	end

	wallContact = nil
	wallRun = nil
	lastWallContactAt = -math.huge
	returnDashAvailable = false
	returnDashExpiresAt = -math.huge

	local isGrounded = humanoid and humanoid.Health > 0
		and humanoid.FloorMaterial ~= Enum.Material.Air
	setMovementState(if isGrounded then "Grounded" else "AirborneFree")
end

local function stepDash(deltaTime)
	local state = dashState
	if not state then return end
	if state.Generation ~= generation or not rootPart or not rootPart.Parent or not humanoid or humanoid.Health <= 0 then
		finishDash(true)
		return
	end

	state.Elapsed += deltaTime
	local total = dashConfig.EntryDurationSeconds + dashConfig.TravelDurationSeconds + dashConfig.ExitDurationSeconds
	local phase, alpha, fromMultiplier, toMultiplier = phaseAt(math.min(state.Elapsed, total))
	local multiplier = fromMultiplier + (toMultiplier - fromMultiplier) * math.clamp(alpha, 0, 1)
	local speed = state.BaseSpeed * multiplier
	state.PeakSpeed = math.max(state.PeakSpeed, speed)
	local vertical = rootPart.AssemblyLinearVelocity.Y
	if state.Grounded and dashConfig.VerticalMomentumMode == "PreserveAtActivation" then
		vertical = state.VerticalVelocity
	end
	rootPart.AssemblyLinearVelocity = Vector3.new(state.Direction.X * speed, vertical, state.Direction.Z * speed)
	MovementEngine.DashUpdated:Fire(state.Action, phase, math.clamp(state.Elapsed / total, 0, 1))
	if state.Elapsed >= total then finishDash(false) end
end

local function tryDash(action, direction)
	if dashState or not gameplayEnabled or inputSuppressed or not humanoid or not rootPart or humanoid.Health <= 0 then
		diagnose("dash rejected // unavailable")
		return
	end
	if movementState == "VerticalWallRun" or movementState == "HorizontalWallRun" or movementState == "WallJumpRecovery" then
		diagnose("dash rejected // wall commitment")
		return
	end

	local now = os.clock()
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local cooldown = if grounded then dashConfig.GroundCooldownSeconds else dashConfig.AirCooldownSeconds
	if now - lastDashTime < cooldown then diagnose("dash rejected // cooldown") return end
	local isReturnDash = false
	if not grounded and airDashCount >= dashConfig.AirDashLimit then
		if not returnDashAvailable or now > returnDashExpiresAt then
			diagnose("dash rejected // air limit")
			return
		end
		isReturnDash = true
		returnDashAvailable = false
	else
		if not grounded then airDashCount += 1 end
	end

	lastDashTime = now
	local distance = if grounded then dashConfig.GroundDistanceStuds else dashConfig.AirDistanceStuds
	dashState = {
		Action = action,
		Direction = direction,
		Grounded = grounded,
		Elapsed = 0,
		BaseSpeed = distance / curveArea(),
		VerticalVelocity = rootPart.AssemblyLinearVelocity.Y,
		Generation = generation,
		StartPosition = rootPart.Position,
		PeakSpeed = 0,
		IsReturnDash = isReturnDash,
	}
	setMovementState(if grounded then "GroundDash" elseif isReturnDash then "WallReturnDash" else "AirDash")
	diagnose(string.format("%s start grounded=%s return=%s", action, tostring(grounded), tostring(isReturnDash)))
	MovementEngine.DashStarted:Fire(action, direction, grounded)
end

local function sameWall(contact)
	return lastWall == contact.Part and lastWallNormal:Dot(contact.Normal) >= WallConfig.SameWallNormalMatchDot
end

local function canRecontact(contact, now)
	if not sameWall(contact) then return true end
	local elapsed = now - lastWallActionAt
	local pointMoved = (contact.Position - lastWallPoint).Magnitude
	local horizontal = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)
	local reentrySpeed = -horizontal:Dot(contact.Normal)
	if character and WallConfig.DiagnosticsEnabled then
		character:SetAttribute("BLIKK_WallMovingBack", reentrySpeed >= WallConfig.SameWallMinimumReentrySpeedStudsPerSecond)
		character:SetAttribute("BLIKK_WallTimeSinceExit", now - lastWallActionAt)
	end
	return elapsed >= WallConfig.SameWallMinimumRecontactSeconds
		and hasSeparatedFromLastWall
		and pointMoved >= WallConfig.SameWallMinimumContactPointMovementStuds
		and reentrySpeed >= WallConfig.SameWallMinimumReentrySpeedStudsPerSecond
end

local function rememberWallAction(contact, now)
	lastWall = contact.Part
	lastWallNormal = contact.Normal
	lastWallPoint = contact.Position
	lastWallActionAt = now
	hasSeparatedFromLastWall = false
end

local function wallLaunch(now, exitKind, exitReason)
	if not wallContact or not rootPart then return end
	local exitedContact = wallContact
	local exitedRunKind = wallRun and wallRun.Kind or nil
	finishDash(true)
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local tangent = horizontal - exitedContact.Normal * horizontal:Dot(exitedContact.Normal)
	local movement = MovementEngine:GetMoveVector()
	local exitConfig
	if exitKind == "Automatic" then
		exitConfig = if exitedRunKind == "Horizontal"
			then WallConfig.AutomaticHorizontalExit
			else WallConfig.AutomaticVerticalExit
	end
	local outward = exitConfig and exitConfig.OutwardSpeedStudsPerSecond or WallConfig.OutwardSpeedStudsPerSecond
	local upward = exitConfig and exitConfig.UpwardSpeedStudsPerSecond or WallConfig.UpwardSpeedStudsPerSecond
	local tangentScale = exitConfig and exitConfig.TangentialRetentionScale or WallConfig.RetainedTangentialVelocityScale
	local launchHorizontal = exitedContact.Normal * outward + tangent * tangentScale
	if exitKind ~= "Automatic" then
		local movementTangent = movement - exitedContact.Normal * movement:Dot(exitedContact.Normal)
		launchHorizontal += movementTangent * WallConfig.DirectionalInfluenceStudsPerSecond
	end
	local minimumOutward = outward * WallConfig.MinimumOutwardRetentionScale
	if launchHorizontal:Dot(exitedContact.Normal) < minimumOutward then
		launchHorizontal += exitedContact.Normal * (minimumOutward - launchHorizontal:Dot(exitedContact.Normal))
	end
	rememberWallAction(exitedContact, now)
	wallRun = nil
	wallContact = nil
	lastWallContactAt = -math.huge
	setMovementState("WallJumpRecovery")
	rootPart.AssemblyLinearVelocity = Vector3.new(launchHorizontal.X, upward, launchHorizontal.Z)
	if character and WallConfig.DiagnosticsEnabled then
		character:SetAttribute("BLIKK_WallExitReason", exitReason)
		character:SetAttribute("BLIKK_WallExitImpulse", Vector3.new(launchHorizontal.X, upward, launchHorizontal.Z))
		character:SetAttribute("BLIKK_WallSeparated", false)
	end
	MovementEngine.WallJumped:Fire(now, lastWall, lastWallNormal, exitedContact.Side, exitKind == "Automatic")
end

local function classifyWallEntry()
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = horizontal.Magnitude
	if speed <= 0 then return "Standard" end
	local intoSpeed = math.max(0, -horizontal:Dot(wallContact.Normal))
	local tangent = horizontal + wallContact.Normal * intoSpeed
	local intoRatio = intoSpeed / speed
	local tangentRatio = tangent.Magnitude / speed
	if intoRatio >= WallConfig.HeadOnMinimumIntoWallRatio
		and tangentRatio <= WallConfig.HeadOnMaximumTangentRatio
		and intoSpeed >= WallConfig.HeadOnMinimumIntoWallSpeedStudsPerSecond then
		return "Vertical"
	end
	local angleFromPlane = math.deg(math.asin(math.clamp(intoRatio, 0, 1)))
	if angleFromPlane >= WallConfig.AngledMinimumDegreesFromWallPlane
		and angleFromPlane <= WallConfig.AngledMaximumDegreesFromWallPlane
		and tangentRatio >= WallConfig.AngledMinimumTangentRatio
		and intoSpeed >= WallConfig.AngledMinimumIntoWallSpeedStudsPerSecond
		and tangent.Magnitude >= WallConfig.AngledMinimumTangentSpeedStudsPerSecond then
		return "Horizontal"
	end
	return "Standard"
end

local function beginWallAction(now, entryJumpAt)
	if not wallContact or now - lastWallContactAt > WallConfig.ContactGraceSeconds then return false end
	if not canRecontact(wallContact, now) then
		setMovementState("RecontactLocked")
		diagnose("wall rejected // recontact evidence incomplete")
		return false
	end
	local classification = classifyWallEntry()
	if character and WallConfig.DiagnosticsEnabled then
		character:SetAttribute("BLIKK_WallClassification", classification)
		character:SetAttribute("BLIKK_WallRunEntryTimestamp", now)
		character:SetAttribute("BLIKK_WallJumpBufferTimestamp", entryJumpAt)
		character:SetAttribute("BLIKK_WallFreshExitJumpAccepted", false)
	end
	if classification == "Standard" then
		wallLaunch(now, "Standard", "StandardWallJump")
		return true
	end
	finishDash(true)
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local tangent = horizontal - wallContact.Normal * horizontal:Dot(wallContact.Normal)
	wallRun = {
		Kind = classification,
		StartedAt = now,
		StartHeight = rootPart.Position.Y,
		Tangent = tangent.Magnitude > 0 and tangent.Unit or Vector3.zero,
		EntryTangentSpeed = tangent.Magnitude,
		EntryJumpAt = entryJumpAt,
		Part = wallContact.Part,
		Normal = wallContact.Normal,
	}
	setMovementState(if classification == "Vertical" then "VerticalWallRun" else "HorizontalWallRun")
	diagnose("wall run accepted // " .. classification)
	return true
end

local function acceptGroundJump(now)
	ActionBuffer:Consume("Jump", jumpConfig.InputBufferSeconds, now)
	humanoid.Jump = true
	setMovementState("JumpRising")
	MovementEngine.JumpAccepted:Fire(now, false)
end

local function acceptBufferedWallJump(now)
	local buffered = ActionBuffer:Consume("Jump", WallConfig.JumpInputBufferSeconds, now)
	if not buffered then return false end
	local accepted = beginWallAction(now, buffered.Time)
	if accepted then MovementEngine.JumpAccepted:Fire(buffered.Time, true) end
	return accepted
end

local function stepWall(now)
	if lastWall and not hasSeparatedFromLastWall then
		local separation = (rootPart.Position - lastWallPoint):Dot(lastWallNormal)
		if separation >= WallConfig.SameWallMinimumSeparationStuds then
			hasSeparatedFromLastWall = true
			if character and WallConfig.DiagnosticsEnabled then character:SetAttribute("BLIKK_WallSeparated", true) end
		end
		if character and WallConfig.DiagnosticsEnabled then character:SetAttribute("BLIKK_WallMovingAway", separation > 0) end
	end
	if returnDashAvailable and now > returnDashExpiresAt then returnDashAvailable = false end
	if character and WallConfig.DiagnosticsEnabled then
		character:SetAttribute("BLIKK_WallReturnDashAvailable", returnDashAvailable)
		character:SetAttribute("BLIKK_WallReturnDashExpiry", returnDashExpiresAt)
		if lastWall then character:SetAttribute("BLIKK_WallTimeSinceExit", now - lastWallActionAt) end
	end

	if movementState == "WallApproach" then
		acceptBufferedWallJump(now)
		if now - lastWallContactAt > WallConfig.ContactGraceSeconds then setMovementState("AirborneFree") end
		return
	end
	if movementState ~= "VerticalWallRun" and movementState ~= "HorizontalWallRun" then
		if movementState == "WallJumpRecovery" and now - movementStateStartedAt >= WallConfig.RecoveryDurationSeconds then
			setMovementState("AirborneFree")
		end
		return
	end
	if not wallRun or not wallContact or now - lastWallContactAt > WallConfig.ContactGraceSeconds then
		wallLaunch(now, "Automatic", "ContactLost")
		return
	end
	if wallRun.Kind == "Vertical" and wallContact.HasOverheadClearance == false then
		wallLaunch(now, "Automatic", "CeilingBlocked")
		return
	end

	local runConfig = if wallRun.Kind == "Vertical" then WallConfig.VerticalRun else WallConfig.HorizontalRun
	local elapsed = now - wallRun.StartedAt
	local heightGain = rootPart.Position.Y - wallRun.StartHeight
	if elapsed >= runConfig.DurationSeconds or heightGain >= characterHeightStuds * runConfig.MaximumHeightCharacterScale then
		wallLaunch(now, "Automatic", if elapsed >= runConfig.DurationSeconds then "Duration" else "HeightCap")
		return
	end
	local minimumClearance = characterHorizontalHalfExtentStuds + WallConfig.ClearancePaddingStuds
	local wallDistance = (rootPart.Position - wallContact.Position):Dot(wallContact.Normal)
	if wallDistance > minimumClearance + WallConfig.ContactMaintenanceDistanceStuds then
		wallLaunch(now, "Automatic", "MaintenanceDistance")
		return
	end
	local alpha = math.clamp(elapsed / runConfig.DurationSeconds, 0, 1)
	local upward = runConfig.InitialUpwardSpeedStudsPerSecond
		+ (runConfig.FinalUpwardSpeedStudsPerSecond - runConfig.InitialUpwardSpeedStudsPerSecond) * alpha
	local tangentSpeed
	if wallRun.Kind == "Vertical" then
		tangentSpeed = wallRun.EntryTangentSpeed * runConfig.TangentialRetentionScale
	else
		tangentSpeed = math.max(
			wallRun.EntryTangentSpeed * runConfig.TangentialRetentionScale,
			runConfig.MinimumTangentialSpeedStudsPerSecond
		)
	end
	local normalSpeed
	local adhesionActive = wallDistance >= minimumClearance
	if wallDistance < minimumClearance then
		normalSpeed = math.min(
			(minimumClearance - wallDistance) * WallConfig.ClearanceCorrectionGain,
			WallConfig.MaximumClearanceCorrectionSpeedStudsPerSecond
		)
	else
		normalSpeed = -WallConfig.AdhesionSpeedStudsPerSecond
	end
	local horizontal = wallRun.Tangent * tangentSpeed + wallContact.Normal * normalSpeed
	rootPart.AssemblyLinearVelocity = Vector3.new(horizontal.X, upward, horizontal.Z)
	if character and WallConfig.DiagnosticsEnabled then
		character:SetAttribute("BLIKK_WallClassification", wallRun.Kind)
		character:SetAttribute("BLIKK_WallDistanceStuds", wallDistance)
		character:SetAttribute("BLIKK_WallNormalSpeed", normalSpeed)
		character:SetAttribute("BLIKK_WallTangentSpeed", tangentSpeed)
		character:SetAttribute("BLIKK_WallAdhesionActive", adhesionActive)
		character:SetAttribute("BLIKK_WallTimeSinceEntry", elapsed)
		character:SetAttribute("BLIKK_WallReturnDashAvailable", returnDashAvailable)
	end
end

local function heartbeat(deltaTime)
	if not humanoid or not rootPart or humanoid.Health <= 0 then return end
	local now = os.clock()
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if grounded then
		lastGroundedAt = now
	end
	if not gameplayEnabled or inputSuppressed then
		if dashState or isWallState(movementState) or movementState == "WallReturnDash" then
			cancelOwnedMovement()
		end
		return
	end
	if grounded and ActionBuffer:Consume("Jump", jumpConfig.InputBufferSeconds, now) then acceptGroundJump(now) end
	stepDash(deltaTime)
	if not dashState then stepWall(now) end
end

function MovementEngine:ReportWallContact(contact)
	if not gameplayEnabled or inputSuppressed or not humanoid or humanoid.Health <= 0 then return end
	if humanoid.FloorMaterial ~= Enum.Material.Air then return end
	local now = os.clock()
	if movementState == "VerticalWallRun" or movementState == "HorizontalWallRun" then
		if not wallRun or contact.Part ~= wallRun.Part or contact.Normal:Dot(wallRun.Normal) < WallConfig.SameWallNormalMatchDot then
			return
		end
		wallContact = contact
		lastWallContactAt = now
		return
	end
	if movementState ~= "AirborneFree"
		and movementState ~= "JumpRising"
		and movementState ~= "AirDash"
		and movementState ~= "WallReturnDash"
		and movementState ~= "WallApproach"
		and movementState ~= "RecontactLocked" then
		return
	end
	if sameWall(contact) and not hasSeparatedFromLastWall then
		if movementState == "AirborneFree" or movementState == "WallApproach" then setMovementState("RecontactLocked") end
		return
	end
	wallContact = contact
	lastWallContactAt = now
	if movementState ~= "WallApproach" then
		if canRecontact(contact, now) then
			setMovementState("WallApproach")
			acceptBufferedWallJump(now)
		else
			setMovementState("RecontactLocked")
		end
	end
end

function MovementEngine:ClearWallContact()
	-- Keep the last accepted sample through the configured grace window so one missed
	-- shape cast cannot strand a run or discard a buffered wall action.
end

function MovementEngine:ConfirmSlashAccepted(timestamp)
	if movementState ~= "WallJumpRecovery" then return false end
	if timestamp - movementStateStartedAt > WallConfig.SlashCancelWindowSeconds then return false end
	setMovementState("WallCancelFreedom")
	returnDashAvailable = true
	returnDashExpiresAt = timestamp + WallConfig.ReturnDashAvailabilitySeconds
	diagnose("wall recovery cancelled // return dash earned")
	return true
end

function MovementEngine:HandleAction(action, timestamp)
	local now = timestamp or os.clock()
	if action == "Jump" then
		if not humanoid or humanoid.Health <= 0 then return end
		if movementState == "VerticalWallRun" or movementState == "HorizontalWallRun" then
			ActionBuffer:Consume("Jump", WallConfig.JumpInputBufferSeconds, now)
			if wallRun and now - wallRun.EntryJumpAt >= WallConfig.MinimumFreshExitInputDelaySeconds then
				wallLaunch(now, "Manual", "FreshJump")
				MovementEngine.JumpAccepted:Fire(now, true)
				if character and WallConfig.DiagnosticsEnabled then character:SetAttribute("BLIKK_WallFreshExitJumpAccepted", true) end
			end
		elseif humanoid.FloorMaterial ~= Enum.Material.Air or now - lastGroundedAt <= jumpConfig.GroundedGraceSeconds then
			acceptGroundJump(now)
		else
			acceptBufferedWallJump(now)
		end
		return
	end
	if not directions[action] then return end
	heldDirections[action] = true
	local previous = lastDirectionPress[action]
	lastDirectionPress[action] = now
	if previous and now - previous <= dashConfig.DoubleTapWindowSeconds then
		local direction = flatDirection(action)
		if direction then tryDash(action, direction) end
	end
end

function MovementEngine:HandleActionEnded(action)
	if directions[action] then heldDirections[action] = nil end
end

function MovementEngine:GetState()
	return movementState
end

function MovementEngine:GetCharacterMetrics()
	return characterHeightStuds, rootPart and rootPart.Size.Y or 0, humanoid and humanoid.HipHeight or 0
end

function MovementEngine:BindCharacter(nextCharacter)
	generation += 1
	local bindGeneration = generation
	finishDash(true)
	if stateConnection then stateConnection:Disconnect() end
	stateConnection = nil
	wallContact, wallRun, lastWall = nil, nil, nil
	lastWallNormal, lastWallPoint = Vector3.zero, Vector3.zero
	lastWallContactAt, lastWallActionAt = -math.huge, -math.huge
	hasSeparatedFromLastWall = false
	returnDashAvailable, returnDashExpiresAt = false, -math.huge
	setMovementState("AirborneFree")
	character, humanoid, rootPart = nil, nil, nil
	local dependencyDeadline = os.clock() + MultiplayerConfig.CharacterDependencyTimeoutSeconds
	local nextHumanoid = nextCharacter:FindFirstChild("Humanoid")
		or nextCharacter:WaitForChild("Humanoid", math.max(0, dependencyDeadline - os.clock()))
	local nextRootPart = nextCharacter:FindFirstChild("HumanoidRootPart")
		or nextCharacter:WaitForChild("HumanoidRootPart", math.max(0, dependencyDeadline - os.clock()))
	local player = Players.LocalPlayer
	if bindGeneration ~= generation or player.Character ~= nextCharacter
		or not nextHumanoid or not nextHumanoid:IsA("Humanoid")
		or not nextRootPart or not nextRootPart:IsA("BasePart") then
		if bindGeneration == generation and player.Character == nextCharacter then
			warn("[BLIKK MOVEMENT] Character bind timed out waiting for required dependencies.")
		end
		return
	end
	character, humanoid, rootPart = nextCharacter, nextHumanoid, nextRootPart
	humanoid.WalkSpeed = MovementConfig.Ground.WalkSpeedStudsPerSecond
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = jumpConfig.HeightStuds
	airDashCount, lastDashTime, lastDirectionPress, heldDirections = 0, -math.huge, {}, {}
	wallContact, wallRun, lastWall = nil, nil, nil
	lastGroundedAt = if humanoid.FloorMaterial ~= Enum.Material.Air then os.clock() else -math.huge
	returnDashAvailable = false
	measureCharacter()
	setMovementState(if humanoid.FloorMaterial == Enum.Material.Air then "AirborneFree" else "Grounded")
	stateConnection = humanoid.StateChanged:Connect(function(_, newState)
		if bindGeneration ~= generation or character ~= nextCharacter then return end
		if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
			local wasAirborne = movementState ~= "Grounded"
			airDashCount = 0
			wallContact, wallRun, lastWall = nil, nil, nil
			returnDashAvailable = false
			finishDash(true)
			setMovementState("Grounded")
			if wasAirborne then MovementEngine.Landed:Fire(os.clock()) end
		elseif newState == Enum.HumanoidStateType.Freefall and movementState == "JumpRising" then
			setMovementState("AirborneFree")
		end
	end)
	character:SetAttribute("BLIKK_ClientMovementReady", true)
end

function MovementEngine:Init(inputManager, gameplayCamera)
	if isInitialised then return end
	isInitialised, cameraController = true, gameplayCamera
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(nextCharacter) self:BindCharacter(nextCharacter) end)
	player.CharacterRemoving:Connect(function(removingCharacter)
		if removingCharacter ~= character then return end
		generation += 1
		finishDash(true)
		if stateConnection then stateConnection:Disconnect(); stateConnection = nil end
		wallContact, wallRun, lastWall = nil, nil, nil
		lastWallNormal, lastWallPoint = Vector3.zero, Vector3.zero
		lastWallContactAt, lastWallActionAt = -math.huge, -math.huge
		hasSeparatedFromLastWall = false
		returnDashAvailable, returnDashExpiresAt = false, -math.huge
		setMovementState("AirborneFree")
		character, humanoid, rootPart = nil, nil, nil
		heldDirections, lastDirectionPress = {}, {}
		airDashCount, lastDashTime, lastGroundedAt = 0, -math.huge, -math.huge
	end)
	if player.Character then self:BindCharacter(player.Character) end
	inputManager.ActionBegan.Event:Connect(function(action, timestamp) self:HandleAction(action, timestamp) end)
	inputManager.ActionEnded.Event:Connect(function(action) self:HandleActionEnded(action) end)
	inputManager.GameplayEnabledChanged.Event:Connect(function(enabled)
		gameplayEnabled = enabled
		if not enabled then
			heldDirections, lastDirectionPress = {}, {}
			cancelOwnedMovement()
		end
	end)
	inputManager.SuppressionChanged.Event:Connect(function(suppressed)
		inputSuppressed = suppressed
		if suppressed then
			heldDirections, lastDirectionPress = {}, {}
			cancelOwnedMovement()
		end
	end)
	RunService.Heartbeat:Connect(heartbeat)
	RunService:BindToRenderStep("BLIKKSemanticWalking", Enum.RenderPriority.Input.Value + 1, updateWalking)
end

return MovementEngine
