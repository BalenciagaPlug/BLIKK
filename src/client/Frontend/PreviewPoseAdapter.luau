local PreviewPoseAdapter = {}

local ALIASES = {
	Root = "Root",
	RootJoint = "Root",
	Waist = "Waist",
	Neck = "Neck",
	RightShoulder = "RightShoulder",
	LeftShoulder = "LeftShoulder",
	RightElbow = "RightElbow",
	LeftElbow = "LeftElbow",
	RightWrist = "RightWrist",
	LeftWrist = "LeftWrist",
	RightHip = "RightHip",
	LeftHip = "LeftHip",
}

local EXPECTED_ENDPOINTS = {
	Root = { { "HumanoidRootPart", "LowerTorso" }, { "HumanoidRootPart", "Torso" } },
	Waist = { { "LowerTorso", "UpperTorso" } },
	Neck = { { "UpperTorso", "Head" }, { "Torso", "Head" } },
	RightShoulder = { { "UpperTorso", "RightUpperArm" }, { "Torso", "Right Arm" } },
	LeftShoulder = { { "UpperTorso", "LeftUpperArm" }, { "Torso", "Left Arm" } },
	RightElbow = { { "RightUpperArm", "RightLowerArm" } },
	LeftElbow = { { "LeftUpperArm", "LeftLowerArm" } },
	RightWrist = { { "RightLowerArm", "RightHand" } },
	LeftWrist = { { "LeftLowerArm", "LeftHand" } },
	RightHip = { { "LowerTorso", "RightUpperLeg" }, { "Torso", "Right Leg" } },
	LeftHip = { { "LowerTorso", "LeftUpperLeg" }, { "Torso", "Left Leg" } },
}

local function canonicalDirection(alias, part0, part1)
	for _, endpoints in EXPECTED_ENDPOINTS[alias] or {} do
		if part0.Name == endpoints[1] and part1.Name == endpoints[2] then return 1 end
		if part0.Name == endpoints[2] and part1.Name == endpoints[1] then return -1 end
	end
	return nil
end

local function resolveMotor(joint)
	local alias = ALIASES[joint.Name:gsub(" ", "")]
	local part0, part1 = joint.Part0, joint.Part1
	if not alias or not part0 or not part1 then return nil end
	local direction = canonicalDirection(alias, part0, part1)
	if not direction then return nil end
	joint:SetAttribute("BLIKK_PreviewPoseJoint", true)
	return alias, { Joint = joint, IsReversed = direction < 0 }
end

function PreviewPoseAdapter.Collect(model, pose)
	local joints = {}
	-- Match live capability exactly. PoseCoordinator discovers Motor6D joints only, so
	-- EquippedIdle must not be applied to an upgraded AnimationConstraint preview rig.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local requestedAlias = ALIASES[descendant.Name:gsub(" ", "")]
			if requestedAlias and pose[requestedAlias] and not joints[requestedAlias] then
				local alias, entry = resolveMotor(descendant)
				if alias then joints[alias] = entry end
			end
		end
	end
	return joints
end

function PreviewPoseAdapter.Apply(joints, pose)
	for alias, degrees in pose do
		local entry = joints[alias]
		local joint = entry and entry.Joint
		if joint and joint.Parent then
			local target = CFrame.Angles(
				math.rad(degrees.X),
				math.rad(degrees.Y),
				math.rad(degrees.Z)
			)
			-- EquippedIdle is the absolute Transform target used by the live coordinator
			-- on the legacy Motor6D capability path.
			joint.Transform = if entry.IsReversed then target:Inverse() else target
		end
	end
end

return PreviewPoseAdapter
