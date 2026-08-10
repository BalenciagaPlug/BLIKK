local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatFeedbackConfig = require(ReplicatedStorage.Shared.Combat.CombatFeedbackConfig)
local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local CombatFeedbackController = {}

local player = Players.LocalPlayer
local isInitialised = false
local isDestroyed = false
local screenGui = nil
local hitmarkerLines = {}
local damageNumberPool = {}
local remoteConnections = {}
local updateConnection = nil
local generationConnection = nil
local destroyingConnection = nil
local markerStartedAt = -math.huge
local markerColor = CombatFeedbackConfig.Colors.Mixed
local soundEffectsController = nil
local hasWarnedMalformed = false
local acceptedSpawnGeneration = nil
local lastAcceptedSequences = { Firearm = 0, Melee = 0 }

local VALID_TARGET_KINDS = {
	Player = true,
	PracticeDummy = true,
}

local function finiteNumber(value)
	return type(value) == "number" and value == value
		and value > -math.huge and value < math.huge
end

local function finiteInteger(value)
	return finiteNumber(value) and value % 1 == 0
end

local function finiteVector(value)
	if typeof(value) ~= "Vector3" then return false end
	local limit = CombatFeedbackConfig.Payload.MaximumWorldCoordinateMagnitude
	return finiteNumber(value.X) and finiteNumber(value.Y) and finiteNumber(value.Z)
		and math.abs(value.X) <= limit and math.abs(value.Y) <= limit
		and math.abs(value.Z) <= limit
end

local function warnMalformedOnce()
	if hasWarnedMalformed then return end
	hasWarnedMalformed = true
	warn("[BLIKK COMBAT FEEDBACK] Ignored a malformed or stale server hit confirmation.")
end

local function validateDamageResult(result, seenTargets, operation)
	if type(result) ~= "table" then return false end
	local payloadConfig = CombatFeedbackConfig.Payload
	local maximumDamage = if operation == "Melee"
		then payloadConfig.MaximumMeleeDamagePerTarget
		else payloadConfig.MaximumDamagePerTarget
	local validContact = if operation == "Melee"
		then finiteInteger(result.ContactCount) and result.ContactCount == 1
		else finiteInteger(result.PelletHits) and result.PelletHits >= 1
			and result.PelletHits <= payloadConfig.MaximumPelletHitsPerTarget
	if not VALID_TARGET_KINDS[result.TargetKind]
		or type(result.TargetId) ~= "string" or #result.TargetId < 1
		or #result.TargetId > payloadConfig.MaximumTargetIdLength
		or seenTargets[result.TargetKind .. ":" .. result.TargetId]
		or not validContact
		or not finiteNumber(result.RawDamage) or result.RawDamage < 0
		or result.RawDamage > maximumDamage
		or not finiteNumber(result.ArmourDamage) or result.ArmourDamage < 0
		or result.ArmourDamage > maximumDamage
		or not finiteNumber(result.HealthDamage) or result.HealthDamage < 0
		or result.HealthDamage > maximumDamage
		or not finiteNumber(result.AppliedDamage) or result.AppliedDamage <= 0
		or result.AppliedDamage > maximumDamage
		or math.abs(result.AppliedDamage - result.ArmourDamage - result.HealthDamage)
			> payloadConfig.DamageEqualityTolerance
		or not finiteVector(result.WorldPosition)
		or type(result.Eliminated) ~= "boolean" then return false end
	seenTargets[result.TargetKind .. ":" .. result.TargetId] = true
	return true
end

local function validatePayload(payload, operation)
	if type(payload) ~= "table" or payload.Operation ~= operation or payload.Accepted ~= true
		or not finiteInteger(payload.Sequence) or payload.Sequence <= 0
		or not finiteInteger(payload.SpawnGeneration)
		or payload.SpawnGeneration ~= player:GetAttribute("BLIKK_SpawnGeneration")
		or type(payload.HitResults) ~= "table" then return false end
	local maximumResults = if operation == "Melee"
		then CombatFeedbackConfig.Payload.MaximumMeleeResultsPerSwing
		else CombatFeedbackConfig.Payload.MaximumResultsPerShot
	local count = 0
	for key in payload.HitResults do
		if not finiteInteger(key) or key < 1 or key > maximumResults then return false end
		count += 1
	end
	if count > maximumResults then return false end
	local seenTargets = {}
	for index = 1, count do
		if not validateDamageResult(payload.HitResults[index], seenTargets, operation) then return false end
	end
	return true
end

local function colorHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end

local function selectDamageColor(result)
	local colors = CombatFeedbackConfig.Colors
	if result.Eliminated then return colors.Elimination end
	if result.ArmourDamage > 0 and result.HealthDamage > 0 then return colors.Mixed end
	if result.HealthDamage > 0 then return colors.Health end
	return colors.Armour
end

local function formatBreakdown(result)
	local parts = {}
	local colors = CombatFeedbackConfig.Colors
	if result.ArmourDamage > 0 then
		table.insert(parts, string.format(
			'<font color="%s">%d AP</font>',
			colorHex(colors.Armour),
			math.round(result.ArmourDamage)
		))
	end
	if result.HealthDamage > 0 then
		table.insert(parts, string.format(
			'<font color="%s">%d HP</font>',
			colorHex(colors.Health),
			math.round(result.HealthDamage)
		))
	end
	return table.concat(parts, "  //  ")
end

local function createDamageNumber(parent, index)
	local config = CombatFeedbackConfig.DamageNumber
	local frame = Instance.new("Frame")
	frame.Name = "DamageNumber" .. index
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(config.SizePixels.X, config.SizePixels.Y)
	frame.Visible = false
	frame.Parent = parent

	local total = Instance.new("TextLabel")
	total.Name = "Total"
	total.BackgroundTransparency = 1
	total.Size = UDim2.new(1, 0, 0, 28)
	total.Font = Enum.Font.Code
	total.TextSize = config.TotalTextSizePixels
	total.TextStrokeColor3 = CombatFeedbackConfig.Colors.Shadow
	total.TextStrokeTransparency = 0.15
	total.Parent = frame

	local breakdown = Instance.new("TextLabel")
	breakdown.Name = "Breakdown"
	breakdown.BackgroundTransparency = 1
	breakdown.Position = UDim2.fromOffset(0, 27)
	breakdown.Size = UDim2.new(1, 0, 0, 18)
	breakdown.Font = Enum.Font.Code
	breakdown.RichText = true
	breakdown.TextColor3 = CombatFeedbackConfig.Colors.Mixed
	breakdown.TextSize = config.BreakdownTextSizePixels
	breakdown.TextStrokeColor3 = CombatFeedbackConfig.Colors.Shadow
	breakdown.TextStrokeTransparency = 0.2
	breakdown.Parent = frame

	return {
		Active = false,
		StartedAt = 0,
		WorldPosition = Vector3.zero,
		Frame = frame,
		Total = total,
		Breakdown = breakdown,
	}
end

local function createHitmarkerLine(parent, name, x, y, rotation)
	local config = CombatFeedbackConfig.Hitmarker
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = markerColor
	line.BackgroundTransparency = 1
	line.BorderSizePixel = 0
	line.Position = UDim2.new(0.5, x, 0.5, y)
	line.Rotation = rotation
	line.Size = UDim2.fromOffset(config.LineLengthPixels, config.LineThicknessPixels)
	line.Parent = parent
	table.insert(hitmarkerLines, line)
end

local function createInterface()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then error("[BLIKK COMBAT FEEDBACK] PlayerGui unavailable", 0) end
	local existing = playerGui:FindFirstChild(CombatFeedbackConfig.ScreenGui.Name)
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = CombatFeedbackConfig.ScreenGui.Name
	gui.DisplayOrder = CombatFeedbackConfig.ScreenGui.DisplayOrder
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screenGui = gui

	local hitmarker = CombatFeedbackConfig.Hitmarker
	local offset = (hitmarker.CenterGapPixels + hitmarker.LineLengthPixels * 0.5) / math.sqrt(2)
	createHitmarkerLine(gui, "UpperLeft", -offset, -offset, 45)
	createHitmarkerLine(gui, "UpperRight", offset, -offset, -45)
	createHitmarkerLine(gui, "LowerLeft", -offset, offset, -45)
	createHitmarkerLine(gui, "LowerRight", offset, offset, 45)

	for index = 1, CombatFeedbackConfig.DamageNumber.PoolSize do
		damageNumberPool[index] = createDamageNumber(gui, index)
	end
end

local function triggerDamageNumber(result, now)
	local selected = nil
	for _, record in damageNumberPool do
		if not record.Active then selected = record; break end
		if not selected or record.StartedAt < selected.StartedAt then selected = record end
	end
	if not selected then return end
	selected.Active = true
	selected.StartedAt = now
	selected.WorldPosition = result.WorldPosition
	selected.Total.Text = tostring(math.round(result.AppliedDamage))
	selected.Total.TextColor3 = selectDamageColor(result)
	selected.Total.TextTransparency = 0
	selected.Total.TextStrokeTransparency = 0.15
	selected.Breakdown.Text = formatBreakdown(result)
	selected.Breakdown.TextTransparency = 0
	selected.Breakdown.TextStrokeTransparency = 0.2
	selected.Frame.Visible = true
end

local function triggerHitmarker(results, now)
	local hasDamage = false
	local hasHealthDamage = false
	local hasElimination = false
	for _, result in results do
		hasDamage = hasDamage or result.AppliedDamage > 0
		hasHealthDamage = hasHealthDamage or result.HealthDamage > 0
		hasElimination = hasElimination or result.Eliminated
	end
	if not hasDamage then return end
	local colors = CombatFeedbackConfig.Colors
	markerColor = if hasElimination then colors.Elimination
		elseif hasHealthDamage then colors.Health else colors.Armour
	markerStartedAt = now
	for _, line in hitmarkerLines do
		line.BackgroundColor3 = markerColor
		line.BackgroundTransparency = 0
	end
end

local function handleConfirmation(payload)
	if isDestroyed then return end
	if type(payload) ~= "table" or payload.Accepted ~= true then return end
	local operation = payload.Operation
	if operation ~= "Fire" and operation ~= "Melee" and operation ~= "ReloadAccepted" then return end
	if (operation == "Fire" or operation == "Melee") and not validatePayload(payload, operation) then
		warnMalformedOnce()
		return
	elseif operation == "ReloadAccepted" and (
		not finiteInteger(payload.Sequence) or payload.Sequence <= 0
		or not finiteInteger(payload.SpawnGeneration)
		or payload.SpawnGeneration ~= player:GetAttribute("BLIKK_SpawnGeneration")
		or payload.Slot ~= "Primary1" and payload.Slot ~= "Primary2"
	) then
		warnMalformedOnce()
		return
	end
	if acceptedSpawnGeneration ~= payload.SpawnGeneration then
		acceptedSpawnGeneration = payload.SpawnGeneration
		lastAcceptedSequences.Firearm = 0
		lastAcceptedSequences.Melee = 0
	end
	local sequenceChannel = if operation == "Melee" then "Melee" else "Firearm"
	if payload.Sequence <= lastAcceptedSequences[sequenceChannel] then return end
	lastAcceptedSequences[sequenceChannel] = payload.Sequence
	if operation == "ReloadAccepted" then
		soundEffectsController:Play("ReloadInitiated")
		return
	end
	local now = os.clock()
	for _, result in payload.HitResults do triggerDamageNumber(result, now) end
	triggerHitmarker(payload.HitResults, now)
	local appliedDamage = 0
	local eliminatedPracticeDummyPosition = nil
	for _, result in payload.HitResults do
		appliedDamage += result.AppliedDamage
		if result.TargetKind == "PracticeDummy" and result.Eliminated then
			eliminatedPracticeDummyPosition = result.WorldPosition
		end
	end
	if appliedDamage > 0 then
		soundEffectsController:Play(if operation == "Melee" then "MeleeHitConfirm" else "FirearmHitConfirm")
	end
	if eliminatedPracticeDummyPosition then
		soundEffectsController:PlayAtPosition("PracticeDummyDeath", eliminatedPracticeDummyPosition)
	end
end

local function updateDamageNumbers(now, camera)
	local config = CombatFeedbackConfig.DamageNumber
	local viewportSize = camera.ViewportSize
	local center = viewportSize * 0.5
	for _, record in damageNumberPool do
		if not record.Active then continue end
		local elapsed = now - record.StartedAt
		if elapsed >= config.LifetimeSeconds then
			record.Active = false
			record.Frame.Visible = false
			continue
		end
		local projected, onScreen = camera:WorldToViewportPoint(record.WorldPosition)
		local x = projected.X + config.InitialOffsetPixels.X
		local y = projected.Y + config.InitialOffsetPixels.Y
		local fromCenter = Vector2.new(x, y) - center
		if fromCenter.Magnitude < config.CrosshairClearancePixels then
			x = center.X + config.CrosshairClearancePixels
		end
		local margin = config.OffscreenMarginPixels
		local visible = onScreen and projected.Z > 0
			and x >= margin and x <= viewportSize.X - margin
			and y >= margin and y <= viewportSize.Y - margin
		record.Frame.Visible = visible
		if visible then
			local alpha = math.clamp(elapsed / config.LifetimeSeconds, 0, 1)
			record.Frame.Position = UDim2.fromOffset(
				x,
				y - config.RiseDistancePixels * alpha
			)
			record.Total.TextTransparency = alpha
			record.Total.TextStrokeTransparency = 0.15 + 0.85 * alpha
			record.Breakdown.TextTransparency = alpha
			record.Breakdown.TextStrokeTransparency = 0.2 + 0.8 * alpha
		end
	end
end

local function updateHitmarker(now)
	local config = CombatFeedbackConfig.Hitmarker
	local elapsed = now - markerStartedAt
	local transparency = 1
	if elapsed >= 0 and elapsed < config.VisibleDurationSeconds then
		transparency = 0
	elseif elapsed < config.VisibleDurationSeconds + config.FadeDurationSeconds then
		transparency = math.clamp(
			(elapsed - config.VisibleDurationSeconds) / config.FadeDurationSeconds,
			0,
			1
		)
	end
	for _, line in hitmarkerLines do line.BackgroundTransparency = transparency end
end

function CombatFeedbackController:Init(soundEffectsControllerValue)
	if isInitialised then return end
	isInitialised = true
	isDestroyed = false
	soundEffectsController = soundEffectsControllerValue
	createInterface()
	local remotes = ReplicatedStorage:WaitForChild(
		"BLIKKRemotes",
		MultiplayerConfig.RemoteLookupTimeoutSeconds
	)
	local firearmResult = remotes and remotes:WaitForChild(
		"FirearmResult",
		MultiplayerConfig.RemoteLookupTimeoutSeconds
	)
	if not firearmResult then error("[BLIKK COMBAT FEEDBACK] FirearmResult unavailable", 0) end
	table.insert(remoteConnections, firearmResult.OnClientEvent:Connect(handleConfirmation))
	local meleeResult = remotes:WaitForChild("MeleeResult", MultiplayerConfig.RemoteLookupTimeoutSeconds)
	if not meleeResult then error("[BLIKK COMBAT FEEDBACK] MeleeResult unavailable", 0) end
	table.insert(remoteConnections, meleeResult.OnClientEvent:Connect(handleConfirmation))
	updateConnection = RunService.RenderStepped:Connect(function()
		if isDestroyed then return end
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local now = os.clock()
		updateDamageNumbers(now, camera)
		updateHitmarker(now)
	end)
	generationConnection = player:GetAttributeChangedSignal("BLIKK_SpawnGeneration"):Connect(function()
		acceptedSpawnGeneration = player:GetAttribute("BLIKK_SpawnGeneration")
		lastAcceptedSequences.Firearm = 0
		lastAcceptedSequences.Melee = 0
		for _, record in damageNumberPool do
			record.Active = false
			record.Frame.Visible = false
		end
		markerStartedAt = -math.huge
	end)
	destroyingConnection = script.Destroying:Connect(function()
		CombatFeedbackController:Destroy()
	end)
end

function CombatFeedbackController:Destroy()
	if isDestroyed then return end
	isDestroyed = true
	for _, connection in remoteConnections do connection:Disconnect() end
	table.clear(remoteConnections)
	if updateConnection then updateConnection:Disconnect(); updateConnection = nil end
	if generationConnection then generationConnection:Disconnect(); generationConnection = nil end
	if destroyingConnection then destroyingConnection:Disconnect(); destroyingConnection = nil end
	soundEffectsController = nil
	if screenGui then screenGui:Destroy(); screenGui = nil end
	table.clear(hitmarkerLines)
	table.clear(damageNumberPool)
end

return CombatFeedbackController
