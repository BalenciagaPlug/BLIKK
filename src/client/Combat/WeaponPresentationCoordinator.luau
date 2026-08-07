local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local Coordinator = {}
local player = Players.LocalPlayer
local generation = 0
local boundCharacter = nil
local isInitialised = false

local REQUIRED = {
	"BLIKK_ClientMeleeReady",
	"BLIKK_ClientPrimary1Ready",
	"BLIKK_ClientPrimary2Ready",
}

local function bindCharacter(character)
	generation += 1
	local bindGeneration = generation
	boundCharacter = character
	character:SetAttribute("BLIKK_ClientWeaponReady", nil)
	task.spawn(function()
		local deadline = os.clock() + math.max(
			1,
			MultiplayerConfig.RequiredClientReadinessTimeoutSeconds - 2
		)
		repeat
			if bindGeneration ~= generation or player.Character ~= character then return end
			local ready = true
			for _, attribute in REQUIRED do
				if character:GetAttribute(attribute) ~= true then ready = false; break end
			end
			if ready then character:SetAttribute("BLIKK_ClientWeaponReady", true); return end
			RunService.Heartbeat:Wait()
		until os.clock() >= deadline
		if bindGeneration == generation and player.Character == character then
			local missing = {}
			for _, attribute in REQUIRED do
				if character:GetAttribute(attribute) ~= true then table.insert(missing, attribute) end
			end
			warn("[BLIKK WEAPONS] Presentation readiness timed out.\nMissing: " .. table.concat(missing, ", "))
		end
	end)
end

function Coordinator:Init()
	if isInitialised then return end
	isInitialised = true
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(character)
		if character ~= boundCharacter then return end
		generation += 1
		boundCharacter = nil
	end)
	if player.Character then bindCharacter(player.Character) end
end

return Coordinator
