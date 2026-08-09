local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Combat.FirearmPresentationConfig)
local FeedbackConfig = require(ReplicatedStorage.Shared.Combat.FirearmShotFeedbackConfig)

local FirearmAimRig = {}
local Rig = {}
Rig.__index = Rig

local FORWARD_COLOR = Color3.fromRGB(70, 145, 255)
local UP_COLOR = Color3.fromRGB(80, 220, 110)
local RIGHT_COLOR = Color3.fromRGB(235, 75, 75)
local STOCK_COLOR = Color3.fromRGB(255, 220, 70)
local TRIGGER_COLOR = Color3.fromRGB(255, 70, 220)
local FOREGRIP_COLOR = Color3.fromRGB(70, 235, 235)
local hasReportedDiagnostics = false

local function findBasePart(character, name)
	local instance = character:FindFirstChild(name)
	return if instance and instance:IsA("BasePart") then instance else nil
end

local function findAttachment(parent, name)
	local instance = parent and parent:FindFirstChild(name)
	return if instance and instance:IsA("Attachment") then instance else nil
end

local function attachmentDistance(part, firstName, secondName)
	local first = findAttachment(part, firstName)
	local second = findAttachment(part, secondName)
	return if first and second then (first.Position - second.Position).Magnitude else nil
end

local function createTarget(rootPart, name, owned)
	local target = Instance.new("Attachment")
	table.insert(owned, target)
	target.Name = name
	target:SetAttribute("BLIKK_FirearmAimOwned", true)
	target.Parent = rootPart
	return target
end

local function createControl(
	humanoid,
	name,
	chainRoot,
	endEffector,
	target,
	pole,
	priority,
	controlType,
	owned
)
	local control = Instance.new("IKControl")
	table.insert(owned, control)
	control.Name = name
	control:SetAttribute("BLIKK_FirearmAimOwned", true)
	control.Enabled = false
	control.Type = controlType
	control.ChainRoot = chainRoot
	control.EndEffector = endEffector
	control.Target = target
	control.Pole = pole
	control.Priority = priority
	control.SmoothTime = Config.AimIK.SmoothTimeSeconds
	control.Weight = Config.AimIK.Weight
	control.Parent = humanoid
	return control
end

local function finiteVector(vector)
	return typeof(vector) == "Vector3"
		and vector.X == vector.X
		and vector.Y == vector.Y
		and vector.Z == vector.Z
end

local function referenceWorldPosition(receiverWorld, reference)
	return (receiverWorld * reference).Position
end

local function heightFromBarrelLine(point, stock, muzzle, weaponUp)
	local barrel = muzzle - stock
	local barrelLengthSquared = barrel:Dot(barrel)
	if barrelLengthSquared < 0.000001 then return math.huge end
	local alpha = math.clamp((point - stock):Dot(barrel) / barrelLengthSquared, 0, 1)
	return (point - (stock + barrel * alpha)):Dot(weaponUp)
end

local function validateReceiverOrientation(
	receiverWorld,
	muzzleReference,
	stockReference,
	topReference,
	bottomReference,
	rightHandGrip,
	foregrip,
	expectedForward,
	expectedUp,
	worldUp
)
	local muzzle = referenceWorldPosition(receiverWorld, muzzleReference)
	local stock = referenceWorldPosition(receiverWorld, stockReference)
	local top = referenceWorldPosition(receiverWorld, topReference)
	local bottom = referenceWorldPosition(receiverWorld, bottomReference)
	local trigger = referenceWorldPosition(receiverWorld, rightHandGrip)
	local support = referenceWorldPosition(receiverWorld, foregrip)
	local forwardDelta = muzzle - stock
	local upDelta = top - bottom
	if forwardDelta.Magnitude < 0.000001 or upDelta.Magnitude < 0.000001 then
		return false, -1, -1, -1, -1, math.huge, math.huge, -1
	end
	local weaponForward = forwardDelta.Unit
	local weaponUp = upDelta.Unit
	local forwardDot = weaponForward:Dot(expectedForward)
	local upDot = weaponUp:Dot(expectedUp)
	local muzzleAhead = forwardDelta:Dot(expectedForward)
	local topAbove = upDelta:Dot(worldUp)
	local triggerHeight = heightFromBarrelLine(trigger, stock, muzzle, weaponUp)
	local foregripHeight = heightFromBarrelLine(support, stock, muzzle, weaponUp)
	local foregripAhead = (support - trigger):Dot(expectedForward)
	local validation = Config.OrientationValidation
	local passed = forwardDot >= validation.MinimumForwardDot
		and upDot >= validation.MinimumUpDot
		and muzzleAhead > 0
		and topAbove > 0
		and triggerHeight < 0
		and foregripHeight < 0
		and foregripAhead > 0
	return passed, forwardDot, upDot, muzzleAhead, topAbove,
		triggerHeight, foregripHeight, foregripAhead
end

FirearmAimRig.ValidateReceiverOrientation = validateReceiverOrientation

local function createDiagnosticPart(parent, name, color, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = if size.X == size.Y and size.Y == size.Z
		then Enum.PartType.Ball
		else Enum.PartType.Block
	part.Parent = parent
	return part
end

local function createDiagnostics(owned)
	if not Config.DiagnosticsEnabled then return nil end
	local diagnosticsConfig = Config.Diagnostics
	local markerSize = Vector3.one * diagnosticsConfig.MarkerSizeStuds
	local thickness = diagnosticsConfig.AxisThicknessStuds
	local axisLength = diagnosticsConfig.AxisLengthStuds
	local folder = Instance.new("Folder")
	folder.Name = "BLIKK_FirearmOrientationDiagnostics"
	folder:SetAttribute("BLIKK_FirearmAimOwned", true)
	folder.Parent = Workspace
	table.insert(owned, folder)
	return {
		Folder = folder,
		Stock = createDiagnosticPart(folder, "Stock", STOCK_COLOR, markerSize),
		Muzzle = createDiagnosticPart(folder, "Muzzle", FORWARD_COLOR, markerSize),
		Top = createDiagnosticPart(folder, "WeaponTop", UP_COLOR, markerSize),
		Bottom = createDiagnosticPart(folder, "WeaponBottom", Color3.fromRGB(35, 100, 50), markerSize),
		Trigger = createDiagnosticPart(folder, "TriggerGrip", TRIGGER_COLOR, markerSize),
		Foregrip = createDiagnosticPart(folder, "Foregrip", FOREGRIP_COLOR, markerSize),
		RightTarget = createDiagnosticPart(folder, "RightHandTarget", TRIGGER_COLOR, markerSize),
		LeftTarget = createDiagnosticPart(folder, "LeftHandTarget", FOREGRIP_COLOR, markerSize),
		RightPole = createDiagnosticPart(folder, "RightElbowPole", RIGHT_COLOR, markerSize),
		LeftPole = createDiagnosticPart(folder, "LeftElbowPole", FOREGRIP_COLOR, markerSize),
		ForwardAxis = createDiagnosticPart(
			folder,
			"CanonicalForward",
			FORWARD_COLOR,
			Vector3.new(thickness, thickness, axisLength)
		),
		UpAxis = createDiagnosticPart(
			folder,
			"CanonicalUp",
			UP_COLOR,
			Vector3.new(thickness, axisLength, thickness)
		),
		RightAxis = createDiagnosticPart(
			folder,
			"CanonicalRight",
			RIGHT_COLOR,
			Vector3.new(axisLength, thickness, thickness)
		),
	}
end

local function validateConfiguredGeometry()
	local attachments = Config.Attachments
	local sampleReport = ""
	for _, pitchDegrees in Config.OrientationValidation.PitchSamplesDegrees do
		local canonicalBasis = CFrame.Angles(math.rad(pitchDegrees), 0, 0)
		local receiverWorld = canonicalBasis * Config.GeometryToCanonical
		local passed, forwardDot, upDot, _, topAbove = validateReceiverOrientation(
			receiverWorld,
			attachments.MuzzleReference,
			attachments.StockReference,
			attachments.WeaponTopReference,
			attachments.WeaponBottomReference,
			attachments.RightHandGrip,
			attachments.Foregrip,
			canonicalBasis.LookVector,
			canonicalBasis.UpVector,
			Vector3.yAxis
		)
		if not passed then
			return false, string.format(
				"configured B-8 orientation failed at %.1f degrees (forwardDot=%.4f, upDot=%.4f)",
				pitchDegrees,
				forwardDot,
				upDot
			)
		end
		if Config.DiagnosticsEnabled and not hasReportedDiagnostics then
			sampleReport ..= string.format(
				"%+.0f degrees: forward=%.4f up=%.4f worldUp=%.4f; ",
				pitchDegrees,
				forwardDot,
				upDot,
				topAbove
			)
		end
	end
	return true, nil, sampleReport
end

local function updateDiagnostics(
	diagnostics,
	receiverWorld,
	canonicalReceiverWorld,
	muzzleReference,
	stockReference,
	topReference,
	bottomReference,
	rightHandGrip,
	foregrip,
	rightHandTarget,
	leftHandTarget,
	rightElbowPole,
	leftElbowPole
)
	if not diagnostics then return end
	local axisLength = Config.Diagnostics.AxisLengthStuds
	diagnostics.Stock.CFrame = receiverWorld * stockReference
	diagnostics.Muzzle.CFrame = receiverWorld * muzzleReference
	diagnostics.Top.CFrame = receiverWorld * topReference
	diagnostics.Bottom.CFrame = receiverWorld * bottomReference
	diagnostics.Trigger.CFrame = receiverWorld * rightHandGrip
	diagnostics.Foregrip.CFrame = receiverWorld * foregrip
	diagnostics.RightTarget.CFrame = rightHandTarget.WorldCFrame
	diagnostics.LeftTarget.CFrame = leftHandTarget.WorldCFrame
	diagnostics.RightPole.CFrame = rightElbowPole.WorldCFrame
	diagnostics.LeftPole.CFrame = leftElbowPole.WorldCFrame
	diagnostics.ForwardAxis.CFrame = canonicalReceiverWorld * CFrame.new(0, 0, -axisLength * 0.5)
	diagnostics.UpAxis.CFrame = canonicalReceiverWorld * CFrame.new(0, axisLength * 0.5, 0)
	diagnostics.RightAxis.CFrame = canonicalReceiverWorld * CFrame.new(axisLength * 0.5, 0, 0)
end

function FirearmAimRig.Create(character, humanoid, rootPart)
	local geometryIsValid, geometryReason, sampleReport = validateConfiguredGeometry()
	if not geometryIsValid then return nil, geometryReason end
	if Config.DiagnosticsEnabled and not hasReportedDiagnostics then
		hasReportedDiagnostics = true
		print("[BLIKK FIREARM ORIENTATION] PASS " .. sampleReport)
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil, "arm IK currently requires an R15 rig"
	end

	local upperTorso = findBasePart(character, "UpperTorso")
	local rightUpperArm = findBasePart(character, "RightUpperArm")
	local rightLowerArm = findBasePart(character, "RightLowerArm")
	local rightHand = findBasePart(character, "RightHand")
	local leftUpperArm = findBasePart(character, "LeftUpperArm")
	local leftHand = findBasePart(character, "LeftHand")
	local rightShoulder = findAttachment(upperTorso, "RightShoulderRigAttachment")
	local leftShoulder = findAttachment(upperTorso, "LeftShoulderRigAttachment")
	local upperArmLength = attachmentDistance(
		rightUpperArm,
		"RightShoulderRigAttachment",
		"RightElbowRigAttachment"
	)
	local lowerArmLength = attachmentDistance(
		rightLowerArm,
		"RightElbowRigAttachment",
		"RightWristRigAttachment"
	)
	local rightWrist = findAttachment(rightHand, "RightWristRigAttachment")
	if not upperTorso or not rightUpperArm or not rightLowerArm or not rightHand
		or not leftUpperArm or not leftHand or not rightShoulder or not leftShoulder
		or not upperArmLength or not lowerArmLength or not rightWrist then
		return nil, "required R15 arm parts or shoulder attachments are unavailable"
	end
	local shoulderWidth = (rightShoulder.Position - leftShoulder.Position).Magnitude
	local torsoHeight = upperTorso.Size.Y
	local armReach = upperArmLength + lowerArmLength + rightWrist.Position.Magnitude
	if shoulderWidth < 0.001 or torsoHeight < 0.001 or armReach < 0.001 then
		return nil, "R15 body scale produced invalid firearm pose landmarks"
	end

	local owned = {}
	local succeeded, result = pcall(function()
		local diagnostics = createDiagnostics(owned)
		local rightHandTarget = createTarget(rootPart, "BLIKK_FirearmRightHandTarget", owned)
		local leftHandTarget = createTarget(rootPart, "BLIKK_FirearmLeftHandTarget", owned)
		local rightElbowPole = createTarget(rootPart, "BLIKK_FirearmRightElbowPole", owned)
		local leftElbowPole = createTarget(rootPart, "BLIKK_FirearmLeftElbowPole", owned)

		local rightControl = createControl(
			humanoid,
			"BLIKK_FirearmRightArmAim",
			rightUpperArm,
			rightHand,
			rightHandTarget,
			rightElbowPole,
			Config.AimIK.RightArmPriority,
			Enum.IKControlType.Transform,
			owned
		)
		local leftControl = createControl(
			humanoid,
			"BLIKK_FirearmLeftArmSupport",
			leftUpperArm,
			leftHand,
			leftHandTarget,
			leftElbowPole,
			Config.AimIK.LeftArmPriority,
			Enum.IKControlType.Position,
			owned
		)

		return setmetatable({
			Character = character,
			Humanoid = humanoid,
			RootPart = rootPart,
			UpperTorso = upperTorso,
			RightHand = rightHand,
			RightShoulder = rightShoulder,
			LeftShoulder = leftShoulder,
			ShoulderWidth = shoulderWidth,
			TorsoHeight = torsoHeight,
			ArmReach = armReach,
			RightHandTarget = rightHandTarget,
			LeftHandTarget = leftHandTarget,
			RightElbowPole = rightElbowPole,
			LeftElbowPole = leftElbowPole,
			RightControl = rightControl,
			LeftControl = leftControl,
			Diagnostics = diagnostics,
			IsEnabled = false,
			IsDestroyed = false,
			HasSolvedPose = false,
		}, Rig)
	end)
	if not succeeded then
		for index = #owned, 1, -1 do owned[index]:Destroy() end
		return nil, "IKControl construction failed: " .. tostring(result)
	end
	return result, nil
end

function Rig:SetEnabled(enabled)
	if self.IsDestroyed or self.IsEnabled == enabled then return end
	self.IsEnabled = enabled
	self.RightControl.Enabled = enabled
	self.LeftControl.Enabled = enabled
end

function Rig:HasPose()
	return not self.IsDestroyed and self.HasSolvedPose
end

function Rig:Update(model, grip, aimDirection, recoilAlpha)
	if self.IsDestroyed or self.Character.Parent == nil or self.Humanoid.Health <= 0
		or self.RootPart.Parent ~= self.Character or self.UpperTorso.Parent ~= self.Character
		or self.RightShoulder.Parent ~= self.UpperTorso or self.LeftShoulder.Parent ~= self.UpperTorso then
		return false, "the bound character is no longer usable"
	end
	local receiver = model and model.PrimaryPart
	local muzzleReference = receiver and receiver:FindFirstChild("MuzzleReference")
	local stockReference = receiver and receiver:FindFirstChild("StockReference")
	local topReference = receiver and receiver:FindFirstChild("WeaponTopReference")
	local bottomReference = receiver and receiver:FindFirstChild("WeaponBottomReference")
	local rightHandGrip = receiver and receiver:FindFirstChild("RightHandGripAttachment")
	local foregrip = receiver and receiver:FindFirstChild("ForegripAttachment")
	if not receiver or not muzzleReference or not muzzleReference:IsA("Attachment")
		or not stockReference or not stockReference:IsA("Attachment")
		or not topReference or not topReference:IsA("Attachment")
		or not bottomReference or not bottomReference:IsA("Attachment")
		or not rightHandGrip or not rightHandGrip:IsA("Attachment")
		or not foregrip or not foregrip:IsA("Attachment")
		then
		return false, "the equipped B-8 is missing canonical orientation or grip geometry"
	end
	if not grip or not grip:IsA("Motor6D") or grip.Part0 ~= self.RightHand or grip.Part1 ~= receiver then
		return false, "the equipped B-8 right-hand grip is invalid"
	end
	if grip.C0 ~= rightHandGrip.CFrame:Inverse()
		or grip.C1 ~= CFrame.identity or grip.Transform ~= CFrame.identity then
		return false, "the equipped B-8 hand joint no longer matches its canonical grip"
	end
	if not finiteVector(aimDirection) or aimDirection.Magnitude < 0.001 then
		self:SetEnabled(false)
		return true, nil
	end

	-- Presentation pitch comes only from the camera direction in root space. Neither
	-- weapon geometry nor the preceding IK result can feed back into this basis.
	local localDirection = self.RootPart.CFrame:VectorToObjectSpace(aimDirection.Unit)
	local basePitchDegrees = math.clamp(
		math.deg(math.asin(math.clamp(localDirection.Y, -1, 1))),
		Config.AimPitchMinimumDegrees,
		Config.AimPitchMaximumDegrees
	)
	local recoil = math.clamp(recoilAlpha, 0, 1)
	local pitchDegrees = basePitchDegrees + FeedbackConfig.Recoil.PitchDegrees * recoil
	local rootRotation = self.RootPart.CFrame.Rotation
	local aimPivotWorld = CFrame.new(self.RightShoulder.WorldPosition) * rootRotation
	local neutralReceiverFromAimPivot = CFrame.new(
		-self.ShoulderWidth * Config.AimIK.NeutralReceiverInwardShoulderWidths,
		-self.TorsoHeight * Config.AimIK.NeutralReceiverDownTorsoHeights,
		-self.ArmReach * Config.AimIK.NeutralReceiverForwardArmReaches
	)
	local pitchRotation = CFrame.Angles(math.rad(pitchDegrees), 0, 0)
	local neutralCanonicalReceiverWorld = aimPivotWorld * neutralReceiverFromAimPivot
	local neutralReceiverWorld = neutralCanonicalReceiverWorld * Config.GeometryToCanonical
	local stockWorldPosition = (neutralReceiverWorld * stockReference.CFrame).Position
	local pitchBasis = rootRotation * pitchRotation
	local forward = pitchBasis.LookVector
	local upHint = self.RootPart.CFrame.UpVector
	local right = forward:Cross(upHint).Unit
	local correctedUp = right:Cross(forward).Unit
	stockWorldPosition -= forward * FeedbackConfig.Recoil.BackwardTravelStuds * recoil
	local desiredStockWorld = CFrame.fromMatrix(stockWorldPosition, right, correctedUp, -forward)
	local receiverWorld = desiredStockWorld
		* stockReference.CFrame:Inverse()
		* Config.GeometryToCanonical
	local canonicalReceiverWorld = receiverWorld * Config.GeometryToCanonical:Inverse()
	local passed, forwardDot, upDot, muzzleAhead, topAbove,
		triggerHeight, foregripHeight, foregripAhead = validateReceiverOrientation(
		receiverWorld,
		muzzleReference.CFrame,
		stockReference.CFrame,
		topReference.CFrame,
		bottomReference.CFrame,
		rightHandGrip.CFrame,
		foregrip.CFrame,
		forward,
		correctedUp,
		upHint
	)
	if not passed then
		return false, string.format(
			"orientation validation failed (forwardDot=%.4f, upDot=%.4f, muzzleAhead=%.4f, "
				.. "topAbove=%.4f, triggerHeight=%.4f, foregripHeight=%.4f, foregripAhead=%.4f, "
				.. "muzzle=%s, stock=%s, top=%s, bottom=%s)",
			forwardDot,
			upDot,
			muzzleAhead,
			topAbove,
			triggerHeight,
			foregripHeight,
			foregripAhead,
			tostring((receiverWorld * muzzleReference.CFrame).Position),
			tostring((receiverWorld * stockReference.CFrame).Position),
			tostring((receiverWorld * topReference.CFrame).Position),
			tostring((receiverWorld * bottomReference.CFrame).Position)
		)
	end
	local rightHandWorld = receiverWorld * rightHandGrip.CFrame
	local leftHandWorld = receiverWorld * foregrip.CFrame
	self.RightHandTarget.CFrame = self.RootPart.CFrame:ToObjectSpace(rightHandWorld)
	self.LeftHandTarget.CFrame = self.RootPart.CFrame:ToObjectSpace(leftHandWorld)

	local poleBasisWorld = CFrame.fromMatrix(
		self.RightShoulder.WorldPosition,
		right,
		correctedUp,
		-forward
	)
	local rightPoleOffset = Vector3.new(
		self.ShoulderWidth * Config.AimIK.RightElbowPoleOutwardShoulderWidths,
		-self.TorsoHeight * Config.AimIK.RightElbowPoleDownTorsoHeights,
		self.ArmReach * Config.AimIK.RightElbowPoleRearwardArmReaches
	)
	local leftPoleOffset = Vector3.new(
		-self.ShoulderWidth * Config.AimIK.LeftElbowPoleOutwardShoulderWidths,
		-self.TorsoHeight * Config.AimIK.LeftElbowPoleDownTorsoHeights,
		-self.ArmReach * Config.AimIK.LeftElbowPoleForwardArmReaches
	)
	local rightPolePosition = self.RightShoulder.WorldPosition
		+ poleBasisWorld:VectorToWorldSpace(rightPoleOffset)
	local leftPolePosition = self.LeftShoulder.WorldPosition
		+ poleBasisWorld:VectorToWorldSpace(leftPoleOffset)
	self.RightElbowPole.CFrame = self.RootPart.CFrame:ToObjectSpace(CFrame.new(rightPolePosition))
	self.LeftElbowPole.CFrame = self.RootPart.CFrame:ToObjectSpace(CFrame.new(leftPolePosition))
	updateDiagnostics(
		self.Diagnostics,
		receiverWorld,
		canonicalReceiverWorld,
		muzzleReference.CFrame,
		stockReference.CFrame,
		topReference.CFrame,
		bottomReference.CFrame,
		rightHandGrip.CFrame,
		foregrip.CFrame,
		self.RightHandTarget,
		self.LeftHandTarget,
		self.RightElbowPole,
		self.LeftElbowPole
	)
	self.HasSolvedPose = true
	self:SetEnabled(true)
	return true, nil
end

function Rig:Destroy()
	if self.IsDestroyed then return end
	self.IsDestroyed = true
	self.IsEnabled = false
	if self.Diagnostics then
		self.Diagnostics.Folder:Destroy()
		self.Diagnostics = nil
	end
	self.RightControl:Destroy()
	self.LeftControl:Destroy()
	self.RightHandTarget:Destroy()
	self.LeftHandTarget:Destroy()
	self.RightElbowPole:Destroy()
	self.LeftElbowPole:Destroy()
end

return FirearmAimRig
