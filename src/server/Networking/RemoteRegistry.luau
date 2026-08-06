local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = {}
local remotes = nil

local function getOrCreate(className, name)
	local existing = remotes:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, "Remote type mismatch for " .. name)
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

function RemoteRegistry:Init()
	if remotes then return self end
	remotes = ReplicatedStorage:FindFirstChild("BLIKKRemotes") or Instance.new("Folder")
	remotes.Name = "BLIKKRemotes"
	remotes.Parent = ReplicatedStorage
	self.RequestMovementLabSpawn = getOrCreate("RemoteEvent", "RequestMovementLabSpawn")
	self.CharacterProfilesRequest = getOrCreate("RemoteFunction", "CharacterProfilesRequest")
	self.CharacterProfilesUpdated = getOrCreate("RemoteEvent", "CharacterProfilesUpdated")
	return self
end

return RemoteRegistry
