local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local PoseCoordinator = {}

local player = Players.LocalPlayer
local claims = {}
local joints = {}
local applied = {}
local generation = 0
local claimSerial = 0
local boundCharacter = nil
local descendantConnection = nil
local isInitialised = false
local BIND_TIMEOUT_SECONDS = MultiplayerConfig.CharacterDependencyTimeoutSeconds

local aliases = {
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

local EXPECTED_CAPABILITIES = { "Root", "Waist", "RightShoulder", "LeftShoulder" }

local function clearApplied()
	for alias in applied do
		local joint = joints[alias]
		if joint and joint.Parent then
			joint.Transform = CFrame.identity
		end
	end
	table.clear(applied)
end

local function bindCharacter(character)
	generation += 1
	local bindGeneration = generation
	clearApplied()
	if descendantConnection then descendantConnection:Disconnect(); descendantConnection = nil end
	table.clear(claims)
	table.clear(joints)
	boundCharacter = character
	character:SetAttribute("BLIKK_ClientPoseReady", nil)
	character:SetAttribute("BLIKK_ClientPoseJointType", nil)
	local function hasAllCapabilities()
		for _, alias in EXPECTED_CAPABILITIES do
			if not joints[alias] then return false end
		end
		return true
	end
	local function markReady()
		if not hasAllCapabilities() or bindGeneration ~= generation
			or player.Character ~= character or not character.Parent then return false end
		character:SetAttribute("BLIKK_ClientPoseReady", true)
		character:SetAttribute("BLIKK_ClientPoseJointType", joints.Root.ClassName)
		return true
	end
	local function register(descendant)
		if not descendant:IsA("AnimationConstraint") and not descendant:IsA("Motor6D") then return end
		local alias = aliases[descendant.Name:gsub(" ", "")]
		if alias then
			local current = joints[alias]
			-- Avatar Joint Upgrade characters can temporarily expose compatibility
			-- joints while they assemble. Prefer the engine's final constraint joint.
			if descendant:IsA("AnimationConstraint") or not current or not current.Parent then
				joints[alias] = descendant
			end
			markReady()
		end
	end
	for _, descendant in character:GetDescendants() do register(descendant) end
	descendantConnection = character.DescendantAdded:Connect(function(descendant)
		if bindGeneration == generation and boundCharacter == character then register(descendant) end
	end)
	markReady()
	task.spawn(function()
		local deadline = os.clock() + BIND_TIMEOUT_SECONDS
		repeat
			if bindGeneration ~= generation or player.Character ~= character or not character.Parent then return end
			for _, descendant in character:GetDescendants() do register(descendant) end
			if markReady() then return end
			RunService.Heartbeat:Wait()
		until os.clock() >= deadline
		if bindGeneration ~= generation or player.Character ~= character or not character.Parent then return end
		local discovered = {}
		local missing = {}
		for alias, joint in joints do
			if joint and joint.Parent then table.insert(discovered, alias) end
		end
		for _, alias in EXPECTED_CAPABILITIES do
			if not joints[alias] then table.insert(missing, alias) end
		end
		table.sort(discovered)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if #discovered == 0 then
			warn(string.format(
				"[BLIKK POSE] No supported Motor6D or AnimationConstraint "
					.. "pose joint graph found. RigType=%s Missing=%s",
				humanoid and humanoid.RigType.Name or "Unknown",
				table.concat(missing, ",")
			))
			return
		end
		warn(string.format(
			"[BLIKK POSE] Partial pose capability. RigType=%s Discovered=%s Missing=%s",
			humanoid and humanoid.RigType.Name or "Unknown",
			table.concat(discovered, ","),
			table.concat(missing, ",")
		))
	end)
end

local function applyClaims()
	local selected = {}
	for owner, claim in claims do
		for alias, target in claim.Poses do
			local current = selected[alias]
			local priority = math.max(claim.Priority, claim.PriorityOverrides[alias] or claim.Priority)
			if not current or priority > current.Priority
				or priority == current.Priority and claim.Serial > current.Serial then
				selected[alias] = {
					Owner = owner,
					Priority = priority,
					Serial = claim.Serial,
					Target = target,
					Blend = claim.Blend,
					SuppressAnimator = claim.SuppressAnimator[alias] == true,
					StableReference = claim.StableReference[alias] == true,
				}
			end
		end
	end
	for alias in applied do
		if not selected[alias] then
			local joint = joints[alias]
			if joint and joint.Parent then
				joint.Transform = CFrame.identity
			end
			applied[alias] = nil
		end
	end
	for alias, selection in selected do
		local joint = joints[alias]
		if joint and joint.Parent then
			local blend = selection.Blend or 1
			if selection.SuppressAnimator then
				-- Weapon-bearing limbs must not inherit the Animator's walk-cycle arm
				-- swing. Advance from our last resolved weapon pose each frame so a
				-- smooth recovery actually reaches idle instead of freezing after its
				-- first blended frame.
				local previous = applied[alias]
				local sameOwner = previous and previous.SuppressAnimator
					and previous.Owner == selection.Owner
				local reference = if sameOwner and previous.StableReference
					then previous.StableReference else joint.Transform
				local from = if selection.StableReference
					then (if sameOwner then previous.ResolvedTarget else reference)
					else if sameOwner then previous.ResolvedTarget else joint.Transform
				local resolved = from:Lerp(selection.Target, blend)
				joint.Transform = resolved
				applied[alias] = {
					Owner = selection.Owner,
					Target = selection.Target,
					ResolvedTarget = resolved,
					SuppressAnimator = true,
					StableReference = if selection.StableReference then reference else nil,
				}
			elseif joint:IsA("AnimationConstraint") then
				-- Animator evaluates before PreSimulation. Layering the procedural
				-- offset here preserves locomotion and avatar retargeting underneath.
				joint.Transform = CFrame.identity:Lerp(selection.Target, blend) * joint.Transform
			else
				joint.Transform = joint.Transform:Lerp(selection.Target, blend)
				applied[alias] = { Owner = selection.Owner, SuppressAnimator = false }
			end
		end
	end
end

function PoseCoordinator:Submit(owner, priority, poses, blend, options)
	if type(owner) ~= "string" or type(poses) ~= "table" then return end
	options = if type(options) == "table" then options else {}
	claimSerial += 1
	claims[owner] = {
		Priority = priority,
		Serial = claimSerial,
		Poses = poses,
		Blend = blend,
		SuppressAnimator = if type(options.SuppressAnimator) == "table"
			then options.SuppressAnimator else {},
		StableReference = if type(options.StableReference) == "table"
			then options.StableReference else {},
		PriorityOverrides = if type(options.PriorityOverrides) == "table"
			then options.PriorityOverrides else {},
	}
end

function PoseCoordinator:Release(owner)
	claims[owner] = nil
end

function PoseCoordinator:Init()
	if isInitialised then return end
	isInitialised = true
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(character)
		if character ~= boundCharacter then return end
		generation += 1
		if descendantConnection then descendantConnection:Disconnect(); descendantConnection = nil end
		clearApplied()
		table.clear(claims)
		table.clear(joints)
		boundCharacter = nil
	end)
	if player.Character then bindCharacter(player.Character) end
	-- AnimationConstraint.Transform is written by Animator after PreAnimation;
	-- PreSimulation is the supported phase for a procedural layer.
	RunService.PreSimulation:Connect(applyClaims)
end

return PoseCoordinator
