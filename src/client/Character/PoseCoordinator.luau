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
		if joint and joint.Parent then joint.Transform = CFrame.identity end
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
		return true
	end
	local function register(descendant)
		if not descendant:IsA("Motor6D") then return end
		local alias = aliases[descendant.Name:gsub(" ", "")]
		if alias then
			joints[alias] = descendant
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
	for _, claim in claims do
		for alias, target in claim.Poses do
			local current = selected[alias]
			if not current or claim.Priority > current.Priority
				or claim.Priority == current.Priority and claim.Serial > current.Serial then
				selected[alias] = {
					Priority = claim.Priority,
					Serial = claim.Serial,
					Target = target,
					Blend = claim.Blend,
				}
			end
		end
	end
	for alias in applied do
		if not selected[alias] then
			local joint = joints[alias]
			if joint and joint.Parent then joint.Transform = CFrame.identity end
			applied[alias] = nil
		end
	end
	for alias, selection in selected do
		local joint = joints[alias]
		if joint and joint.Parent then
			joint.Transform = joint.Transform:Lerp(selection.Target, selection.Blend or 1)
			applied[alias] = true
		end
	end
end

function PoseCoordinator:Submit(owner, priority, poses, blend)
	if type(owner) ~= "string" or type(poses) ~= "table" then return end
	claimSerial += 1
	claims[owner] = { Priority = priority, Serial = claimSerial, Poses = poses, Blend = blend }
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
	RunService:BindToRenderStep(
		"BLIKKPoseCoordinator",
		Enum.RenderPriority.Character.Value + 10,
		applyClaims
	)
end

return PoseCoordinator
